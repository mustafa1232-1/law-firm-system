import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Payment, PaymentSchema } from '../billing/schemas/payment.schema';
import { CaseFile, CaseSchema } from '../cases/schemas/case.schema';
import {
  ConstitutionArticle,
  ConstitutionArticleSchema,
} from '../constitution/schemas/constitution-article.schema';
import {
  JudicialDecision,
  JudicialDecisionSchema,
} from '../decisions/schemas/judicial-decision.schema';
import { Court, CourtSchema } from '../courts/schemas/court.schema';
import { Hearing, HearingSchema } from '../hearings/schemas/hearing.schema';
import { LawArticle, LawArticleSchema } from '../laws/schemas/law-article.schema';
import {
  LawDocumentEntity,
  LawDocumentSchema,
} from '../laws/schemas/law-document.schema';
import { Notification, NotificationSchema } from '../notifications/schemas/notification.schema';
import { TaskItem, TaskItemSchema } from '../tasks/schemas/task.schema';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { PermissionEntity, PermissionSchema } from './schemas/permission.schema';
import { RoleEntity, RoleSchema } from './schemas/role.schema';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: RoleEntity.name, schema: RoleSchema },
      { name: PermissionEntity.name, schema: PermissionSchema },
      { name: CaseFile.name, schema: CaseSchema },
      { name: Hearing.name, schema: HearingSchema },
      { name: TaskItem.name, schema: TaskItemSchema },
      { name: Payment.name, schema: PaymentSchema },
      { name: Notification.name, schema: NotificationSchema },
      { name: ConstitutionArticle.name, schema: ConstitutionArticleSchema },
      { name: LawDocumentEntity.name, schema: LawDocumentSchema },
      { name: LawArticle.name, schema: LawArticleSchema },
      { name: JudicialDecision.name, schema: JudicialDecisionSchema },
      { name: Court.name, schema: CourtSchema },
    ]),
  ],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
