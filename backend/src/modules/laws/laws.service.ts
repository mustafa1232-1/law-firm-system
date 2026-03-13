import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import {
  buildSearchTerms,
  buildTokenRegexConditions,
} from 'src/common/utils/search-query.util';
import { AuditService } from '../audit/audit.service';
import { CreateLawArticleDto } from './dto/create-law-article.dto';
import { CreateLawDto } from './dto/create-law.dto';
import { UpdateLawDto } from './dto/update-law.dto';
import { LawArticle, LawArticleDocument } from './schemas/law-article.schema';
import {
  LawDocumentEntity,
  LawDocumentEntityDocument,
} from './schemas/law-document.schema';

@Injectable()
export class LawsService {
  constructor(
    @InjectModel(LawDocumentEntity.name)
    private readonly lawModel: Model<LawDocumentEntityDocument>,
    @InjectModel(LawArticle.name)
    private readonly articleModel: Model<LawArticleDocument>,
    private readonly auditService: AuditService,
  ) {}

  private toArticleOrder(articleNumber: string, articleOrder?: number) {
    if (typeof articleOrder === 'number' && Number.isFinite(articleOrder) && articleOrder >= 0) {
      return articleOrder;
    }

    const numeric = Number(`${articleNumber ?? ''}`.replace(/[^\d]/g, ''));
    return Number.isFinite(numeric) && numeric >= 0 ? numeric : 0;
  }

  private toLatinDigits(value: string) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
    return `${value ?? ''}`
      .replace(/[٠-٩]/g, (char) => String(arabicIndic.indexOf(char)))
      .replace(/[۰-۹]/g, (char) => String(easternArabicIndic.indexOf(char)));
  }

  private tokenizeForScoring(value: string) {
    const normalized = normalizeArabic(this.toLatinDigits(value));
    if (!normalized) {
      return [] as string[];
    }

    return Array.from(
      new Set(
        normalized
          .split(/\s+/)
          .map((token) => token.replace(/[^\p{L}\p{N}]/gu, '').trim())
          .filter((token) => token.length >= 2 || /^\d+$/.test(token)),
      ),
    ).slice(0, 12);
  }

  private normalizeTokenVariants(token: string) {
    const variants = new Set<string>();
    const value = token.trim();
    if (!value) {
      return [] as string[];
    }

    variants.add(value);
    if (value.startsWith('ال') && value.length > 3) {
      variants.add(value.slice(2));
    }
    if (!value.startsWith('ال') && value.length > 2) {
      variants.add(`ال${value}`);
    }
    return Array.from(variants);
  }

  private extractNumbers(value: string) {
    const latin = this.toLatinDigits(value);
    const matches = latin.match(/\d+/g) ?? [];
    return Array.from(new Set(matches.map((item) => item.trim()).filter(Boolean)));
  }

  async createLaw(dto: CreateLawDto, actorId?: string) {
    const law = await this.lawModel.create(dto);
    await this.auditService.record({
      action: 'law.create',
      entity: 'law_documents',
      entityId: law.id,
      actorId,
    });
    return law;
  }

  async updateLaw(id: string, dto: UpdateLawDto, actorId?: string) {
    const law = await this.lawModel.findByIdAndUpdate(id, dto, { new: true }).lean();
    if (!law) {
      throw new NotFoundException('Law not found');
    }
    await this.auditService.record({
      action: 'law.update',
      entity: 'law_documents',
      entityId: id,
      actorId,
    });
    return law;
  }

  async createArticle(dto: CreateLawArticleDto, actorId?: string) {
    const lawExists = await this.lawModel.exists({ _id: dto.lawId });
    if (!lawExists) {
      throw new NotFoundException('Law not found');
    }

    const article = await this.articleModel.create({
      ...dto,
      lawId: new Types.ObjectId(dto.lawId),
      articleOrder: this.toArticleOrder(dto.articleNumber, dto.articleOrder),
      normalizedText: normalizeArabic(dto.text),
    });

    await this.auditService.record({
      action: 'law.article.create',
      entity: 'law_articles',
      entityId: article.id,
      actorId,
    });

    return article;
  }

  async findAll(query: PaginationQueryDto, q?: string) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const terms = buildSearchTerms(q);

    const filter = terms.rawQuery
      ? {
          $or: [
            { title: { $regex: terms.escapedRawQuery, $options: 'i' } },
            { legalDomain: { $regex: terms.escapedRawQuery, $options: 'i' } },
            { lawNumber: { $regex: terms.escapedRawQuery, $options: 'i' } },
            ...buildTokenRegexConditions('title', terms.rawTokens),
            ...buildTokenRegexConditions('legalDomain', terms.rawTokens),
            ...buildTokenRegexConditions('lawNumber', terms.rawTokens),
            ...buildTokenRegexConditions('keywords', terms.rawTokens),
          ],
        }
      : {};

    const [items, total] = await Promise.all([
      this.lawModel
        .find(filter)
        .sort({ year: -1, lawNumber: 1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.lawModel.countDocuments(filter),
    ]);

    return { items, total, page, limit };
  }

  async search(q: string, query: PaginationQueryDto) {
    const terms = buildSearchTerms(q);
    const rawQuery = terms.rawQuery;
    const { page, limit } = query;

    if (!rawQuery) {
      const lawsPage = await this.findAll(query);
      return {
        query: rawQuery,
        laws: lawsPage.items,
        articles: [],
        totalLaws: lawsPage.total,
        note: 'تم عرض القوانين المتاحة. يمكن إدخال عبارة بحث لتضييق النتائج.',
      };
    }

    const skip = (page - 1) * limit;
    const candidateCap = Math.min(2000, Math.max(400, skip + limit * 8));
    const queryTokens = this.tokenizeForScoring(rawQuery);
    const normalizedQuery = normalizeArabic(this.toLatinDigits(rawQuery));
    const queryNumbers = this.extractNumbers(rawQuery);

    const [lawCandidates, articleCandidates] = await Promise.all([
      this.lawModel
        .find({
          $or: [
            { title: { $regex: terms.escapedRawQuery, $options: 'i' } },
            { legalDomain: { $regex: terms.escapedRawQuery, $options: 'i' } },
            { lawNumber: { $regex: terms.escapedRawQuery, $options: 'i' } },
            ...buildTokenRegexConditions('title', terms.rawTokens),
            ...buildTokenRegexConditions('legalDomain', terms.rawTokens),
            ...buildTokenRegexConditions('lawNumber', terms.rawTokens),
            ...buildTokenRegexConditions('keywords', terms.rawTokens),
          ],
        })
        .limit(Math.min(300, candidateCap))
        .lean(),
      this.articleModel
        .find({
          $or: [
            { normalizedText: { $regex: terms.escapedNormalizedQuery, $options: 'i' } },
            { text: { $regex: terms.escapedRawQuery, $options: 'i' } },
            { articleNumber: { $regex: terms.escapedRawQuery, $options: 'i' } },
            ...buildTokenRegexConditions('normalizedText', terms.normalizedTokens),
            ...buildTokenRegexConditions('text', terms.rawTokens),
            ...buildTokenRegexConditions('articleNumber', terms.rawTokens),
            ...buildTokenRegexConditions('keywords', terms.rawTokens),
          ],
        })
        .populate('lawId', 'title lawNumber year legalDomain')
        .limit(candidateCap)
        .lean(),
    ]);

    const scoredLaws = lawCandidates
      .map((law) => {
        const reasons: string[] = [];
        let score = 0;

        const title = (law.title ?? '').toString();
        const domain = (law.legalDomain ?? '').toString();
        const lawNumber = (law.lawNumber ?? '').toString();

        const normalizedTitle = normalizeArabic(this.toLatinDigits(title));
        const normalizedDomain = normalizeArabic(this.toLatinDigits(domain));
        const normalizedLawNumber = this.toLatinDigits(lawNumber);

        if (normalizedQuery && normalizedTitle.includes(normalizedQuery)) {
          score += 120;
          reasons.push('مطابقة مباشرة في اسم القانون');
        }

        if (normalizedQuery && normalizedDomain.includes(normalizedQuery)) {
          score += 70;
          reasons.push('مطابقة في المجال القانوني');
        }

        if (queryNumbers.some((number) => normalizedLawNumber === number)) {
          score += 110;
          reasons.push('مطابقة رقم القانون');
        }

        for (const token of queryTokens) {
          const variants = this.normalizeTokenVariants(token);
          const titleMatch = variants.some((variant) => normalizedTitle.includes(variant));
          const domainMatch = variants.some((variant) => normalizedDomain.includes(variant));

          if (titleMatch) {
            score += 18;
          }
          if (domainMatch) {
            score += 12;
          }
        }

        if (!reasons.length && score > 0) {
          reasons.push('تشابه في الكلمات القانونية');
        }

        return {
          law,
          score,
          reasons,
        };
      })
      .filter((item) => item.score > 0)
      .sort((a, b) => {
        if (b.score !== a.score) {
          return b.score - a.score;
        }
        return Number(b.law.year ?? 0) - Number(a.law.year ?? 0);
      });

    const scoredArticles = articleCandidates
      .map((article) => {
        const reasons: string[] = [];
        let score = 0;

        const text = (article.text ?? '').toString();
        const normalizedText = normalizeArabic(this.toLatinDigits(text));
        const articleNumber = this.toLatinDigits((article.articleNumber ?? '').toString());
        const lawRef = (article.lawId ?? {}) as Record<string, unknown>;
        const lawTitle = (lawRef.title ?? '').toString();
        const normalizedLawTitle = normalizeArabic(this.toLatinDigits(lawTitle));
        const lawNumber = this.toLatinDigits((lawRef.lawNumber ?? '').toString());

        if (queryNumbers.some((number) => number === articleNumber)) {
          score += 160;
          reasons.push('مطابقة رقم المادة');
        }

        if (normalizedQuery && normalizedText.includes(normalizedQuery)) {
          score += 120;
          reasons.push('مطابقة مباشرة داخل نص المادة');
        }

        if (queryNumbers.some((number) => number === lawNumber)) {
          score += 45;
          reasons.push('مرتبطة برقم القانون المطلوب');
        }

        if (normalizedQuery && normalizedLawTitle.includes(normalizedQuery)) {
          score += 45;
          reasons.push('مرتبطة بقانون مطابق للاستعلام');
        }

        for (const token of queryTokens) {
          const variants = this.normalizeTokenVariants(token);
          const textMatch = variants.some((variant) => normalizedText.includes(variant));
          const lawTitleMatch = variants.some((variant) =>
            normalizedLawTitle.includes(variant),
          );

          if (textMatch) {
            score += 14;
          }
          if (lawTitleMatch) {
            score += 8;
          }
        }

        if (!reasons.length && score > 0) {
          reasons.push('تشابه لغوي مع طلب البحث');
        }

        return {
          article,
          score,
          reasons,
        };
      })
      .filter((item) => item.score > 0)
      .sort((a, b) => {
        if (b.score !== a.score) {
          return b.score - a.score;
        }
        const aOrder = Number(a.article.articleOrder ?? 0);
        const bOrder = Number(b.article.articleOrder ?? 0);
        return aOrder - bOrder;
      });

    const pagedLaws = scoredLaws.slice(skip, skip + limit).map((item) => ({
      ...item.law,
      relevanceScore: item.score,
      relevanceReason: item.reasons[0] ?? 'تشابه في الكلمات القانونية',
      relevanceReasons: item.reasons,
    }));

    const pagedArticles = scoredArticles.slice(skip, skip + limit).map((item) => ({
      ...item.article,
      relevanceScore: item.score,
      relevanceReason: item.reasons[0] ?? 'تشابه لغوي مع طلب البحث',
      relevanceReasons: item.reasons,
    }));

    return {
      query: rawQuery,
      normalizedQuery,
      queryTokens,
      numbersDetected: queryNumbers,
      laws: pagedLaws,
      articles: pagedArticles,
      totalLaws: scoredLaws.length,
      totalArticles: scoredArticles.length,
      page,
      limit,
      note: 'تم ترتيب النتائج حسب درجة الصلة النصية والرقمية. المخرجات تحتاج مراجعة قانونية مهنية.',
    };
  }

  async findLawById(id: string) {
    const law = await this.lawModel.findById(id).lean();
    if (!law) {
      throw new NotFoundException('Law not found');
    }
    return law;
  }

  async findArticleById(id: string) {
    const article = await this.articleModel
      .findById(id)
      .populate('lawId', 'title lawNumber year issuingBody legalDomain')
      .lean();
    if (!article) {
      throw new NotFoundException('Law article not found');
    }
    return article;
  }

  async findLawArticles(id: string, query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const lawObjectId = new Types.ObjectId(id);

    const [items, total] = await Promise.all([
      this.articleModel
        .aggregate([
          { $match: { lawId: lawObjectId } },
          {
            $addFields: {
              articleOrderSort: {
                $cond: [
                  { $gt: [{ $ifNull: ['$articleOrder', 0] }, 0] },
                  '$articleOrder',
                  {
                    $convert: {
                      input: '$articleNumber',
                      to: 'int',
                      onError: 0,
                      onNull: 0,
                    },
                  },
                ],
              },
            },
          },
          { $sort: { articleOrderSort: 1, articleNumber: 1 } },
          { $skip: skip },
          { $limit: limit },
          { $project: { articleOrderSort: 0 } },
        ])
        .exec(),
      this.articleModel.countDocuments({ lawId: lawObjectId }),
    ]);

    return { items, total, page, limit };
  }
}
