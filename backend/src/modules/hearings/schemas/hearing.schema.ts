import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type HearingDocument = HydratedDocument<Hearing>;

@Schema({ timestamps: true, versionKey: false, collection: 'hearings' })
export class Hearing {
  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: true })
  caseId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'Court', required: false })
  courtId?: Types.ObjectId;

  @Prop({ required: true })
  hearingDate: Date;

  @Prop({ required: false })
  court?: string;

  @Prop({ required: false })
  courtGovernorate?: string;

  @Prop({ required: false })
  courtCity?: string;

  @Prop({ required: false })
  courtDistrict?: string;

  @Prop({ required: false })
  courtArea?: string;

  @Prop({ required: false })
  courtLocationDescription?: string;

  @Prop({ required: false })
  room?: string;

  @Prop({ required: false })
  judge?: string;

  @Prop({ required: false })
  notes?: string;

  @Prop({ type: [String], default: [] })
  requiredDocuments: string[];

  @Prop({ required: false })
  outcome?: string;

  @Prop({ required: false })
  nextAction?: string;
}

export const HearingSchema = SchemaFactory.createForClass(Hearing);
HearingSchema.index({ hearingDate: 1 });
