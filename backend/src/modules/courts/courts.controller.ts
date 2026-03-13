import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CourtsService } from './courts.service';
import { QueryCourtsDto } from './dto/query-courts.dto';

@ApiTags('courts')
@ApiBearerAuth()
@Controller('courts')
export class CourtsController {
  constructor(private readonly courtsService: CourtsService) {}

  @Get()
  search(@Query() query: QueryCourtsDto) {
    return this.courtsService.search(query);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.courtsService.findOne(id);
  }
}
