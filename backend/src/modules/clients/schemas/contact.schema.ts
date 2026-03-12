import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type ContactDocument = HydratedDocument<Contact>;

@Schema({ timestamps: true, versionKey: false, collection: 'contacts' })
export class Contact {
  @Prop({ type: Types.ObjectId, ref: 'Client', required: true })
  clientId: Types.ObjectId;

  @Prop({ required: true })
  name: string;

  @Prop({ required: false })
  role?: string;

  @Prop({ required: false })
  phone?: string;

  @Prop({ required: false })
  email?: string;
}

export const ContactSchema = SchemaFactory.createForClass(Contact);
