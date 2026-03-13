import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type CourtDocument = HydratedDocument<Court>;

@Schema({ timestamps: true, versionKey: false, collection: 'courts' })
export class Court {
  @Prop({ required: true })
  name: string;

  @Prop({ required: false })
  nameAr?: string;

  @Prop({ required: false })
  nameEn?: string;

  @Prop({ required: false })
  governorate?: string;

  @Prop({ required: false })
  city?: string;

  @Prop({ required: false })
  district?: string;

  @Prop({ required: false })
  area?: string;

  @Prop({ required: false })
  addressDescription?: string;

  @Prop({ required: false })
  latitude?: number;

  @Prop({ required: false })
  longitude?: number;

  @Prop({ default: 'manual' })
  source: string;

  @Prop({ required: false })
  sourceType?: string;

  @Prop({ required: false })
  sourceRef?: string;

  @Prop({ required: false })
  sourceUrl?: string;

  @Prop({ type: Object, default: {} })
  tags: Record<string, unknown>;
}

export const CourtSchema = SchemaFactory.createForClass(Court);
CourtSchema.index({
  name: 'text',
  nameAr: 'text',
  nameEn: 'text',
  governorate: 'text',
  city: 'text',
  district: 'text',
  area: 'text',
  addressDescription: 'text',
});
CourtSchema.index({ governorate: 1, city: 1, district: 1, name: 1 });
