import { ConfigService } from '@nestjs/config';
import { InjectModel } from '@nestjs/mongoose';
import { Injectable } from '@nestjs/common';
import { Model } from 'mongoose';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import { toObjectIdOrUndefined } from 'src/common/utils/object-id.util';
import { AuditService } from '../../audit/audit.service';
import { AiAnalysis, AiAnalysisDocument } from '../schemas/ai-analysis.schema';
import {
  ArgumentSuggestion,
  ArgumentSuggestionDocument,
} from '../schemas/argument-suggestion.schema';
import { MemoDraft, MemoDraftDocument } from '../schemas/memo-draft.schema';
import {
  ArgumentBuilderDto,
  CaseAnalysisDto,
  LegalResearchDto,
  MemoDraftDto,
} from '../dto/ai.dto';
import { ArgumentSuggestionService } from './argument-suggestion.service';
import { ConstitutionalMatcherService } from './constitutional-matcher.service';
import { DecisionSimilarityService } from './decision-similarity.service';
import { LegalArticleMatcherService } from './legal-article-matcher.service';
import { MemoDraftingService } from './memo-drafting.service';
import { OpenAiLegalService } from './openai-legal.service';
import { RetrievalService } from './retrieval.service';

@Injectable()
export class AiOrchestratorService {
  constructor(
    private readonly configService: ConfigService,
    private readonly retrievalService: RetrievalService,
    private readonly constitutionalMatcher: ConstitutionalMatcherService,
    private readonly legalArticleMatcher: LegalArticleMatcherService,
    private readonly decisionSimilarityService: DecisionSimilarityService,
    private readonly argumentSuggestionService: ArgumentSuggestionService,
    private readonly memoDraftingService: MemoDraftingService,
    private readonly openAiLegalService: OpenAiLegalService,
    private readonly auditService: AuditService,
    @InjectModel(AiAnalysis.name)
    private readonly analysisModel: Model<AiAnalysisDocument>,
    @InjectModel(ArgumentSuggestion.name)
    private readonly argumentModel: Model<ArgumentSuggestionDocument>,
    @InjectModel(MemoDraft.name)
    private readonly memoModel: Model<MemoDraftDocument>,
  ) {}

  async analyzeCase(dto: CaseAnalysisDto, actorId?: string) {
    const results = await this.retrievalService.hybridSearch({
      query: dto.description,
      searchConstitution: true,
      searchLaws: true,
      searchDecisions: true,
      limit: 12,
    });

    const constitutionalHints = this.constitutionalMatcher.match(dto.description);
    const legalHints = this.legalArticleMatcher.suggest(dto.description);
    const similarDecisions = this.decisionSimilarityService.rankSimilar(results);
    const llmEnrichment = await this.openAiLegalService.enrichCaseAnalysis({
      description: dto.description,
      authorities: results,
    });

    const issues = this.extractIssues(dto.description);
    const confidence = this.estimateConfidence(results, dto.description);
    const disclaimer = this.getDisclaimer();

    const output = {
      extractedType:
        llmEnrichment?.extractedType ??
        dto.caseTypeHint ??
        this.inferCaseType(dto.description),
      extractedParties:
        llmEnrichment?.extractedParties ?? this.extractParties(dto.description),
      extractedFacts: llmEnrichment?.extractedFacts ?? this.extractFacts(dto.description),
      extractedClaims: llmEnrichment?.extractedClaims ?? this.extractClaims(dto.description),
      legalTopic: llmEnrichment?.legalTopic ?? issues[0] ?? 'موضوع قانوني عام',
      keywords: llmEnrichment?.keywords ?? this.extractKeywords(dto.description),
      constitutionalHints,
      legalHints,
      similarDecisions,
      missingDocuments:
        llmEnrichment?.missingDocuments ?? this.detectMissingDocuments(dto.description),
      questionsForLawyer:
        llmEnrichment?.questionsForLawyer ?? this.proposeQuestions(dto.description),
      riskScore: this.estimateRisk(dto.description),
      evidenceGaps: llmEnrichment?.evidenceGaps ?? this.detectEvidenceGaps(dto.description),
      confidence,
      disclaimer,
      aiProvider: this.openAiLegalService.enabled ? 'openai+routed' : 'heuristic',
    };

    const analysis = await this.analysisModel.create({
      caseId: toObjectIdOrUndefined(dto.caseId),
      analysisType: 'case-analysis',
      inputText: dto.description,
      output,
      citations: results.map((r) => ({
        sourceType: r.sourceType,
        citation: r.citation,
        id: r.id,
      })),
      confidenceScore: confidence,
      disclaimer,
    });

    await this.auditService.record({
      action: 'ai.case-analysis',
      entity: 'ai_analyses',
      entityId: analysis.id,
      actorId,
      payload: { caseId: dto.caseId, confidence },
    });

    return {
      analysisId: analysis.id,
      ...output,
      citations: analysis.citations,
    };
  }

  async legalResearch(dto: LegalResearchDto, actorId?: string) {
    const retrieval = await this.retrievalService.hybridSearch({
      query: dto.query,
      searchConstitution: dto.searchConstitution !== false,
      searchLaws: dto.searchLaws !== false,
      searchDecisions: dto.searchDecisions !== false,
      limit: 14,
    });

    const grouped = {
      constitution: retrieval.filter((r) => r.sourceType === 'constitution'),
      laws: retrieval.filter((r) => r.sourceType === 'law'),
      decisions: retrieval.filter((r) => r.sourceType === 'decision'),
    };

    const confidence = this.estimateConfidence(retrieval, dto.query);
    const disclaimer = this.getDisclaimer();
    const hasSources =
      grouped.constitution.length + grouped.laws.length + grouped.decisions.length > 0;
    const llmEnrichment = await this.openAiLegalService.enrichLegalResearch({
      query: dto.query,
      authorities: retrieval,
    });

    const answer = {
      summary:
        llmEnrichment?.summary ??
        (hasSources
          ? 'تم العثور على مصادر قانونية مرتبطة بالسؤال ضمن الدستور والقوانين والقرارات المتاحة.'
          : 'لم يتم العثور على مصادر كافية ضمن البيانات المفهرسة لهذا السؤال.'),
      groundedAnswer:
        llmEnrichment?.groundedAnswer ??
        'هذه الإجابة أولية ومبنية على المصادر القانونية المتاحة داخل النظام مع الاستشهادات.',
      extractedIssues: llmEnrichment?.extractedIssues ?? this.extractIssues(dto.query),
      proposedQuestions:
        llmEnrichment?.proposedQuestions ?? this.proposeQuestions(dto.query),
      suggestedAuthorities: retrieval.slice(0, 10),
      confidence,
      limitations:
        llmEnrichment?.limitations ?? [
          'قد تكون بعض البيانات القضائية غير مكتملة أو غير محدثة.',
          'المخرجات لا تُعد استشارة قانونية نهائية.',
        ],
      disclaimer,
      aiProvider: this.openAiLegalService.enabled ? 'openai+routed' : 'heuristic',
    };

    const analysis = await this.analysisModel.create({
      caseId: toObjectIdOrUndefined(dto.caseId),
      analysisType: 'legal-research',
      inputText: dto.query,
      output: answer,
      citations: retrieval.map((r) => ({
        sourceType: r.sourceType,
        citation: r.citation,
        id: r.id,
      })),
      confidenceScore: confidence,
      disclaimer,
    });

    await this.auditService.record({
      action: 'ai.legal-research',
      entity: 'ai_analyses',
      entityId: analysis.id,
      actorId,
    });

    return {
      analysisId: analysis.id,
      ...answer,
      groupedResults: grouped,
    };
  }

  async argumentBuilder(dto: ArgumentBuilderDto, actorId?: string) {
    const authorities = await this.retrievalService.hybridSearch({
      query: dto.narrative,
      limit: 12,
      searchConstitution: true,
      searchLaws: true,
      searchDecisions: true,
    });

    const built = this.argumentSuggestionService.build({
      narrative: dto.narrative,
      authorities,
    });

    const created = await this.argumentModel.create({
      caseId: toObjectIdOrUndefined(dto.caseId),
      title: 'هيكل دفوع أولي بالذكاء الاصطناعي',
      argumentType: 'primary',
      content: JSON.stringify(built),
      authorityIds: authorities.map((a) => a.id),
      confidenceScore: this.estimateConfidence(authorities, dto.narrative),
    });

    await this.auditService.record({
      action: 'ai.argument-builder',
      entity: 'argument_suggestions',
      entityId: created.id,
      actorId,
    });

    return {
      suggestionId: created.id,
      ...built,
      disclaimer: this.getDisclaimer(),
    };
  }

  async memoDraft(dto: MemoDraftDto, actorId?: string) {
    const authorities = await this.retrievalService.hybridSearch({
      query: `${dto.topic}\n${dto.facts}`,
      limit: 10,
    });

    const disclaimer = this.getDisclaimer();
    const body = this.memoDraftingService.compose({
      topic: dto.topic,
      facts: dto.facts,
      authorities,
      disclaimer,
    });

    const memo = await this.memoModel.create({
      caseId: toObjectIdOrUndefined(dto.caseId),
      title: `مسودة مذكرة: ${dto.topic}`,
      body,
      citations: authorities.map((a) => ({ citation: a.citation, id: a.id })),
      status: 'draft',
    });

    await this.auditService.record({
      action: 'ai.memo-draft',
      entity: 'memo_drafts',
      entityId: memo.id,
      actorId,
    });

    return {
      memoId: memo.id,
      title: memo.title,
      body: memo.body,
      citations: memo.citations,
      disclaimer,
    };
  }

  private inferCaseType(text: string) {
    const normalized = normalizeArabic(text);
    if (this.hasAny(normalized, ['جنائي', 'جريمة', 'متهم', 'عقوبة'])) return 'جنائية';
    if (this.hasAny(normalized, ['تجاري', 'شركة', 'افلاس', 'كمبيالة'])) return 'تجارية';
    if (this.hasAny(normalized, ['احوال', 'طلاق', 'نفقة', 'زواج'])) return 'أحوال شخصية';
    if (this.hasAny(normalized, ['دستوري', 'دستور'])) return 'دستورية';
    if (this.hasAny(normalized, ['تنفيذ'])) return 'تنفيذ';
    if (this.hasAny(normalized, ['عمل', 'عمال'])) return 'عمالية';
    return 'مدنية';
  }

  private extractParties(text: string) {
    const lines = text.split(/\n|\./).map((line) => line.trim());
    return lines
      .filter((line) =>
        this.hasAny(normalizeArabic(line), [
          'مدعي',
          'مدعى',
          'مدعى عليه',
          'مشتكي',
          'متهم',
          'وكيل',
          'طرف',
        ]),
      )
      .slice(0, 5);
  }

  private extractFacts(text: string) {
    return text
      .split(/\n|\./)
      .map((x) => x.trim())
      .filter((x) => x.length > 25)
      .slice(0, 5);
  }

  private extractClaims(text: string) {
    const normalized = normalizeArabic(text);
    const claims: string[] = [];
    if (this.hasAny(normalized, ['تعويض', 'ضرر'])) claims.push('طلب تعويض');
    if (this.hasAny(normalized, ['فسخ', 'ابطال', 'الغاء'])) claims.push('طلب فسخ/إبطال');
    if (this.hasAny(normalized, ['الزام', 'تنفيذ'])) claims.push('طلب إلزام');
    if (this.hasAny(normalized, ['وقف', 'مستعجل'])) claims.push('طلب إجراء وقتي/مستعجل');
    return claims.length ? claims : ['تحديد المطالب القانونية بدقة من قبل المحامي'];
  }

  private extractKeywords(text: string) {
    return Array.from(
      new Set(
        text
          .split(/\s+/)
          .map((token) => token.trim())
          .filter((token) => token.length > 3)
          .slice(0, 20),
      ),
    );
  }

  private detectMissingDocuments(text: string) {
    const normalized = normalizeArabic(text);
    const missing: string[] = [];
    if (!normalized.includes('عقد')) missing.push('نسخة من العقد الأساسي');
    if (!normalized.includes('انذار')) missing.push('إنذار رسمي أو تبليغ');
    if (!normalized.includes('هويه')) missing.push('مستندات هوية أو صفة الخصوم');
    return missing;
  }

  private proposeQuestions(text: string) {
    const questions = [
      'ما هو التسلسل الزمني الدقيق للوقائع محل النزاع؟',
      'ما هي المستندات المؤيدة لكل ادعاء أو دفع؟',
      'هل توجد سوابق قضائية مشابهة يمكن الاستناد إليها؟',
    ];

    if (normalizeArabic(text).includes('تعويض')) {
      questions.push('ما هو أساس تقدير مبلغ التعويض وهل يوجد تقرير خبرة داعم؟');
    }

    return questions;
  }

  private detectEvidenceGaps(text: string) {
    const normalized = normalizeArabic(text);
    const gaps: string[] = [];
    if (normalized.includes('شاهد')) gaps.push('يلزم دعم شهادة الشهود بمستندات مساندة.');
    if (!normalized.includes('عقد')) gaps.push('لا يظهر مستند تعاقدي واضح ضمن الوقائع.');
    if (!normalized.includes('تقرير')) gaps.push('لا يوجد تقرير فني/خبير داعم للادعاء.');
    return gaps;
  }

  private estimateRisk(text: string) {
    const normalized = normalizeArabic(text);
    let risk = 35;
    if (this.hasAny(normalized, ['تناقض', 'غموض'])) risk += 12;
    if (this.hasAny(normalized, ['بدون عقد', 'لا يوجد عقد'])) risk += 18;
    if (this.hasAny(normalized, ['نزاع ملكيه', 'اختصاص'])) risk += 15;
    return Math.min(95, risk);
  }

  private extractIssues(text: string) {
    const normalized = normalizeArabic(text);
    const issues: string[] = [];
    if (this.hasAny(normalized, ['اختصاص'])) issues.push('مسألة الاختصاص القضائي');
    if (this.hasAny(normalized, ['اثبات', 'بينه'])) issues.push('مسألة عبء الإثبات وقوته');
    if (this.hasAny(normalized, ['تقادم', 'مده'])) issues.push('مسألة المدد والتقادم');
    if (this.hasAny(normalized, ['اجراء', 'تبليغ'])) issues.push('مسألة صحة الإجراءات');
    if (issues.length === 0) issues.push('مسألة قانونية عامة تحتاج تدقيق');
    return issues;
  }

  private estimateConfidence(results: Array<{ score: number }>, text: string) {
    if (!results.length) {
      return 0.35;
    }

    const avgScore = results.reduce((acc, item) => acc + item.score, 0) / results.length;
    const lengthFactor = Math.min(1, text.length / 1200);
    return Number(Math.max(0.3, Math.min(0.92, avgScore * 0.85 + lengthFactor * 0.25)).toFixed(2));
  }

  private getDisclaimer() {
    return this.configService.get<string>('ai.disclaimer')!;
  }

  private hasAny(text: string, tokens: string[]) {
    return tokens.some((token) => text.includes(normalizeArabic(token)));
  }
}
