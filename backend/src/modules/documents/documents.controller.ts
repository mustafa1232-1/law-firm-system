import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { AnalyzeDocumentDto } from './dto/analyze-document.dto';
import { CreateDocumentDto } from './dto/create-document.dto';
import { UploadDocumentDto } from './dto/upload-document.dto';
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

  @Post('upload')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
        title: { type: 'string' },
        caseId: { type: 'string' },
        extractedText: { type: 'string' },
        tags: { type: 'string' },
      },
      required: ['file'],
    },
  })
  @UseInterceptors(FileInterceptor('file'))
  upload(
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: UploadDocumentDto,
    @CurrentUser() user: any,
  ) {
    if (!file) {
      throw new BadRequestException('File is required');
    }
    return this.documentsService.uploadFile(file, dto, user?.sub);
  }

  @Get()
  @ApiQuery({ name: 'search', required: false })
  @ApiQuery({ name: 'caseId', required: false })
  findAll(
    @Query() query: PaginationQueryDto,
    @Query('search') search?: string,
    @Query('caseId') caseId?: string,
  ) {
    return this.documentsService.findAll(query, search, caseId);
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
