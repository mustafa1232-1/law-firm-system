import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import * as bcrypt from 'bcryptjs';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AuditService } from '../audit/audit.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { User, UserDocument } from './schemas/user.schema';

@Injectable()
export class UsersService {
  constructor(
    @InjectModel(User.name) private readonly userModel: Model<UserDocument>,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateUserDto, actorId?: string) {
    const email = this.normalizeEmail(dto.email);
    const phone = this.normalizePhone(dto.phone);
    if (!email && !phone) {
      throw new BadRequestException(
        'Either email or phone must be provided',
      );
    }

    if (email) {
      const existingEmail = await this.findByEmail(email);
      if (existingEmail) {
        throw new ConflictException('Email already used');
      }
    }

    if (phone) {
      const existingPhone = await this.findByPhone(phone);
      if (existingPhone) {
        throw new ConflictException('Phone already used');
      }
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const created = await this.userModel.create({
      ...dto,
      email,
      phone,
      firmId: dto.firmId ? new Types.ObjectId(dto.firmId) : undefined,
      passwordHash,
    });

    await this.auditService.record({
      action: 'user.create',
      entity: 'users',
      entityId: created.id,
      actorId,
      payload: {
        email: created.email,
        phone: created.phone,
      },
    });

    return this.sanitize(created.toObject());
  }

  async findAll(query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;

    const [items, total] = await Promise.all([
      this.userModel.find().sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      this.userModel.countDocuments(),
    ]);

    return {
      items: items.map((u) => this.sanitize(u)),
      page,
      limit,
      total,
    };
  }

  async findById(id: string) {
    const user = await this.userModel.findById(id).lean();
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return this.sanitize(user);
  }

  async findByEmail(email?: string | null) {
    const normalized = this.normalizeEmail(email);
    if (!normalized) {
      return null;
    }
    return this.userModel.findOne({ email: normalized });
  }

  async findByPhone(phone?: string | null) {
    const normalized = this.normalizePhone(phone);
    if (!normalized) {
      return null;
    }
    return this.userModel.findOne({ phone: normalized });
  }

  async findByIdentifier(identifier: string) {
    const normalized = identifier.trim();
    if (!normalized) {
      return null;
    }

    if (normalized.includes('@')) {
      return this.findByEmail(normalized);
    }

    return this.findByPhone(normalized);
  }

  async update(id: string, dto: UpdateUserDto, actorId?: string) {
    const payload: Record<string, unknown> = { ...dto };
    if (dto.password) {
      payload.passwordHash = await bcrypt.hash(dto.password, 10);
      delete payload.password;
    }
    if (dto.firmId) {
      payload.firmId = new Types.ObjectId(dto.firmId);
    }
    if (dto.email !== undefined) {
      payload.email = this.normalizeEmail(dto.email);
    }
    if (dto.phone !== undefined) {
      payload.phone = this.normalizePhone(dto.phone);
    }

    const updated = await this.userModel
      .findByIdAndUpdate(id, payload, { new: true })
      .lean();

    if (!updated) {
      throw new NotFoundException('User not found');
    }

    await this.auditService.record({
      action: 'user.update',
      entity: 'users',
      entityId: id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });

    return this.sanitize(updated);
  }

  async updatePassword(id: string, newPassword: string, actorId?: string) {
    const user = await this.userModel.findById(id);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    user.passwordHash = await bcrypt.hash(newPassword, 10);
    await user.save();

    await this.auditService.record({
      action: 'user.password.update',
      entity: 'users',
      entityId: id,
      actorId,
    });

    return this.sanitize(user.toObject());
  }

  async remove(id: string, actorId?: string) {
    const deleted = await this.userModel.findByIdAndDelete(id).lean();
    if (!deleted) {
      throw new NotFoundException('User not found');
    }
    await this.auditService.record({
      action: 'user.delete',
      entity: 'users',
      entityId: id,
      actorId,
    });
    return { success: true };
  }

  private sanitize(user: any) {
    const { passwordHash, ...rest } = user;
    return rest;
  }

  private normalizeEmail(value?: string | null): string | undefined {
    const normalized = (value ?? '').trim().toLowerCase();
    return normalized.length === 0 ? undefined : normalized;
  }

  private normalizePhone(value?: string | null): string | undefined {
    const raw = (value ?? '').trim();
    if (!raw) {
      return undefined;
    }

    const normalized = raw
      .replace(/\s+/g, '')
      .replace(/-/g, '')
      .replace(/\(/g, '')
      .replace(/\)/g, '');

    return normalized.length === 0 ? undefined : normalized;
  }
}
