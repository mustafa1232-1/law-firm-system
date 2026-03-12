import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
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
    ]),
  ],
  controllers: [ClientsController],
  providers: [ClientsService],
  exports: [ClientsService],
})
export class ClientsModule {}
