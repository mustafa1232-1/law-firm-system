import { Injectable } from '@nestjs/common';
import { CaseAnalysisDto } from './dto/ai.dto';
import { AiOrchestratorService } from './services/ai-orchestrator.service';

@Injectable()
export class AiService {
  constructor(private readonly orchestrator: AiOrchestratorService) {}

  async runCaseAnalysis(input: {
    caseId?: string;
    description: string;
    caseTypeHint?: string;
  }) {
    const dto: CaseAnalysisDto = {
      caseId: input.caseId,
      description: input.description,
      caseTypeHint: input.caseTypeHint,
    };

    const output = await this.orchestrator.analyzeCase(dto);

    return {
      extractedFacts: output.extractedFacts,
      extractedParties: output.extractedParties,
      extractedClaims: output.extractedClaims,
      legalTopic: output.legalTopic,
      keywords: output.keywords,
      suggestedLegalArticles: output.legalHints,
      suggestedConstitutionArticles: output.constitutionalHints.map((h: any) => h.articleHint),
      similarDecisions: output.similarDecisions.map((d: any) => d.id),
      riskScore: output.riskScore,
      evidenceStrength: output.riskScore < 50 ? 'قوة الأدلة جيدة' : 'قوة الأدلة متوسطة',
      weaknesses: output.evidenceGaps,
      conflicts: ['قد توجد نقاط تعارض بين الوقائع المدخلة والمستندات المتاحة.'],
      possibleDefenses: ['دفع بعدم الاختصاص', 'دفع بعدم القبول', 'دفع بانتفاء المسؤولية'],
      possibleCounterDefenses: ['الرد على الاختصاص', 'ثبوت الصفة', 'سلامة إجراءات المطالبة'],
      timelineHints: ['تثبيت تاريخ النزاع', 'تحديد تاريخ أول إجراء', 'تحديد تاريخ آخر جلسة'],
      requiredDocuments: output.missingDocuments,
      questionsForLawyer: output.questionsForLawyer,
      strategy: output.legalHints,
      missingDocuments: output.missingDocuments,
      disclaimer: output.disclaimer,
    };
  }
}
