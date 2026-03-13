import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import { toObjectIdOrUndefined } from 'src/common/utils/object-id.util';
import { escapeRegex } from 'src/common/utils/regex.util';
import { AiService } from '../ai/ai.service';
import { AuditService } from '../audit/audit.service';
import { Invoice, InvoiceDocument } from '../billing/schemas/invoice.schema';
import { Payment, PaymentDocument } from '../billing/schemas/payment.schema';
import { Client, ClientDocument } from '../clients/schemas/client.schema';
import { Court, CourtDocument } from '../courts/schemas/court.schema';
import {
  Notification,
  NotificationDocument,
} from '../notifications/schemas/notification.schema';
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
    @InjectModel(Client.name) private readonly clientModel: Model<ClientDocument>,
    @InjectModel(Court.name) private readonly courtModel: Model<CourtDocument>,
    @InjectModel(Invoice.name) private readonly invoiceModel: Model<InvoiceDocument>,
    @InjectModel(Payment.name) private readonly paymentModel: Model<PaymentDocument>,
    @InjectModel(Notification.name)
    private readonly notificationModel: Model<NotificationDocument>,
    private readonly aiService: AiService,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateCaseDto, actorId?: string) {
    const contractAmount = Number(dto.contractAmount ?? dto.fees ?? 0);
    const initialPayment = Number(dto.initialPayment ?? 0);
    const secondPaymentAmount = Number(dto.secondPaymentAmount ?? 0);

    if (contractAmount < 0 || initialPayment < 0 || secondPaymentAmount < 0) {
      throw new BadRequestException('Contract amount and payments must be non-negative');
    }

    if (initialPayment > contractAmount && contractAmount > 0) {
      throw new BadRequestException('Initial payment cannot exceed contract amount');
    }

    let clientObjectId = toObjectIdOrUndefined(dto.clientId);

    if (!clientObjectId && dto.newClient?.fullName?.trim()) {
      const createdClient = await this.clientModel.create({
        fullName: dto.newClient.fullName.trim(),
        companyName: dto.newClient.companyName?.trim() || undefined,
        phone: dto.newClient.phone?.trim() || undefined,
        email: dto.newClient.email?.trim() || undefined,
        address: dto.newClient.address?.trim() || undefined,
      });
      clientObjectId = createdClient._id;
    }

    if (!clientObjectId) {
      throw new BadRequestException('A linked client is required for creating a case');
    }

    const courtContext = await this.resolveCourtContext(dto);
    const normalizedEvidenceEntries = this.normalizeEvidenceEntries(dto.evidenceEntries);
    const evidenceList = this.mergeEvidenceDescriptions(dto.evidenceList, normalizedEvidenceEntries);
    const documentIdsFromEvidence = normalizedEvidenceEntries
      .map((entry) => entry.documentId)
      .filter((id): id is Types.ObjectId => Boolean(id));

    const paidAmount = contractAmount > 0 ? Math.min(initialPayment, contractAmount) : 0;
    const outstandingAmount = Math.max(contractAmount - paidAmount, 0);
    const paymentStatus = this.resolvePaymentStatus(contractAmount, paidAmount);
    const contractDate = dto.contractDate ? new Date(dto.contractDate) : new Date();

    const created = await this.caseModel.create({
      caseNumber: dto.caseNumber,
      internalReference: dto.internalReference,
      title: dto.title,
      caseType: dto.caseType,
      ...courtContext,
      status: dto.status,
      clientId: clientObjectId,
      summary: dto.summary,
      facts: dto.facts,
      claims: dto.claims,
      oppositeParty: dto.oppositeParty,
      evidenceList,
      evidenceEntries: normalizedEvidenceEntries,
      documentIds: documentIdsFromEvidence,
      lawyerIds: (dto.lawyerIds ?? [])
        .map((id) => toObjectIdOrUndefined(id))
        .filter((id): id is Types.ObjectId => Boolean(id)),
      hearingDates: (dto.hearingDates ?? []).map((d) => new Date(d)),
      fees: dto.fees,
      contractAmount,
      contractDate,
      paidAmount,
      outstandingAmount,
      paymentStatus,
    });

    if (contractAmount > 0) {
      const installments = this.buildInstallmentPlan({
        contractAmount,
        initialPayment,
        secondPaymentAmount,
        secondPaymentDueDate: dto.secondPaymentDueDate,
        additionalInstallments: dto.additionalInstallments,
        contractDate,
      });

      const createdInvoices: Array<{
        _id: Types.ObjectId;
        amount: number;
        dueDate?: Date;
        label: string;
        autoPaid: boolean;
      }> = [];

      for (const installment of installments) {
        const invoice = await this.invoiceModel.create({
          invoiceNumber: this.generateInvoiceNumber(),
          clientId: clientObjectId,
          caseId: created._id,
          amount: installment.amount,
          currency: 'IQD',
          issueDate: contractDate,
          dueDate: installment.dueDate,
          status: installment.autoPaid ? 'paid' : 'unpaid',
          notes: installment.label,
        });

        createdInvoices.push({
          _id: invoice._id,
          amount: installment.amount,
          dueDate: installment.dueDate,
          label: installment.label,
          autoPaid: installment.autoPaid,
        });

        if (installment.autoPaid) {
          await this.paymentModel.create({
            invoiceId: invoice._id,
            amount: installment.amount,
            paymentDate: contractDate,
            method: 'contract_initial_payment',
            notes: installment.label,
          });
        }
      }

      await this.createInstallmentReminders({
        caseId: created._id.toString(),
        caseNumber: created.caseNumber,
        caseTitle: created.title,
        recipients: this.resolveReminderRecipients(
          actorId,
          (created.lawyerIds ?? []).map((id) => id.toString()),
        ),
        installments: createdInvoices
          .filter((item) => !item.autoPaid)
          .map((item) => ({
            dueDate: item.dueDate,
            amount: item.amount,
            label: item.label,
            invoiceId: item._id.toString(),
          })),
      });
    }

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

    try {
      await this.analyze(created.id, {}, actorId);
    } catch {
      // AI analysis is best-effort and should not fail case creation.
    }

    return created;
  }

  async findAll(query: PaginationQueryDto, q?: string) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;

    const rawQuery = (q ?? '').trim();
    const safeQuery = escapeRegex(rawQuery);

    const filter = rawQuery
      ? {
          $or: [
            { caseNumber: { $regex: safeQuery, $options: 'i' } },
            { title: { $regex: safeQuery, $options: 'i' } },
            { court: { $regex: safeQuery, $options: 'i' } },
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
    const hasCourtUpdates =
      dto.courtId !== undefined ||
      dto.court !== undefined ||
      dto.courtCity !== undefined ||
      dto.courtDistrict !== undefined ||
      dto.courtArea !== undefined ||
      dto.courtLocationDescription !== undefined ||
      dto.governorate !== undefined;
    const courtContext = hasCourtUpdates ? await this.resolveCourtContext(dto) : {};
    const payload: Record<string, unknown> = { ...dto, ...courtContext };
    if (dto.clientId !== undefined) {
      payload.clientId = toObjectIdOrUndefined(dto.clientId);
    }
    if (dto.lawyerIds !== undefined) {
      payload.lawyerIds = dto.lawyerIds
        ?.map((lawyerId) => toObjectIdOrUndefined(lawyerId))
        .filter((item): item is Types.ObjectId => Boolean(item));
    }
    if (dto.hearingDates !== undefined) {
      payload.hearingDates = dto.hearingDates?.map((d) => new Date(d));
    }
    if (dto.contractDate !== undefined) {
      payload.contractDate = dto.contractDate ? new Date(dto.contractDate) : undefined;
    }
    if (dto.evidenceEntries !== undefined) {
      const normalizedEntries = this.normalizeEvidenceEntries(dto.evidenceEntries);
      payload.evidenceEntries = normalizedEntries;
      payload.evidenceList = this.mergeEvidenceDescriptions(dto.evidenceList, normalizedEntries);
      payload.documentIds = normalizedEntries
        .map((entry) => entry.documentId)
        .filter((id): id is Types.ObjectId => Boolean(id));
    }

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
      description: this.buildAiDescription(caseItem, dto.context),
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

  async exportCaseSummary(id: string, format: string, actorId?: string) {
    const caseItem = await this.caseModel
      .findById(id)
      .populate('clientId', 'fullName phone address')
      .populate('lawyerIds', 'fullName title')
      .lean();

    if (!caseItem) {
      throw new NotFoundException('Case not found');
    }

    const timeline = await this.eventModel
      .find({ caseId: new Types.ObjectId(id) })
      .sort({ eventDate: 1, createdAt: 1 })
      .limit(60)
      .lean();

    const client = (caseItem.clientId as unknown as Record<string, unknown> | undefined) ?? {};
    const lawyers = ((caseItem.lawyerIds ?? []) as unknown as Array<Record<string, unknown>>)
      .map((lawyer) => (lawyer.fullName ?? '').toString().trim())
      .filter(Boolean);
    const genome = (caseItem.caseGenome ?? {}) as Record<string, unknown>;
    const insights = (caseItem.aiInsights ?? {}) as Record<string, unknown>;
    const genomeKeywords = this.toStringArray(genome['keywords']);
    const genomeWeaknesses = this.toStringArray(genome['weaknesses']);
    const insightMissingDocs = this.toStringArray(insights['missingDocuments']);

    const lines = [
      'ملخص القضية - LexIQ Iraq',
      `رقم القضية: ${caseItem.caseNumber ?? '-'}`,
      `العنوان: ${caseItem.title ?? '-'}`,
      `نوع القضية: ${caseItem.caseType ?? '-'}`,
      `المحكمة: ${caseItem.court ?? '-'}`,
      `المحافظة: ${caseItem.governorate ?? '-'}`,
      `الحالة: ${caseItem.status ?? '-'}`,
      `المرحلة: ${caseItem.stage ?? '-'}`,
      `العميل: ${client.fullName ?? '-'}`,
      `هاتف العميل: ${client.phone ?? '-'}`,
      `الخصم المقابل: ${caseItem.oppositeParty ?? '-'}`,
      `المحامون: ${lawyers.length === 0 ? '-' : lawyers.join('، ')}`,
      `ملخص الوقائع: ${caseItem.summary ?? '-'}`,
      `الوقائع: ${caseItem.facts ?? '-'}`,
      `المطالب: ${caseItem.claims ?? '-'}`,
      `الدفوع: ${caseItem.defenses ?? '-'}`,
      `الدفوع المضادة: ${caseItem.counterArguments ?? '-'}`,
      `درجة المخاطر: ${caseItem.riskScore ?? 0}%`,
      `حالة السداد: ${caseItem.paymentStatus ?? 'unpaid'}`,
      `قيمة العقد: ${Number(caseItem.contractAmount ?? caseItem.fees ?? 0)} IQD`,
      `المبلغ المسدد: ${Number(caseItem.paidAmount ?? 0)} IQD`,
      `المبلغ المتبقي: ${Number(caseItem.outstandingAmount ?? 0)} IQD`,
      '',
      'المواد القانونية المرتبطة:',
      ...((caseItem.linkedLawArticleIds ?? []) as string[]).map((entry) => `- ${entry}`),
      '',
      'المواد الدستورية المرتبطة:',
      ...((caseItem.linkedConstitutionArticleIds ?? []) as string[]).map((entry) => `- ${entry}`),
      '',
      'القرارات المرتبطة:',
      ...((caseItem.linkedDecisionIds ?? []) as string[]).map((entry) => `- ${entry}`),
      '',
      'مؤشرات Case Genome:',
      `- الموضوع القانوني: ${(genome['legalTopic'] ?? '').toString()}`,
      `- الكلمات المفتاحية: ${genomeKeywords.join('، ')}`,
      `- نقاط الضعف: ${genomeWeaknesses.join(' | ')}`,
      `- فجوات الأدلة: ${insightMissingDocs.join(' | ')}`,
      '',
      'الخط الزمني:',
      ...timeline.map(
        (entry) =>
          `- ${this.toDateOnly(entry.eventDate)} | ${(entry.title ?? '-').toString()} | ${(entry.details ?? '').toString()}`,
      ),
      '',
      'تنبيه:',
      this.getDisclaimer(),
    ];

    const baseName = `case-${caseItem.caseNumber ?? id}-summary`
      .replaceAll(/[^a-zA-Z0-9_\-]+/g, '-')
      .replaceAll(/-+/g, '-')
      .toLowerCase();
    const normalizedFormat = (format ?? 'word').toLowerCase();

    await this.auditService.record({
      action: 'case.export-summary',
      entity: 'cases',
      entityId: id,
      actorId,
      payload: { format: normalizedFormat },
    });

    if (normalizedFormat == 'txt') {
      const body = lines.join('\n');
      return {
        filename: `${baseName}.txt`,
        contentType: 'text/plain; charset=utf-8',
        buffer: Buffer.from(body, 'utf8'),
      };
    }

    const htmlBody = this.renderWordDocument({
      title: 'ملخص القضية',
      subtitle: `${caseItem.caseNumber ?? '-'} - ${caseItem.title ?? '-'}`,
      lines,
    });

    return {
      filename: `${baseName}.doc`,
      contentType: 'application/msword; charset=utf-8',
      buffer: Buffer.from(htmlBody, 'utf8'),
    };
  }

  private toStringArray(value: unknown): string[] {
    if (!Array.isArray(value)) {
      return [];
    }
    return value
      .map((item) => `${item ?? ''}`.trim())
      .filter((item) => item.length > 0);
  }

  private async resolveCourtContext(dto: CreateCaseDto | UpdateCaseDto) {
    if (!dto.courtId) {
      return {
        court: dto.court,
        courtId: undefined,
        courtCity: dto.courtCity,
        courtDistrict: dto.courtDistrict,
        courtArea: dto.courtArea,
        courtLocationDescription: dto.courtLocationDescription,
        governorate: dto.governorate,
      };
    }

    if (!Types.ObjectId.isValid(dto.courtId)) {
      throw new BadRequestException('Court not found');
    }

    const court = await this.courtModel.findById(dto.courtId).lean();
    if (!court) {
      throw new BadRequestException('Court not found');
    }

    return {
      courtId: new Types.ObjectId(dto.courtId),
      court: dto.court ?? court.name,
      courtCity: dto.courtCity ?? court.city,
      courtDistrict: dto.courtDistrict ?? court.district,
      courtArea: dto.courtArea ?? court.area,
      courtLocationDescription:
        dto.courtLocationDescription ??
        court.addressDescription ??
        [court.area, court.district, court.city, court.governorate]
          .filter(Boolean)
          .join(' - '),
      governorate: dto.governorate ?? court.governorate,
    };
  }

  private buildAiDescription(caseItem: Record<string, any>, context?: string) {
    const evidenceDescriptions = [
      ...(caseItem.evidenceList ?? []),
      ...((caseItem.evidenceEntries ?? []) as Array<Record<string, any>>).map(
        (entry) => entry?.description,
      ),
    ]
      .filter(Boolean)
      .join('\n');

    return [
      `عنوان القضية: ${caseItem.title ?? ''}`,
      `نوع القضية: ${caseItem.caseType ?? ''}`,
      `المحكمة: ${caseItem.court ?? ''}`,
      `الخصم المقابل: ${caseItem.oppositeParty ?? ''}`,
      caseItem.summary,
      caseItem.facts,
      caseItem.claims,
      caseItem.defenses,
      caseItem.counterArguments,
      evidenceDescriptions ? `الأدلة:\n${evidenceDescriptions}` : '',
      context ?? '',
    ]
      .filter((item) => item && `${item}`.trim().length > 0)
      .join('\n');
  }

  private normalizeEvidenceEntries(entries?: Array<Record<string, any>>) {
    return (entries ?? [])
      .map((entry) => ({
        documentId: toObjectIdOrUndefined(entry?.documentId),
        attachmentName: entry?.attachmentName?.toString()?.trim() || undefined,
        description: entry?.description?.toString()?.trim() || undefined,
      }))
      .filter((entry) => entry.documentId || entry.attachmentName || entry.description);
  }

  private mergeEvidenceDescriptions(
    evidenceList?: string[],
    evidenceEntries?: Array<{ description?: string }>,
  ) {
    const merged = new Set<string>();
    for (const item of evidenceList ?? []) {
      const value = `${item ?? ''}`.trim();
      if (value) {
        merged.add(value);
      }
    }
    for (const item of evidenceEntries ?? []) {
      const value = `${item?.description ?? ''}`.trim();
      if (value) {
        merged.add(value);
      }
    }
    return [...merged];
  }

  private buildInstallmentPlan(input: {
    contractAmount: number;
    initialPayment: number;
    secondPaymentAmount: number;
    secondPaymentDueDate?: string;
    additionalInstallments?: Array<{ dueDate: string; amount: number; label?: string }>;
    contractDate: Date;
  }) {
    const plan: Array<{ label: string; amount: number; dueDate?: Date; autoPaid: boolean }> = [];
    const contractAmount = Number(input.contractAmount ?? 0);
    const initialPayment = Number(input.initialPayment ?? 0);
    const secondPaymentAmount = Number(input.secondPaymentAmount ?? 0);

    if (initialPayment > 0) {
      plan.push({
        label: 'الدفعة الأولى',
        amount: initialPayment,
        dueDate: input.contractDate,
        autoPaid: true,
      });
    }

    if (secondPaymentAmount > 0) {
      plan.push({
        label: 'الدفعة الثانية',
        amount: secondPaymentAmount,
        dueDate: input.secondPaymentDueDate ? new Date(input.secondPaymentDueDate) : undefined,
        autoPaid: false,
      });
    }

    for (let i = 0; i < (input.additionalInstallments ?? []).length; i++) {
      const installment = input.additionalInstallments?.[i];
      const amount = Number(installment?.amount ?? 0);
      if (!installment || amount <= 0) {
        continue;
      }
      plan.push({
        label: installment.label?.trim() || `دفعة إضافية ${i + 1}`,
        amount,
        dueDate: installment.dueDate ? new Date(installment.dueDate) : undefined,
        autoPaid: false,
      });
    }

    const totalPlanned = plan.reduce((sum, item) => sum + item.amount, 0);
    if (totalPlanned > contractAmount) {
      throw new BadRequestException('Installments exceed contract amount');
    }

    const remaining = Math.max(contractAmount - totalPlanned, 0);
    if (remaining > 0) {
      const fallbackDueDate =
        plan.find((item) => item.label === 'الدفعة الثانية')?.dueDate ??
        new Date(input.contractDate.getTime() + 30 * 24 * 60 * 60 * 1000);
      plan.push({
        label: 'الدفعة المتبقية',
        amount: remaining,
        dueDate: fallbackDueDate,
        autoPaid: false,
      });
    }

    return plan.filter((item) => item.amount > 0);
  }

  private resolveReminderRecipients(actorId?: string, lawyerIds: string[] = []) {
    const set = new Set<string>();
    if (actorId && Types.ObjectId.isValid(actorId)) {
      set.add(actorId);
    }
    for (const lawyerId of lawyerIds) {
      if (Types.ObjectId.isValid(lawyerId)) {
        set.add(lawyerId);
      }
    }
    return [...set];
  }

  private async createInstallmentReminders(input: {
    caseId: string;
    caseNumber: string;
    caseTitle: string;
    recipients: string[];
    installments: Array<{ dueDate?: Date; amount: number; label: string; invoiceId: string }>;
  }) {
    if (!input.recipients.length || !input.installments.length) {
      return;
    }

    const now = new Date();
    const rows: Array<Record<string, unknown>> = [];
    for (const recipient of input.recipients) {
      for (const installment of input.installments) {
        if (!installment.dueDate) {
          continue;
        }
        const dueDate = new Date(installment.dueDate);
        const oneDayBefore = new Date(dueDate.getTime() - 24 * 60 * 60 * 1000);
        const checkpoints = [
          { key: 'day_before', when: oneDayBefore, titleSuffix: 'غدًا' },
          { key: 'due_day', when: dueDate, titleSuffix: 'اليوم' },
        ];

        for (const checkpoint of checkpoints) {
          if (checkpoint.when.getTime() <= now.getTime()) {
            continue;
          }
          rows.push({
            userId: new Types.ObjectId(recipient),
            title: `تذكير استحقاق دفعة ${checkpoint.titleSuffix}`,
            message: `القضية ${input.caseNumber} - ${input.caseTitle} | ${installment.label} بقيمة ${installment.amount} IQD`,
            level: checkpoint.key === 'due_day' ? 'warning' : 'info',
            entityType: 'case_installment_reminder',
            entityId: `${input.caseId}:${installment.invoiceId}`,
            reminderKey: checkpoint.key,
            scheduledFor: checkpoint.when,
          });
        }
      }
    }

    if (rows.length) {
      await this.notificationModel.insertMany(rows, { ordered: false });
    }
  }

  private resolvePaymentStatus(contractAmount: number, paidAmount: number) {
    if (contractAmount <= 0) {
      return 'unpaid';
    }
    if (paidAmount <= 0) {
      return 'unpaid';
    }
    if (paidAmount >= contractAmount) {
      return 'paid';
    }
    return 'partial';
  }

  private getDisclaimer() {
    return 'هذا ملخص أولي للمراجعة المهنية، ولا يُعد بديلاً عن التقدير القانوني للمحامي.';
  }

  private generateInvoiceNumber() {
    const now = new Date();
    const y = now.getFullYear();
    const m = `${now.getMonth() + 1}`.padStart(2, '0');
    const d = `${now.getDate()}`.padStart(2, '0');
    const tail = Math.random().toString(36).slice(2, 7).toUpperCase();
    return `INV-${y}${m}${d}-${tail}`;
  }

  private toDateOnly(value: unknown) {
    if (!value) {
      return '-';
    }
    const raw = value instanceof Date ? value.toISOString() : `${value}`;
    return raw.split('T')[0] ?? raw;
  }

  private renderWordDocument(input: {
    title: string;
    subtitle?: string;
    lines: string[];
  }) {
    const body = input.lines
      .map((line) => `<p>${this.escapeHtml(line)}</p>`)
      .join('');
    return `<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8" />
  <title>${this.escapeHtml(input.title)}</title>
  <style>
    body { font-family: Tahoma, Arial, sans-serif; direction: rtl; unicode-bidi: embed; line-height: 1.65; padding: 24px; color: #111827; }
    h1 { margin: 0 0 6px; font-size: 24px; }
    h2 { margin: 0 0 18px; font-size: 16px; font-weight: 500; color: #374151; }
    p { margin: 0 0 8px; font-size: 14px; white-space: pre-wrap; }
  </style>
</head>
<body>
  <h1>${this.escapeHtml(input.title)}</h1>
  <h2>${this.escapeHtml(input.subtitle ?? '')}</h2>
  ${body}
</body>
</html>`;
  }

  private escapeHtml(value: string) {
    return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
  }
}
