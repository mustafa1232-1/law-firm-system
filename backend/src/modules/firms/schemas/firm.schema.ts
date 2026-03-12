import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type FirmDocument = HydratedDocument<Firm>;

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

  @Prop({ default: true })
  isActive: boolean;
}

export const FirmSchema = SchemaFactory.createForClass(Firm);
