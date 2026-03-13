import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { CaseFile, CaseSchema } from '../cases/schemas/case.schema';
import { BillingController } from './billing.controller';
import { BillingService } from './billing.service';
import { Invoice, InvoiceSchema } from './schemas/invoice.schema';
import { Payment, PaymentSchema } from './schemas/payment.schema';

@Module({
  imports: [
    AuditModule,
    MongooseModule.forFeature([
      { name: Invoice.name, schema: InvoiceSchema },
      { name: Payment.name, schema: PaymentSchema },
      { name: CaseFile.name, schema: CaseSchema },
    ]),
  ],
  controllers: [BillingController],
  providers: [BillingService],
  exports: [BillingService],
})
export class BillingModule {}
