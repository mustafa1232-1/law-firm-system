import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AuditService } from '../audit/audit.service';
import { CreateHearingDto } from './dto/create-hearing.dto';
import { UpdateHearingDto } from './dto/update-hearing.dto';
import { Hearing, HearingDocument } from './schemas/hearing.schema';

@Injectable()
export class HearingsService {
  constructor(
    @InjectModel(Hearing.name) private readonly hearingModel: Model<HearingDocument>,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateHearingDto, actorId?: string) {
    const created = await this.hearingModel.create({
      ...dto,
      caseId: new Types.ObjectId(dto.caseId),
      hearingDate: new Date(dto.hearingDate),
    });

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
        .lean(),
      this.hearingModel.countDocuments(),
    ]);

    return { items, page, limit, total };
  }

  async update(id: string, dto: UpdateHearingDto, actorId?: string) {
    const payload: Record<string, unknown> = { ...dto };
    if (dto.caseId) payload.caseId = new Types.ObjectId(dto.caseId);
    if (dto.hearingDate) payload.hearingDate = new Date(dto.hearingDate);

    const updated = await this.hearingModel
      .findByIdAndUpdate(id, payload, { new: true })
      .lean();
    if (!updated) {
      throw new NotFoundException('Hearing not found');
    }

    await this.auditService.record({
      action: 'hearing.update',
      entity: 'hearings',
      entityId: id,
      actorId,
    });

    return updated;
  }
}
