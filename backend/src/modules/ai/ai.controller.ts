import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import {
  AttachAiAnalysisToCaseDto,
  ArgumentBuilderDto,
  CaseAnalysisDto,
  LegalResearchDto,
  MemoDraftDto,
  SaveAiAnalysisDto,
} from './dto/ai.dto';
import { AiOrchestratorService } from './services/ai-orchestrator.service';

@ApiTags('ai')
@ApiBearerAuth()
@Controller('ai')
export class AiController {
  constructor(private readonly aiOrchestratorService: AiOrchestratorService) {}

  @Post('case-analysis')
  caseAnalysis(@Body() dto: CaseAnalysisDto, @CurrentUser() user: any) {
    return this.aiOrchestratorService.analyzeCase(dto, user?.sub);
  }

  @Post('legal-research')
  legalResearch(@Body() dto: LegalResearchDto, @CurrentUser() user: any) {
    return this.aiOrchestratorService.legalResearch(dto, user?.sub);
  }

  @Post('argument-builder')
  argumentBuilder(@Body() dto: ArgumentBuilderDto, @CurrentUser() user: any) {
    return this.aiOrchestratorService.argumentBuilder(dto, user?.sub);
  }

  @Post('memo-draft')
  memoDraft(@Body() dto: MemoDraftDto, @CurrentUser() user: any) {
    return this.aiOrchestratorService.memoDraft(dto, user?.sub);
  }

  @Get('analyses')
  listAnalyses(
    @Query() query: PaginationQueryDto,
    @Query('caseId') caseId?: string,
    @Query('analysisType') analysisType?: string,
    @Query('sessionId') sessionId?: string,
    @CurrentUser() user?: any,
  ) {
    return this.aiOrchestratorService.listAnalyses(
      {
        ...query,
        caseId,
        analysisType,
        sessionId,
      },
      user?.sub,
    );
  }

  @Get('sessions')
  listSessions(
    @Query() query: PaginationQueryDto,
    @Query('caseId') caseId?: string,
    @CurrentUser() user?: any,
  ) {
    return this.aiOrchestratorService.listSessions({ ...query, caseId }, user?.sub);
  }

  @Post('analyses/save')
  saveAnalysis(@Body() dto: SaveAiAnalysisDto, @CurrentUser() user: any) {
    return this.aiOrchestratorService.saveAnalysis(dto, user?.sub);
  }

  @Post('analyses/:id/attach-case')
  attachAnalysisToCase(
    @Param('id') id: string,
    @Body() dto: AttachAiAnalysisToCaseDto,
    @CurrentUser() user: any,
  ) {
    return this.aiOrchestratorService.attachAnalysisToCase(id, dto.caseId, user?.sub);
  }
}
