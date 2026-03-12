import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class DecisionsExplorerPage extends StatelessWidget {
  const DecisionsExplorerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'Judicial Decisions Explorer',
      description: 'Decision search, filters, similarity, and authority linking',
      highlights: const [
        'Court/date/number metadata and classification',
        'Extracted legal citations and references',
        'Save to case and research folder',
      ],
      trailing: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.cloud_upload_rounded),
        label: Text(context.tr('Ingest Decision')),
      ),
    );
  }
}
