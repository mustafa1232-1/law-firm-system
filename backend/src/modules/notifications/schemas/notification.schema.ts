import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type NotificationDocument = HydratedDocument<Notification>;

@Schema({ timestamps: true, versionKey: false, collection: 'notifications' })
export class Notification {
  @Prop({ type: Types.ObjectId, ref: 'User', required: false })
  userId?: Types.ObjectId;

  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  message: string;

  @Prop({ default: 'info' })
  level: 'info' | 'warning' | 'critical';

  @Prop({ default: false })
  isRead: boolean;

  @Prop({ required: false })
  scheduledFor?: Date;

  @Prop({ required: false })
  reminderKey?: string;

  @Prop({ required: false })
  entityType?: string;

  @Prop({ required: false })
  entityId?: string;
}

export const NotificationSchema = SchemaFactory.createForClass(Notification);
NotificationSchema.index({ userId: 1, isRead: 1, scheduledFor: -1, createdAt: -1 });
NotificationSchema.index({ entityType: 1, entityId: 1, reminderKey: 1 });
