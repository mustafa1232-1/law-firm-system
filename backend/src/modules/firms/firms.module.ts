import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { UsersModule } from '../users/users.module';
import { User, UserSchema } from '../users/schemas/user.schema';
import { Firm, FirmSchema } from './schemas/firm.schema';
import { FirmSettings, FirmSettingsSchema } from './schemas/firm-settings.schema';
import { FirmsController } from './firms.controller';
import { FirmsService } from './firms.service';

@Module({
  imports: [
    AuditModule,
    UsersModule,
    MongooseModule.forFeature([
      { name: Firm.name, schema: FirmSchema },
      { name: FirmSettings.name, schema: FirmSettingsSchema },
      { name: User.name, schema: UserSchema },
    ]),
  ],
  controllers: [FirmsController],
  providers: [FirmsService],
  exports: [FirmsService],
})
export class FirmsModule {}
