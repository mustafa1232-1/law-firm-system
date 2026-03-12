import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AuditService } from '../audit/audit.service';
import { CreateFirmDto } from './dto/create-firm.dto';
import { UpdateFirmSettingsDto } from './dto/update-firm-settings.dto';
import { UpdateFirmDto } from './dto/update-firm.dto';
import { Firm, FirmDocument } from './schemas/firm.schema';
import { FirmSettings, FirmSettingsDocument } from './schemas/firm-settings.schema';

@Injectable()
export class FirmsService {
  constructor(
    @InjectModel(Firm.name)
    private readonly firmModel: Model<FirmDocument>,
    @InjectModel(FirmSettings.name)
    private readonly settingsModel: Model<FirmSettingsDocument>,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateFirmDto, actorId?: string) {
    const firm = await this.firmModel.create(dto);
    await this.settingsModel.create({ firmId: firm._id });

    await this.auditService.record({
      action: 'firm.create',
      entity: 'firms',
      entityId: firm.id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });

    return firm;
  }

  async findAll(query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.firmModel.find().sort({ createdAt: -1 }).skip(skip).limit(limit),
      this.firmModel.countDocuments(),
    ]);
    return { items, page, limit, total };
  }

  async findOne(id: string) {
    const firm = await this.firmModel.findById(id).lean();
    if (!firm) {
      throw new NotFoundException('Firm not found');
    }
    const settings = await this.settingsModel.findOne({ firmId: new Types.ObjectId(id) }).lean();
    return { ...firm, settings };
  }

  async update(id: string, dto: UpdateFirmDto, actorId?: string) {
    const firm = await this.firmModel.findByIdAndUpdate(id, dto, { new: true });
    if (!firm) {
      throw new NotFoundException('Firm not found');
    }

    await this.auditService.record({
      action: 'firm.update',
      entity: 'firms',
      entityId: id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });

    return firm;
  }

  async updateSettings(firmId: string, dto: UpdateFirmSettingsDto, actorId?: string) {
    const settings = await this.settingsModel.findOneAndUpdate(
      { firmId: new Types.ObjectId(firmId) },
      dto,
      { new: true, upsert: true },
    );
    await this.auditService.record({
      action: 'firm.settings.update',
      entity: 'firm_settings',
      entityId: settings.id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });
    return settings;
  }
}
