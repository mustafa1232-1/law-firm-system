import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type CaseDocument = HydratedDocument<CaseFile>;

export const IraqiCaseTypes = [
  'مدنية',
  'تجارية',
  'جنائية',
  'أحوال شخصية',
  'عمالية',
  'إدارية',
  'عقارية',
  'ضريبية',
  'دستورية',
  'تنفيذ',
  'تحكيم',
  'أخرى',
] as const;

@Schema({ _id: false, versionKey: false })
export class CaseEvidenceEntry {
  @Prop({ type: Types.ObjectId, ref: 'Document', required: false })
  documentId?: Types.ObjectId;

  @Prop({ required: false })
  attachmentName?: string;

  @Prop({ required: false })
  description?: string;
}

export const CaseEvidenceEntrySchema = SchemaFactory.createForClass(CaseEvidenceEntry);

@Schema({ timestamps: true, versionKey: false, collection: 'cases' })
export class CaseFile {
  @Prop({ type: Types.ObjectId, ref: 'Firm', required: false })
  firmId?: Types.ObjectId;

  @Prop({ required: true })
  caseNumber: string;

  @Prop({ required: false })
  internalReference?: string;

  @Prop({ required: true })
  title: string;

  @Prop({ enum: IraqiCaseTypes, default: 'أخرى' })
  caseType: string;

  @Prop({ required: false })
  subcategory?: string;

  @Prop({ type: Types.ObjectId, ref: 'Court', required: false })
  courtId?: Types.ObjectId;

  @Prop({ required: false })
  court?: string;

  @Prop({ required: false })
  courtCity?: string;

  @Prop({ required: false })
  courtDistrict?: string;

  @Prop({ required: false })
  courtArea?: string;

  @Prop({ required: false })
  courtLocationDescription?: string;

  @Prop({ required: false })
  governorate?: string;

  @Prop({ required: false })
  jurisdiction?: string;

  @Prop({ default: 'open' })
  status: string;

  @Prop({ required: false })
  stage?: string;

  @Prop({ type: Types.ObjectId, ref: 'Client', required: false })
  clientId?: Types.ObjectId;

  @Prop({ required: false })
  oppositeParty?: string;

  @Prop({ type: [Types.ObjectId], ref: 'User', default: [] })
  lawyerIds: Types.ObjectId[];

  @Prop({ required: false })
  summary?: string;

  @Prop({ required: false })
  facts?: string;

  @Prop({ required: false })
  claims?: string;

  @Prop({ required: false })
  defenses?: string;

  @Prop({ required: false })
  counterArguments?: string;

  @Prop({ type: [Date], default: [] })
  importantDates: Date[];

  @Prop({ type: [Date], default: [] })
  hearingDates: Date[];

  @Prop({ type: [Types.ObjectId], ref: 'Document', default: [] })
  documentIds: Types.ObjectId[];

  @Prop({ type: [String], default: [] })
  evidenceList: string[];

  @Prop({ type: [CaseEvidenceEntrySchema], default: [] })
  evidenceEntries: CaseEvidenceEntry[];

  @Prop({ required: false })
  fees?: number;

  @Prop({ required: false })
  contractDate?: Date;

  @Prop({ required: false, default: 0 })
  contractAmount?: number;

  @Prop({ default: 0 })
  paidAmount: number;

  @Prop({ default: 0 })
  outstandingAmount: number;

  @Prop({ default: 'unpaid' })
  paymentStatus: 'unpaid' | 'partial' | 'paid';

  @Prop({ default: 'pending' })
  outcome: 'pending' | 'won' | 'lost';

  @Prop({ type: [String], default: [] })
  linkedLawArticleIds: string[];

  @Prop({ type: [String], default: [] })
  linkedConstitutionArticleIds: string[];

  @Prop({ type: [String], default: [] })
  linkedDecisionIds: string[];

  @Prop({ type: Object, default: {} })
  aiInsights: Record<string, unknown>;

  @Prop({ default: 0 })
  riskScore: number;

  @Prop({ required: false })
  strategyNotes?: string;

  @Prop({ default: false })
  archived: boolean;

  @Prop({ type: Object, default: {} })
  caseGenome: Record<string, unknown>;
}

export const CaseSchema = SchemaFactory.createForClass(CaseFile);
CaseSchema.index({ title: 'text', caseNumber: 'text', summary: 'text', facts: 'text' });
