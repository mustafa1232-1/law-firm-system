import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type ConstitutionArticleDocument = HydratedDocument<ConstitutionArticle>;

@Schema({
  timestamps: true,
  versionKey: false,
  collection: 'constitution_articles',
})
export class ConstitutionArticle {
  @Prop({ required: false })
  sourceName?: string;

  @Prop({ required: false })
  sourceUrl?: string;

  @Prop({ required: false })
  sourceType?: string;

  @Prop({ required: true })
  articleNumber: string;

  @Prop({ required: false })
  title?: string;

  @Prop({ required: false })
  chapter?: string;

  @Prop({ required: false })
  section?: string;

  @Prop({ required: true })
  text: string;

  @Prop({ required: true })
  normalizedText: string;

  @Prop({ type: [String], default: [] })
  keywords: string[];

  @Prop({ type: [String], default: [] })
  linkedLawArticleIds: string[];

  @Prop({ type: [String], default: [] })
  linkedDecisionIds: string[];
}

export const ConstitutionArticleSchema =
  SchemaFactory.createForClass(ConstitutionArticle);
ConstitutionArticleSchema.index({ articleNumber: 1 }, { unique: true });
ConstitutionArticleSchema.index({ text: 'text', title: 'text', keywords: 'text' });
