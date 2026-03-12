import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type ClientDocument = HydratedDocument<Client>;

@Schema({ timestamps: true, versionKey: false, collection: 'clients' })
export class Client {
  @Prop({ type: Types.ObjectId, ref: 'Firm', required: false })
  firmId?: Types.ObjectId;

  @Prop({ required: true })
  fullName: string;

  @Prop({ required: false })
  companyName?: string;

  @Prop({ required: false })
  nationalId?: string;

  @Prop({ required: false })
  phone?: string;

  @Prop({ required: false })
  email?: string;

  @Prop({ required: false })
  address?: string;

  @Prop({ type: [String], default: [] })
  tags: string[];

  @Prop({ default: false })
  archived: boolean;
}

export const ClientSchema = SchemaFactory.createForClass(Client);
ClientSchema.index({ fullName: 'text', companyName: 'text' });
