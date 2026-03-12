import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/action_feedback.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'Clients',
      description: 'Client records, contacts, and legal engagement management',
      highlights: const [
        'Client profile and contact management',
        'Case, invoice, and document linkage',
        'Fast filtering and search',
      ],
      trailing: ElevatedButton.icon(
        onPressed: () => showFeatureInProgress(context, 'إضافة عميل'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(context.tr('New Client')),
      ),
    );
  }
}
