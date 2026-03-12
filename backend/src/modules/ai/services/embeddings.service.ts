import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class EmbeddingsService {
  constructor(private readonly configService: ConfigService) {}

  async embed(text: string): Promise<number[]> {
    const provider = this.configService.get<string>('ai.embeddingsProvider');

    if (!provider || provider === 'none') {
      const seed = Array.from(text.slice(0, 64)).reduce(
        (acc, char) => acc + char.charCodeAt(0),
        0,
      );
      return Array.from({ length: 16 }, (_, idx) => ((seed + idx * 13) % 1000) / 1000);
    }

    return Array.from({ length: 16 }, () => 0.0);
  }
}
