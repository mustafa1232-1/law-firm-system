import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class StorageService {
  constructor(private readonly configService: ConfigService) {}

  async generatePath(params: {
    firmId?: string;
    caseId?: string;
    originalName: string;
  }): Promise<string> {
    const prefix = [params.firmId ?? 'global', params.caseId ?? 'unlinked']
      .filter(Boolean)
      .join('/');
    const safeName = params.originalName.replace(/\s+/g, '_');
    return `${prefix}/${Date.now()}_${safeName}`;
  }

  async getSignedUrl(path: string): Promise<string> {
    const endpoint = this.configService.get<string>('storage.endpoint');
    if (endpoint) {
      return `${endpoint}/${path}`;
    }
    return `/storage/${path}`;
  }
}
