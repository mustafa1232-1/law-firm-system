import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type CasePartyDocument = HydratedDocument<CaseParty>;

@Schema({ timestamps: true, versionKey: false, collection: 'case_parties' })
export class CaseParty {
  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: true })
  caseId: Types.ObjectId;

  @Prop({ required: true })
  name: string;

  @Prop({ required: true })
  role: string;

  @Prop({ required: false })
  representation?: string;
}

export const CasePartySchema = SchemaFactory.createForClass(CaseParty);
