import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import {
  ConstitutionArticle,
  ConstitutionArticleSchema,
} from '../constitution/schemas/constitution-article.schema';
import {
  JudicialDecision,
  JudicialDecisionSchema,
} from '../decisions/schemas/judicial-decision.schema';
import { LawArticle, LawArticleSchema } from '../laws/schemas/law-article.schema';
import { ResearchController } from './research.controller';
import { ResearchService } from './research.service';
import { ResearchFolder, ResearchFolderSchema } from './schemas/research-folder.schema';
import { SavedAuthority, SavedAuthoritySchema } from './schemas/saved-authority.schema';

@Module({
  imports: [
    AuditModule,
    MongooseModule.forFeature([
      { name: ConstitutionArticle.name, schema: ConstitutionArticleSchema },
      { name: LawArticle.name, schema: LawArticleSchema },
      { name: JudicialDecision.name, schema: JudicialDecisionSchema },
      { name: ResearchFolder.name, schema: ResearchFolderSchema },
      { name: SavedAuthority.name, schema: SavedAuthoritySchema },
    ]),
  ],
  controllers: [ResearchController],
  providers: [ResearchService],
  exports: [ResearchService],
})
export class ResearchModule {}
