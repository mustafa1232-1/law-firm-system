import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { CaseFile, CaseSchema } from '../cases/schemas/case.schema';
import { Court, CourtSchema } from '../courts/schemas/court.schema';
import {
  Notification,
  NotificationSchema,
} from '../notifications/schemas/notification.schema';
import { HearingsController } from './hearings.controller';
import { HearingsService } from './hearings.service';
import { Hearing, HearingSchema } from './schemas/hearing.schema';

@Module({
  imports: [
    AuditModule,
    MongooseModule.forFeature([
      { name: Hearing.name, schema: HearingSchema },
      { name: CaseFile.name, schema: CaseSchema },
      { name: Court.name, schema: CourtSchema },
      { name: Notification.name, schema: NotificationSchema },
    ]),
  ],
  controllers: [HearingsController],
  providers: [HearingsService],
  exports: [HearingsService],
})
export class HearingsModule {}
