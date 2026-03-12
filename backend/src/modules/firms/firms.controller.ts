import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
import { Roles } from 'src/common/decorators/roles.decorator';
import { SystemRole } from 'src/common/constants/system.constants';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { CreateFirmDto } from './dto/create-firm.dto';
import { UpdateFirmSettingsDto } from './dto/update-firm-settings.dto';
import { UpdateFirmDto } from './dto/update-firm.dto';
import { FirmsService } from './firms.service';

@ApiTags('firms')
@ApiBearerAuth()
@Controller('firms')
export class FirmsController {
  constructor(private readonly firmsService: FirmsService) {}

  @Post()
  @Roles(SystemRole.SUPER_ADMIN)
  create(@Body() dto: CreateFirmDto, @CurrentUser() user: any) {
    return this.firmsService.create(dto, user?.sub);
  }

  @Get()
  findAll(@Query() query: PaginationQueryDto) {
    return this.firmsService.findAll(query);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.firmsService.findOne(id);
  }

  @Patch(':id')
  @Roles(SystemRole.SUPER_ADMIN, SystemRole.FIRM_ADMIN)
  update(@Param('id') id: string, @Body() dto: UpdateFirmDto, @CurrentUser() user: any) {
    return this.firmsService.update(id, dto, user?.sub);
  }

  @Patch(':id/settings')
  @Roles(SystemRole.SUPER_ADMIN, SystemRole.FIRM_ADMIN)
  updateSettings(
    @Param('id') id: string,
    @Body() dto: UpdateFirmSettingsDto,
    @CurrentUser() user: any,
  ) {
    return this.firmsService.updateSettings(id, dto, user?.sub);
  }
}
