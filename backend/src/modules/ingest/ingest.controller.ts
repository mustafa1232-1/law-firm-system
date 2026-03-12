import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { CreateIngestSourceDto } from './dto/create-ingest-source.dto';
import { StartIngestDto } from './dto/start-ingest.dto';
import { IngestService } from './ingest.service';

@ApiTags('ingest')
@ApiBearerAuth()
@Controller('ingest')
export class IngestController {
  constructor(private readonly ingestService: IngestService) {}

  @Post('sources')
  createSource(@Body() dto: CreateIngestSourceDto, @CurrentUser() user: any) {
    return this.ingestService.createSource(dto, user?.sub);
  }

  @Get('sources')
  listSources() {
    return this.ingestService.listSources();
  }

  @Post('decisions')
  startIngestion(@Body() dto: StartIngestDto, @CurrentUser() user: any) {
    return this.ingestService.startDecisionIngestion(dto, user?.sub);
  }

  @Get('jobs')
  @ApiQuery({ name: 'status', required: false })
  jobs(@Query('status') status?: string) {
    return this.ingestService.getJobs(status);
  }

  @Get('jobs/:id')
  findJob(@Param('id') id: string) {
    return this.ingestService.getJobById(id);
  }

  @Post('jobs/:id/run')
  runJob(@Param('id') id: string) {
    return this.ingestService.runQueuedJob(id);
  }
}
