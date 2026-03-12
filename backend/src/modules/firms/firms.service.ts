import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { SystemRole } from 'src/common/constants/system.constants';
import { AuditService } from '../audit/audit.service';
import { UsersService } from '../users/users.service';
import { User, UserDocument } from '../users/schemas/user.schema';
import { CreateFirmDto } from './dto/create-firm.dto';
import { RegisterCompanyDto } from './dto/register-company.dto';
import { UpdateFirmSettingsDto } from './dto/update-firm-settings.dto';
import { UpdateFirmDto } from './dto/update-firm.dto';
import { Firm, FirmCategories, FirmDocument } from './schemas/firm.schema';
import { FirmSettings, FirmSettingsDocument } from './schemas/firm-settings.schema';

@Injectable()
export class FirmsService {
  constructor(
    @InjectModel(Firm.name)
    private readonly firmModel: Model<FirmDocument>,
    @InjectModel(FirmSettings.name)
    private readonly settingsModel: Model<FirmSettingsDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    private readonly usersService: UsersService,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateFirmDto, actorId?: string) {
    const firm = await this.firmModel.create({
      ...dto,
      employeeCount: dto.employeeCount ?? 1,
      category: this.normalizeFirmCategory(dto.category),
    });
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

  async registerCompany(dto: RegisterCompanyDto) {
    const existingUser = await this.usersService.findByEmail(dto.adminEmail);
    if (existingUser) {
      throw new ConflictException('Admin email already used');
    }

    const firm = await this.firmModel.create({
      name: dto.name,
      legalName: dto.legalName,
      registrationNo: dto.registrationNo,
      governorate: dto.governorate,
      address: dto.address,
      phone: dto.phone,
      email: dto.email,
      website: dto.website,
      logoUrl: dto.logoUrl,
      description: dto.description,
      category: this.normalizeFirmCategory(dto.category),
      practiceFocus: dto.practiceFocus,
      establishedYear: dto.establishedYear,
      employeeCount: dto.employeeCount ?? 1,
    });

    await this.settingsModel.create({ firmId: firm._id });

    const adminUser = await this.usersService.create({
      fullName: dto.adminFullName,
      email: dto.adminEmail,
      phone: dto.adminPhone,
      password: dto.adminPassword,
      firmId: firm._id.toString(),
      roles: [SystemRole.FIRM_ADMIN],
    });

    await this.auditService.record({
      action: 'firm.register-company',
      entity: 'firms',
      entityId: firm.id,
      payload: {
        firmName: dto.name,
        adminEmail: dto.adminEmail,
      },
    });

    return {
      message: 'Company account registered successfully. Please sign in with the admin credentials.',
      firm,
      adminUser,
    };
  }

  async findAll(query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this.firmModel.find().sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      this.firmModel.countDocuments(),
    ]);

    const enriched = await Promise.all(
      items.map(async (firm) => {
        const activeUsers = await this.userModel.countDocuments({
          firmId: firm._id,
          isActive: true,
        });

        return {
          ...firm,
          activeUsers,
          workforceStrength: this.calcWorkforceStrength(activeUsers, firm.employeeCount ?? 0),
        };
      }),
    );

    return { items: enriched, page, limit, total };
  }

  async findOne(id: string) {
    const firm = await this.firmModel.findById(id).lean();
    if (!firm) {
      throw new NotFoundException('Firm not found');
    }

    const settings = await this.settingsModel.findOne({ firmId: new Types.ObjectId(id) }).lean();
    const activeUsers = await this.userModel.countDocuments({
      firmId: new Types.ObjectId(id),
      isActive: true,
    });

    return {
      ...firm,
      settings,
      activeUsers,
      workforceStrength: this.calcWorkforceStrength(activeUsers, firm.employeeCount ?? 0),
    };
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

  private calcWorkforceStrength(activeUsers: number, employeeCount: number) {
    const workforce = Math.max(activeUsers, employeeCount);
    if (workforce >= 100) return 'Tier 4 - Enterprise';
    if (workforce >= 40) return 'Tier 3 - Large Firm';
    if (workforce >= 15) return 'Tier 2 - Growing Firm';
    return 'Tier 1 - Small Firm';
  }

  private normalizeFirmCategory(value?: string) {
    const raw = (value ?? '').trim();
    if (!raw) {
      return 'أخرى';
    }

    if (FirmCategories.includes(raw as any)) {
      return raw;
    }

    const normalized = raw.toLowerCase();

    if (normalized.includes('large') || normalized.includes('كبرى')) {
      return 'شركة محاماة كبرى';
    }

    if (normalized.includes('medium') || normalized.includes('متوسطة')) {
      return 'شركة محاماة متوسطة';
    }

    if (normalized.includes('small') || normalized.includes('صغيرة')) {
      return 'شركة محاماة صغيرة';
    }

    if (normalized.includes('consult') || normalized.includes('استشار')) {
      return 'شركة استشارات قانونية';
    }

    if (normalized.includes('research') || normalized.includes('بحث')) {
      return 'شركة بحث قانوني';
    }

    if (normalized.includes('law') || normalized.includes('firm') || normalized.includes('محام')) {
      return 'شركة محاماة صغيرة';
    }

    return 'أخرى';
  }
}
