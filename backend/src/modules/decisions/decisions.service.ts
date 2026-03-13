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
import { IngestService } from '../ingest/ingest.service';
import { StorageService } from '../storage/storage.service';
import { CreateDecisionDto } from './dto/create-decision.dto';
import { IngestDecisionDto } from './dto/ingest-decision.dto';
import { ReclassifyDecisionDto } from './dto/reclassify-decision.dto';
import { SyncSjcAppellateDto } from './dto/sync-sjc-appellate.dto';
import { UploadDecisionDto } from './dto/upload-decision.dto';
import { DecisionChunk, DecisionChunkDocument } from './schemas/decision-chunk.schema';
import {
  JudicialDecision,
  JudicialDecisionDocument,
} from './schemas/judicial-decision.schema';

type DecisionSearchFilters = {
  court?: string;
  caseType?: string;
  legalDomain?: string;
  courtLevel?: string;
  year?: string;
};

type ScrapedDecisionRow = {
  source: string;
  decisionNumber: string;
  caseType: string;
  caseTypeRaw: string;
  legalDomain: string;
  summary: string;
  courtLevel: 'appellate' | 'cassation';
  courtName: string;
  decisionDate: Date;
  constitutionalReferences: string[];
  legalArticleReferences: string[];
  legalKeywords: string[];
  confidenceScore: number;
  tags: string[];
};

type ParsedSjcRow = {
  decisionNumber: string;
  caseTypeRaw: string;
  summary: string;
  detailPath: string;
  year: number;
};

@Injectable()
export class DecisionsService {
  private readonly sjcBaseUrl = 'https://sjc.iq';

  constructor(
    @InjectModel(JudicialDecision.name)
    private readonly decisionModel: Model<JudicialDecisionDocument>,
    @InjectModel(DecisionChunk.name)
    private readonly chunkModel: Model<DecisionChunkDocument>,
    private readonly ingestService: IngestService,
    private readonly auditService: AuditService,
    private readonly storageService: StorageService,
  ) {}

  async create(dto: CreateDecisionDto, actorId?: string) {
    const normalizedText = normalizeArabic(dto.fullText ?? dto.summary ?? '');
    const created = await this.decisionModel.create({
      ...dto,
      decisionDate: new Date(dto.decisionDate),
      normalizedText,
    });

    if (created.fullText) {
      await this.buildChunks(created._id.toString(), created.fullText);
    }

    await this.auditService.record({
      action: 'decision.create',
      entity: 'judicial_decisions',
      entityId: created.id,
      actorId,
    });

    return created;
  }
  async uploadDecision(file: Express.Multer.File, dto: UploadDecisionDto, actorId?: string) {
    const originalName = file.originalname || 'decision-attachment.bin';
    const mimeType = file.mimetype || 'application/octet-stream';
    const storagePath = await this.storageService.generatePath({
      firmId: actorId,
      caseId: `decision-${Date.now()}`,
      originalName,
    });

    await this.storageService.uploadFile({
      storagePath,
      buffer: file.buffer,
      mimeType,
    });

    const summary = dto.summary?.trim() || '';
    const fullText = dto.fullText?.trim() || '';
    const mergedText = [summary, fullText].filter(Boolean).join(' ').trim();

    const caseType = dto.caseType?.trim() || this.mapCaseType('', mergedText);
    const legalDomain = dto.legalDomain?.trim() || this.mapLegalDomain(caseType);

    const legalKeywordsFromDto = this.parseStringList(dto.legalKeywords);
    const extractedKeywords = this.extractKeywords(`${caseType} ${summary}`.trim());
    const legalKeywords = Array.from(
      new Set([...legalKeywordsFromDto, ...extractedKeywords].filter(Boolean)),
    ).slice(0, 24);

    const legalArticleReferences = this.parseStringList(dto.legalArticleReferences);
    const constitutionalReferences = this.parseStringList(dto.constitutionalReferences);
    const tags = Array.from(
      new Set([...this.parseStringList(dto.tags), 'user-upload', 'review-required']),
    );

    const source =
      dto.source?.trim() ||
      `user-upload://${Date.now()}-${dto.decisionNumber?.trim() || 'decision'}`;

    const created = await this.decisionModel.create({
      source,
      sourceType: dto.sourceType?.trim() || 'user_upload',
      courtName: dto.courtName.trim(),
      courtLevel: dto.courtLevel?.trim() || 'appellate',
      governorate: dto.governorate?.trim() || undefined,
      chamber: dto.chamber?.trim() || undefined,
      decisionNumber: dto.decisionNumber.trim(),
      decisionDate: new Date(dto.decisionDate),
      publicationDate: dto.publicationDate ? new Date(dto.publicationDate) : undefined,
      caseType,
      legalDomain,
      summary: summary || undefined,
      fullText: fullText || summary || undefined,
      extractedCitations: [],
      constitutionalReferences:
        constitutionalReferences.length > 0
          ? constitutionalReferences
          : this.extractConstitutionalRefs(mergedText),
      legalArticleReferences:
        legalArticleReferences.length > 0
          ? legalArticleReferences
          : this.extractLegalArticleRefs(mergedText),
      legalKeywords,
      outcome: 'قرار مرفوع من المستخدم ويحتاج مراجعة قانونية قبل الاعتماد النهائي.',
      precedentWeight: 0.5,
      confidenceScore: 0.5,
      tags,
      reviewStatus: 'pending',
      ingestionStatus: 'published',
      normalizedText: normalizeArabic(mergedText),
      attachmentStoragePath: storagePath,
      attachmentOriginalName: originalName,
      attachmentMimeType: mimeType,
      attachmentSizeBytes: file.size,
      submittedByUserId: actorId,
    });

    if (created.fullText) {
      await this.buildChunks(created._id.toString(), created.fullText);
    }

    await this.auditService.record({
      action: 'decision.upload',
      entity: 'judicial_decisions',
      entityId: created.id,
      actorId,
      payload: {
        source,
        courtName: created.courtName,
        decisionNumber: created.decisionNumber,
        attachmentOriginalName: originalName,
      },
    });

    const attachmentUrl = await this.storageService.getSignedUrl(storagePath);
    return {
      ...created.toObject(),
      attachmentUrl,
    };
  }
  async search(q: string, query: PaginationQueryDto, filters: DecisionSearchFilters) {
    const terms = buildSearchTerms(q);
    const rawQuery = terms.rawQuery;
    const { page, limit } = query;
    const skip = (page - 1) * limit;

    const filter: any = this.buildSearchFilter(filters);

    if (rawQuery) {
      filter.$or = [
        { normalizedText: { $regex: terms.escapedNormalizedQuery, $options: 'i' } },
        { summary: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { fullText: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { decisionNumber: { $regex: terms.escapedRawQuery, $options: 'i' } },
        ...buildTokenRegexConditions('normalizedText', terms.normalizedTokens),
        ...buildTokenRegexConditions('summary', terms.rawTokens),
        ...buildTokenRegexConditions('fullText', terms.rawTokens),
      ];
    }

    const [items, total] = await Promise.all([
      this.decisionModel
        .find(filter)
        .sort({ decisionDate: -1, updatedAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.decisionModel.countDocuments(filter),
    ]);

    const relevanceReason = rawQuery
      ? 'تطابق في الكلمات المفتاحية ونطاق المحكمة والموضوع القانوني'
      : 'أحدث القرارات وفق الفلاتر المحددة';

    return {
      items: items.map((item) => ({
        ...item,
        caseType: this.mapCaseType((item.caseType ?? '').toString()),
        hasAttachment: Boolean(item.attachmentStoragePath),
        relevanceReason,
      })),
      page,
      limit,
      total,
    };
  }

  async caseTypeSummary(filters: Pick<DecisionSearchFilters, 'courtLevel' | 'year'>) {
    const filter: any = this.buildSearchFilter(filters);

    const [total, grouped] = await Promise.all([
      this.decisionModel.countDocuments(filter),
      this.decisionModel.aggregate([
        { $match: filter },
        {
          $group: {
            _id: '$caseType',
            count: { $sum: 1 },
            latestDate: { $max: '$decisionDate' },
          },
        },
      ]),
    ]);

    const merged = new Map<string, { count: number; latestDate?: Date }>();

    for (const row of grouped) {
      const canonicalCaseType = this.mapCaseType((row._id ?? '').toString());
      const current = merged.get(canonicalCaseType);
      if (!current) {
        merged.set(canonicalCaseType, {
          count: row.count ?? 0,
          latestDate: row.latestDate,
        });
        continue;
      }

      current.count += row.count ?? 0;
      if (
        row.latestDate &&
        (!current.latestDate || new Date(row.latestDate) > new Date(current.latestDate))
      ) {
        current.latestDate = row.latestDate;
      }
    }

    const items = Array.from(merged.entries())
      .map(([caseType, value]) => ({
        caseType,
        count: value.count,
        latestDate: value.latestDate,
      }))
      .sort(
        (a, b) =>
          b.count - a.count ||
          `${a.caseType ?? ''}`.localeCompare(`${b.caseType ?? ''}`, 'ar'),
      );

    return {
      total,
      items,
    };
  }

  async findOne(id: string) {
    if (!Types.ObjectId.isValid(id)) {
      throw new NotFoundException('Decision not found');
    }

    const decision = await this.decisionModel.findById(id).lean();
    if (!decision) {
      throw new NotFoundException('Decision not found');
    }

    const similar = await this.decisionModel
      .find({
        _id: { $ne: new Types.ObjectId(id) },
        legalDomain: decision.legalDomain,
      })
      .limit(5)
      .select('decisionNumber courtName decisionDate legalDomain caseType')
      .lean();

    return {
      ...decision,
      caseType: this.mapCaseType((decision.caseType ?? '').toString()),
      attachmentUrl: decision.attachmentStoragePath
        ? await this.storageService.getSignedUrl(decision.attachmentStoragePath)
        : null,
      similarDecisions: similar.map((entry) => ({
        ...entry,
        caseType: this.mapCaseType((entry.caseType ?? '').toString()),
      })),
    };
  }

  async reclassify(id: string, dto: ReclassifyDecisionDto, actorId?: string) {
    const updated = await this.decisionModel
      .findByIdAndUpdate(id, dto, { new: true })
      .lean();

    if (!updated) {
      throw new NotFoundException('Decision not found');
    }

    await this.auditService.record({
      action: 'decision.reclassify',
      entity: 'judicial_decisions',
      entityId: id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });

    return updated;
  }

  async ingest(dto: IngestDecisionDto, actorId?: string) {
    return this.ingestService.startDecisionIngestion(dto, actorId);
  }

  async syncSjcAppellate(dto: SyncSjcAppellateDto, actorId?: string) {
    const startId = Math.max(1, dto.startId ?? 1);
    const endId = Math.max(startId, dto.endId ?? 4200);
    const concurrency = Math.min(50, Math.max(1, dto.concurrency ?? 20));
    const maxDecisions = Math.min(10000, Math.max(10, dto.maxDecisions ?? 1200));
    const mode = dto.mode ?? 'appellate';
    const dryRun = dto.dryRun ?? false;

    const scrape = await this.scrapeSjcDecisions({
      startId,
      endId,
      concurrency,
      maxDecisions,
      mode,
    });

    if (dryRun) {
      return {
        dryRun: true,
        ...scrape,
        preview: scrape.decisions.slice(0, 20),
      };
    }

    if (!scrape.decisions.length) {
      return {
        ...scrape,
        insertedCount: 0,
        updatedCount: 0,
        message: 'No decisions collected from source range.',
      };
    }

    const bulkOps: any[] = scrape.decisions.map((entry) => ({
      updateOne: {
        filter: { source: entry.source },
        update: {
          $set: {
            source: entry.source,
            sourceType: 'public_web_scrape',
            courtName: entry.courtName,
            courtLevel: entry.courtLevel,
            decisionNumber: entry.decisionNumber,
            decisionDate: entry.decisionDate,
            caseType: entry.caseType,
            legalDomain: entry.legalDomain,
            summary: entry.summary,
            fullText: entry.summary,
            extractedCitations: [],
            constitutionalReferences: entry.constitutionalReferences,
            legalArticleReferences: entry.legalArticleReferences,
            legalKeywords: entry.legalKeywords,
            outcome:
              'مستخرج من مصدر علني ويحتاج مراجعة محامٍ بشري قبل الاعتماد المهني النهائي.',
            precedentWeight: 0.62,
            confidenceScore: entry.confidenceScore,
            tags: entry.tags,
            reviewStatus: 'pending' as const,
            ingestionStatus: 'published' as const,
            normalizedText: normalizeArabic(entry.summary),
          },
          $setOnInsert: {
            similarityEmbedding: [],
          },
        },
        upsert: true,
      },
    }));

    const bulkResult: any = await this.decisionModel.bulkWrite(bulkOps, {
      ordered: false,
    });

    const insertedCount = bulkResult?.upsertedCount ?? 0;
    const updatedCount = bulkResult?.modifiedCount ?? 0;

    await this.auditService.record({
      action: 'decision.sync.sjc_appellate',
      entity: 'judicial_decisions',
      actorId,
      payload: {
        startId,
        endId,
        concurrency,
        maxDecisions,
        mode,
        insertedCount,
        updatedCount,
        collectedCount: scrape.collectedCount,
      },
    });

    return {
      ...scrape,
      insertedCount,
      updatedCount,
    };
  }

  private buildSearchFilter(filters: DecisionSearchFilters) {
    const filter: any = {};

    if (filters.court) {
      const courtTerms = buildSearchTerms(filters.court);
      filter.courtName = { $regex: courtTerms.escapedRawQuery, $options: 'i' };
    }

    if (filters.caseType) {
      const caseTypeTerms = buildSearchTerms(filters.caseType);
      filter.caseType = { $regex: caseTypeTerms.escapedRawQuery, $options: 'i' };
    }

    if (filters.legalDomain) {
      const domainTerms = buildSearchTerms(filters.legalDomain);
      filter.legalDomain = { $regex: domainTerms.escapedRawQuery, $options: 'i' };
    }

    if (filters.courtLevel) {
      filter.courtLevel = filters.courtLevel;
    }

    if (filters.year && /^\d{4}$/.test(filters.year.trim())) {
      const year = Number(filters.year);
      filter.decisionDate = {
        $gte: new Date(Date.UTC(year, 0, 1)),
        $lt: new Date(Date.UTC(year + 1, 0, 1)),
      };
    }

    return filter;
  }

  private async scrapeSjcDecisions(options: {
    startId: number;
    endId: number;
    concurrency: number;
    maxDecisions: number;
    mode: 'appellate' | 'all';
  }) {
    let nextId = options.startId;
    let scannedPages = 0;
    let failedPages = 0;
    const decisionsBySource = new Map<string, ScrapedDecisionRow>();

    const worker = async () => {
      while (nextId <= options.endId && decisionsBySource.size < options.maxDecisions) {
        const currentId = nextId;
        nextId += 1;

        try {
          const html = await this.fetchHtmlWithTimeout(
            `${this.sjcBaseUrl}/qview.${currentId}/`,
            9000,
          );
          scannedPages += 1;

          const rows = this.extractRowsFromSjcPage(html);
          for (const row of rows) {
            if (decisionsBySource.size >= options.maxDecisions) {
              break;
            }

            const normalized = this.normalizeScrapedRow(row, options.mode);
            if (!normalized) {
              continue;
            }

            if (!decisionsBySource.has(normalized.source)) {
              decisionsBySource.set(normalized.source, normalized);
            }
          }
        } catch {
          failedPages += 1;
        }
      }
    };

    await Promise.all(
      Array.from({ length: options.concurrency }, () => worker()),
    );

    const decisions = Array.from(decisionsBySource.values()).sort(
      (a, b) => b.decisionDate.getTime() - a.decisionDate.getTime(),
    );

    const byCaseType: Record<string, number> = {};
    for (const row of decisions) {
      byCaseType[row.caseType] = (byCaseType[row.caseType] ?? 0) + 1;
    }

    return {
      scannedPages,
      failedPages,
      collectedCount: decisions.length,
      byCaseType,
      decisions,
    };
  }

  private extractRowsFromSjcPage(html: string): ParsedSjcRow[] {
    const rows: ParsedSjcRow[] = [];
    const pattern =
      /<a href="#" class="badge text-bg-warning mb-2"><i[^>]*><\/i>([^<]+)<\/a>[\s\S]*?<h6 class="course-title[^\"]*"><a href="#">([^<]*)<\/a><\/h6>[\s\S]*?<p>([\s\S]*?)<a href="(\/qview\.\d+\/)"[\s\S]*?<h6 class="course-title[^\"]*"><a href="#">(\d{4})<\/a><\/h6>/gi;

    for (const match of html.matchAll(pattern)) {
      const decisionNumber = this.cleanHtmlText(match[1]);
      const caseTypeRaw = this.cleanHtmlText(match[2]);
      const summary = this.cleanHtmlText(match[3]);
      const detailPath = (match[4] ?? '').trim();
      const year = Number(match[5]);

      if (!decisionNumber || !summary || !detailPath) {
        continue;
      }

      rows.push({
        decisionNumber,
        caseTypeRaw,
        summary,
        detailPath,
        year,
      });
    }

    return rows;
  }

  private normalizeScrapedRow(
    row: ParsedSjcRow,
    mode: 'appellate' | 'all',
  ): ScrapedDecisionRow | null {
    const summary = row.summary.trim();
    if (!summary) {
      return null;
    }

    const normalizedSummary = normalizeArabic(summary);
    if (mode === 'appellate' && !this.looksLikeAppellateOrCassation(normalizedSummary)) {
      return null;
    }

    const caseType = this.mapCaseType(row.caseTypeRaw, row.summary);
    const legalDomain = this.mapLegalDomain(caseType);
    const courtLevel = normalizedSummary.includes('تمييز') ? 'cassation' : 'appellate';
    const courtName =
      courtLevel === 'cassation'
        ? 'محكمة التمييز الاتحادية'
        : 'محكمة الاستئناف العراقية';

    const source = `${this.sjcBaseUrl}${row.detailPath}`;
    const parsedYear = Number.isFinite(row.year) && row.year >= 1900 ? row.year : 2026;

    return {
      source,
      decisionNumber: row.decisionNumber,
      caseType,
      caseTypeRaw: row.caseTypeRaw,
      legalDomain,
      summary,
      courtLevel,
      courtName,
      decisionDate: new Date(Date.UTC(parsedYear, 0, 1)),
      constitutionalReferences: this.extractConstitutionalRefs(summary),
      legalArticleReferences: this.extractLegalArticleRefs(summary),
      legalKeywords: this.extractKeywords(`${caseType} ${summary}`).slice(0, 16),
      confidenceScore: 0.58,
      tags: [
        'sjc-sync',
        'public-source',
        'review-required',
        row.caseTypeRaw ? `raw-type:${row.caseTypeRaw}` : 'raw-type:unknown',
      ],
    };
  }

  private looksLikeAppellateOrCassation(normalizedSummary: string) {
    return (
      normalizedSummary.includes('استيناف') ||
      normalizedSummary.includes('تمييز') ||
      normalizedSummary.includes('محكمه')
    );
  }

  private mapCaseType(rawCaseType?: string, contextText?: string) {
    const normalized = normalizeArabic(
      [rawCaseType ?? '', contextText ?? ''].filter(Boolean).join(' '),
    );

    if (!normalized) {
      return 'أخرى';
    }
    if (normalized.includes('مدني')) {
      return 'مدني';
    }
    if (
      normalized.includes('جزايي') ||
      normalized.includes('جزاي') ||
      normalized.includes('جنايي') ||
      normalized.includes('جناي')
    ) {
      return 'جزائي';
    }
    if (
      normalized.includes('احوال') ||
      normalized.includes('مواد شخص') ||
      normalized.includes('مطاوعه') ||
      normalized.includes('طلاق') ||
      normalized.includes('مهر') ||
      normalized.includes('زواج')
    ) {
      return 'أحوال شخصية';
    }
    if (normalized.includes('تجاري')) {
      return 'تجاري';
    }
    if (normalized.includes('اداري')) {
      return 'إداري';
    }
    if (normalized.includes('عمال')) {
      return 'عمالي';
    }
    if (normalized.includes('عقار') || normalized.includes('ايجار')) {
      return 'عقاري';
    }
    if (normalized.includes('تنفيذ')) {
      return 'تنفيذ';
    }
    if (normalized.includes('دستور')) {
      return 'دستوري';
    }
    if (normalized.includes('اثبات') || normalized.includes('يمين حاسمه')) {
      return 'إثبات';
    }
    if (normalized.includes('مرافعات')) {
      return 'إجرائي';
    }
    if (normalized.includes('وقف')) {
      return 'وقف';
    }

    return 'أخرى';
  }

  private mapLegalDomain(caseType: string) {
    switch (caseType) {
      case 'مدني':
        return 'مدني';
      case 'جزائي':
        return 'عقوبات';
      case 'أحوال شخصية':
        return 'أحوال شخصية';
      case 'تجاري':
        return 'تجاري';
      case 'إداري':
        return 'إداري';
      case 'عمالي':
        return 'عمل';
      case 'عقاري':
        return 'عقارات';
      case 'تنفيذ':
        return 'تنفيذ';
      case 'دستوري':
        return 'دستوري';
      case 'إثبات':
        return 'أدلة / إثبات';
      case 'إجرائي':
        return 'أصول محاكمات';
      default:
        return 'أخرى';
    }
  }

  private extractLegalArticleRefs(text: string) {
    const refs = new Set<string>();
    const pattern = /المادة\s*\(?\s*([0-9٠-٩]+)\s*\)?/g;

    for (const match of text.matchAll(pattern)) {
      const number = this.toWesternDigits(match[1]);
      if (!number) {
        continue;
      }
      refs.add(number);
    }

    return Array.from(refs).slice(0, 20);
  }

  private extractConstitutionalRefs(text: string) {
    const refs = new Set<string>();
    const pattern = /الدستور[\s\S]{0,25}?المادة\s*\(?\s*([0-9٠-٩]+)\s*\)?/g;

    for (const match of text.matchAll(pattern)) {
      const number = this.toWesternDigits(match[1]);
      if (!number) {
        continue;
      }
      refs.add(number);
    }

    return Array.from(refs).slice(0, 12);
  }

  private extractKeywords(value: string) {
    const tokens = value
      .replace(/[.,;:!?()\[\]{}\-_/\\]/g, ' ')
      .split(/\s+/)
      .map((token) => token.trim())
      .filter((token) => token.length >= 2);

    return Array.from(new Set(tokens));
  }
  private parseStringList(raw?: string) {
    const value = `${raw ?? ''}`.trim();
    if (!value) {
      return [] as string[];
    }

    if (value.startsWith('[') && value.endsWith(']')) {
      try {
        const parsed = JSON.parse(value);
        if (Array.isArray(parsed)) {
          return parsed.map((item) => `${item}`.trim()).filter(Boolean);
        }
      } catch {
        // fallback to comma split
      }
    }

    return value
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }
  private toWesternDigits(value: string) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const easternDigits = '۰۱۲۳۴۵۶۷۸۹';

    const transformed = `${value ?? ''}`
      .replace(/[٠-٩]/g, (char) => String(arabicDigits.indexOf(char)))
      .replace(/[۰-۹]/g, (char) => String(easternDigits.indexOf(char)))
      .replace(/[^0-9]/g, '');

    return transformed.trim();
  }

  private cleanHtmlText(value: string) {
    return this.decodeHtmlEntities(value)
      .replace(/<[^>]+>/g, ' ')
      .replace(/\u200f|\u200e|\u00a0/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private decodeHtmlEntities(value: string) {
    return `${value ?? ''}`
      .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) =>
        String.fromCharCode(parseInt(hex, 16)),
      )
      .replace(/&#([0-9]+);/g, (_, dec) =>
        String.fromCharCode(parseInt(dec, 10)),
      )
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");
  }

  private async fetchHtmlWithTimeout(url: string, timeoutMs: number) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(url, {
        signal: controller.signal,
        headers: {
          'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'accept-language': 'ar-IQ,ar;q=0.9,en;q=0.8',
        },
      });

      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`);
      }

      return response.text();
    } finally {
      clearTimeout(timeout);
    }
  }

  private async buildChunks(decisionId: string, text: string) {
    const chunkSize = 1200;
    const cleaned = text.trim();
    if (!cleaned) {
      return;
    }
    const chunks = [];
    for (let i = 0; i < cleaned.length; i += chunkSize) {
      chunks.push({
        decisionId: new Types.ObjectId(decisionId),
        chunkIndex: chunks.length,
        text: cleaned.slice(i, i + chunkSize),
      });
    }

    await this.chunkModel.deleteMany({ decisionId: new Types.ObjectId(decisionId) });
    await this.chunkModel.insertMany(chunks);
  }
}





