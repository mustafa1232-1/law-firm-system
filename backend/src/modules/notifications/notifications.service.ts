import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { Notification, NotificationDocument } from './schemas/notification.schema';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectModel(Notification.name)
    private readonly notificationModel: Model<NotificationDocument>,
  ) {}

  create(dto: CreateNotificationDto) {
    return this.notificationModel.create({
      ...dto,
      userId: dto.userId ? new Types.ObjectId(dto.userId) : undefined,
    });
  }

  listForUser(userId: string, query: PaginationQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    return this.notificationModel
      .find({ userId: new Types.ObjectId(userId) })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();
  }

  markAsRead(id: string) {
    return this.notificationModel
      .findByIdAndUpdate(id, { $set: { isRead: true } }, { new: true })
      .lean();
  }
}
