import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import { ApiBearerAuth, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AnalyzeCaseDto } from './dto/analyze-case.dto';
import { CreateCaseDto } from './dto/create-case.dto';
import { UpdateCaseDto } from './dto/update-case.dto';
import { CasesService } from './cases.service';

@ApiTags('cases')
@ApiBearerAuth()
@Controller('cases')
export class CasesController {
  constructor(private readonly casesService: CasesService) {}

  @Get()
  @ApiQuery({ name: 'q', required: false })
  findAll(@Query() query: PaginationQueryDto, @Query('q') q?: string) {
    return this.casesService.findAll(query, q);
  }

  @Post()
  create(@Body() dto: CreateCaseDto, @CurrentUser() user: any) {
    return this.casesService.create(dto, user?.sub);
  }

  @Get(':id/export/summary')
  async exportSummary(
    @Param('id') id: string,
    @Query('format') format: string,
    @CurrentUser() user: any,
    @Res() res: Response,
  ) {
    const file = await this.casesService.exportCaseSummary(id, format, user?.sub);
    res.setHeader('Content-Type', file.contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${file.filename}"`);
    res.send(file.buffer);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.casesService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateCaseDto, @CurrentUser() user: any) {
    return this.casesService.update(id, dto, user?.sub);
  }

  @Post(':id/analyze')
  analyze(@Param('id') id: string, @Body() dto: AnalyzeCaseDto, @CurrentUser() user: any) {
    return this.casesService.analyze(id, dto, user?.sub);
  }
}
