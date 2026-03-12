import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import { AuditService } from '../audit/audit.service';
import { CreateConstitutionArticleDto } from './dto/create-constitution-article.dto';
import { UpdateConstitutionArticleDto } from './dto/update-constitution-article.dto';
import {
  ConstitutionArticle,
  ConstitutionArticleDocument,
} from './schemas/constitution-article.schema';

@Injectable()
export class ConstitutionService {
  constructor(
    @InjectModel(ConstitutionArticle.name)
    private readonly articleModel: Model<ConstitutionArticleDocument>,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateConstitutionArticleDto, actorId?: string) {
    const normalizedText = normalizeArabic(dto.text);
    const article = await this.articleModel.create({ ...dto, normalizedText });
    await this.auditService.record({
      action: 'constitution.article.create',
      entity: 'constitution_articles',
      entityId: article.id,
      actorId,
    });
    return article;
  }

  async findAll(query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.articleModel
        .find()
        .sort({ articleNumber: 1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.articleModel.countDocuments(),
    ]);
    return { items, total, page, limit };
  }

  async search(q: string, query: PaginationQueryDto) {
    const normalized = normalizeArabic(q ?? '');
    const { page, limit } = query;
    const skip = (page - 1) * limit;

    const filter = {
      $or: [
        { articleNumber: { $regex: q, $options: 'i' } },
        { $text: { $search: q } },
        { normalizedText: { $regex: normalized, $options: 'i' } },
      ],
    };

    const [items, total] = await Promise.all([
      this.articleModel.find(filter).skip(skip).limit(limit).lean(),
      this.articleModel.countDocuments(filter),
    ]);

    return {
      items,
      total,
      page,
      limit,
      query: q,
      note:
        'نتائج البحث أولية وتعتمد على النصوص المفهرسة داخل قاعدة بيانات النظام.',
    };
  }

  async findOne(id: string) {
    const article = await this.articleModel.findById(id).lean();
    if (!article) {
      throw new NotFoundException('Constitution article not found');
    }
    return article;
  }

  async update(id: string, dto: UpdateConstitutionArticleDto, actorId?: string) {
    const payload: Record<string, unknown> = { ...dto };
    if (dto.text) {
      payload.normalizedText = normalizeArabic(dto.text);
    }
    const article = await this.articleModel
      .findByIdAndUpdate(id, payload, { new: true })
      .lean();
    if (!article) {
      throw new NotFoundException('Constitution article not found');
    }

    await this.auditService.record({
      action: 'constitution.article.update',
      entity: 'constitution_articles',
      entityId: id,
      actorId,
    });
    return article;
  }

  async ensureSeed() {
    const exists = await this.articleModel.countDocuments();
    if (exists > 0) {
      return { seeded: false, reason: 'already-exists' };
    }

    const seed = [
      {
        articleNumber: '2',
        chapter: 'الباب الأول',
        section: 'المبادئ الأساسية',
        title: 'دين الدولة',
        text: 'الإسلام دين الدولة الرسمي وهو مصدر أساس للتشريع.',
        keywords: ['الإسلام', 'التشريع'],
      },
      {
        articleNumber: '19',
        chapter: 'الباب الثاني',
        section: 'الحقوق والحريات',
        title: 'حق التقاضي',
        text: 'التقاضي حق مصون ومكفول للجميع.',
        keywords: ['التقاضي', 'الضمانات', 'حق التقاضي'],
      },
      {
        articleNumber: '23',
        chapter: 'الباب الثاني',
        section: 'الحقوق والحريات',
        title: 'حماية الملكية',
        text: 'الملكية الخاصة مصونة ويحق للمالك الانتفاع بها ضمن حدود القانون.',
        keywords: ['الملكية', 'الحقوق'],
      },
    ];

    await this.articleModel.insertMany(
      seed.map((item) => ({
        ...item,
        normalizedText: normalizeArabic(item.text),
      })),
    );

    return { seeded: true, count: seed.length };
  }
}
