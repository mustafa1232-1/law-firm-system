import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/action_feedback.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class LawsExplorerPage extends StatelessWidget {
  const LawsExplorerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'Iraqi Laws Explorer',
      description: 'Law documents, articles, amendments, and legal classification',
      highlights: const [
        'Law title, number, year, and issuing body',
        'Indexed article text and category taxonomy',
        'Cross-linking with constitution and decisions',
      ],
      trailing: ElevatedButton.icon(
        onPressed: () => showFeatureInProgress(context, 'تصفح القوانين'),
        icon: const Icon(Icons.library_books_rounded),
        label: Text(context.tr('Browse Laws')),
      ),
    );
  }
}
