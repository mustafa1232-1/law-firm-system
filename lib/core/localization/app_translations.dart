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

    'Interface Language': 'لغة الواجهة',
    'Arabic': 'العربية',
    'English': 'الإنجليزية',
    'Core Capabilities': 'القدرات الأساسية',

    'Sign In': 'تسجيل الدخول',
    'Create Account': 'إنشاء حساب',
    'Create account': 'إنشاء حساب',
    'Access your LexIQ Iraq legal workspace.': 'ادخل إلى مساحة عملك القانونية في LexIQ Iraq.',
    'Email': 'البريد الإلكتروني',
    'Password': 'كلمة المرور',
    'Full name': 'الاسم الكامل',
    'Confirm password': 'تأكيد كلمة المرور',
    'Forgot password?': 'هل نسيت كلمة المرور؟',
    'Already have an account? Sign in': 'لديك حساب بالفعل؟ سجل الدخول',
    'Reset Password': 'إعادة تعيين كلمة المرور',
    'We will send a reset link to your email address.': 'سنرسل رابط إعادة التعيين إلى بريدك الإلكتروني.',
    'Send Link': 'إرسال الرابط',
    'Back to sign in': 'العودة لتسجيل الدخول',

    'New Case': 'قضية جديدة',
    'Search by case number, title, or court': 'ابحث برقم القضية أو العنوان أو المحكمة',
    'Case No.': 'رقم القضية',
    'Title': 'العنوان',
    'Type': 'النوع',
    'Court': 'المحكمة',
    'Status': 'الحالة',
    'Risk': 'المخاطر',
    'Close': 'إغلاق',
    'Back': 'رجوع',
    'Basic Info': 'بيانات أساسية',
    'Parties': 'الأطراف',
    'Facts': 'الوقائع',
    'Claims': 'المطالبات',
    'Documents': 'المستندات',
    'AI Initial Analysis': 'تحليل AI أولي',
    'Case Type': 'نوع القضية',
    'Case Details | {caseId}': 'تفاصيل القضية | {caseId}',
    'Analyze': 'تحليل',
    'Timeline': 'الخط الزمني',
    'Evidence Checklist': 'قائمة الأدلة',
    'AI Suggestions': 'اقتراحات الذكاء الاصطناعي',
    'Constitution article': 'مادة دستورية',
    'Legal article': 'مادة قانونية',
    'Similar decision': 'قرار مشابه',

    'Search laws, constitution, and decisions': 'ابحث في القوانين والدستور والقرارات',
    'Search': 'بحث',
    'Search Results': 'نتائج البحث',
    'Pinned Citations': 'الاستشهادات المثبتة',
    'Compare Mode': 'وضع المقارنة',
    'Split panel for law + decision + notes': 'عرض مقسم: قانون + قرار + ملاحظات',
    'Open Compare': 'فتح المقارنة',
    'Please enter search query first.': 'يرجى إدخال عبارة البحث أولاً.',
    'Pin at least two authorities to compare.': 'ثبّت مرجعين على الأقل لبدء المقارنة.',
    'No results yet. Start by typing a legal question or term.': 'لا توجد نتائج بعد. ابدأ بكتابة سؤال أو مصطلح قانوني.',
    'No pinned citations yet.': 'لا توجد استشهادات مثبتة بعد.',

    'Describe the case facts or ask a legal question': 'اكتب وقائع القضية أو سؤالك القانوني',
    'Please enter case facts or a legal question.': 'يرجى إدخال وقائع القضية أو السؤال القانوني.',
    'Enter content before converting to memo.': 'أدخل محتوى قبل التحويل إلى مذكرة.',
    'Run analysis first to save results.': 'شغّل التحليل أولاً قبل حفظ النتائج.',
    'Analysis has been saved in this session.': 'تم حفظ التحليل في الجلسة الحالية.',
    'Save Analysis': 'حفظ التحليل',
    'Run Analysis': 'تشغيل التحليل',
    'Convert to Memo': 'تحويل إلى مذكرة',
    'Draft Memo': 'مسودة مذكرة',
    'Results': 'النتائج',
    'Citation-aware grounded answer appears here.': 'ستظهر هنا إجابة موثقة بالاستشهادات المتاحة.',
    'AI output is preliminary and must be reviewed by a licensed lawyer.': 'مخرجات الذكاء الاصطناعي أولية ويجب مراجعتها من محامٍ مرخص.',
    'Confidence': 'مستوى الثقة',
    'Suggested Authorities': 'المرجعيات المقترحة',
    'No suggested authorities yet.': 'لا توجد مرجعيات مقترحة بعد.',
    'Extracted Issues': 'النقاط المستخرجة',
    'No extracted issues yet.': 'لا توجد نقاط مستخرجة بعد.',
    'Proposed Questions': 'الأسئلة المقترحة',
    'No proposed questions yet.': 'لا توجد أسئلة مقترحة بعد.',
    'Attached case ID': 'معرّف القضية المرتبطة',
    'Attached document IDs': 'معرّفات المستندات المرتبطة',
    'Search Constitution': 'البحث في الدستور',
    'Search Laws': 'البحث في القوانين',
    'Search Decisions': 'البحث في القرارات',
    'Only Firm Knowledge': 'معرفة الشركة فقط',

    'New Client': 'عميل جديد',
    'New Hearing': 'جلسة جديدة',
    'New Task': 'مهمة جديدة',
    'Upload Document': 'رفع مستند',
    'New Invoice': 'فاتورة جديدة',
    'Search Articles': 'بحث المواد',
    'Browse Laws': 'تصفح القوانين',
    'Ingest Decision': 'إدخال قرار',
    'RBAC': 'إدارة الصلاحيات',


    'Executive Legal Dashboard': 'لوحة الأداء القانوني التنفيذية',
    'Firm operations, litigation activity, and intelligence insights': 'عمليات المكتب ونشاط التقاضي ورؤى الذكاء القانوني',
    'Active Cases': 'القضايا النشطة',
    'Hearings This Week': 'جلسات هذا الأسبوع',
    'Overdue Tasks': 'مهام متأخرة',
    'Billing Collected': 'التحصيلات المالية',
    'Hearing Timeline': 'الخط الزمني للجلسات',
    'Legal Alerts': 'تنبيهات قانونية',

    'Case Management': 'إدارة القضايا',
    'Case operations linked to laws, constitution, and decisions': 'إدارة القضايا وربطها بالقوانين والدستور والقرارات',

    'Active cases, hearings, tasks, and recommended authorities': 'قضايا نشطة وجلسات ومهام ومرجعيات مقترحة',
    'Recommended Authorities': 'المرجعيات الموصى بها',

    'Client records, contacts, and legal engagement management': 'إدارة ملفات العملاء وجهات الاتصال والتكليفات القانونية',
    'Schedule hearings and track outcomes and next actions': 'جدولة الجلسات وتتبع النتائج والإجراءات التالية',
    'Assign tasks, due dates, priorities, and reminders': 'إسناد المهام والمواعيد والأولويات والتذكيرات',
    'Upload, OCR, extract entities, and archive document versions': 'رفع المستندات وOCR واستخراج الكيانات وأرشفة الإصدارات',
    'Fee agreements, invoices, payments, and client balances': 'اتفاقات الأتعاب والفواتير والمدفوعات وأرصدة العملاء',
    'Structured Iraqi constitution knowledge module': 'وحدة معرفة منظمة للدستور العراقي',
    'Law documents, articles, amendments, and legal classification': 'وثائق القوانين والمواد والتعديلات والتصنيف القانوني',
    'Decision search, filters, similarity, and authority linking': 'بحث القرارات والتصفية والتشابه وربط المرجعيات',
    'RBAC, ingestion review workflow, and firm administration': 'إدارة الأدوار ومراجعة الإدخال وإدارة الشركة',
    'Legal alerts, case updates, hearing reminders, and AI notices': 'تنبيهات قانونية وتحديثات القضايا وتذكيرات الجلسات وإشعارات الذكاء',
    'Localization, export templates, storage, and AI settings': 'إعدادات اللغة والتصدير والتخزين والذكاء الاصطناعي',
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
