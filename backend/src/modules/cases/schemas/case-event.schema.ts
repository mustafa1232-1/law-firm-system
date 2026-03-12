import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type CaseEventDocument = HydratedDocument<CaseEvent>;

@Schema({ timestamps: true, versionKey: false, collection: 'case_events' })
export class CaseEvent {
  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: true })
  caseId: Types.ObjectId;

  @Prop({ required: true })
  eventType: string;

  @Prop({ required: true })
  title: string;

  @Prop({ required: false })
  details?: string;

  @Prop({ required: false })
  eventDate?: Date;
}

export const CaseEventSchema = SchemaFactory.createForClass(CaseEvent);
