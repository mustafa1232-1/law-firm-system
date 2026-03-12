import { Injectable } from '@nestjs/common';
import { RetrievalResult } from './retrieval.service';

@Injectable()
export class DecisionSimilarityService {
  rankSimilar(results: RetrievalResult[]) {
    return results
      .filter((r) => r.sourceType === 'decision')
      .sort((a, b) => b.score - a.score)
      .slice(0, 5)
      .map((item, index) => ({
        ...item,
        similarity: Math.max(0.42, Number((item.score - index * 0.03).toFixed(2))),
      }));
  }
}
