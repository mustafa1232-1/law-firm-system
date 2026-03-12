import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type DecisionChunkDocument = HydratedDocument<DecisionChunk>;

@Schema({ timestamps: true, versionKey: false, collection: 'decision_chunks' })
export class DecisionChunk {
  @Prop({ type: Types.ObjectId, ref: 'JudicialDecision', required: true })
  decisionId: Types.ObjectId;

  @Prop({ required: true })
  chunkIndex: number;

  @Prop({ required: true })
  text: string;

  @Prop({ type: [Number], default: [] })
  embedding: number[];

  @Prop({ type: Object, default: {} })
  metadata: Record<string, unknown>;
}

export const DecisionChunkSchema = SchemaFactory.createForClass(DecisionChunk);
DecisionChunkSchema.index({ text: 'text' });
