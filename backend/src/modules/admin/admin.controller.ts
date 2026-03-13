import { Body, Controller, Get, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from 'src/common/decorators/current-user.decorator';
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

  @Get('dashboard-summary')
  dashboardSummary(@CurrentUser() user: any) {
    return this.adminService.getDashboardSummary(user?.sub);
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

  @Post('bootstrap-legal-data')
  @Roles(SystemRole.SUPER_ADMIN)
  bootstrapLegalData(@Body() body: { replace?: boolean }) {
    return this.adminService.bootstrapLegalData({ replace: body?.replace !== false });
  }
}
