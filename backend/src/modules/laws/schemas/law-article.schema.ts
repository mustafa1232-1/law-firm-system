import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type LawArticleDocument = HydratedDocument<LawArticle>;

@Schema({ timestamps: true, versionKey: false, collection: 'law_articles' })
export class LawArticle {
  @Prop({ type: Types.ObjectId, ref: 'LawDocumentEntity', required: true })
  lawId: Types.ObjectId;

  @Prop({ required: true })
  articleNumber: string;

  @Prop({ required: true, default: 0 })
  articleOrder: number;

  @Prop({ required: true })
  text: string;

  @Prop({ required: true })
  normalizedText: string;

  @Prop({ type: [String], default: [] })
  paragraphs: string[];

  @Prop({ type: [String], default: [] })
  keywords: string[];
}

export const LawArticleSchema = SchemaFactory.createForClass(LawArticle);
LawArticleSchema.index({ text: 'text', keywords: 'text' });
LawArticleSchema.index({ lawId: 1, articleOrder: 1 });
