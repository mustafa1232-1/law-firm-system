import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type DocumentFileDocument = HydratedDocument<DocumentFile>;

@Schema({ timestamps: true, versionKey: false, collection: 'documents' })
export class DocumentFile {
  @Prop({ type: Types.ObjectId, ref: 'Firm', required: false })
  firmId?: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: false })
  caseId?: Types.ObjectId;

  @Prop({ required: true })
  title: string;

  @Prop({ required: true })
  originalName: string;

  @Prop({ required: true })
  mimeType: string;

  @Prop({ required: true })
  storagePath: string;

  @Prop({ required: false })
  sizeBytes?: number;

  @Prop({ type: [String], default: [] })
  tags: string[];

  @Prop({ required: false })
  extractedText?: string;

  @Prop({ type: Object, default: {} })
  extractedEntities: Record<string, unknown>;

  @Prop({ type: [String], default: [] })
  referencedLawArticles: string[];

  @Prop({ type: [String], default: [] })
  referencedConstitutionArticles: string[];

  @Prop({ type: [String], default: [] })
  referencedDecisionIds: string[];

  @Prop({ default: 1 })
  version: number;

  @Prop({ default: false })
  archived: boolean;
}

export const DocumentFileSchema = SchemaFactory.createForClass(DocumentFile);
DocumentFileSchema.index({ title: 'text', originalName: 'text', extractedText: 'text' });
