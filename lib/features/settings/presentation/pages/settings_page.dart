import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Settings',
            subtitle: 'Localization, export templates, storage, and AI settings',
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Interface Language'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      selected: locale.languageCode == 'ar',
                      label: Text(context.tr('Arabic')),
                      onSelected: (_) => ref.read(localeProvider.notifier).state = const Locale('ar', 'IQ'),
                    ),
                    ChoiceChip(
                      selected: locale.languageCode == 'en',
                      label: Text(context.tr('English')),
                      onSelected: (_) => ref.read(localeProvider.notifier).state = const Locale('en'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const GlassPanel(
            child: _SettingsHighlights(),
          ),
        ],
      ),
    );
  }
}

class _SettingsHighlights extends StatelessWidget {
  const _SettingsHighlights();

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      'Arabic-first RTL configuration',
      'PDF and Word export defaults',
      'Provider and integration setup',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('Core Capabilities'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.settings_suggest_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr(item))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
