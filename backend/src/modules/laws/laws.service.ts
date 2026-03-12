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

  async search(q: string, query: PaginationQueryDto) {
    const terms = buildSearchTerms(q);
    const rawQuery = terms.rawQuery;
    const { page, limit } = query;

    if (!rawQuery) {
      return {
        query: rawQuery,
        laws: [],
        articles: [],
        note: 'يرجى إدخال عبارة بحث.',
      };
    }

    const skip = (page - 1) * limit;

    const [laws, articles] = await Promise.all([
      this.lawModel
        .find({
          $or: [
            { title: { $regex: terms.escapedRawQuery, $options: 'i' } },
            { category: { $regex: terms.escapedRawQuery, $options: 'i' } },
            ...buildTokenRegexConditions('title', terms.rawTokens),
            ...buildTokenRegexConditions('category', terms.rawTokens),
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
            ...buildTokenRegexConditions('normalizedText', terms.normalizedTokens),
            ...buildTokenRegexConditions('text', terms.rawTokens),
          ],
        })
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

  async findLawArticles(id: string, query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.articleModel
        .find({ lawId: new Types.ObjectId(id) })
        .sort({ articleNumber: 1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.articleModel.countDocuments({ lawId: new Types.ObjectId(id) }),
    ]);

    return { items, total, page, limit };
  }
}
