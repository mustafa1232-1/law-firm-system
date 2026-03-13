import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiQuery, ApiTags } from '@nestjs/swagger';
import { ApiBody, ApiConsumes } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { CreateDecisionDto } from './dto/create-decision.dto';
import { IngestDecisionDto } from './dto/ingest-decision.dto';
import { ReclassifyDecisionDto } from './dto/reclassify-decision.dto';
import { SyncSjcAppellateDto } from './dto/sync-sjc-appellate.dto';
import { UploadDecisionDto } from './dto/upload-decision.dto';
import { DecisionsService } from './decisions.service';

@ApiTags('decisions')
@ApiBearerAuth()
@Controller('decisions')
export class DecisionsController {
  constructor(private readonly decisionsService: DecisionsService) {}

  @Get('search')
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'court', required: false })
  @ApiQuery({ name: 'caseType', required: false })
  @ApiQuery({ name: 'legalDomain', required: false })
  @ApiQuery({ name: 'courtLevel', required: false })
  @ApiQuery({ name: 'year', required: false })
  search(
    @Query('q') q: string,
    @Query() query: PaginationQueryDto,
    @Query('court') court?: string,
    @Query('caseType') caseType?: string,
    @Query('legalDomain') legalDomain?: string,
    @Query('courtLevel') courtLevel?: string,
    @Query('year') year?: string,
  ) {
    return this.decisionsService.search(q, query, {
      court: court ?? '',
      caseType: caseType ?? '',
      legalDomain: legalDomain ?? '',
      courtLevel: courtLevel ?? '',
      year: year ?? '',
    });
  }

  @Get('case-type-summary')
  @ApiQuery({ name: 'courtLevel', required: false })
  @ApiQuery({ name: 'year', required: false })
  caseTypeSummary(
    @Query('courtLevel') courtLevel?: string,
    @Query('year') year?: string,
  ) {
    return this.decisionsService.caseTypeSummary({
      courtLevel: courtLevel ?? '',
      year: year ?? '',
    });
  }

  @Post()
  create(@Body() dto: CreateDecisionDto, @CurrentUser() user: any) {
    return this.decisionsService.create(dto, user?.sub);
  }

  @Post('upload')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        courtName: { type: 'string' },
        courtLevel: { type: 'string', enum: ['appellate', 'cassation'] },
        governorate: { type: 'string' },
        decisionNumber: { type: 'string' },
        decisionDate: { type: 'string', format: 'date-time' },
        publicationDate: { type: 'string', format: 'date-time' },
        chamber: { type: 'string' },
        source: { type: 'string' },
        sourceType: { type: 'string' },
        caseType: { type: 'string' },
        legalDomain: { type: 'string' },
        summary: { type: 'string' },
        fullText: { type: 'string' },
        tags: { type: 'string' },
        legalKeywords: { type: 'string' },
        legalArticleReferences: { type: 'string' },
        constitutionalReferences: { type: 'string' },
      },
      required: ['file', 'courtName', 'decisionNumber', 'decisionDate'],
    },
  })
  @UseInterceptors(FileInterceptor('file'))
  upload(
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: UploadDecisionDto,
    @CurrentUser() user: any,
  ) {
    if (!file) {
      throw new BadRequestException('File is required');
    }
    return this.decisionsService.uploadDecision(file, dto, user?.sub);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.decisionsService.findOne(id);
  }

  @Post('ingest')
  ingest(@Body() dto: IngestDecisionDto, @CurrentUser() user: any) {
    return this.decisionsService.ingest(dto, user?.sub);
  }

  @Post('sync/sjc-appellate')
  syncSjcAppellate(@Body() dto: SyncSjcAppellateDto, @CurrentUser() user: any) {
    return this.decisionsService.syncSjcAppellate(dto, user?.sub);
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
