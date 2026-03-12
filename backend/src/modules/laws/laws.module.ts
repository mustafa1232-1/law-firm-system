import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { LawsController } from './laws.controller';
import { LawsService } from './laws.service';
import { LawArticle, LawArticleSchema } from './schemas/law-article.schema';
import {
  LawDocumentEntity,
  LawDocumentSchema,
} from './schemas/law-document.schema';

@Module({
  imports: [
    AuditModule,
    MongooseModule.forFeature([
      { name: LawDocumentEntity.name, schema: LawDocumentSchema },
      { name: LawArticle.name, schema: LawArticleSchema },
    ]),
  ],
  controllers: [LawsController],
  providers: [LawsService],
  exports: [LawsService],
})
export class LawsModule {}
