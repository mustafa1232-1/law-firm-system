import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type MemoDraftDocument = HydratedDocument<MemoDraft>;

@Schema({ timestamps: true, versionKey: false, collection: 'memo_drafts' })
export class MemoDraft {
  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: false })
  caseId?: Types.ObjectId;

  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  body: string;

  @Prop({ type: [Object], default: [] })
  citations: Array<Record<string, unknown>>;

  @Prop({ default: 'draft' })
  status: 'draft' | 'reviewed';
}

export const MemoDraftSchema = SchemaFactory.createForClass(MemoDraft);
