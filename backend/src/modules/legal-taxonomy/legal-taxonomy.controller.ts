import { Controller, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Public } from 'src/common/decorators/public.decorator';
import { LegalTaxonomyService } from './legal-taxonomy.service';

@ApiTags('legal-taxonomy')
@ApiBearerAuth()
@Controller('legal-taxonomy')
export class LegalTaxonomyController {
  constructor(private readonly legalTaxonomyService: LegalTaxonomyService) {}

  @Get()
  findAll() {
    return this.legalTaxonomyService.findAll();
  }

  @Post('seed')
  @Public()
  seed() {
    return this.legalTaxonomyService.seedDefaults();
  }
}
