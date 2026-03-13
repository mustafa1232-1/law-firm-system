import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import * as fs from 'fs';
import * as path from 'path';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import { Payment, PaymentDocument } from '../billing/schemas/payment.schema';
import { CaseFile, CaseDocument } from '../cases/schemas/case.schema';
import {
  ConstitutionArticle,
  ConstitutionArticleDocument,
} from '../constitution/schemas/constitution-article.schema';
import {
  JudicialDecision,
  JudicialDecisionDocument,
} from '../decisions/schemas/judicial-decision.schema';
import { Court, CourtDocument } from '../courts/schemas/court.schema';
import { Hearing, HearingDocument } from '../hearings/schemas/hearing.schema';
import { LawArticle, LawArticleDocument } from '../laws/schemas/law-article.schema';
import {
  LawDocumentEntity,
  LawDocumentEntityDocument,
} from '../laws/schemas/law-document.schema';
import {
  Notification,
  NotificationDocument,
} from '../notifications/schemas/notification.schema';
import { TaskItem, TaskItemDocument } from '../tasks/schemas/task.schema';
import { CreatePermissionDto, CreateRoleDto } from './dto/admin.dto';
import { PermissionEntity, PermissionDocument } from './schemas/permission.schema';
import { RoleEntity, RoleDocument } from './schemas/role.schema';

@Injectable()
export class AdminService {
  constructor(
    @InjectModel(RoleEntity.name)
    private readonly roleModel: Model<RoleDocument>,
    @InjectModel(PermissionEntity.name)
    private readonly permissionModel: Model<PermissionDocument>,
    @InjectModel(CaseFile.name)
    private readonly caseModel: Model<CaseDocument>,
    @InjectModel(Hearing.name)
    private readonly hearingModel: Model<HearingDocument>,
    @InjectModel(TaskItem.name)
    private readonly taskModel: Model<TaskItemDocument>,
    @InjectModel(Payment.name)
    private readonly paymentModel: Model<PaymentDocument>,
    @InjectModel(Notification.name)
    private readonly notificationModel: Model<NotificationDocument>,
    @InjectModel(ConstitutionArticle.name)
    private readonly constitutionModel: Model<ConstitutionArticleDocument>,
    @InjectModel(LawDocumentEntity.name)
    private readonly lawDocumentModel: Model<LawDocumentEntityDocument>,
    @InjectModel(LawArticle.name)
    private readonly lawArticleModel: Model<LawArticleDocument>,
    @InjectModel(JudicialDecision.name)
    private readonly decisionModel: Model<JudicialDecisionDocument>,
    @InjectModel(Court.name)
    private readonly courtModel: Model<CourtDocument>,
  ) {}

  createRole(dto: CreateRoleDto) {
    return this.roleModel.create(dto);
  }

  createPermission(dto: CreatePermissionDto) {
    return this.permissionModel.create(dto);
  }

  listRoles() {
    return this.roleModel.find().sort({ key: 1 }).lean();
  }

  listPermissions() {
    return this.permissionModel.find().sort({ key: 1 }).lean();
  }

  async bootstrapLegalData(options?: { replace?: boolean }) {
    const replace = options?.replace !== false;

    const constitutionSeed = this.readSeedFile<any[]>('constitution_articles.seed.json');
    const lawsSeed = this.readSeedFile<any[]>('laws.seed.json');
    const decisionsSeed = this.readSeedFile<any[]>('judicial_decisions.seed.json');
    const courtsSeed = this.readSeedFile<any[]>('iraqi_courts.seed.json');

    if (replace) {
      await Promise.all([
        this.constitutionModel.deleteMany({}),
        this.lawArticleModel.deleteMany({}),
        this.lawDocumentModel.deleteMany({}),
        this.decisionModel.deleteMany({}),
        this.courtModel.deleteMany({}),
      ]);
    }

    const constitutionDocs = constitutionSeed.map((item) => ({
      ...item,
      normalizedText: normalizeArabic(item.text ?? ''),
      linkedLawArticleIds: item.linkedLawArticleIds ?? [],
      linkedDecisionIds: item.linkedDecisionIds ?? [],
    }));

    if (constitutionDocs.length) {
      await this.constitutionModel.insertMany(constitutionDocs, { ordered: false });
    }

    let lawArticlesCount = 0;
    for (const lawSeed of lawsSeed) {
      const law = await this.lawDocumentModel.create({
        ...lawSeed.document,
        linkedConstitutionTopics: lawSeed.document?.linkedConstitutionTopics ?? [],
        linkedDecisionIds: lawSeed.document?.linkedDecisionIds ?? [],
        repealStatus: lawSeed.document?.repealStatus ?? 'active',
      });

      const articles = (lawSeed.articles ?? []).map((article: any) => ({
        lawId: law._id,
        articleNumber: article.articleNumber,
        text: article.text,
        normalizedText: normalizeArabic(article.text ?? ''),
        keywords: article.keywords ?? [],
      }));

      if (articles.length) {
        lawArticlesCount += articles.length;
        await this.lawArticleModel.insertMany(articles, { ordered: false });
      }
    }

    const decisionDocs = decisionsSeed.map((item) => ({
      ...item,
      decisionDate: new Date(item.decisionDate),
      publicationDate: item.publicationDate ? new Date(item.publicationDate) : undefined,
      extractedCitations: item.extractedCitations ?? [],
      constitutionalReferences: item.constitutionalReferences ?? [],
      legalArticleReferences: item.legalArticleReferences ?? [],
      legalKeywords: item.legalKeywords ?? [],
      tags: item.tags ?? [],
      similarityEmbedding: [],
      normalizedText: normalizeArabic(`${item.summary ?? ''} ${item.fullText ?? ''}`),
    }));

    if (decisionDocs.length) {
      await this.decisionModel.insertMany(decisionDocs, { ordered: false });
    }

    const courtDocs = courtsSeed.map((item) => ({
      ...item,
      name: item.name ?? item.nameAr ?? item.nameEn ?? 'محكمة غير مسماة',
      nameAr: item.nameAr ?? undefined,
      nameEn: item.nameEn ?? undefined,
      governorate: item.governorate ?? undefined,
      city: item.city ?? undefined,
      district: item.district ?? undefined,
      area: item.area ?? undefined,
      addressDescription: item.addressDescription ?? undefined,
      latitude: item.latitude ?? undefined,
      longitude: item.longitude ?? undefined,
      source: item.source ?? 'openstreetmap',
      sourceType: item.sourceType ?? 'osm_amenity_courthouse',
      sourceRef: item.sourceRef ?? undefined,
      sourceUrl: item.sourceUrl ?? undefined,
      tags: item.tags ?? {},
    }));

    if (courtDocs.length) {
      await this.courtModel.insertMany(courtDocs, { ordered: false });
    }

    return {
      seeded: true,
      replace,
      constitutionArticles: constitutionDocs.length,
      lawDocuments: lawsSeed.length,
      lawArticles: lawArticlesCount,
      judicialDecisions: decisionDocs.length,
      courts: courtDocs.length,
    };
  }

  async getDashboardSummary(_userId?: string) {
    const now = new Date();
    const weekStart = new Date(now);
    weekStart.setHours(0, 0, 0, 0);
    weekStart.setDate(weekStart.getDate() - ((weekStart.getDay() + 6) % 7));
    const weekEnd = new Date(weekStart);
    weekEnd.setDate(weekEnd.getDate() + 7);

    const [activeCases, hearingsThisWeek, overdueTasks, caseTypeDistribution] =
      await Promise.all([
        this.caseModel.countDocuments({
          status: { $nin: ['closed', 'archived'] },
        }),
        this.hearingModel.countDocuments({
          hearingDate: { $gte: weekStart, $lt: weekEnd },
        }),
        this.taskModel.countDocuments({
          status: { $nin: ['done', 'cancelled'] },
          dueDate: { $lt: now },
        }),
        this.caseModel.aggregate([
          { $group: { _id: '$caseType', count: { $sum: 1 } } },
          { $sort: { count: -1 } },
          { $limit: 10 },
        ]),
      ]);

    const [openWithDebt, openFullyPaid, closedWithDebt, closedFullyPaid, wonCases, lostCases, debtAgg] =
      await Promise.all([
        this.caseModel.countDocuments({
          status: { $nin: ['closed', 'archived'] },
          outstandingAmount: { $gt: 0 },
        }),
        this.caseModel.countDocuments({
          status: { $nin: ['closed', 'archived'] },
          outstandingAmount: { $lte: 0 },
          paymentStatus: 'paid',
        }),
        this.caseModel.countDocuments({
          status: { $in: ['closed', 'archived'] },
          outstandingAmount: { $gt: 0 },
        }),
        this.caseModel.countDocuments({
          status: { $in: ['closed', 'archived'] },
          outstandingAmount: { $lte: 0 },
          paymentStatus: 'paid',
        }),
        this.caseModel.countDocuments({ outcome: 'won' }),
        this.caseModel.countDocuments({ outcome: 'lost' }),
        this.caseModel.aggregate([
          {
            $group: {
              _id: null,
              totalOutstanding: { $sum: '$outstandingAmount' },
            },
          },
        ]),
      ]);

    const [paymentAgg, upcomingHearings, urgentTasks, unreadNotifications, highRiskCases] =
      await Promise.all([
        this.paymentModel.aggregate([
          {
            $group: {
              _id: null,
              collected: { $sum: '$amount' },
              paymentsCount: { $sum: 1 },
            },
          },
        ]),
        this.hearingModel
          .find({ hearingDate: { $gte: new Date(now.getTime() - 86400000) } })
          .sort({ hearingDate: 1 })
          .limit(20)
          .populate('caseId', 'title caseNumber')
          .lean(),
        this.taskModel
          .find({
            status: { $nin: ['done', 'cancelled'] },
            priority: { $in: ['high', 'urgent'] },
          })
          .sort({ dueDate: 1, createdAt: -1 })
          .limit(8)
          .populate('caseId', 'title caseNumber')
          .lean(),
        this.notificationModel.find({ isRead: false }).sort({ createdAt: -1 }).limit(8).lean(),
        this.caseModel.find({ riskScore: { $gte: 70 } }).sort({ riskScore: -1, updatedAt: -1 }).limit(6).lean(),
      ]);

    const billingCollected = Number(paymentAgg[0]?.collected ?? 0);
    const paymentsCount = Number(paymentAgg[0]?.paymentsCount ?? 0);

    const alerts = [
      ...unreadNotifications.map((item) => ({
        type: 'notification',
        title: item.title,
        subtitle: item.message,
        level: item.level,
      })),
      ...highRiskCases.map((item) => ({
        type: 'risk',
        title: `مخاطر مرتفعة: ${item.caseNumber}`,
        subtitle: item.title,
        level: item.riskScore >= 85 ? 'critical' : 'warning',
      })),
    ].slice(0, 10);

    const reminderWindows = [
      { key: 'day_1', label: 'قبل يوم', offsetMs: 24 * 60 * 60 * 1000 },
      { key: 'hours_6', label: 'قبل 6 ساعات', offsetMs: 6 * 60 * 60 * 1000 },
      { key: 'hours_2', label: 'قبل ساعتين', offsetMs: 2 * 60 * 60 * 1000 },
      { key: 'hour_1', label: 'قبل ساعة', offsetMs: 60 * 60 * 1000 },
    ];

    const lawyerAgenda = upcomingHearings.map((hearing: any) => {
      const hearingDate = new Date(hearing.hearingDate);
      const reminders = reminderWindows
        .map((window) => {
          const remindAt = new Date(hearingDate.getTime() - window.offsetMs);
          const millisecondsUntil = remindAt.getTime() - now.getTime();
          return {
            key: window.key,
            label: window.label,
            remindAt,
            isDue: millisecondsUntil <= 0 && hearingDate.getTime() > now.getTime(),
            millisecondsUntil,
          };
        })
        .sort((a, b) => a.remindAt.getTime() - b.remindAt.getTime());

      const nextReminder =
        reminders.find((item) => item.millisecondsUntil > 0) ??
        reminders.find((item) => item.isDue) ??
        null;

      return {
        hearingId: hearing._id?.toString(),
        hearingDate,
        case: hearing.caseId,
        court: hearing.court,
        courtGovernorate: hearing.courtGovernorate,
        courtCity: hearing.courtCity,
        courtDistrict: hearing.courtDistrict,
        courtArea: hearing.courtArea,
        courtLocationDescription: hearing.courtLocationDescription,
        room: hearing.room,
        judge: hearing.judge,
        reminders,
        nextReminder,
      };
    });

    return {
      generatedAt: now,
      kpis: {
        activeCases,
        hearingsThisWeek,
        overdueTasks,
        billingCollected,
        paymentsCount,
      },
      financeCaseIndicators: {
        openWithDebt,
        openFullyPaid,
        closedWithDebt,
        closedFullyPaid,
        wonCases,
        lostCases,
        totalOutstanding: Number(debtAgg[0]?.totalOutstanding ?? 0),
      },
      caseTypeDistribution: caseTypeDistribution.map((entry) => ({
        caseType: entry._id ?? 'أخرى',
        count: entry.count ?? 0,
      })),
      lawyerAgenda,
      upcomingHearings,
      urgentTasks,
      alerts,
    };
  }

  async seedDefaultRbac() {
    const permissions = [
      { key: 'cases.read', name: 'Read cases' },
      { key: 'cases.write', name: 'Write cases' },
      { key: 'research.read', name: 'Read research' },
      { key: 'billing.manage', name: 'Manage billing' },
      { key: 'admin.manage', name: 'Manage admin settings' },
    ];

    for (const permission of permissions) {
      await this.permissionModel.updateOne(
        { key: permission.key },
        { $setOnInsert: permission },
        { upsert: true },
      );
    }

    const roles = [
      {
        key: 'SUPER_ADMIN',
        name: 'Super Admin',
        permissions: permissions.map((p) => p.key),
      },
      {
        key: 'FIRM_ADMIN',
        name: 'Firm Admin',
        permissions: ['cases.read', 'cases.write', 'research.read', 'billing.manage'],
      },
      {
        key: 'LAWYER',
        name: 'Lawyer',
        permissions: ['cases.read', 'cases.write', 'research.read'],
      },
      {
        key: 'RESEARCHER',
        name: 'Researcher',
        permissions: ['research.read'],
      },
      {
        key: 'READ_ONLY_VIEWER',
        name: 'Read-only Viewer',
        permissions: ['cases.read'],
      },
    ];

    for (const role of roles) {
      await this.roleModel.updateOne({ key: role.key }, { $setOnInsert: role }, { upsert: true });
    }

    return { seeded: true, roles: roles.length, permissions: permissions.length };
  }

  private readSeedFile<T>(fileName: string): T {
    const absPath = path.join(process.cwd(), 'data', 'public', fileName);
    const raw = fs.readFileSync(absPath, 'utf8');
    return JSON.parse(raw) as T;
  }
}
