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
import { Public } from 'src/common/decorators/public.decorator';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { ConstitutionService } from './constitution.service';
import { CreateConstitutionArticleDto } from './dto/create-constitution-article.dto';
import { UpdateConstitutionArticleDto } from './dto/update-constitution-article.dto';

@ApiTags('constitution')
@ApiBearerAuth()
@Controller('constitution')
export class ConstitutionController {
  constructor(private readonly constitutionService: ConstitutionService) {}

  @Get('articles')
  findAll(@Query() query: PaginationQueryDto) {
    return this.constitutionService.findAll(query);
  }

  @Get('articles/:id')
  findOne(@Param('id') id: string) {
    return this.constitutionService.findOne(id);
  }

  @Get('article-number/:articleNumber')
  findByArticleNumber(@Param('articleNumber') articleNumber: string) {
    return this.constitutionService.findByArticleNumber(articleNumber);
  }

  @Get('search')
  @ApiQuery({ name: 'q', required: true })
  search(@Query('q') q: string, @Query() query: PaginationQueryDto) {
    return this.constitutionService.search(q, query);
  }

  @Post('articles')
  create(@Body() dto: CreateConstitutionArticleDto, @CurrentUser() user: any) {
    return this.constitutionService.create(dto, user?.sub);
  }

  @Patch('articles/:id')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateConstitutionArticleDto,
    @CurrentUser() user: any,
  ) {
    return this.constitutionService.update(id, dto, user?.sub);
  }

  @Post('seed')
  @Public()
  seed() {
    return this.constitutionService.ensureSeed();
  }
}
