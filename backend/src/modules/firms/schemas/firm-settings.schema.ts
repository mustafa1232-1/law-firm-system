import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type FirmSettingsDocument = HydratedDocument<FirmSettings>;

@Schema({ timestamps: true, versionKey: false, collection: 'firm_settings' })
export class FirmSettings {
  @Prop({ type: Types.ObjectId, ref: 'Firm', required: true, unique: true })
  firmId: Types.ObjectId;

  @Prop({ default: 'ar-IQ' })
  locale: string;

  @Prop({ default: 'Asia/Baghdad' })
  timezone: string;

  @Prop({ default: 'IQD' })
  currency: string;

  @Prop({ type: Object, default: {} })
  preferences: Record<string, unknown>;
}

export const FirmSettingsSchema = SchemaFactory.createForClass(FirmSettings);
