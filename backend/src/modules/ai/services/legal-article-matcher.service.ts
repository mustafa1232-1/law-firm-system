import { Injectable } from '@nestjs/common';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';

@Injectable()
export class LegalArticleMatcherService {
  suggest(description: string) {
    const text = normalizeArabic(description);
    const refs: string[] = [];

    if (text.includes('اثبات') || text.includes('بينه')) {
      refs.push('قانون الإثبات العراقي - قواعد عبء الإثبات');
    }
    if (text.includes('عقد') || text.includes('تعويض')) {
      refs.push('القانون المدني العراقي - المسؤولية العقدية والمدنية');
    }
    if (text.includes('جريمه') || text.includes('متهم')) {
      refs.push('قانون العقوبات العراقي - الوصف الجرمي');
    }
    if (text.includes('اجراء') || text.includes('محكمه')) {
      refs.push('قانون أصول المحاكمات - الاختصاص والإجراءات');
    }

    return refs;
  }
}
