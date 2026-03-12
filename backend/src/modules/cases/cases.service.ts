import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AuditService } from '../audit/audit.service';
import { AiService } from '../ai/ai.service';
import { AnalyzeCaseDto } from './dto/analyze-case.dto';
import { CreateCaseDto } from './dto/create-case.dto';
import { UpdateCaseDto } from './dto/update-case.dto';
import { CaseEvent, CaseEventDocument } from './schemas/case-event.schema';
import { CaseFile, CaseDocument } from './schemas/case.schema';

@Injectable()
export class CasesService {
  constructor(
    @InjectModel(CaseFile.name) private readonly caseModel: Model<CaseDocument>,
    @InjectModel(CaseEvent.name) private readonly eventModel: Model<CaseEventDocument>,
    private readonly aiService: AiService,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateCaseDto, actorId?: string) {
    const created = await this.caseModel.create({
      ...dto,
      clientId: dto.clientId ? new Types.ObjectId(dto.clientId) : undefined,
      lawyerIds: (dto.lawyerIds ?? []).map((id) => new Types.ObjectId(id)),
      hearingDates: (dto.hearingDates ?? []).map((d) => new Date(d)),
    });

    await this.eventModel.create({
      caseId: created._id,
      eventType: 'created',
      title: 'Case created',
      details: created.title,
      eventDate: new Date(),
    });

    await this.auditService.record({
      action: 'case.create',
      entity: 'cases',
      entityId: created.id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });

    return created;
  }

  async findAll(query: PaginationQueryDto, q?: string) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const filter = q
      ? {
          $or: [
            { $text: { $search: q } },
            { caseNumber: { $regex: q, $options: 'i' } },
          ],
        }
      : {};

    const [items, total] = await Promise.all([
      this.caseModel
        .find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('clientId', 'fullName')
        .lean(),
      this.caseModel.countDocuments(filter),
    ]);

    return { items, total, page, limit };
  }

  async findOne(id: string) {
    const item = await this.caseModel
      .findById(id)
      .populate('clientId', 'fullName phone email')
      .populate('lawyerIds', 'fullName email title')
      .lean();

    if (!item) {
      throw new NotFoundException('Case not found');
    }

    const timeline = await this.eventModel
      .find({ caseId: new Types.ObjectId(id) })
      .sort({ eventDate: 1, createdAt: 1 })
      .lean();

    return { ...item, timeline };
  }

  async update(id: string, dto: UpdateCaseDto, actorId?: string) {
    const payload: Record<string, unknown> = {
      ...dto,
      clientId: dto.clientId ? new Types.ObjectId(dto.clientId) : undefined,
      lawyerIds: dto.lawyerIds?.map((lawyerId) => new Types.ObjectId(lawyerId)),
      hearingDates: dto.hearingDates?.map((d) => new Date(d)),
    };

    const updated = await this.caseModel
      .findByIdAndUpdate(id, payload, { new: true })
      .lean();

    if (!updated) {
      throw new NotFoundException('Case not found');
    }

    await this.eventModel.create({
      caseId: new Types.ObjectId(id),
      eventType: 'updated',
      title: 'Case updated',
      details: dto.summary ?? dto.title ?? 'Case information changed',
      eventDate: new Date(),
    });

    await this.auditService.record({
      action: 'case.update',
      entity: 'cases',
      entityId: id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });

    return updated;
  }

  async analyze(id: string, dto: AnalyzeCaseDto, actorId?: string) {
    const caseItem = await this.caseModel.findById(id).lean();
    if (!caseItem) {
      throw new NotFoundException('Case not found');
    }

    const analysis = await this.aiService.runCaseAnalysis({
      caseId: id,
      description: [caseItem.summary, caseItem.facts, caseItem.claims, dto.context]
        .filter(Boolean)
        .join('\n'),
      caseTypeHint: caseItem.caseType,
    });

    const normalizedFacts = normalizeArabic(caseItem.facts ?? '');
    const riskBase =
      normalizedFacts.includes('تناقض') || normalizedFacts.includes('لا يوجد') ? 72 : 34;

    const caseGenome = {
      caseType: caseItem.caseType,
      factsCore: analysis.extractedFacts,
      parties: analysis.extractedParties,
      requests: analysis.extractedClaims,
      legalTopic: analysis.legalTopic,
      keywords: analysis.keywords,
      suggestedLegalArticles: analysis.suggestedLegalArticles,
      suggestedConstitutionArticles: analysis.suggestedConstitutionArticles,
      similarDecisions: analysis.similarDecisions,
      riskScore: analysis.riskScore ?? riskBase,
      evidenceStrength: analysis.evidenceStrength,
      weaknesses: analysis.weaknesses,
      conflicts: analysis.conflicts,
      possibleDefenses: analysis.possibleDefenses,
      possibleCounterDefenses: analysis.possibleCounterDefenses,
      timelineHints: analysis.timelineHints,
      requiredCoreDocuments: analysis.requiredDocuments,
    };

    await this.caseModel.findByIdAndUpdate(id, {
      $set: {
        caseGenome,
        aiInsights: analysis,
        riskScore: caseGenome.riskScore,
        linkedLawArticleIds: analysis.suggestedLegalArticles,
        linkedConstitutionArticleIds: analysis.suggestedConstitutionArticles,
        linkedDecisionIds: analysis.similarDecisions,
      },
    });

    await this.eventModel.create({
      caseId: new Types.ObjectId(id),
      eventType: 'analysis',
      title: 'AI Case Genome generated',
      details: 'Initial AI legal analysis completed',
      eventDate: new Date(),
    });

    await this.auditService.record({
      action: 'case.analyze',
      entity: 'cases',
      entityId: id,
      actorId,
      payload: { context: dto.context },
    });

    return {
      caseId: id,
      disclaimer: analysis.disclaimer,
      caseGenome,
      suggestions: {
        questionsForLawyer: analysis.questionsForLawyer,
        strategy: analysis.strategy,
        missingDocuments: analysis.missingDocuments,
      },
    };
  }
}
