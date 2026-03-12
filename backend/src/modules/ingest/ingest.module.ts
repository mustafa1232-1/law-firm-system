import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { QueueModule } from '../queue/queue.module';
import { DecisionChunkSchema } from '../decisions/schemas/decision-chunk.schema';
import {
  JudicialDecision,
  JudicialDecisionSchema,
} from '../decisions/schemas/judicial-decision.schema';
import { IngestController } from './ingest.controller';
import { IngestService } from './ingest.service';
import { IngestJob, IngestJobSchema } from './schemas/ingest-job.schema';
import { IngestSource, IngestSourceSchema } from './schemas/ingest-source.schema';

@Module({
  imports: [
    QueueModule,
    AuditModule,
    MongooseModule.forFeature([
      { name: IngestJob.name, schema: IngestJobSchema },
      { name: IngestSource.name, schema: IngestSourceSchema },
      { name: JudicialDecision.name, schema: JudicialDecisionSchema },
    ]),
  ],
  controllers: [IngestController],
  providers: [IngestService],
  exports: [IngestService],
})
export class IngestModule {}
