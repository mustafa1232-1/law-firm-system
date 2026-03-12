import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AuditService } from '../audit/audit.service';
import { CreateClientDto } from './dto/create-client.dto';
import { UpdateClientDto } from './dto/update-client.dto';
import { Client, ClientDocument } from './schemas/client.schema';

@Injectable()
export class ClientsService {
  constructor(
    @InjectModel(Client.name)
    private readonly clientModel: Model<ClientDocument>,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateClientDto, actorId?: string) {
    const client = await this.clientModel.create(dto);
    await this.auditService.record({
      action: 'client.create',
      entity: 'clients',
      entityId: client.id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });
    return client;
  }

  async findAll(query: PaginationQueryDto, search?: string) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const filter = search ? { $text: { $search: search } } : {};

    const [items, total] = await Promise.all([
      this.clientModel
        .find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.clientModel.countDocuments(filter),
    ]);

    return { items, page, limit, total };
  }

  async findOne(id: string) {
    const client = await this.clientModel.findById(id).lean();
    if (!client) {
      throw new NotFoundException('Client not found');
    }
    return client;
  }

  async update(id: string, dto: UpdateClientDto, actorId?: string) {
    const client = await this.clientModel.findByIdAndUpdate(id, dto, { new: true });
    if (!client) {
      throw new NotFoundException('Client not found');
    }
    await this.auditService.record({
      action: 'client.update',
      entity: 'clients',
      entityId: id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });
    return client;
  }

  async remove(id: string, actorId?: string) {
    const deleted = await this.clientModel.findByIdAndDelete(id);
    if (!deleted) {
      throw new NotFoundException('Client not found');
    }
    await this.auditService.record({
      action: 'client.delete',
      entity: 'clients',
      entityId: id,
      actorId,
    });
    return { success: true };
  }
}
