import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type PaymentDocument = HydratedDocument<Payment>;

@Schema({ timestamps: true, versionKey: false, collection: 'payments' })
export class Payment {
  @Prop({ type: Types.ObjectId, ref: 'Invoice', required: true })
  invoiceId: Types.ObjectId;

  @Prop({ required: true })
  amount: number;

  @Prop({ required: true })
  paymentDate: Date;

  @Prop({ required: false })
  method?: string;

  @Prop({ required: false })
  reference?: string;

  @Prop({ required: false })
  notes?: string;
}

export const PaymentSchema = SchemaFactory.createForClass(Payment);
