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

    const [laws, articles] = await Promise.all([
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
        .skip(skip)
        .limit(limit)
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
        .skip(skip)
        .limit(limit)
        .lean(),
    ]);

    return {
      query: rawQuery,
      laws,
      articles,
      note: 'نتائج البحث تعتمد على الفهرسة النصية وقد تحتاج مراجعة قانونية إضافية.',
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
