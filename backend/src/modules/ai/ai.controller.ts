import { Body, Controller, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import {
  ArgumentBuilderDto,
  CaseAnalysisDto,
  LegalResearchDto,
  MemoDraftDto,
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
}
