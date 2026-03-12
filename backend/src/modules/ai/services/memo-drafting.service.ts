import { Injectable } from '@nestjs/common';
import { RetrievalResult } from './retrieval.service';

@Injectable()
export class MemoDraftingService {
  compose(input: {
    topic: string;
    facts: string;
    authorities: RetrievalResult[];
    disclaimer: string;
  }) {
    const authorities = input.authorities
      .slice(0, 8)
      .map((authority) => `- ${authority.citation}`)
      .join('\n');

    return [
      `الموضوع: ${input.topic}`,
      '',
      'الوقائع: ملخص وقائع القضية',
      input.facts,
      '',
      'الدفوع: مرتكزات قانونية أولية',
      '- التكييف القانوني للواقعة.',
      '- مدى تحقق أركان المطالبة القانونية.',
      '- تقدير عبء الإثبات وتوزيعه.',
      '',
      'المرجعيات: السلطات القانونية المقترحة',
      authorities || '- لا توجد نتائج مرجعية كافية في البيانات المفهرسة.',
      '',
      'تنبيه: مراجعة بشرية',
      '- هذه المسودة أولية وتحتاج مراجعة محامٍ مرخّص قبل اعتمادها.',
      `- ${input.disclaimer}`,
    ].join('\n');
  }
}
