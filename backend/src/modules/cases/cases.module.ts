import { forwardRef, Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AiModule } from '../ai/ai.module';
import { AuditModule } from '../audit/audit.module';
import { Invoice, InvoiceSchema } from '../billing/schemas/invoice.schema';
import { Payment, PaymentSchema } from '../billing/schemas/payment.schema';
import { Client, ClientSchema } from '../clients/schemas/client.schema';
import { Court, CourtSchema } from '../courts/schemas/court.schema';
import {
  Notification,
  NotificationSchema,
} from '../notifications/schemas/notification.schema';
import { CasesController } from './cases.controller';
import { CasesService } from './cases.service';
import { CaseEvent, CaseEventSchema } from './schemas/case-event.schema';
import { CaseFile, CaseSchema } from './schemas/case.schema';
import { CaseParty, CasePartySchema } from './schemas/case-party.schema';

@Module({
  imports: [
    forwardRef(() => AiModule),
    AuditModule,
    MongooseModule.forFeature([
      { name: CaseFile.name, schema: CaseSchema },
      { name: CaseParty.name, schema: CasePartySchema },
      { name: CaseEvent.name, schema: CaseEventSchema },
      { name: Client.name, schema: ClientSchema },
      { name: Court.name, schema: CourtSchema },
      { name: Invoice.name, schema: InvoiceSchema },
      { name: Payment.name, schema: PaymentSchema },
      { name: Notification.name, schema: NotificationSchema },
    ]),
  ],
  controllers: [CasesController],
  providers: [CasesService],
  exports: [CasesService, MongooseModule],
})
export class CasesModule {}
