import 'package:flutter/material.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderPage(
      title: 'Notifications Center',
      description: 'Legal alerts, case updates, hearing reminders, and AI notices',
      highlights: [
        'Unread/read workflow',
        'Priority levels (info/warning/critical)',
        'Deep linking to related entities',
      ],
    );
  }
}
