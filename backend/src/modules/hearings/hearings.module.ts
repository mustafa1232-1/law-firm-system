import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { HearingsController } from './hearings.controller';
import { HearingsService } from './hearings.service';
import { Hearing, HearingSchema } from './schemas/hearing.schema';

@Module({
  imports: [
    AuditModule,
    MongooseModule.forFeature([{ name: Hearing.name, schema: HearingSchema }]),
  ],
  controllers: [HearingsController],
  providers: [HearingsService],
  exports: [HearingsService],
})
export class HearingsModule {}
