import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../localization/app_translations.dart';
import '../localization/locale_provider.dart';

class LexiqApp extends ConsumerWidget {
  const LexiqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode.toLowerCase().startsWith('ar');

    return MaterialApp.router(
      title: 'LexIQ Iraq',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppTranslations.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.build(isArabic: isArabic),
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
