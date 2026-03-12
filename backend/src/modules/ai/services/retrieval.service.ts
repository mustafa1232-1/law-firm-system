import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import {
  ConstitutionArticle,
  ConstitutionArticleDocument,
} from '../../constitution/schemas/constitution-article.schema';
import { LawArticle, LawArticleDocument } from '../../laws/schemas/law-article.schema';
import {
  JudicialDecision,
  JudicialDecisionDocument,
} from '../../decisions/schemas/judicial-decision.schema';
import { EmbeddingsService } from './embeddings.service';

export interface RetrievalResult {
  id: string;
  sourceType: 'constitution' | 'law' | 'decision';
  title: string;
  snippet: string;
  score: number;
  citation: string;
  metadata: Record<string, unknown>;
}

@Injectable()
export class RetrievalService {
  constructor(
    private readonly embeddingsService: EmbeddingsService,
    @InjectModel(ConstitutionArticle.name)
    private readonly constitutionModel: Model<ConstitutionArticleDocument>,
    @InjectModel(LawArticle.name)
    private readonly lawArticleModel: Model<LawArticleDocument>,
    @InjectModel(JudicialDecision.name)
    private readonly decisionModel: Model<JudicialDecisionDocument>,
  ) {}

  async hybridSearch(input: {
    query: string;
    searchConstitution?: boolean;
    searchLaws?: boolean;
    searchDecisions?: boolean;
    limit?: number;
    legalDomain?: string;
    court?: string;
  }): Promise<RetrievalResult[]> {
    const limit = input.limit ?? 10;
    const normalized = normalizeArabic(input.query);
    const embedding = await this.embeddingsService.embed(input.query);
    const embeddingHint = embedding.reduce((acc, v) => acc + v, 0) / embedding.length;

    const tasks: Promise<RetrievalResult[]>[] = [];

    if (input.searchConstitution !== false) {
      tasks.push(this.searchConstitution(input.query, normalized, limit, embeddingHint));
    }

    if (input.searchLaws !== false) {
      tasks.push(this.searchLaws(input.query, normalized, limit, embeddingHint));
    }

    if (input.searchDecisions !== false) {
      tasks.push(
        this.searchDecisions(
          input.query,
          normalized,
          limit,
          embeddingHint,
          input.legalDomain,
          input.court,
        ),
      );
    }

    const groups = await Promise.all(tasks);

    return groups
      .flat()
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);
  }

  private async searchConstitution(
    query: string,
    normalized: string,
    limit: number,
    semanticHint: number,
  ): Promise<RetrievalResult[]> {
    const items = await this.constitutionModel
      .find({
        $or: [
          { $text: { $search: query } },
          { normalizedText: { $regex: normalized, $options: 'i' } },
        ],
      })
      .limit(limit)
      .lean();

    return items.map((item, idx) => ({
      id: item._id.toString(),
      sourceType: 'constitution',
      title: `الدستور العراقي - المادة ${item.articleNumber}`,
      snippet: item.text.slice(0, 220),
      score: 0.75 - idx * 0.02 + semanticHint / 10,
      citation: `الدستور العراقي المادة ${item.articleNumber}`,
      metadata: { articleNumber: item.articleNumber, chapter: item.chapter },
    }));
  }

  private async searchLaws(
    query: string,
    normalized: string,
    limit: number,
    semanticHint: number,
  ): Promise<RetrievalResult[]> {
    const items = await this.lawArticleModel
      .find({
        $or: [
          { $text: { $search: query } },
          { normalizedText: { $regex: normalized, $options: 'i' } },
        ],
      })
      .limit(limit)
      .populate('lawId', 'title lawNumber year legalDomain')
      .lean();

    return items.map((item: any, idx) => ({
      id: item._id.toString(),
      sourceType: 'law',
      title: `${item.lawId?.title ?? 'قانون'} - المادة ${item.articleNumber}`,
      snippet: item.text.slice(0, 220),
      score: 0.72 - idx * 0.02 + semanticHint / 12,
      citation: `القانون ${item.lawId?.lawNumber ?? '-'} المادة ${item.articleNumber}`,
      metadata: {
        articleNumber: item.articleNumber,
        lawNumber: item.lawId?.lawNumber,
        year: item.lawId?.year,
      },
    }));
  }

  private async searchDecisions(
    query: string,
    normalized: string,
    limit: number,
    semanticHint: number,
    legalDomain?: string,
    court?: string,
  ): Promise<RetrievalResult[]> {
    const filter: any = {
      $or: [
        { $text: { $search: query } },
        { normalizedText: { $regex: normalized, $options: 'i' } },
      ],
    };
    if (legalDomain) {
      filter.legalDomain = legalDomain;
    }
    if (court) {
      filter.courtName = { $regex: court, $options: 'i' };
    }

    const items = await this.decisionModel
      .find(filter)
      .sort({ decisionDate: -1 })
      .limit(limit)
      .lean();

    return items.map((item, idx) => ({
      id: item._id.toString(),
      sourceType: 'decision',
      title: `${item.courtName} - القرار ${item.decisionNumber}`,
      snippet: (item.summary ?? item.fullText ?? '').slice(0, 240),
      score: 0.7 - idx * 0.018 + semanticHint / 13,
      citation: `قرار ${item.decisionNumber} (${item.courtName})`,
      metadata: {
        decisionNumber: item.decisionNumber,
        courtName: item.courtName,
        decisionDate: item.decisionDate,
      },
    }));
  }
}
