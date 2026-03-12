import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type LegalTaxonomyDocument = HydratedDocument<LegalTaxonomy>;

@Schema({ timestamps: true, versionKey: false, collection: 'legal_taxonomy' })
export class LegalTaxonomy {
  @Prop({ required: true })
  category: string;

  @Prop({ required: true })
  code: string;

  @Prop({ required: true })
  title: string;

  @Prop({ required: false })
  parentCode?: string;

  @Prop({ type: [String], default: [] })
  keywords: string[];
}

export const LegalTaxonomySchema = SchemaFactory.createForClass(LegalTaxonomy);
LegalTaxonomySchema.index({ code: 1 }, { unique: true });
