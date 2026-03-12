import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument, Types } from 'mongoose';

export type InvoiceDocument = HydratedDocument<Invoice>;

@Schema({ timestamps: true, versionKey: false, collection: 'invoices' })
export class Invoice {
  @Prop({ required: true })
  invoiceNumber: string;

  @Prop({ type: Types.ObjectId, ref: 'Client', required: true })
  clientId: Types.ObjectId;

  @Prop({ type: Types.ObjectId, ref: 'CaseFile', required: false })
  caseId?: Types.ObjectId;

  @Prop({ required: true })
  amount: number;

  @Prop({ default: 'IQD' })
  currency: string;

  @Prop({ required: true })
  issueDate: Date;

  @Prop({ required: false })
  dueDate?: Date;

  @Prop({ default: 'unpaid' })
  status: 'unpaid' | 'partial' | 'paid' | 'overdue';

  @Prop({ required: false })
  notes?: string;
}

export const InvoiceSchema = SchemaFactory.createForClass(Invoice);
InvoiceSchema.index({ invoiceNumber: 1 }, { unique: true });
