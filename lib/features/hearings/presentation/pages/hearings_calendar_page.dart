import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class HearingsCalendarPage extends StatelessWidget {
  const HearingsCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'Hearings Calendar',
      description: 'Schedule hearings and track outcomes and next actions',
      highlights: const [
        'Hearing date, court, room, and judge',
        'Required documents checklist',
        'Outcome and next action tracking',
      ],
      trailing: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_alert_rounded),
        label: Text(context.tr('New Hearing')),
      ),
    );
  }
}
