import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import {
  buildSearchTerms,
  buildTokenRegexConditions,
} from 'src/common/utils/search-query.util';
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
    const terms = buildSearchTerms(q);
    const rawQuery = terms.rawQuery;
    const { page, limit } = query;

    if (!rawQuery) {
      return {
        items: [],
        total: 0,
        page,
        limit,
        query: rawQuery,
        note: 'يرجى إدخال عبارة بحث صالحة.',
      };
    }

    const skip = (page - 1) * limit;

    const filter = {
      $or: [
        { articleNumber: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { title: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { text: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { normalizedText: { $regex: terms.escapedNormalizedQuery, $options: 'i' } },
        ...buildTokenRegexConditions('title', terms.rawTokens),
        ...buildTokenRegexConditions('text', terms.rawTokens),
        ...buildTokenRegexConditions('normalizedText', terms.normalizedTokens),
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
      query: rawQuery,
      note: 'نتائج البحث أولية وتعتمد على النصوص المفهرسة داخل قاعدة بيانات النظام.',
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
      return { seeded: false, reason: 'already-exists', count: exists };
    }

    const seed = [
      {
        articleNumber: '1',
        chapter: 'الباب الأول',
        section: 'المبادئ الأساسية',
        title: 'شكل الدولة',
        text: 'جمهورية العراق دولة اتحادية واحدة مستقلة ذات سيادة كاملة، نظام الحكم فيها جمهوري نيابي ديمقراطي اتحادي.',
        keywords: ['الدولة', 'اتحادية', 'سيادة'],
      },
      {
        articleNumber: '2',
        chapter: 'الباب الأول',
        section: 'المبادئ الأساسية',
        title: 'دين الدولة',
        text: 'الإسلام دين الدولة الرسمي، وهو مصدرٌ أساس للتشريع.',
        keywords: ['الإسلام', 'التشريع'],
      },
      {
        articleNumber: '14',
        chapter: 'الباب الثاني',
        section: 'الحقوق والحريات',
        title: 'المساواة',
        text: 'العراقيون متساوون أمام القانون دون تمييز.',
        keywords: ['المساواة', 'عدم التمييز'],
      },
      {
        articleNumber: '15',
        chapter: 'الباب الثاني',
        section: 'الحقوق والحريات',
        title: 'الحق في الحياة والحرية',
        text: 'لكل فرد الحق في الحياة والأمن والحرية، ولا يجوز الحرمان من هذه الحقوق إلا وفقاً للقانون.',
        keywords: ['الحق في الحياة', 'الحرية'],
      },
      {
        articleNumber: '19',
        chapter: 'الباب الثاني',
        section: 'الحقوق والحريات',
        title: 'الضمانات القضائية',
        text: 'التقاضي حق مصون ومكفول للجميع، ويُحظر تحصين أي عمل أو قرار إداري من الطعن.',
        keywords: ['التقاضي', 'ضمانات المحاكمة'],
      },
      {
        articleNumber: '23',
        chapter: 'الباب الثاني',
        section: 'الحقوق والحريات',
        title: 'الملكية الخاصة',
        text: 'الملكية الخاصة مصونة، ويحق للمالك الانتفاع بها واستغلالها والتصرف بها ضمن حدود القانون.',
        keywords: ['الملكية', 'الحقوق المالية'],
      },
      {
        articleNumber: '47',
        chapter: 'الباب الثالث',
        section: 'السلطات الاتحادية',
        title: 'الفصل بين السلطات',
        text: 'تتكون السلطات الاتحادية من السلطات التشريعية والتنفيذية والقضائية، وتمارس اختصاصاتها على أساس مبدأ الفصل بين السلطات.',
        keywords: ['الفصل بين السلطات'],
      },
      {
        articleNumber: '88',
        chapter: 'الباب الثالث',
        section: 'السلطة القضائية',
        title: 'استقلال القضاء',
        text: 'القضاة مستقلون لا سلطان عليهم في قضائهم لغير القانون، ولا يجوز لأي سلطة التدخل في القضاء أو في شؤون العدالة.',
        keywords: ['استقلال القضاء'],
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
