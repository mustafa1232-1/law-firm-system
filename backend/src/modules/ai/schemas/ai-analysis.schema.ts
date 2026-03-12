import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type AiAnalysisDocument = HydratedDocument<AiAnalysis>;

@Schema({ timestamps: true, versionKey: false, collection: 'ai_analyses' })
export class AiAnalysis {
  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: false })
  caseId?: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'AiSession', required: false })
  sessionId?: Types.ObjectId;

  @Prop({ required: true })
  analysisType: string;

  @Prop({ required: true })
  inputText: string;

  @Prop({ type: Object, default: {} })
  output: Record<string, unknown>;

  @Prop({ type: [Object], default: [] })
  citations: Array<Record<string, unknown>>;

  @Prop({ default: 0.5 })
  confidenceScore: number;

  @Prop({ required: true })
  disclaimer: string;
}

export const AiAnalysisSchema = SchemaFactory.createForClass(AiAnalysis);
