import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type TaskItemDocument = HydratedDocument<TaskItem>;

@Schema({ timestamps: true, versionKey: false, collection: 'tasks' })
export class TaskItem {
  @Prop({ required: true })
  title: string;

  @Prop({ required: false })
  description?: string;

  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: false })
  caseId?: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'User', required: false })
  assignedTo?: Types.ObjectId;

  @Prop({ required: false })
  dueDate?: Date;

  @Prop({ default: 'medium' })
  priority: 'low' | 'medium' | 'high' | 'urgent';

  @Prop({ default: 'open' })
  status: 'open' | 'in_progress' | 'done' | 'cancelled';

  @Prop({ required: false })
  reminderAt?: Date;

  @Prop({ type: [String], default: [] })
  comments: string[];
}

export const TaskItemSchema = SchemaFactory.createForClass(TaskItem);
TaskItemSchema.index({ dueDate: 1, status: 1 });
