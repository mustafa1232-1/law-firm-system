import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type DocumentChunkDocument = HydratedDocument<DocumentChunk>;

@Schema({ timestamps: true, versionKey: false, collection: 'document_chunks' })
export class DocumentChunk {
  @Prop({ type: Types.ObjectId, ref: 'DocumentFile', required: true })
  documentId: Types.ObjectId;

  @Prop({ required: true })
  chunkIndex: number;

  @Prop({ required: true })
  text: string;

  @Prop({ type: [Number], default: [] })
  embedding: number[];

  @Prop({ type: Object, default: {} })
  metadata: Record<string, unknown>;
}

export const DocumentChunkSchema = SchemaFactory.createForClass(DocumentChunk);
DocumentChunkSchema.index({ text: 'text' });
