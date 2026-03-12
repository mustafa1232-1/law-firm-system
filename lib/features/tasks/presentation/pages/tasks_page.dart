import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/action_feedback.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'Tasks & Reminders',
      description: 'Assign tasks, due dates, priorities, and reminders',
      highlights: const [
        'Case-linked task assignment',
        'Priority and status workflow',
        'Comments and reminder timeline',
      ],
      trailing: ElevatedButton.icon(
        onPressed: () => showFeatureInProgress(context, 'إضافة مهمة'),
        icon: const Icon(Icons.playlist_add_check_rounded),
        label: Text(context.tr('New Task')),
      ),
    );
  }
}
