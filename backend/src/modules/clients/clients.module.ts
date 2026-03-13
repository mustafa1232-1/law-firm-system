import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { CaseFile, CaseSchema } from '../cases/schemas/case.schema';
import { ClientsController } from './clients.controller';
import { ClientsService } from './clients.service';
import { Client, ClientSchema } from './schemas/client.schema';
import { Contact, ContactSchema } from './schemas/contact.schema';

@Module({
  imports: [
    AuditModule,
    MongooseModule.forFeature([
      { name: Client.name, schema: ClientSchema },
      { name: Contact.name, schema: ContactSchema },
      { name: CaseFile.name, schema: CaseSchema },
    ]),
  ],
  controllers: [ClientsController],
  providers: [ClientsService],
  exports: [ClientsService],
})
export class ClientsModule {}
