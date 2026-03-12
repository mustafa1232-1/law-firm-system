import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AnalyzeDocumentDto } from './dto/analyze-document.dto';
import { CreateDocumentDto } from './dto/create-document.dto';
import { UpdateDocumentDto } from './dto/update-document.dto';
import { DocumentsService } from './documents.service';

@ApiTags('documents')
@ApiBearerAuth()
@Controller('documents')
export class DocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  @Post()
  create(@Body() dto: CreateDocumentDto, @CurrentUser() user: any) {
    return this.documentsService.create(dto, user?.sub);
  }

  @Get()
  @ApiQuery({ name: 'search', required: false })
  findAll(@Query() query: PaginationQueryDto, @Query('search') search?: string) {
    return this.documentsService.findAll(query, search);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.documentsService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateDocumentDto, @CurrentUser() user: any) {
    return this.documentsService.update(id, dto, user?.sub);
  }

  @Post(':id/analyze')
  analyze(@Param('id') id: string, @Body() dto: AnalyzeDocumentDto, @CurrentUser() user: any) {
    return this.documentsService.analyze(id, dto, user?.sub);
  }
}
