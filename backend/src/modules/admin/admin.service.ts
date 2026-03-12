import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { CreatePermissionDto, CreateRoleDto } from './dto/admin.dto';
import { PermissionEntity, PermissionDocument } from './schemas/permission.schema';
import { RoleEntity, RoleDocument } from './schemas/role.schema';

@Injectable()
export class AdminService {
  constructor(
    @InjectModel(RoleEntity.name)
    private readonly roleModel: Model<RoleDocument>,
    @InjectModel(PermissionEntity.name)
    private readonly permissionModel: Model<PermissionDocument>,
  ) {}

  createRole(dto: CreateRoleDto) {
    return this.roleModel.create(dto);
  }

  createPermission(dto: CreatePermissionDto) {
    return this.permissionModel.create(dto);
  }

  listRoles() {
    return this.roleModel.find().sort({ key: 1 }).lean();
  }

  listPermissions() {
    return this.permissionModel.find().sort({ key: 1 }).lean();
  }

  async seedDefaultRbac() {
    const permissions = [
      { key: 'cases.read', name: 'Read cases' },
      { key: 'cases.write', name: 'Write cases' },
      { key: 'research.read', name: 'Read research' },
      { key: 'billing.manage', name: 'Manage billing' },
      { key: 'admin.manage', name: 'Manage admin settings' },
    ];

    for (const permission of permissions) {
      await this.permissionModel.updateOne(
        { key: permission.key },
        { $setOnInsert: permission },
        { upsert: true },
      );
    }

    const roles = [
      {
        key: 'SUPER_ADMIN',
        name: 'Super Admin',
        permissions: permissions.map((p) => p.key),
      },
      {
        key: 'FIRM_ADMIN',
        name: 'Firm Admin',
        permissions: ['cases.read', 'cases.write', 'research.read', 'billing.manage'],
      },
      {
        key: 'LAWYER',
        name: 'Lawyer',
        permissions: ['cases.read', 'cases.write', 'research.read'],
      },
      {
        key: 'RESEARCHER',
        name: 'Researcher',
        permissions: ['research.read'],
      },
      {
        key: 'READ_ONLY_VIEWER',
        name: 'Read-only Viewer',
        permissions: ['cases.read'],
      },
    ];

    for (const role of roles) {
      await this.roleModel.updateOne({ key: role.key }, { $setOnInsert: role }, { upsert: true });
    }

    return { seeded: true, roles: roles.length, permissions: permissions.length };
  }
}
