import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import {
  CreateResearchFolderDto,
  SaveAuthorityDto,
  SearchResearchDto,
} from './dto/research.dto';
import { ResearchService } from './research.service';

@ApiTags('research')
@ApiBearerAuth()
@Controller('research')
export class ResearchController {
  constructor(private readonly researchService: ResearchService) {}

  @Get('search')
  @ApiQuery({ name: 'q', required: true })
  search(@Query() query: SearchResearchDto) {
    return this.researchService.search(query);
  }

  @Post('folders')
  createFolder(@Body() dto: CreateResearchFolderDto, @CurrentUser() user: any) {
    return this.researchService.createFolder(dto, user?.sub);
  }

  @Get('folders')
  listFolders(@CurrentUser() user: any) {
    return this.researchService.listFolders(user?.sub);
  }

  @Post('folders/:id/authorities')
  saveAuthority(
    @Param('id') folderId: string,
    @Body() dto: SaveAuthorityDto,
    @CurrentUser() user: any,
  ) {
    return this.researchService.saveAuthority(folderId, dto, user?.sub);
  }

  @Get('folders/:id/authorities')
  listAuthorities(@Param('id') folderId: string) {
    return this.researchService.listFolderAuthorities(folderId);
  }
}
