import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import { QueueService } from '../queue/queue.service';
import { AuditService } from '../audit/audit.service';
import { StartIngestDto } from './dto/start-ingest.dto';
import { CreateIngestSourceDto } from './dto/create-ingest-source.dto';
import { IngestJob, IngestJobDocument } from './schemas/ingest-job.schema';
import { IngestSource, IngestSourceDocument } from './schemas/ingest-source.schema';
import {
  JudicialDecision,
  JudicialDecisionDocument,
} from '../decisions/schemas/judicial-decision.schema';

@Injectable()
export class IngestService {
  private readonly pipelineName = 'Decision Ingestion Pipeline';

  constructor(
    @InjectModel(IngestJob.name)
    private readonly ingestJobModel: Model<IngestJobDocument>,
    @InjectModel(IngestSource.name)
    private readonly sourceModel: Model<IngestSourceDocument>,
    @InjectModel(JudicialDecision.name)
    private readonly decisionModel: Model<JudicialDecisionDocument>,
    private readonly queueService: QueueService,
    private readonly auditService: AuditService,
  ) {}

  async createSource(dto: CreateIngestSourceDto, actorId?: string) {
    const source = await this.sourceModel.create(dto);
    await this.auditService.record({
      action: 'ingest.source.create',
      entity: 'ingest_sources',
      entityId: source.id,
      actorId,
    });
    return source;
  }

  async listSources() {
    return this.sourceModel.find().sort({ createdAt: -1 }).lean();
  }

  async startDecisionIngestion(dto: StartIngestDto, actorId?: string) {
    const ingestJobDoc = await this.ingestJobModel.create({
      pipeline: this.pipelineName,
      status: 'queued',
      input: dto as any,
      stepsCompleted: [],
      actorId,
    });
    const ingestJob = ingestJobDoc as any;

    const queued = await this.queueService.enqueue(
      'decision_ingestion',
      'ingest-decision',
      { ingestJobId: ingestJob.id, dto, actorId },
      { removeOnComplete: true, removeOnFail: 50 },
    );

    if (!queued.queued) {
      await this.runPipeline(ingestJob.id, dto, actorId);
      return this.ingestJobModel.findById(ingestJob.id).lean();
    }

    await this.ingestJobModel.updateOne(
      { _id: ingestJob._id },
      { $set: { queuedJobId: queued.jobId } },
    );

    return {
      ingestJobId: ingestJob.id,
      status: 'queued',
      queuedJobId: queued.jobId,
      message:
        'Decision ingestion job queued. If worker is not configured, trigger /ingest/jobs/:id/run.',
    };
  }

  async runQueuedJob(jobId: string) {
    const job = await this.ingestJobModel.findById(jobId).lean();
    if (!job) {
      throw new NotFoundException('Ingest job not found');
    }
    return this.runPipeline(jobId, job.input as unknown as StartIngestDto, job.actorId);
  }

  async getJobs(status?: string) {
    const filter = status ? { status } : {};
    return this.ingestJobModel.find(filter).sort({ createdAt: -1 }).limit(100).lean();
  }

  async getJobById(id: string) {
    const job = await this.ingestJobModel.findById(id).lean();
    if (!job) {
      throw new NotFoundException('Ingest job not found');
    }
    return job;
  }

  private async runPipeline(jobId: string, dto: StartIngestDto, actorId?: string) {
    const steps: string[] = [];
    const update = async (status: string, extra?: Record<string, unknown>) => {
      await this.ingestJobModel.updateOne(
        { _id: jobId },
        {
          $set: {
            status,
            stepsCompleted: steps,
            ...(extra ?? {}),
          },
        },
      );
    };

    try {
      await update('processing');

      // 1. fetch source metadata
      const sourceMetadata = { source: dto.source, sourceType: dto.sourceType };
      steps.push('fetch source metadata');

      // 2. store raw file/page metadata
      const rawMetadata = { filePath: dto.filePath ?? null };
      steps.push('store raw file/page metadata');

      // 3. OCR only when necessary (placeholder)
      const ocrApplied = Boolean(dto.filePath && !dto.rawText);
      steps.push('ocr when necessary');

      // 4. text extraction from PDF/HTML
      const extractedText = dto.rawText ?? `Imported from source: ${dto.source}`;
      steps.push('text extraction from PDF/HTML');

      // 5. normalization for Arabic text
      const normalizedText = normalizeArabic(extractedText);
      steps.push('normalization for Arabic text');

      // 6. chunking
      const chunkCount = Math.max(1, Math.ceil(extractedText.length / 1200));
      steps.push('chunking');

      // 7. legal entity extraction
      const legalEntities = (
        extractedText.match(new RegExp('\\u0627\\u0644\\u0645\\u0627\\u062f\\u0629\\s+\\d+', 'g')) ??
        []
      ).slice(0, 20);
      steps.push('legal entity extraction');

      // 8. article extraction
      const legalArticleReferences = legalEntities.map((x) =>
        x.replace('\u0627\u0644\u0645\u0627\u062f\u0629', '').trim(),
      );
      steps.push('article extraction');

      // 9. constitution reference extraction
      const constitutionalReferences = (
        extractedText.match(
          new RegExp(
            '\\u0627\\u0644\\u062f\\u0633\\u062a\\u0648\\u0631\\s+\\d+',
            'g',
          ),
        ) ?? []
      ).slice(0, 20);
      steps.push('constitution reference extraction');

      // 10. court/date/number parsing
      const parsedCourt = extractedText.includes('cassation')
        ? 'Cassation Court'
        : extractedText.includes('appeal')
          ? 'Appellate Court'
          : 'Iraqi Court';
      const parsedNumber = `AUTO-${Date.now().toString().slice(-8)}`;
      steps.push('court/date/number parsing');

      // 11. classification by legal domain
      const legalDomain = extractedText.includes('contract')
        ? 'commercial'
        : extractedText.includes('property')
          ? 'civil'
          : 'other';
      steps.push('classification by legal domain');

      // 12. AI summarization (heuristic foundation)
      const summary = extractedText.slice(0, 600);
      steps.push('ai summarization');

      // 13. human review queue
      const reviewStatus = 'pending';
      steps.push('human review queue');

      // 14. publish to searchable index
      const decision = await this.decisionModel.create({
        source: dto.source,
        sourceType: dto.sourceType,
        courtName: parsedCourt,
        decisionNumber: parsedNumber,
        decisionDate: new Date(),
        legalDomain,
        summary,
        fullText: extractedText,
        extractedCitations: legalEntities,
        constitutionalReferences,
        legalArticleReferences,
        legalKeywords: [legalDomain, dto.sourceType],
        reviewStatus,
        ingestionStatus: 'published',
        normalizedText,
        confidenceScore: 0.62,
        precedentWeight: 0.5,
      });
      steps.push('publish to searchable index');

      await update('needs_review', {
        output: {
          sourceMetadata,
          rawMetadata,
          ocrApplied,
          chunkCount,
          legalEntities,
          legalArticleReferences,
          constitutionalReferences,
          parsedCourt,
          parsedNumber,
          legalDomain,
          summary,
          decisionId: decision.id,
        },
      });

      await this.auditService.record({
        action: 'ingest.decision.completed',
        entity: 'ingest_jobs',
        entityId: jobId,
        actorId,
        payload: { decisionId: decision.id },
      });

      return this.ingestJobModel.findById(jobId).lean();
    } catch (error: any) {
      await update('failed', { errorMessage: error.message ?? 'Ingestion failed' });
      throw error;
    }
  }
}
