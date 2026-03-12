import 'package:flutter/widgets.dart';

class AppTranslations {
  static const supportedLocales = <Locale>[
    Locale('ar', 'IQ'),
    Locale('en'),
  ];

  static String translate(
    Locale locale,
    String key, {
    Map<String, String> params = const {},
  }) {
    final useArabic = locale.languageCode.toLowerCase().startsWith('ar');
    var value = useArabic ? (_ar[key] ?? key) : (_en[key] ?? key);
    params.forEach((paramKey, paramValue) {
      value = value.replaceAll('{$paramKey}', paramValue);
    });
    return value;
  }

  static const _en = <String, String>{};

  static const _ar = <String, String>{
    'LexIQ Iraq': 'LexIQ Iraq',
    'Iraqi Legal Intelligence': 'الذكاء القانوني العراقي',
    'Iraqi Legal Intelligence Platform': 'منصة الذكاء القانوني العراقي',

    'Dashboard': 'لوحة التحكم',
    'Lawyer Hub': 'مركز المحامي',
    'Cases': 'القضايا',
    'Clients': 'العملاء',
    'Research': 'البحث',
    'Constitution': 'الدستور',
    'Laws': 'القوانين',
    'Decisions': 'القرارات',
    'AI Workspace': 'مساحة الذكاء الاصطناعي',
    'Hearings': 'الجلسات',
    'Tasks': 'المهام',
    'Documents': 'المستندات',
    'Billing': 'الفوترة',
    'Notifications': 'الإشعارات',
    'Admin': 'الإدارة',
    'Settings': 'الإعدادات',

    'Home Dashboard': 'لوحة القيادة',
    'Lawyer Intelligence Hub': 'مركز ذكاء المحامي',
    'Create New Case Wizard': 'معالج إنشاء قضية جديدة',
    'Case Details': 'تفاصيل القضية',
    'Hearings Calendar': 'تقويم الجلسات',
    'Tasks & Reminders': 'المهام والتذكيرات',
    'Documents / Archive': 'المستندات والأرشيف',
    'Billing & Fees': 'الأتعاب والفوترة',
    'Research Workspace': 'مساحة البحث القانوني',
    'Constitution Explorer': 'مستكشف الدستور',
    'Iraqi Laws Explorer': 'مستكشف القوانين العراقية',
    'Judicial Decisions Explorer': 'مستكشف القرارات القضائية',
    'AI Legal Workspace': 'مساحة الذكاء القانوني',
    'Notifications Center': 'مركز الإشعارات',
    'Admin Panel': 'لوحة الإدارة',

    'Core Capabilities': 'القدرات الأساسية',
    'Interface Language': 'لغة الواجهة',
    'Arabic': 'العربية',
    'English': 'الإنجليزية',

    'Sign In': 'تسجيل الدخول',
    'Access your LexIQ Iraq legal workspace.': 'ادخل إلى مساحة عملك القانونية في LexIQ Iraq.',
    'Email': 'البريد الإلكتروني',
    'Password': 'كلمة المرور',
    'Forgot password?': 'هل نسيت كلمة المرور؟',
    'Create account': 'إنشاء حساب',
    'Create Account': 'إنشاء حساب',
    'Full name': 'الاسم الكامل',
    'Confirm password': 'تأكيد كلمة المرور',
    'Already have an account? Sign in': 'لديك حساب بالفعل؟ سجّل الدخول',
    'Reset Password': 'إعادة تعيين كلمة المرور',
    'We will send a reset link to your email address.': 'سنرسل رابط إعادة التعيين إلى بريدك الإلكتروني.',
    'Send Link': 'إرسال الرابط',
    'Back to sign in': 'العودة إلى تسجيل الدخول',

    'Active Cases': 'القضايا النشطة',
    '+12 this month': '+12 هذا الشهر',
    'Hearings This Week': 'جلسات هذا الأسبوع',
    'Overdue Tasks': 'مهام متأخرة',
    'Needs action': 'تحتاج إجراء',
    'Billing Collected': 'المبالغ المحصّلة',
    'Executive Legal Dashboard': 'لوحة الأداء القانوني التنفيذية',
    'Firm operations, litigation activity, and intelligence insights':
        'عمليات المكتب ونشاط التقاضي ورؤى الذكاء القانوني',
    'Hearing Timeline': 'الخط الزمني للجلسات',
    'Legal Alerts': 'تنبيهات قانونية',
    'Missing document in commercial case': 'مستند مفقود في قضية تجارية',
    'Main contract and formal notice are missing': 'العقد الأساسي والإنذار الرسمي غير مرفقين',
    'New constitutional relation detected': 'تم رصد ارتباط دستوري جديد',
    'Possible relation with Article 19': 'احتمال الارتباط بالمادة 19',
    'Risk score increased': 'ارتفعت درجة المخاطر',
    'Case C-4432 requires stronger evidence': 'القضية C-4432 تحتاج أدلة أقوى',
    'Evidence hearing - Karkh Court': 'جلسة إثبات - محكمة الكرخ',
    'Pleading hearing - Appeal Court': 'جلسة مرافعة - محكمة الاستئناف',
    'Execution follow-up': 'متابعة تنفيذ',
    'Memo drafting session': 'جلسة إعداد مذكرة',

    'Case Management': 'إدارة القضايا',
    'Case operations linked to laws, constitution, and decisions':
        'إدارة القضايا المرتبطة بالقوانين والدستور والقرارات',
    'New Case': 'قضية جديدة',
    'Search by case number, title, or court': 'ابحث برقم الدعوى أو العنوان أو المحكمة',
    'Case No.': 'رقم الدعوى',
    'Title': 'العنوان',
    'Type': 'النوع',
    'Court': 'المحكمة',
    'Status': 'الحالة',
    'Risk': 'المخاطر',
    'Case file {index}': 'ملف قضية {index}',
    'Commercial': 'تجارية',
    'Civil': 'مدنية',
    'Baghdad Court': 'محكمة بغداد',
    'Active': 'نشطة',
    'Review': 'قيد المراجعة',

    'Basic info, parties, facts, claims, documents, AI analysis':
        'البيانات الأساسية والأطراف والوقائع والمطالبات والمستندات والتحليل الذكي',
    'Close': 'إغلاق',
    'Create': 'إنشاء',
    'Next': 'التالي',
    'Back': 'السابق',
    'Basic Info': 'بيانات أساسية',
    'Parties': 'الأطراف',
    'Facts': 'الوقائع',
    'Claims': 'المطالبات',
    'AI Initial Analysis': 'تحليل أولي بالذكاء الاصطناعي',
    'Case Number': 'رقم القضية',
    'Case Type': 'نوع القضية',
    'Client': 'العميل',
    'Opposite Party': 'الخصم',
    'Assigned Lawyers': 'المحامون المكلّفون',
    'Facts Summary': 'ملخص الوقائع',
    'Timeline Events': 'أحداث الخط الزمني',
    'Defenses': 'الدفوع',
    'Counter Arguments': 'الدفوع المضادة',
    'Upload Core Documents': 'رفع المستندات الأساسية',
    'Evidence Checklist': 'قائمة الأدلة',
    'Case Genome Suggestions': 'اقتراحات بصمة القضية',
    'Risk Snapshot': 'لقطة المخاطر',

    'Case Details | {caseId}': 'تفاصيل القضية | {caseId}',
    'Case Genome, timeline, evidence, and AI suggestions':
        'بصمة القضية والخط الزمني والأدلة واقتراحات الذكاء الاصطناعي',
    'Analyze': 'تحليل',
    'Timeline': 'الخط الزمني',
    'Legal event {index}': 'حدث قانوني {index}',
    'Procedural activity and notes.': 'نشاط إجرائي وملاحظات.',
    'Main contract': 'العقد الأساسي',
    'Formal notice': 'الإنذار الرسمي',
    'Expert report': 'تقرير الخبرة',
    'Ownership document': 'مستند الملكية',
    'AI Suggestions': 'اقتراحات الذكاء الاصطناعي',
    'Constitution article': 'مادة دستورية',
    'Article 19 (right to litigation)': 'المادة 19 (حق التقاضي)',
    'Legal article': 'مادة قانونية',
    'Evidence law, burden of proof': 'قانون الإثبات، عبء الإثبات',
    'Similar decision': 'قرار مشابه',

    'Active cases, hearings, tasks, and recommended authorities':
        'القضايا النشطة والجلسات والمهام والمرجعيات المقترحة',
    'My Active Cases': 'قضاياي النشطة',
    'Upcoming Hearings': 'الجلسات القادمة',
    'Missing Documents': 'مستندات ناقصة',
    'Recommended Authorities': 'المرجعيات الموصى بها',
    'C-3201 Contract dispute': 'C-3201 نزاع عقد',
    'C-3208 Execution file': 'C-3208 ملف تنفيذ',
    '09:30 Karkh Court': '09:30 محكمة الكرخ',
    '11:45 Appeal Court': '11:45 محكمة الاستئناف',
    'Case C-3201: official notice missing': 'القضية C-3201: الإنذار الرسمي مفقود',
    'Constitutional': 'دستوري',
    'Article 19': 'المادة 19',
    'Linked to 2 open cases': 'مرتبط بقضيتين مفتوحتين',
    'Statutory': 'قانوني',
    'Evidence Law Article 7': 'قانون الإثبات المادة 7',
    'Proof pattern match': 'تطابق مع نمط الإثبات',
    'Decision': 'قرار',
    'Cassation D-9981': 'تمييز D-9981',
    'Similarity 0.78': 'تشابه 0.78',
    'Saved memo': 'مذكرة محفوظة',
    'Jurisdiction objections note': 'ملاحظة دفوع الاختصاص',
    'Research folder: commercial': 'مجلد بحث: تجاري',

    'Constitution, laws, and decision search with pinned citations':
        'البحث في الدستور والقوانين والقرارات مع تثبيت الاستشهادات',
    'Search laws, constitution, and decisions': 'ابحث في القوانين والدستور والقرارات',
    'Filters': 'تصفية',
    'Search Results': 'نتائج البحث',
    'Legal result {index}': 'نتيجة قانونية {index}',
    'Snippet + relevance reason + linked authorities': 'مقتطف + سبب الصلة + المراجع المرتبطة',
    'Pinned Citations': 'الاستشهادات المثبتة',
    'Constitution Article 19': 'المادة 19 من الدستور',
    'Law 40 / Article 12': 'القانون 40 / المادة 12',
    'Decision D-2231': 'القرار D-2231',
    'Compare Mode': 'وضع المقارنة',
    'Split panel for law + decision + notes': 'لوحة مقسمة للقانون + القرار + الملاحظات',
    'Open Compare': 'فتح المقارنة',

    'Grounded legal research and case analysis': 'بحث قانوني وتحليل قضايا مستند إلى مصادر',
    'Describe the case facts or ask a legal question': 'اكتب وقائع القضية أو اطرح سؤالًا قانونيًا',
    'Search Constitution': 'البحث في الدستور',
    'Search Laws': 'البحث في القوانين',
    'Search Decisions': 'البحث في القرارات',
    'Only Firm Knowledge': 'معرفة المكتب فقط',
    'Save Analysis': 'حفظ التحليل',
    'Convert to Memo': 'تحويل إلى مذكرة',
    'Results': 'النتائج',
    'Citation-aware grounded answer appears here.':
        'ستظهر هنا إجابة مؤسَّسة على الاستشهادات المتاحة.',
    'AI output is preliminary and must be reviewed by a licensed lawyer.':
        'مخرجات الذكاء الاصطناعي أولية وتحتاج مراجعة محامٍ مجاز.',
    'Confidence': 'مستوى الثقة',
    '68% based on indexed coverage and matching citations':
        '68% بناءً على تغطية الفهرسة وتطابق الاستشهادات',
    'Suggested Authorities': 'المرجعيات المقترحة',
    'Civil Law Article 112': 'القانون المدني المادة 112',
    'Decision D-9821': 'القرار D-9821',

    'Client records, contacts, and legal engagement management':
        'إدارة ملفات العملاء وجهات الاتصال والتكليفات القانونية',
    'Client profile and contact management': 'إدارة ملف العميل وبيانات الاتصال',
    'Case, invoice, and document linkage': 'ربط العميل بالقضايا والفواتير والمستندات',
    'Fast filtering and search': 'تصفية وبحث سريعان',
    'New Client': 'عميل جديد',

    'Schedule hearings and track outcomes and next actions':
        'جدولة الجلسات وتتبع النتائج والإجراءات اللاحقة',
    'Hearing date, court, room, and judge': 'تاريخ الجلسة والمحكمة والقاعة والقاضي',
    'Required documents checklist': 'قائمة المستندات المطلوبة',
    'Outcome and next action tracking': 'متابعة نتيجة الجلسة والإجراء التالي',
    'New Hearing': 'جلسة جديدة',

    'Assign tasks, due dates, priorities, and reminders':
        'إسناد المهام وتواريخ الاستحقاق والأولويات والتذكيرات',
    'Case-linked task assignment': 'إسناد مهام مرتبطة بالقضايا',
    'Priority and status workflow': 'مسار الأولوية والحالة',
    'Comments and reminder timeline': 'التعليقات والخط الزمني للتذكيرات',
    'New Task': 'مهمة جديدة',

    'Upload, OCR, extract entities, and archive document versions':
        'رفع المستندات وOCR واستخراج الكيانات وأرشفة الإصدارات',
    'PDF, Word, image, and evidence file support':
        'دعم PDF وWord والصور وملفات الأدلة',
    'Text extraction, summarization, and legal references detection':
        'استخراج النص والتلخيص واكتشاف المراجع القانونية',
    'Case linkage and access permissions': 'ربط بالقضايا وصلاحيات الوصول',
    'Upload Document': 'رفع مستند',

    'Fee agreements, invoices, payments, and client balances':
        'اتفاقيات الأتعاب والفواتير والمدفوعات وأرصدة العملاء',
    'Invoice and payment records': 'سجلات الفواتير والمدفوعات',
    'Due reminders and expense tracking': 'تذكيرات الاستحقاق وتتبع المصروفات',
    'Printable billing exports': 'تصدير فوترة قابل للطباعة',
    'New Invoice': 'فاتورة جديدة',

    'Structured Iraqi constitution knowledge module': 'وحدة معرفة منظمة للدستور العراقي',
    'Chapters, sections, and searchable articles': 'أبواب وفصول ومواد قابلة للبحث',
    'Pin article to case and add lawyer notes': 'تثبيت المادة على قضية وإضافة ملاحظات المحامي',
    'AI constitutional relevance suggestions with disclaimer':
        'اقتراحات صلة دستورية بالذكاء الاصطناعي مع تنبيه قانوني',
    'Search Articles': 'بحث في المواد',

    'Law documents, articles, amendments, and legal classification':
        'وثائق القوانين والمواد والتعديلات والتصنيف القانوني',
    'Law title, number, year, and issuing body': 'عنوان القانون ورقمه وسنته وجهة الإصدار',
    'Indexed article text and category taxonomy': 'نصوص مواد مفهرسة وتصنيف موضوعي',
    'Cross-linking with constitution and decisions': 'ربط متبادل مع الدستور والقرارات',
    'Browse Laws': 'تصفح القوانين',

    'Decision search, filters, similarity, and authority linking':
        'بحث القرارات والتصفية والتشابه وربط المرجعيات',
    'Court/date/number metadata and classification': 'بيانات المحكمة والتاريخ والرقم والتصنيف',
    'Extracted legal citations and references': 'الاستشهادات والمراجع القانونية المستخرجة',
    'Save to case and research folder': 'حفظ إلى القضية ومجلد البحث',
    'Ingest Decision': 'إدخال قرار',

    'Legal alerts, case updates, hearing reminders, and AI notices':
        'تنبيهات قانونية وتحديثات القضايا وتذكيرات الجلسات وإشعارات الذكاء الاصطناعي',
    'Unread/read workflow': 'سير عمل غير المقروء/المقروء',
    'Priority levels (info/warning/critical)': 'مستويات أولوية (معلومة/تحذير/حرج)',
    'Deep linking to related entities': 'روابط مباشرة للكيانات المرتبطة',

    'RBAC, ingestion review workflow, and firm administration':
        'RBAC وسير مراجعة الإدخال وإدارة المكتب',
    'Roles and permissions management': 'إدارة الأدوار والصلاحيات',
    'Ingestion review queue controls': 'التحكم بطابور مراجعة الإدخال',
    'Policy and firm configuration': 'السياسات وإعدادات المكتب',
    'RBAC': 'RBAC',

    'Localization, export templates, storage, and AI settings':
        'اللغة وقوالب التصدير والتخزين وإعدادات الذكاء الاصطناعي',
    'Arabic-first RTL configuration': 'تهيئة عربية أولًا مع اتجاه RTL',
    'PDF and Word export defaults': 'إعدادات افتراضية لتصدير PDF وWord',
    'Provider and integration setup': 'إعداد المزودات والتكاملات',
  };
}

extension AppTranslationBuildContext on BuildContext {
  String tr(
    String key, [
    Map<String, String> params = const {},
  ]) {
    return AppTranslations.translate(Localizations.localeOf(this), key, params: params);
  }
}
