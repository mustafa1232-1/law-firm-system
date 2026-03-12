import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'Documents / Archive',
      description: 'Upload, OCR, extract entities, and archive document versions',
      highlights: const [
        'PDF, Word, image, and evidence file support',
        'Text extraction, summarization, and legal references detection',
        'Case linkage and access permissions',
      ],
      trailing: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(context.tr('Upload Document')),
      ),
    );
  }
}
