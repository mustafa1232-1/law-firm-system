import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import OpenAI from 'openai';
import { RetrievalResult } from './retrieval.service';

interface CaseAnalysisEnrichment {
  extractedType?: string;
  legalTopic?: string;
  extractedFacts?: string[];
  extractedClaims?: string[];
  extractedParties?: string[];
  keywords?: string[];
  missingDocuments?: string[];
  evidenceGaps?: string[];
  questionsForLawyer?: string[];
}

interface LegalResearchEnrichment {
  summary?: string;
  groundedAnswer?: string;
  extractedIssues?: string[];
  proposedQuestions?: string[];
  limitations?: string[];
}

interface LawArticleExplanationEnrichment {
  plainMeaning?: string;
  legalElements?: string[];
  applicationScenarios?: string[];
  proceduralNotes?: string[];
  potentialRisks?: string[];
  defenseAngles?: string[];
  practicalChecklist?: string[];
  detailedExplanation?: string;
  proposedQuestions?: string[];
}

@Injectable()
export class OpenAiLegalService {
  private readonly logger = new Logger(OpenAiLegalService.name);
  private readonly client: OpenAI | null;
  private readonly model: string;

  constructor(private readonly configService: ConfigService) {
    const apiKey = this.configService.get<string>('ai.openaiApiKey')?.trim();
    this.model = this.configService.get<string>('ai.openaiModel') ?? 'gpt-4.1-mini';
    this.client = apiKey ? new OpenAI({ apiKey }) : null;
  }

  get enabled() {
    return Boolean(this.client);
  }

  async enrichCaseAnalysis(input: {
    description: string;
    authorities: RetrievalResult[];
  }): Promise<CaseAnalysisEnrichment | null> {
    if (!this.client) {
      return null;
    }

    const sources = this.renderAuthorities(input.authorities, 12);

    const prompt = [
      'أنت مساعد قانوني عراقي. حلل الوقائع التالية تحليلاً أولياً فقط.',
      'مهم: لا تقدّم استشارة نهائية. لا تختلق مواد قانونية أو وقائع غير موجودة.',
      'اعتمد على الوقائع المدخلة والمراجع التالية فقط إن لزم.',
      '',
      'الوقائع:',
      input.description,
      '',
      'المراجع:',
      sources || 'لا توجد مراجع متاحة.',
      '',
      'أعد JSON فقط بالمفاتيح التالية:',
      '{"extractedType":"","legalTopic":"","extractedFacts":[],"extractedClaims":[],"extractedParties":[],"keywords":[],"missingDocuments":[],"evidenceGaps":[],"questionsForLawyer":[]}',
    ].join('\n');

    const json = await this.completeJson(prompt);
    if (!json || typeof json !== 'object') {
      return null;
    }

    return {
      extractedType: this.asString(json.extractedType),
      legalTopic: this.asString(json.legalTopic),
      extractedFacts: this.asStringArray(json.extractedFacts),
      extractedClaims: this.asStringArray(json.extractedClaims),
      extractedParties: this.asStringArray(json.extractedParties),
      keywords: this.asStringArray(json.keywords),
      missingDocuments: this.asStringArray(json.missingDocuments),
      evidenceGaps: this.asStringArray(json.evidenceGaps),
      questionsForLawyer: this.asStringArray(json.questionsForLawyer),
    };
  }

  async enrichLegalResearch(input: {
    query: string;
    authorities: RetrievalResult[];
  }): Promise<LegalResearchEnrichment | null> {
    if (!this.client) {
      return null;
    }

    const sources = this.renderAuthorities(input.authorities, 16);

    const prompt = [
      'أنت مساعد بحث قانوني عراقي داخل نظام RAG.',
      'ممنوع تقديم أي معلومة غير موجودة في المصادر التالية.',
      'إن كانت المصادر غير كافية، اذكر ذلك بوضوح.',
      'أعد الاستشهادات بصيغة [1] [2] داخل النص عند استخدامها.',
      '',
      'السؤال:',
      input.query,
      '',
      'المصادر المتاحة:',
      sources || 'لا توجد مصادر متاحة.',
      '',
      'أعد JSON فقط بالمفاتيح:',
      '{"summary":"","groundedAnswer":"","extractedIssues":[],"proposedQuestions":[],"limitations":[]}',
    ].join('\n');

    const json = await this.completeJson(prompt);
    if (!json || typeof json !== 'object') {
      return null;
    }

    return {
      summary: this.asString(json.summary),
      groundedAnswer: this.asString(json.groundedAnswer),
      extractedIssues: this.asStringArray(json.extractedIssues),
      proposedQuestions: this.asStringArray(json.proposedQuestions),
      limitations: this.asStringArray(json.limitations),
    };
  }

  async explainLawArticle(input: {
    articleNumber: string;
    articleText: string;
    lawTitle?: string;
    lawNumber?: string;
    focusQuestion?: string;
    authorities: RetrievalResult[];
  }): Promise<LawArticleExplanationEnrichment | null> {
    if (!this.client) {
      return null;
    }

    const sources = this.renderAuthorities(input.authorities, 14);
    const prompt = [
      'أنت خبير شرح نصوص قانونية عراقية للمحامين.',
      'المطلوب شرح المادة بشكل تفصيلي ومنظم، مع التركيز على المعنى العملي وحدود التطبيق.',
      'ممنوع اختلاق نصوص أو أحكام غير موجودة في النص أو المصادر.',
      'إذا كانت المعلومات غير كافية اذكر ذلك بوضوح.',
      '',
      `القانون: ${input.lawTitle ?? 'غير محدد'} (رقم ${input.lawNumber ?? '-'})`,
      `رقم المادة: ${input.articleNumber}`,
      '',
      'نص المادة:',
      input.articleText,
      '',
      `سؤال التركيز (إن وجد): ${input.focusQuestion?.trim() || 'لا يوجد'}`,
      '',
      'المراجع ذات الصلة:',
      sources || 'لا توجد مراجع إضافية.',
      '',
      'أعد JSON فقط بالمفاتيح التالية:',
      '{"plainMeaning":"","legalElements":[],"applicationScenarios":[],"proceduralNotes":[],"potentialRisks":[],"defenseAngles":[],"practicalChecklist":[],"detailedExplanation":"","proposedQuestions":[]}',
    ].join('\n');

    const json = await this.completeJson(prompt);
    if (!json || typeof json !== 'object') {
      return null;
    }

    return {
      plainMeaning: this.asString(json.plainMeaning),
      legalElements: this.asStringArray(json.legalElements),
      applicationScenarios: this.asStringArray(json.applicationScenarios),
      proceduralNotes: this.asStringArray(json.proceduralNotes),
      potentialRisks: this.asStringArray(json.potentialRisks),
      defenseAngles: this.asStringArray(json.defenseAngles),
      practicalChecklist: this.asStringArray(json.practicalChecklist),
      detailedExplanation: this.asString(json.detailedExplanation),
      proposedQuestions: this.asStringArray(json.proposedQuestions),
    };
  }

  private async completeJson(prompt: string): Promise<Record<string, any> | null> {
    if (!this.client) {
      return null;
    }

    try {
      const completion = await this.client.chat.completions.create({
        model: this.model,
        temperature: 0.2,
        messages: [
          {
            role: 'system',
            content:
              'أنت مساعد قانوني دقيق. يجب أن يكون الرد JSON صالح فقط بدون أي نص إضافي.',
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        response_format: { type: 'json_object' },
      });

      const content = completion.choices?.[0]?.message?.content;
      if (!content) {
        return null;
      }

      return JSON.parse(content);
    } catch (error: any) {
      this.logger.warn(`OpenAI enrichment failed: ${error?.message ?? 'unknown-error'}`);
      return null;
    }
  }

  private renderAuthorities(authorities: RetrievalResult[], limit: number) {
    return authorities
      .slice(0, limit)
      .map((item, index) => {
        const snippet = item.snippet?.replace(/\s+/g, ' ').slice(0, 260) ?? '';
        return `[${index + 1}] ${item.citation} | ${item.title}\n${snippet}`;
      })
      .join('\n\n');
  }

  private asString(value: unknown) {
    if (typeof value !== 'string') {
      return undefined;
    }
    const text = value.trim();
    return text.length ? text : undefined;
  }

  private asStringArray(value: unknown): string[] | undefined {
    if (!Array.isArray(value)) {
      return undefined;
    }

    const normalized = value
      .map((item) => (typeof item === 'string' ? item.trim() : ''))
      .filter((item) => item.length > 0)
      .slice(0, 20);

    return normalized.length ? normalized : undefined;
  }
}
