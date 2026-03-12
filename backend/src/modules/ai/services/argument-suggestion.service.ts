import { Injectable } from '@nestjs/common';
import { RetrievalResult } from './retrieval.service';

@Injectable()
export class ArgumentSuggestionService {
  build(input: { narrative: string; authorities: RetrievalResult[] }) {
    const primary = [
      'تحديد الوصف القانوني الصحيح للوقائع محل النزاع.',
      'إبراز رابطة السببية بين الفعل والنتيجة القانونية.',
      'الاستناد إلى نصوص قانونية متسقة مع موضوع المطالبة.',
    ];

    const counter = [
      'الدفع بعدم كفاية الإثبات أمام عبء الإثبات القانوني.',
      'الدفع بانتفاء الصفة أو المصلحة في الدعوى.',
      'الدفع بوجود تعارض جوهري في سرد الوقائع.',
    ];

    const checklist = [
      'مراجعة التسلسل الزمني للوقائع قبل الجلسة.',
      'مراجعة المستندات الأساسية وربطها بالدفوع.',
      'تحضير ردود موجزة على الدفوع المتوقعة من الخصم.',
    ];

    return {
      facts: input.narrative.slice(0, 280),
      legalIssues: [
        'تحديد الوصف القانوني للواقعة',
        'مدى كفاية عبء الإثبات',
        'سلامة الإجراءات القضائية',
      ],
      authorities: input.authorities.slice(0, 6),
      arguments: primary,
      counterArguments: counter,
      reliefSought: 'الطلبات القضائية وفق ما يثبت من وقائع',
      hearingChecklist: checklist,
    };
  }
}
