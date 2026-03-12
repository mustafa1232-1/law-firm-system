import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/action_feedback.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class ConstitutionExplorerPage extends StatelessWidget {
  const ConstitutionExplorerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'Constitution Explorer',
      description: 'Structured Iraqi constitution knowledge module',
      highlights: const [
        'Chapters, sections, and searchable articles',
        'Pin article to case and add lawyer notes',
        'AI constitutional relevance suggestions with disclaimer',
      ],
      trailing: ElevatedButton.icon(
        onPressed: () => showFeatureInProgress(context, 'بحث مواد الدستور'),
        icon: const Icon(Icons.find_in_page_rounded),
        label: Text(context.tr('Search Articles')),
      ),
    );
  }
}
