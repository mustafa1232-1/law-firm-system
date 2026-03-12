import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { ConstitutionController } from './constitution.controller';
import { ConstitutionService } from './constitution.service';
import {
  ConstitutionArticle,
  ConstitutionArticleSchema,
} from './schemas/constitution-article.schema';

@Module({
  imports: [
    AuditModule,
    MongooseModule.forFeature([
      { name: ConstitutionArticle.name, schema: ConstitutionArticleSchema },
    ]),
  ],
  controllers: [ConstitutionController],
  providers: [ConstitutionService],
  exports: [ConstitutionService],
})
export class ConstitutionModule {}
