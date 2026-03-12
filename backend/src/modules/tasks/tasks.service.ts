import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AuditService } from '../audit/audit.service';
import { CreateTaskDto } from './dto/create-task.dto';
import { UpdateTaskDto } from './dto/update-task.dto';
import { TaskItem, TaskItemDocument } from './schemas/task.schema';

@Injectable()
export class TasksService {
  constructor(
    @InjectModel(TaskItem.name) private readonly taskModel: Model<TaskItemDocument>,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateTaskDto, actorId?: string) {
    const created = await this.taskModel.create({
      ...dto,
      caseId: dto.caseId ? new Types.ObjectId(dto.caseId) : undefined,
      assignedTo: dto.assignedTo ? new Types.ObjectId(dto.assignedTo) : undefined,
      dueDate: dto.dueDate ? new Date(dto.dueDate) : undefined,
      reminderAt: dto.reminderAt ? new Date(dto.reminderAt) : undefined,
    });

    await this.auditService.record({
      action: 'task.create',
      entity: 'tasks',
      entityId: created.id,
      actorId,
    });

    return created;
  }

  async findAll(query: PaginationQueryDto, status?: string) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const filter = status ? { status } : {};

    const [items, total] = await Promise.all([
      this.taskModel
        .find(filter)
        .sort({ dueDate: 1, createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('caseId', 'title caseNumber')
        .populate('assignedTo', 'fullName')
        .lean(),
      this.taskModel.countDocuments(filter),
    ]);

    return { items, page, limit, total };
  }

  async update(id: string, dto: UpdateTaskDto, actorId?: string) {
    const payload: Record<string, unknown> = { ...dto };
    if (dto.caseId) payload.caseId = new Types.ObjectId(dto.caseId);
    if (dto.assignedTo) payload.assignedTo = new Types.ObjectId(dto.assignedTo);
    if (dto.dueDate) payload.dueDate = new Date(dto.dueDate);
    if (dto.reminderAt) payload.reminderAt = new Date(dto.reminderAt);

    const updated = await this.taskModel
      .findByIdAndUpdate(id, payload, { new: true })
      .lean();
    if (!updated) {
      throw new NotFoundException('Task not found');
    }

    await this.auditService.record({
      action: 'task.update',
      entity: 'tasks',
      entityId: id,
      actorId,
    });

    return updated;
  }
}
