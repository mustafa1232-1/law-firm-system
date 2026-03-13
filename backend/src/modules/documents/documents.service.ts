import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { PaginationQueryDto } from 'src/common/dto/pagination-query.dto';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';
import { toObjectIdOrUndefined } from 'src/common/utils/object-id.util';
import { escapeRegex } from 'src/common/utils/regex.util';
import { AuditService } from '../audit/audit.service';
import { StorageService } from '../storage/storage.service';
import { AnalyzeDocumentDto } from './dto/analyze-document.dto';
import { CreateDocumentDto } from './dto/create-document.dto';
import { UploadDocumentDto } from './dto/upload-document.dto';
import { UpdateDocumentDto } from './dto/update-document.dto';
import { DocumentChunk, DocumentChunkDocument } from './schemas/document-chunk.schema';
import { DocumentFile, DocumentFileDocument } from './schemas/document.schema';

@Injectable()
export class DocumentsService {
  constructor(
    @InjectModel(DocumentFile.name)
    private readonly documentModel: Model<DocumentFileDocument>,
    @InjectModel(DocumentChunk.name)
    private readonly chunkModel: Model<DocumentChunkDocument>,
    private readonly storageService: StorageService,
    private readonly auditService: AuditService,
  ) {}

  async create(dto: CreateDocumentDto, actorId?: string) {
    const storagePath = await this.storageService.generatePath({
      caseId: dto.caseId,
      originalName: dto.originalName,
    });

    const document = await this.documentModel.create({
      ...dto,
      caseId: toObjectIdOrUndefined(dto.caseId),
      storagePath,
    });

    if (dto.extractedText) {
      await this.createChunks(document._id.toString(), dto.extractedText);
    }

    await this.auditService.record({
      action: 'document.create',
      entity: 'documents',
      entityId: document.id,
      actorId,
      payload: { title: document.title, mimeType: document.mimeType },
    });

    return document;
  }

  async uploadFile(file: Express.Multer.File, dto: UploadDocumentDto, actorId?: string) {
    const originalName = dto.originalName?.trim() || file.originalname || 'file.bin';
    const mimeType = dto.mimeType?.trim() || file.mimetype || 'application/octet-stream';
    const storagePath = await this.storageService.generatePath({
      caseId: dto.caseId,
      originalName,
    });

    await this.storageService.uploadFile({
      storagePath,
      buffer: file.buffer,
      mimeType,
    });

    const tags = this.parseTags(dto.tags);

    const document = await this.documentModel.create({
      title: dto.title?.trim() || originalName,
      originalName,
      mimeType,
      caseId: toObjectIdOrUndefined(dto.caseId),
      extractedText: dto.extractedText?.trim() || undefined,
      sizeBytes: file.size,
      tags,
      storagePath,
    });

    if (dto.extractedText?.trim()) {
      await this.createChunks(document._id.toString(), dto.extractedText);
    }

    await this.auditService.record({
      action: 'document.upload',
      entity: 'documents',
      entityId: document.id,
      actorId,
      payload: { title: document.title, mimeType: document.mimeType, sizeBytes: file.size },
    });

    return document;
  }

  async findAll(query: PaginationQueryDto, search?: string, caseId?: string) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;

    const rawSearch = (search ?? '').trim();
    const safeSearch = escapeRegex(rawSearch);
    const filter: Record<string, unknown> = rawSearch
      ? {
          $or: [
            { title: { $regex: safeSearch, $options: 'i' } },
            { originalName: { $regex: safeSearch, $options: 'i' } },
            { extractedText: { $regex: safeSearch, $options: 'i' } },
          ],
        }
      : {};

    if (caseId && Types.ObjectId.isValid(caseId)) {
      filter.caseId = new Types.ObjectId(caseId);
    }

    const [items, total] = await Promise.all([
      this.documentModel
        .find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      this.documentModel.countDocuments(filter),
    ]);

    return { items, total, page, limit };
  }

  async findOne(id: string) {
    const doc = await this.documentModel.findById(id).lean();
    if (!doc) {
      throw new NotFoundException('Document not found');
    }
    const signedUrl = await this.storageService.getSignedUrl(doc.storagePath);
    return { ...doc, signedUrl };
  }

  async update(id: string, dto: UpdateDocumentDto, actorId?: string) {
    const updated = await this.documentModel.findByIdAndUpdate(id, dto, { new: true }).lean();
    if (!updated) {
      throw new NotFoundException('Document not found');
    }

    await this.auditService.record({
      action: 'document.update',
      entity: 'documents',
      entityId: id,
      actorId,
      payload: dto as unknown as Record<string, unknown>,
    });

    return updated;
  }

  async analyze(id: string, dto: AnalyzeDocumentDto, actorId?: string) {
    const doc = await this.documentModel.findById(id);
    if (!doc) {
      throw new NotFoundException('Document not found');
    }

    const normalized = normalizeArabic(doc.extractedText ?? '');
    const names = Array.from(
      new Set(
        (doc.extractedText ?? '')
          .split(/\s+/)
          .filter((token) => /^[\u0600-\u06FF]{3,}$/.test(token))
          .slice(0, 10),
      ),
    );

    const dates = (doc.extractedText ?? '').match(/\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/g) ?? [];

    const legalReferenceRegex = new RegExp('\\u0627\\u0644\\u0645\\u0627\\u062F\\u0629\\s+\\d+', 'g');
    const legalRefs = normalized.match(legalReferenceRegex) ?? [];

    doc.extractedEntities = {
      names,
      dates,
      legalReferences: legalRefs,
      note: dto.customPrompt ?? null,
    };
    doc.referencedLawArticles = legalRefs.map((r) =>
      r.replace('\u0627\u0644\u0645\u0627\u062F\u0629', '').trim(),
    );
    await doc.save();

    await this.auditService.record({
      action: 'document.analyze',
      entity: 'documents',
      entityId: id,
      actorId,
    });

    return {
      documentId: id,
      summary: (doc.extractedText ?? '').slice(0, 800),
      extractedEntities: doc.extractedEntities,
      disclaimer: 'تحليل المستند آلي وأولي، ويجب مراجعته قانونيًا قبل الاعتماد المهني.',
    };
  }

  private async createChunks(documentId: string, text: string) {
    const chunkSize = 1200;
    const textClean = text.trim();
    if (!textClean) {
      return;
    }
    const chunks: { documentId: Types.ObjectId; chunkIndex: number; text: string }[] = [];
    for (let i = 0; i < textClean.length; i += chunkSize) {
      chunks.push({
        documentId: new Types.ObjectId(documentId),
        chunkIndex: chunks.length,
        text: textClean.slice(i, i + chunkSize),
      });
    }
    await this.chunkModel.deleteMany({ documentId: new Types.ObjectId(documentId) });
    await this.chunkModel.insertMany(chunks);
  }

  private parseTags(raw?: string) {
    const value = (raw ?? '').trim();
    if (!value) {
      return [] as string[];
    }
    if (value.startsWith('[') && value.endsWith(']')) {
      try {
        const parsed = JSON.parse(value);
        if (Array.isArray(parsed)) {
          return parsed.map((item) => `${item}`.trim()).filter(Boolean);
        }
      } catch {
        // fall back to comma-separated parsing
      }
    }
    return value
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }
}
