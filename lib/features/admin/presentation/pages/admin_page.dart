import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/action_feedback.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'Admin Panel',
      description: 'RBAC, ingestion review workflow, and firm administration',
      highlights: const [
        'Roles and permissions management',
        'Ingestion review queue controls',
        'Policy and firm configuration',
      ],
      trailing: ElevatedButton.icon(
        onPressed: () => showFeatureInProgress(context, 'إدارة الصلاحيات RBAC'),
        icon: const Icon(Icons.security_rounded),
        label: Text(context.tr('RBAC')),
      ),
    );
  }
}
