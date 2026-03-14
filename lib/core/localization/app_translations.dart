import 'package:flutter/widgets.dart';

class AppTranslations {
  static const supportedLocales = <Locale>[Locale('ar', 'IQ'), Locale('en')];

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
    'Logout': 'تسجيل الخروج',
    'User': 'مستخدم',

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
    'Constitution Article Reader': 'قارئ المادة الدستورية',
    'Iraqi Laws Explorer': 'مستكشف القوانين العراقية',
    'Law Reader': 'قارئ القانون',
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
    'Access your LexIQ Iraq legal workspace.':
        'ادخل إلى مساحة عملك القانونية في LexIQ Iraq.',
    'Email': 'البريد الإلكتروني',
    'Password': 'كلمة المرور',
    'Full name': 'الاسم الكامل',
    'Confirm password': 'تأكيد كلمة المرور',
    'Forgot password?': 'هل نسيت كلمة المرور؟',
    'Already have an account? Sign in': 'لديك حساب بالفعل؟ سجل الدخول',
    'Reset Password': 'إعادة تعيين كلمة المرور',
    'We will send a reset link to your email address.':
        'سنرسل رابط إعادة التعيين إلى بريدك الإلكتروني.',
    'Send Link': 'إرسال الرابط',
    'Back to sign in': 'العودة لتسجيل الدخول',
    'Use Email': 'استخدام الإيميل',
    'Use Phone': 'استخدام الهاتف',
    'Phone': 'الهاتف',
    'Phone number': 'رقم الهاتف',
    'Field is required': 'الحقل مطلوب',
    'Invalid email format': 'صيغة البريد الإلكتروني غير صحيحة',
    'Invalid phone number': 'رقم الهاتف غير صحيح',
    'Password is required': 'كلمة المرور مطلوبة',
    'Full name is required': 'الاسم الكامل مطلوب',
    'Email is required': 'البريد الإلكتروني مطلوب',
    'Phone number is required': 'رقم الهاتف مطلوب',
    'Password must be at least 8 characters':
        'يجب أن تكون كلمة المرور 8 أحرف على الأقل',
    'Passwords do not match': 'كلمتا المرور غير متطابقتين',
    'Register law firm': 'تسجيل شركة محاماة',
    'Register individual user': 'تسجيل مستخدم فردي',
    'Create firm account with admin profile and workforce data':
        'إنشاء حساب شركة مع ملف المدير وبيانات القوة العاملة',
    'Create standalone user account': 'إنشاء حساب مستخدم مستقل',
    'Firm name': 'اسم الشركة',
    'Firm name is required': 'اسم الشركة مطلوب',
    'Firm category': 'فئة الشركة',
    'Employee count': 'عدد الموظفين',
    'Enter valid employee count': 'أدخل عدد موظفين صحيح',
    'Please enter phone number.': 'يرجى إدخال رقم الهاتف.',
    'Please enter email.': 'يرجى إدخال البريد الإلكتروني.',
    'Password reset request sent successfully.':
        'تم إرسال طلب إعادة التعيين بنجاح.',
    'Request a reset code first.': 'اطلب رمز إعادة التعيين أولاً.',
    'Enter reset code.': 'أدخل رمز إعادة التعيين.',
    'Password reset completed.': 'تمت إعادة تعيين كلمة المرور بنجاح.',
    'Enter your phone to receive a reset code.':
        'أدخل رقم هاتفك لاستلام رمز إعادة التعيين.',
    'Enter your email to receive a reset code.':
        'أدخل بريدك الإلكتروني لاستلام رمز إعادة التعيين.',
    'Send reset code': 'إرسال رمز إعادة التعيين',
    'Reset code': 'رمز إعادة التعيين',
    'New password': 'كلمة المرور الجديدة',
    'Confirm new password': 'تأكيد كلمة المرور الجديدة',
    'Confirm reset': 'تأكيد إعادة التعيين',
    'Please enter email or phone.':
        'يرجى إدخال البريد الإلكتروني أو رقم الهاتف.',
    'Unexpected error while signing in.':
        'حدث خطأ غير متوقع أثناء تسجيل الدخول.',
    'Unable to create account right now.': 'تعذر إنشاء الحساب الآن.',
    'Company created, but auto sign-in failed. Please sign in manually.':
        'تم إنشاء الشركة لكن فشل تسجيل الدخول التلقائي. يرجى تسجيل الدخول يدويًا.',
    'Unable to create company account right now.':
        'تعذر إنشاء حساب الشركة الآن.',
    'Unable to reach the server. Check API URL and backend status.':
        'تعذر الاتصال بالخادم. تحقق من رابط الـ API وحالة الباك اند.',
    'Request failed. Please try again.':
        'فشل تنفيذ الطلب. يرجى المحاولة مجددًا.',

    'New Case': 'قضية جديدة',
    'Search by case number, title, or court':
        'ابحث برقم القضية أو العنوان أو المحكمة',
    'Case No.': 'رقم القضية',
    'Title': 'العنوان',
    'Type': 'النوع',
    'Court': 'المحكمة',
    'Status': 'الحالة',
    'Risk': 'المخاطر',
    'Close': 'إغلاق',
    'Back': 'رجوع',
    'Next': 'التالي',
    'Create': 'إنشاء',
    'Update': 'تحديث',
    'Basic Info': 'بيانات أساسية',
    'Parties': 'الأطراف',
    'Facts': 'الوقائع',
    'Claims': 'المطالبات',
    'AI Initial Analysis': 'تحليل AI أولي',
    'Case Type': 'نوع القضية',
    'Case Number': 'رقم القضية',
    'Internal Ref': 'المرجع الداخلي',
    'Governorate': 'المحافظة',
    'Summary': 'الملخص',
    'Facts Summary': 'ملخص الوقائع',
    'Evidence Checklist (one per line)': 'قائمة الأدلة (كل سطر عنصر)',
    'Optional AI context to run after opening case details':
        'سياق إضافي اختياري لتحليل AI بعد فتح تفاصيل القضية',
    'Client ID (optional)': 'معرّف العميل (اختياري)',
    'Opposite Party': 'الخصم المقابل',
    'Case Details | {caseId}': 'تفاصيل القضية | {caseId}',
    'Analyze': 'تحليل',
    'Pay': 'دفع',
    'all': 'الكل',
    'Timeline': 'الخط الزمني',
    'Evidence Checklist': 'قائمة الأدلة',
    'AI Suggestions': 'اقتراحات الذكاء الاصطناعي',
    'Constitution article': 'مادة دستورية',
    'Legal article': 'مادة قانونية',
    'Similar decision': 'قرار مشابه',

    'Search laws, constitution, and decisions':
        'ابحث في القوانين والدستور والقرارات',
    'Search': 'بحث',
    'Search Results': 'نتائج البحث',
    'Pinned Citations': 'الاستشهادات المثبتة',
    'Compare Mode': 'وضع المقارنة',
    'Split panel for law + decision + notes':
        'عرض مقسم: قانون + قرار + ملاحظات',
    'Open Compare': 'فتح المقارنة',
    'Please enter search query first.': 'يرجى إدخال عبارة البحث أولاً.',
    'Pin at least two authorities to compare.':
        'ثبّت مرجعين على الأقل لبدء المقارنة.',
    'No results yet. Start by typing a legal question or term.':
        'لا توجد نتائج بعد. ابدأ بكتابة سؤال أو مصطلح قانوني.',
    'No pinned citations yet.': 'لا توجد استشهادات مثبتة بعد.',

    'Describe the case facts or ask a legal question':
        'اكتب وقائع القضية أو سؤالك القانوني',
    'Please enter case facts or a legal question.':
        'يرجى إدخال وقائع القضية أو السؤال القانوني.',
    'Enter content before converting to memo.':
        'أدخل محتوى قبل التحويل إلى مذكرة.',
    'Run analysis first to save results.':
        'شغّل التحليل أولاً قبل حفظ النتائج.',
    'Analysis has been saved in this session.':
        'تم حفظ التحليل في الجلسة الحالية.',
    'Save Analysis': 'حفظ التحليل',
    'Run Analysis': 'تشغيل التحليل',
    'Convert to Memo': 'تحويل إلى مذكرة',
    'Draft Memo': 'مسودة مذكرة',
    'Results': 'النتائج',
    'Citation-aware grounded answer appears here.':
        'ستظهر هنا إجابة موثقة بالاستشهادات المتاحة.',
    'Grounded legal research and case analysis': 'بحث قانوني مؤسس وتحليل قضايا',
    'AI output is preliminary and must be reviewed by a licensed lawyer.':
        'مخرجات الذكاء الاصطناعي أولية ويجب مراجعتها من محامٍ مرخص.',
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
    'Read': 'مقروء',
    'Mark read': 'تعيين كمقروء',
    'New Notification': 'إشعار جديد',
    'info': 'معلومات',
    'warning': 'تحذير',
    'critical': 'حرج',

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
    'Firm operations, litigation activity, and intelligence insights':
        'عمليات المكتب ونشاط التقاضي ورؤى الذكاء القانوني',
    'Active Cases': 'القضايا النشطة',
    'Hearings This Week': 'جلسات هذا الأسبوع',
    'Overdue Tasks': 'مهام متأخرة',
    'Billing Collected': 'التحصيلات المالية',
    'Hearing Timeline': 'الخط الزمني للجلسات',
    'Legal Alerts': 'تنبيهات قانونية',

    'Case Management': 'إدارة القضايا',
    'Case operations linked to laws, constitution, and decisions':
        'إدارة القضايا وربطها بالقوانين والدستور والقرارات',
    'Basic info, client, evidence, and payment plan':
        'بيانات أساسية والعميل والأدلة وخطة الدفعات',
    'Case Genome, timeline, evidence, and AI suggestions':
        'جينوم القضية والخط الزمني والأدلة واقتراحات الذكاء الاصطناعي',

    'Active cases, hearings, tasks, and recommended authorities':
        'قضايا نشطة وجلسات ومهام ومرجعيات مقترحة',
    'Recommended Authorities': 'المرجعيات الموصى بها',

    'Client records, contacts, and legal engagement management':
        'إدارة ملفات العملاء وجهات الاتصال والتكليفات القانونية',
    'Schedule hearings and track outcomes and next actions':
        'جدولة الجلسات وتتبع النتائج والإجراءات التالية',
    'Assign tasks, due dates, priorities, and reminders':
        'إسناد المهام والمواعيد والأولويات والتذكيرات',
    'Upload, OCR, extract entities, and archive document versions':
        'رفع المستندات وOCR واستخراج الكيانات وأرشفة الإصدارات',
    'Fee agreements, invoices, payments, and client balances':
        'اتفاقات الأتعاب والفواتير والمدفوعات وأرصدة العملاء',
    'Structured Iraqi constitution knowledge module':
        'وحدة معرفة منظمة للدستور العراقي',
    'Law documents, articles, amendments, and legal classification':
        'وثائق القوانين والمواد والتعديلات والتصنيف القانوني',
    'Decision search, filters, similarity, and authority linking':
        'بحث القرارات والتصفية والتشابه وربط المرجعيات',
    'RBAC, ingestion review workflow, and firm administration':
        'إدارة الأدوار ومراجعة الإدخال وإدارة الشركة',
    'Legal alerts, case updates, hearing reminders, and AI notices':
        'تنبيهات قانونية وتحديثات القضايا وتذكيرات الجلسات وإشعارات الذكاء',
    'Localization, export templates, storage, and AI settings':
        'إعدادات اللغة والتصدير والتخزين والذكاء الاصطناعي',
  };
}

extension AppTranslationBuildContext on BuildContext {
  String tr(String key, [Map<String, String> params = const {}]) {
    return AppTranslations.translate(
      Localizations.localeOf(this),
      key,
      params: params,
    );
  }
}
