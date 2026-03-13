import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import OpenAI from 'openai';

@Injectable()
export class EmbeddingsService {
  private readonly client: OpenAI | null;

  constructor(private readonly configService: ConfigService) {
    const apiKey = this.configService.get<string>('ai.openaiApiKey')?.trim();
    this.client = apiKey ? new OpenAI({ apiKey }) : null;
  }

  async embed(text: string): Promise<number[]> {
    const provider = this.configService.get<string>('ai.embeddingsProvider');

    if (!provider || provider === 'none' || !this.client) {
      const seed = Array.from(text.slice(0, 64)).reduce(
        (acc, char) => acc + char.charCodeAt(0),
        0,
      );
      return Array.from({ length: 16 }, (_, idx) => ((seed + idx * 13) % 1000) / 1000);
    }

    if (provider === 'openai') {
      try {
        const model =
          this.configService.get<string>('ai.openaiEmbeddingModel') ??
          'text-embedding-3-small';
        const response = await this.client.embeddings.create({ model, input: text.slice(0, 8000) });
        const vector = response.data?.[0]?.embedding ?? [];
        if (Array.isArray(vector) && vector.length) {
          return vector.slice(0, 256);
        }
      } catch {
        // Fall back to deterministic local embedding when provider call fails.
        const seed = Array.from(text.slice(0, 64)).reduce(
          (acc, char) => acc + char.charCodeAt(0),
          0,
        );
        return Array.from({ length: 16 }, (_, idx) => ((seed + idx * 13) % 1000) / 1000);
      }
    }

    return Array.from({ length: 16 }, () => 0.0);
  }
}
