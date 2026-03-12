import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type LawDocumentEntityDocument = HydratedDocument<LawDocumentEntity>;

@Schema({ timestamps: true, versionKey: false, collection: 'law_documents' })
export class LawDocumentEntity {
  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  lawNumber: string;

  @Prop({ required: true })
  year: number;

  @Prop({ required: false })
  issuingBody?: string;

  @Prop({ required: false })
  legalDomain?: string;

  @Prop({ required: false })
  repealStatus?: string;

  @Prop({ type: [String], default: [] })
  keywords: string[];

  @Prop({ type: [String], default: [] })
  linkedConstitutionTopics: string[];

  @Prop({ type: [String], default: [] })
  linkedDecisionIds: string[];
}

export const LawDocumentSchema = SchemaFactory.createForClass(LawDocumentEntity);
LawDocumentSchema.index({ title: 'text', keywords: 'text' });
