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
import { CreateLawArticleDto } from './dto/create-law-article.dto';
import { CreateLawDto } from './dto/create-law.dto';
import { UpdateLawDto } from './dto/update-law.dto';
import { LawsService } from './laws.service';

@ApiTags('laws')
@ApiBearerAuth()
@Controller('laws')
export class LawsController {
  constructor(private readonly lawsService: LawsService) {}

  @Get()
  findAll(@Query() query: PaginationQueryDto, @Query('q') q?: string) {
    return this.lawsService.findAll(query, q);
  }

  @Get('search')
  @ApiQuery({ name: 'q', required: false })
  search(@Query('q') q: string, @Query() query: PaginationQueryDto) {
    return this.lawsService.search(q, query);
  }

  @Post()
  createLaw(@Body() dto: CreateLawDto, @CurrentUser() user: any) {
    return this.lawsService.createLaw(dto, user?.sub);
  }

  @Post('articles')
  createArticle(@Body() dto: CreateLawArticleDto, @CurrentUser() user: any) {
    return this.lawsService.createArticle(dto, user?.sub);
  }

  @Get('articles/:id')
  findArticle(@Param('id') id: string) {
    return this.lawsService.findArticleById(id);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.lawsService.findLawById(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateLawDto, @CurrentUser() user: any) {
    return this.lawsService.updateLaw(id, dto, user?.sub);
  }

  @Get(':id/articles')
  findArticles(@Param('id') id: string, @Query() query: PaginationQueryDto) {
    return this.lawsService.findLawArticles(id, query);
  }
}
