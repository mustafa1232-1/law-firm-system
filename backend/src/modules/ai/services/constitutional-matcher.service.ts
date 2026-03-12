import { Injectable } from '@nestjs/common';
import { normalizeArabic } from 'src/common/utils/arabic-normalization.util';

@Injectable()
export class ConstitutionalMatcherService {
  match(description: string) {
    const text = normalizeArabic(description);
    const suggestions: Array<{ articleHint: string; reason: string }> = [];

    if (text.includes('مساواه') || text.includes('تمييز')) {
      suggestions.push({
        articleHint: 'الدستور العراقي المادة 14',
        reason: 'وجود مؤشرات تتعلق بمبدأ المساواة وعدم التمييز.',
      });
    }
    if (text.includes('ملكيه') || text.includes('عقار')) {
      suggestions.push({
        articleHint: 'الدستور العراقي المادة 23',
        reason: 'وجود مؤشرات على نزاع يمس حق الملكية.',
      });
    }
    if (text.includes('محاكمه') || text.includes('تقاضي') || text.includes('حق دفاع')) {
      suggestions.push({
        articleHint: 'الدستور العراقي المادة 19',
        reason: 'وجود مؤشرات مرتبطة بضمانات المحاكمة العادلة وحق التقاضي.',
      });
    }

    return suggestions;
  }
}
