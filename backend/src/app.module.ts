import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { FirmsModule } from './modules/firms/firms.module';
import { ClientsModule } from './modules/clients/clients.module';
import { CasesModule } from './modules/cases/cases.module';
import { HearingsModule } from './modules/hearings/hearings.module';
import { TasksModule } from './modules/tasks/tasks.module';
import { DocumentsModule } from './modules/documents/documents.module';
import { BillingModule } from './modules/billing/billing.module';
import { ConstitutionModule } from './modules/constitution/constitution.module';
import { LawsModule } from './modules/laws/laws.module';
import { DecisionsModule } from './modules/decisions/decisions.module';
import { ResearchModule } from './modules/research/research.module';
import { AiModule } from './modules/ai/ai.module';
import { IngestModule } from './modules/ingest/ingest.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { AdminModule } from './modules/admin/admin.module';
import { HealthModule } from './modules/health/health.module';
import configuration from './config/configuration';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { AuditModule } from './modules/audit/audit.module';
import { QueueModule } from './modules/queue/queue.module';
import { LegalTaxonomyModule } from './modules/legal-taxonomy/legal-taxonomy.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      envFilePath: ['.env.local', '.env'],
    }),
    MongooseModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        uri: configService.get<string>('mongodb.uri'),
        autoIndex: true,
      }),
    }),
    ThrottlerModule.forRoot({
      throttlers: [
        {
          ttl: Number(process.env.THROTTLE_TTL ?? 60) * 1000,
          limit: Number(process.env.THROTTLE_LIMIT ?? 120),
        },
      ],
    } as any),
    QueueModule,
    AuditModule,
    AuthModule,
    UsersModule,
    FirmsModule,
    ClientsModule,
    CasesModule,
    HearingsModule,
    TasksModule,
    DocumentsModule,
    BillingModule,
    ConstitutionModule,
    LawsModule,
    DecisionsModule,
    ResearchModule,
    AiModule,
    IngestModule,
    NotificationsModule,
    LegalTaxonomyModule,
    AdminModule,
    HealthModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: RolesGuard,
    },
  ],
})
export class AppModule {}
