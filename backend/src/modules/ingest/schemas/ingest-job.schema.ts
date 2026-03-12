import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type IngestJobDocument = HydratedDocument<IngestJob>;

@Schema({ timestamps: true, versionKey: false, collection: 'ingest_jobs' })
export class IngestJob {
  @Prop({ required: true })
  pipeline: string;

  @Prop({ required: true })
  status: 'queued' | 'processing' | 'needs_review' | 'completed' | 'failed';

  @Prop({ type: Types.ObjectId, ref: 'IngestSource', required: false })
  sourceId?: Types.ObjectId;

  @Prop({ required: false })
  queuedJobId?: string;

  @Prop({ type: Object, default: {} })
  input: Record<string, unknown>;

  @Prop({ type: [String], default: [] })
  stepsCompleted: string[];

  @Prop({ type: Object, default: {} })
  output: Record<string, unknown>;

  @Prop({ required: false })
  errorMessage?: string;

  @Prop({ required: false })
  actorId?: string;
}

export const IngestJobSchema = SchemaFactory.createForClass(IngestJob);
IngestJobSchema.index({ status: 1, createdAt: -1 });
