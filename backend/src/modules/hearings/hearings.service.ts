import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AuditService } from '../audit/audit.service';
import { CaseFile, CaseDocument } from '../cases/schemas/case.schema';
import { Court, CourtDocument } from '../courts/schemas/court.schema';
import {
  Notification,
  NotificationDocument,
} from '../notifications/schemas/notification.schema';
import { CreateHearingDto } from './dto/create-hearing.dto';
import { UpdateHearingDto } from './dto/update-hearing.dto';
import { Hearing, HearingDocument } from './schemas/hearing.schema';

const REMINDER_WINDOWS = [
  { key: 'day_1', label: 'قبل يوم', offsetMs: 24 * 60 * 60 * 1000 },
  { key: 'hours_6', label: 'قبل 6 ساعات', offsetMs: 6 * 60 * 60 * 1000 },
  { key: 'hours_2', label: 'قبل ساعتين', offsetMs: 2 * 60 * 60 * 1000 },
  { key: 'hour_1', label: 'قبل ساعة', offsetMs: 60 * 60 * 1000 },
] as const;

@Injectable()
export class HearingsService {
  constructor(
    @InjectModel(Hearing.name) private readonly hearingModel: Model<HearingDocument>,
    @InjectModel(CaseFile.name) private readonly caseModel: Model<CaseDocument>,
    @InjectModel(Court.name) private readonly courtModel: Model<CourtDocument>,
    @InjectModel(Notification.name)
    private readonly notificationModel: Model<NotificationDocument>,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateHearingDto, actorId?: string) {
    const courtContext = await this.resolveCourtContext(dto);
    const created = await this.hearingModel.create({
      ...dto,
      caseId: new Types.ObjectId(dto.caseId),
      ...courtContext,
      hearingDate: new Date(dto.hearingDate),
    });

    await this.syncHearingReminders(created.id, actorId);

    await this.auditService.record({
      action: 'hearing.create',
      entity: 'hearings',
      entityId: created.id,
      actorId,
    });

    return created;
  }

  async findAll(query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.hearingModel
        .find()
        .sort({ hearingDate: 1 })
        .skip(skip)
        .limit(limit)
        .populate('caseId', 'title caseNumber')
        .populate('courtId', 'name governorate city district area addressDescription latitude longitude')
        .lean(),
      this.hearingModel.countDocuments(),
    ]);

    return { items, page, limit, total };
  }

  async update(id: string, dto: UpdateHearingDto, actorId?: string) {
    const payload: Record<string, unknown> = { ...dto };
    if (dto.caseId) payload.caseId = new Types.ObjectId(dto.caseId);
    if (dto.hearingDate) payload.hearingDate = new Date(dto.hearingDate);
    if (
      dto.courtId !== undefined ||
      dto.court !== undefined ||
      dto.courtGovernorate !== undefined ||
      dto.courtCity !== undefined ||
      dto.courtDistrict !== undefined ||
      dto.courtArea !== undefined ||
      dto.courtLocationDescription !== undefined
    ) {
      Object.assign(payload, await this.resolveCourtContext(dto));
    }

    const updated = await this.hearingModel
      .findByIdAndUpdate(id, payload, { new: true })
      .lean();
    if (!updated) {
      throw new NotFoundException('Hearing not found');
    }

    await this.syncHearingReminders(id, actorId);

    await this.auditService.record({
      action: 'hearing.update',
      entity: 'hearings',
      entityId: id,
      actorId,
    });

    return updated;
  }

  private async resolveCourtContext(dto: CreateHearingDto | UpdateHearingDto) {
    const context: Record<string, unknown> = {
      court: dto.court,
      courtGovernorate: dto.courtGovernorate,
      courtCity: dto.courtCity,
      courtDistrict: dto.courtDistrict,
      courtArea: dto.courtArea,
      courtLocationDescription: dto.courtLocationDescription,
    };

    if (!dto.courtId) {
      return context;
    }

    if (!Types.ObjectId.isValid(dto.courtId)) {
      throw new NotFoundException('Court not found');
    }

    const court = await this.courtModel.findById(dto.courtId).lean();
    if (!court) {
      throw new NotFoundException('Court not found');
    }

    return {
      ...context,
      courtId: new Types.ObjectId(dto.courtId),
      court: dto.court ?? court.name,
      courtGovernorate: dto.courtGovernorate ?? court.governorate,
      courtCity: dto.courtCity ?? court.city,
      courtDistrict: dto.courtDistrict ?? court.district,
      courtArea: dto.courtArea ?? court.area,
      courtLocationDescription:
        dto.courtLocationDescription ??
        court.addressDescription ??
        [court.area, court.district, court.city, court.governorate]
          .filter(Boolean)
          .join(' - '),
    };
  }

  private async syncHearingReminders(hearingId: string, actorId?: string) {
    const hearing = await this.hearingModel.findById(hearingId).lean();
    if (!hearing) {
      return;
    }

    const caseItem = await this.caseModel
      .findById(hearing.caseId)
      .select('title caseNumber lawyerIds')
      .lean();

    const recipientIds = new Set<string>();
    if (actorId && Types.ObjectId.isValid(actorId)) {
      recipientIds.add(actorId);
    }
    for (const lawyerId of caseItem?.lawyerIds ?? []) {
      const asString = lawyerId.toString();
      if (Types.ObjectId.isValid(asString)) {
        recipientIds.add(asString);
      }
    }

    if (!recipientIds.size) {
      return;
    }

    await this.notificationModel.deleteMany({
      entityType: 'hearing_reminder',
      entityId: hearingId,
    });

    const hearingDate = new Date(hearing.hearingDate);
    const now = new Date();
    const caseLabel = [caseItem?.caseNumber, caseItem?.title].filter(Boolean).join(' - ');
    const courtLabel = [
      hearing.court,
      hearing.courtGovernorate,
      hearing.courtCity,
      hearing.courtDistrict,
      hearing.courtArea,
    ]
      .filter(Boolean)
      .join(' - ');
    const location = hearing.courtLocationDescription
      ? ` | الموقع: ${hearing.courtLocationDescription}`
      : '';

    const reminders: Array<Record<string, unknown>> = [];
    for (const userId of recipientIds) {
      for (const window of REMINDER_WINDOWS) {
        const scheduledFor = new Date(hearingDate.getTime() - window.offsetMs);
        if (scheduledFor.getTime() <= now.getTime()) {
          continue;
        }

        reminders.push({
          userId: new Types.ObjectId(userId),
          title: `تذكير جلسة ${window.label}`,
          message: `القضية: ${caseLabel || '-'} | المحكمة: ${courtLabel || '-'}${location}`,
          level: window.key === 'hour_1' || window.key === 'hours_2' ? 'warning' : 'info',
          entityType: 'hearing_reminder',
          entityId: hearingId,
          reminderKey: window.key,
          scheduledFor,
        });
      }
    }

    if (reminders.length) {
      await this.notificationModel.insertMany(reminders, { ordered: false });
    }
  }
}
