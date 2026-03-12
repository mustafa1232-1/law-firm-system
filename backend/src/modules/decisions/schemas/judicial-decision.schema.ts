import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type JudicialDecisionDocument = HydratedDocument<JudicialDecision>;

@Schema({ timestamps: true, versionKey: false, collection: 'judicial_decisions' })
export class JudicialDecision {
  @Prop({ required: true })
  source: string;

  @Prop({ required: true })
  sourceType: string;

  @Prop({ required: true })
  courtName: string;

  @Prop({ required: false })
  courtLevel?: string;

  @Prop({ required: false })
  governorate?: string;

  @Prop({ required: true })
  decisionNumber: string;

  @Prop({ required: true })
  decisionDate: Date;

  @Prop({ required: false })
  publicationDate?: Date;

  @Prop({ required: false })
  chamber?: string;

  @Prop({ required: false })
  caseType?: string;

  @Prop({ required: false })
  legalDomain?: string;

  @Prop({ required: false })
  summary?: string;

  @Prop({ required: false })
  fullText?: string;

  @Prop({ type: [String], default: [] })
  extractedCitations: string[];

  @Prop({ type: [String], default: [] })
  constitutionalReferences: string[];

  @Prop({ type: [String], default: [] })
  legalArticleReferences: string[];

  @Prop({ type: [String], default: [] })
  legalKeywords: string[];

  @Prop({ required: false })
  factsSummary?: string;

  @Prop({ required: false })
  reasoningSummary?: string;

  @Prop({ required: false })
  outcome?: string;

  @Prop({ default: 0.5 })
  precedentWeight: number;

  @Prop({ default: 0.5 })
  confidenceScore: number;

  @Prop({ type: [String], default: [] })
  tags: string[];

  @Prop({ type: [Number], default: [] })
  similarityEmbedding: number[];

  @Prop({ default: 'pending' })
  reviewStatus: 'pending' | 'approved' | 'rejected';

  @Prop({ default: 'published' })
  ingestionStatus: 'draft' | 'processing' | 'published' | 'failed';

  @Prop({ required: false })
  normalizedText?: string;
}

export const JudicialDecisionSchema = SchemaFactory.createForClass(JudicialDecision);
JudicialDecisionSchema.index({
  courtName: 'text',
  summary: 'text',
  fullText: 'text',
  legalKeywords: 'text',
  decisionNumber: 'text',
});
