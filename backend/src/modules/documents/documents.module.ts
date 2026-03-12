import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditModule } from '../audit/audit.module';
import { StorageModule } from '../storage/storage.module';
import { DocumentsController } from './documents.controller';
import { DocumentsService } from './documents.service';
import { DocumentChunk, DocumentChunkSchema } from './schemas/document-chunk.schema';
import { DocumentFile, DocumentFileSchema } from './schemas/document.schema';

@Module({
  imports: [
    StorageModule,
    AuditModule,
    MongooseModule.forFeature([
      { name: DocumentFile.name, schema: DocumentFileSchema },
      { name: DocumentChunk.name, schema: DocumentChunkSchema },
    ]),
  ],
  controllers: [DocumentsController],
  providers: [DocumentsService],
  exports: [DocumentsService],
})
export class DocumentsModule {}
