import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { CreateDecisionDto } from './dto/create-decision.dto';
import { IngestDecisionDto } from './dto/ingest-decision.dto';
import { ReclassifyDecisionDto } from './dto/reclassify-decision.dto';
import { DecisionsService } from './decisions.service';

@ApiTags('decisions')
@ApiBearerAuth()
@Controller('decisions')
export class DecisionsController {
  constructor(private readonly decisionsService: DecisionsService) {}

  @Get('search')
  @ApiQuery({ name: 'q', required: true })
  @ApiQuery({ name: 'court', required: false })
  @ApiQuery({ name: 'caseType', required: false })
  @ApiQuery({ name: 'legalDomain', required: false })
  search(
    @Query('q') q: string,
    @Query() query: PaginationQueryDto,
    @Query('court') court?: string,
    @Query('caseType') caseType?: string,
    @Query('legalDomain') legalDomain?: string,
  ) {
    return this.decisionsService.search(q, query, {
      court: court ?? '',
      caseType: caseType ?? '',
      legalDomain: legalDomain ?? '',
    });
  }

  @Post()
  create(@Body() dto: CreateDecisionDto, @CurrentUser() user: any) {
    return this.decisionsService.create(dto, user?.sub);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.decisionsService.findOne(id);
  }

  @Post('ingest')
  ingest(@Body() dto: IngestDecisionDto, @CurrentUser() user: any) {
    return this.decisionsService.ingest(dto, user?.sub);
  }

  @Post(':id/reclassify')
  reclassify(
    @Param('id') id: string,
    @Body() dto: ReclassifyDecisionDto,
    @CurrentUser() user: any,
  ) {
    return this.decisionsService.reclassify(id, dto, user?.sub);
  }
}
