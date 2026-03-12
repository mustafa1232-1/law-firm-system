import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type IngestSourceDocument = HydratedDocument<IngestSource>;

@Schema({ timestamps: true, versionKey: false, collection: 'ingest_sources' })
export class IngestSource {
  @Prop({ required: true })
  name: string;

  @Prop({ required: true })
  sourceType: string;

  @Prop({ required: true })
  sourceUrl: string;

  @Prop({ default: true })
  active: boolean;

  @Prop({ type: Object, default: {} })
  metadata: Record<string, unknown>;
}

export const IngestSourceSchema = SchemaFactory.createForClass(IngestSource);
