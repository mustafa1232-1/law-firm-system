import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type FirmDocument = HydratedDocument<Firm>;

export const FirmCategories = [
  'مكتب محاماة فردي',
  'شركة محاماة صغيرة',
  'شركة محاماة متوسطة',
  'شركة محاماة كبرى',
  'شركة استشارات قانونية',
  'شركة بحث قانوني',
  'أخرى',
] as const;

@Schema({ timestamps: true, versionKey: false, collection: 'firms' })
export class Firm {
  @Prop({ required: true })
  name: string;

  @Prop({ required: false })
  legalName?: string;

  @Prop({ required: false })
  registrationNo?: string;

  @Prop({ required: false })
  governorate?: string;

  @Prop({ required: false })
  address?: string;

  @Prop({ required: false })
  phone?: string;

  @Prop({ required: false })
  email?: string;

  @Prop({ required: false })
  website?: string;

  @Prop({ required: false })
  logoUrl?: string;

  @Prop({ required: false })
  description?: string;

  @Prop({ enum: FirmCategories, default: 'أخرى' })
  category: string;

  @Prop({ required: false })
  practiceFocus?: string;

  @Prop({ required: false })
  establishedYear?: number;

  @Prop({ default: 1 })
  employeeCount: number;

  @Prop({ default: true })
  isActive: boolean;
}

export const FirmSchema = SchemaFactory.createForClass(Firm);
