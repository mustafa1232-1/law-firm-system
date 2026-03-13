import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { IngestModule } from '../ingest/ingest.module';
import { StorageModule } from '../storage/storage.module';
import { DecisionChunk, DecisionChunkSchema } from './schemas/decision-chunk.schema';
import {
  JudicialDecision,
  JudicialDecisionSchema,
} from './schemas/judicial-decision.schema';
import { DecisionsController } from './decisions.controller';
import { DecisionsService } from './decisions.service';

@Module({
  imports: [
    AuditModule,
    IngestModule,
    StorageModule,
    MongooseModule.forFeature([
      { name: JudicialDecision.name, schema: JudicialDecisionSchema },
      { name: DecisionChunk.name, schema: DecisionChunkSchema },
    ]),
  ],
  controllers: [DecisionsController],
  providers: [DecisionsService],
  exports: [DecisionsService],
})
export class DecisionsModule {}
