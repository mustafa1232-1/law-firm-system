import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import { AuditService } from '../audit/audit.service';
import { IngestService } from '../ingest/ingest.service';
import { CreateDecisionDto } from './dto/create-decision.dto';
import { IngestDecisionDto } from './dto/ingest-decision.dto';
import { ReclassifyDecisionDto } from './dto/reclassify-decision.dto';
import { DecisionChunk, DecisionChunkDocument } from './schemas/decision-chunk.schema';
import {
  JudicialDecision,
  JudicialDecisionDocument,
} from './schemas/judicial-decision.schema';

@Injectable()
export class DecisionsService {
  constructor(
    @InjectModel(JudicialDecision.name)
    private readonly decisionModel: Model<JudicialDecisionDocument>,
    @InjectModel(DecisionChunk.name)
    private readonly chunkModel: Model<DecisionChunkDocument>,
    private readonly ingestService: IngestService,
    private readonly auditService: AuditService,
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

  async search(q: string, query: PaginationQueryDto, filters: Record<string, string>) {
    const normalized = normalizeArabic(q ?? '');
    const { page, limit } = query;
    const skip = (page - 1) * limit;

    const filter: any = {
      $or: [
        { $text: { $search: q } },
        { normalizedText: { $regex: normalized, $options: 'i' } },
      ],
    };

    if (filters.court) {
      filter.courtName = { $regex: filters.court, $options: 'i' };
    }
    if (filters.caseType) {
      filter.caseType = filters.caseType;
    }
    if (filters.legalDomain) {
      filter.legalDomain = filters.legalDomain;
    }

    const [items, total] = await Promise.all([
      this.decisionModel
        .find(filter)
        .sort({ decisionDate: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.decisionModel.countDocuments(filter),
    ]);

    return {
      items: items.map((item) => ({
        ...item,
        relevanceReason:
          'تطابق في الكلمات المفتاحية ونطاق المحكمة والموضوع القانوني',
      })),
      page,
      limit,
      total,
    };
  }

  async findOne(id: string) {
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
      .select('decisionNumber courtName decisionDate legalDomain')
      .lean();

    return { ...decision, similarDecisions: similar };
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
