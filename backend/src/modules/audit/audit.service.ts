import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { AuditLog, AuditLogDocument } from './schemas/audit-log.schema';

@Injectable()
export class AuditService {
  constructor(
    @InjectModel(AuditLog.name)
    private readonly auditLogModel: Model<AuditLogDocument>,
  ) {}

  async record(input: {
    action: string;
    entity: string;
    entityId?: string;
    actorId?: string;
    payload?: Record<string, unknown>;
    ipAddress?: string;
  }): Promise<void> {
    await this.auditLogModel.create(input);
  }
}
