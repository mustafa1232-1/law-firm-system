import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import {
  buildSearchTerms,
  buildTokenRegexConditions,
  SearchTerms,
} from 'src/common/utils/search-query.util';
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
    const terms = buildSearchTerms(input.query);

    if (!terms.rawQuery) {
      return [];
    }

    const embedding = await this.embeddingsService.embed(terms.rawQuery);
    const embeddingHint = embedding.reduce((acc, value) => acc + value, 0) / embedding.length;

    const tasks: Promise<RetrievalResult[]>[] = [];

    if (input.searchConstitution !== false) {
      tasks.push(this.searchConstitution(terms, limit, embeddingHint));
    }

    if (input.searchLaws !== false) {
      tasks.push(this.searchLaws(terms, limit, embeddingHint));
    }

    if (input.searchDecisions !== false) {
      tasks.push(
        this.searchDecisions(
          terms,
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

  private safeSnippet(value: unknown, length: number) {
    if (typeof value !== 'string') {
      return '';
    }
    return value.slice(0, length);
  }

  private async searchConstitution(
    terms: SearchTerms,
    limit: number,
    semanticHint: number,
  ): Promise<RetrievalResult[]> {
    const items = await this.constitutionModel
      .find({
        $or: [
          { articleNumber: { $regex: terms.escapedRawQuery, $options: 'i' } },
          { title: { $regex: terms.escapedRawQuery, $options: 'i' } },
          { text: { $regex: terms.escapedRawQuery, $options: 'i' } },
          { normalizedText: { $regex: terms.escapedNormalizedQuery, $options: 'i' } },
          ...buildTokenRegexConditions('title', terms.rawTokens),
          ...buildTokenRegexConditions('text', terms.rawTokens),
          ...buildTokenRegexConditions('normalizedText', terms.normalizedTokens),
        ],
      })
      .limit(limit)
      .lean();

    return items.map((item, index) => ({
      id: item._id.toString(),
      sourceType: 'constitution',
      title: `الدستور العراقي - المادة ${item.articleNumber}`,
      snippet: this.safeSnippet(item.text, 220),
      score: 0.75 - index * 0.02 + semanticHint / 10,
      citation: `الدستور العراقي المادة ${item.articleNumber}`,
      metadata: { articleNumber: item.articleNumber, chapter: item.chapter },
    }));
  }

  private async searchLaws(
    terms: SearchTerms,
    limit: number,
    semanticHint: number,
  ): Promise<RetrievalResult[]> {
    const items = await this.lawArticleModel
      .find({
        $or: [
          { normalizedText: { $regex: terms.escapedNormalizedQuery, $options: 'i' } },
          { text: { $regex: terms.escapedRawQuery, $options: 'i' } },
          ...buildTokenRegexConditions('normalizedText', terms.normalizedTokens),
          ...buildTokenRegexConditions('text', terms.rawTokens),
        ],
      })
      .limit(limit)
      .populate('lawId', 'title lawNumber year legalDomain')
      .lean();

    return items.map((item: any, index) => ({
      id: item._id.toString(),
      sourceType: 'law',
      title: `${item.lawId?.title ?? 'قانون'} - المادة ${item.articleNumber}`,
      snippet: this.safeSnippet(item.text, 220),
      score: 0.72 - index * 0.02 + semanticHint / 12,
      citation: `القانون ${item.lawId?.lawNumber ?? '-'} المادة ${item.articleNumber}`,
      metadata: {
        articleNumber: item.articleNumber,
        lawNumber: item.lawId?.lawNumber,
        year: item.lawId?.year,
      },
    }));
  }

  private async searchDecisions(
    terms: SearchTerms,
    limit: number,
    semanticHint: number,
    legalDomain?: string,
    court?: string,
  ): Promise<RetrievalResult[]> {
    const filter: any = {
      $or: [
        { normalizedText: { $regex: terms.escapedNormalizedQuery, $options: 'i' } },
        { summary: { $regex: terms.escapedRawQuery, $options: 'i' } },
        { fullText: { $regex: terms.escapedRawQuery, $options: 'i' } },
        ...buildTokenRegexConditions('normalizedText', terms.normalizedTokens),
        ...buildTokenRegexConditions('summary', terms.rawTokens),
        ...buildTokenRegexConditions('fullText', terms.rawTokens),
      ],
    };

    if (legalDomain) {
      filter.legalDomain = legalDomain;
    }

    if (court) {
      const courtTerms = buildSearchTerms(court);
      filter.courtName = { $regex: courtTerms.escapedRawQuery, $options: 'i' };
    }

    const items = await this.decisionModel
      .find(filter)
      .sort({ decisionDate: -1 })
      .limit(limit)
      .lean();

    return items.map((item, index) => ({
      id: item._id.toString(),
      sourceType: 'decision',
      title: `${item.courtName} - القرار ${item.decisionNumber}`,
      snippet: this.safeSnippet(item.summary ?? item.fullText, 240),
      score: 0.7 - index * 0.018 + semanticHint / 13,
      citation: `قرار ${item.decisionNumber} (${item.courtName})`,
      metadata: {
        decisionNumber: item.decisionNumber,
        courtName: item.courtName,
        decisionDate: item.decisionDate,
      },
    }));
  }
}
