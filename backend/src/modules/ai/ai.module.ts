import { forwardRef, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { CasesModule } from '../cases/cases.module';
import {
  ConstitutionArticle,
  ConstitutionArticleSchema,
} from '../constitution/schemas/constitution-article.schema';
import {
  JudicialDecision,
  JudicialDecisionSchema,
} from '../decisions/schemas/judicial-decision.schema';
import {
  DocumentFile,
  DocumentFileSchema,
} from '../documents/schemas/document.schema';
import { LawArticle, LawArticleSchema } from '../laws/schemas/law-article.schema';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { AiAnalysis, AiAnalysisSchema } from './schemas/ai-analysis.schema';
import {
  ArgumentSuggestion,
  ArgumentSuggestionSchema,
} from './schemas/argument-suggestion.schema';
import { AiSession, AiSessionSchema } from './schemas/ai-session.schema';
import { MemoDraft, MemoDraftSchema } from './schemas/memo-draft.schema';
import { AiOrchestratorService } from './services/ai-orchestrator.service';
import { ArgumentSuggestionService } from './services/argument-suggestion.service';
import { ConstitutionalMatcherService } from './services/constitutional-matcher.service';
import { DecisionSimilarityService } from './services/decision-similarity.service';
import { EmbeddingsService } from './services/embeddings.service';
import { LegalArticleMatcherService } from './services/legal-article-matcher.service';
import { MemoDraftingService } from './services/memo-drafting.service';
import { OpenAiLegalService } from './services/openai-legal.service';
import { RetrievalService } from './services/retrieval.service';

@Module({
  imports: [
    ConfigModule,
    AuditModule,
    forwardRef(() => CasesModule),
    MongooseModule.forFeature([
      { name: AiSession.name, schema: AiSessionSchema },
      { name: AiAnalysis.name, schema: AiAnalysisSchema },
      { name: ArgumentSuggestion.name, schema: ArgumentSuggestionSchema },
      { name: MemoDraft.name, schema: MemoDraftSchema },
      { name: ConstitutionArticle.name, schema: ConstitutionArticleSchema },
      { name: LawArticle.name, schema: LawArticleSchema },
      { name: JudicialDecision.name, schema: JudicialDecisionSchema },
      { name: DocumentFile.name, schema: DocumentFileSchema },
    ]),
  ],
  controllers: [AiController],
  providers: [
    AiService,
    AiOrchestratorService,
    EmbeddingsService,
    RetrievalService,
    ConstitutionalMatcherService,
    LegalArticleMatcherService,
    DecisionSimilarityService,
    ArgumentSuggestionService,
    MemoDraftingService,
    OpenAiLegalService,
  ],
  exports: [AiService],
})
export class AiModule {}
