import { forwardRef, Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AiModule } from '../ai/ai.module';
import { AuditModule } from '../audit/audit.module';
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
    ]),
  ],
  controllers: [CasesController],
  providers: [CasesService],
  exports: [CasesService, MongooseModule],
})
export class CasesModule {}
