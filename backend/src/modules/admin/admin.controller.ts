import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Public } from 'src/common/decorators/public.decorator';
import { Roles } from 'src/common/decorators/roles.decorator';
import { SystemRole } from 'src/common/constants/system.constants';
import { AdminService } from './admin.service';
import { CreatePermissionDto, CreateRoleDto } from './dto/admin.dto';

@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('roles')
  listRoles() {
    return this.adminService.listRoles();
  }

  @Get('permissions')
  listPermissions() {
    return this.adminService.listPermissions();
  }

  @Post('roles')
  @Roles(SystemRole.SUPER_ADMIN)
  createRole(@Body() dto: CreateRoleDto) {
    return this.adminService.createRole(dto);
  }

  @Post('permissions')
  @Roles(SystemRole.SUPER_ADMIN)
  createPermission(@Body() dto: CreatePermissionDto) {
    return this.adminService.createPermission(dto);
  }

  @Post('seed-rbac')
  @Public()
  seedDefaultRbac() {
    return this.adminService.seedDefaultRbac();
  }
}
