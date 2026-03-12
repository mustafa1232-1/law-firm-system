import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { LegalTaxonomyController } from './legal-taxonomy.controller';
import { LegalTaxonomyService } from './legal-taxonomy.service';
import { LegalTaxonomy, LegalTaxonomySchema } from './schemas/legal-taxonomy.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: LegalTaxonomy.name, schema: LegalTaxonomySchema },
    ]),
  ],
  controllers: [LegalTaxonomyController],
  providers: [LegalTaxonomyService],
  exports: [LegalTaxonomyService],
})
export class LegalTaxonomyModule {}
