import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class StorageService implements OnModuleInit {
  private provider = 'local';
  private bucket = 'lexiq-iraq';
  private endpoint = '';
  private projectPrefix = '';
  private localRoot = path.join(process.cwd(), 'uploads');
  private s3?: S3Client;

  constructor(private readonly configService: ConfigService) {}
  
  onModuleInit() {
    this.provider = this.configService.get<string>('storage.provider') ?? 'local';
    this.bucket = this.configService.get<string>('storage.bucket') ?? 'lexiq-iraq';
    this.endpoint = this.configService.get<string>('storage.endpoint') ?? '';
    this.projectPrefix =
      (this.configService.get<string>('storage.projectPrefix') ?? '')
        .trim()
        .replace(/^\/+|\/+$/g, '');
    this.localRoot =
      this.configService.get<string>('storage.localRoot') ??
      path.join(process.cwd(), 'uploads');

    if (this.provider === 's3' || this.provider === 'r2') {
      this.s3 = new S3Client({
        region: this.configService.get<string>('storage.region') ?? 'us-east-1',
        endpoint: this.endpoint || undefined,
        forcePathStyle: true,
        credentials: {
          accessKeyId: this.configService.get<string>('storage.accessKey') ?? '',
          secretAccessKey: this.configService.get<string>('storage.secretKey') ?? '',
        },
      });
    }

    if (this.provider === 'local') {
      fs.mkdirSync(this.localRoot, { recursive: true });
    }
  }

  async generatePath(params: {
    firmId?: string;
    caseId?: string;
    originalName: string;
  }): Promise<string> {
    const prefix = [params.firmId ?? 'global', params.caseId ?? 'unlinked']
      .filter(Boolean)
      .join('/');
    const safeName = params.originalName
      .replace(/[^\w.\-\u0600-\u06FF]/g, '_')
      .replace(/\s+/g, '_');
    const relativePath = `${prefix}/${Date.now()}_${safeName}`;
    if (!this.projectPrefix) {
      return relativePath;
    }
    return `${this.projectPrefix}/${relativePath}`;
  }

  async uploadFile(params: { storagePath: string; buffer: Buffer; mimeType?: string }) {
    if (this.provider === 's3' || this.provider === 'r2') {
      if (!this.s3) {
        throw new Error('S3 client is not initialized');
      }
      await this.s3.send(
        new PutObjectCommand({
          Bucket: this.bucket,
          Key: params.storagePath,
          Body: params.buffer,
          ContentType: params.mimeType,
        }),
      );
      return params.storagePath;
    }

    const abs = path.join(this.localRoot, params.storagePath);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    await fs.promises.writeFile(abs, params.buffer);
    return params.storagePath;
  }

  async getSignedUrl(path: string): Promise<string> {
    if (this.provider === 's3' || this.provider === 'r2') {
      const publicBaseUrl = this.configService.get<string>('storage.publicBaseUrl') ?? '';
      const normalizedPublicBase = publicBaseUrl.replace(/\/+$/, '');
      if (normalizedPublicBase) {
        return `${normalizedPublicBase}/${path}`;
      }
      if (this.endpoint) {
        const normalized = this.endpoint.replace(/\/+$/, '');
        return `${normalized}/${this.bucket}/${path}`;
      }
      return path;
    }
    const publicBaseUrl = this.configService.get<string>('storage.publicBaseUrl') ?? '';
    const normalizedBase = publicBaseUrl.replace(/\/+$/, '');
    if (normalizedBase) {
      return `${normalizedBase}/storage/${path}`;
    }
    return `/storage/${path}`;
  }
}
