import 'package:flutter/material.dart';
import '../../core/localization/app_translations.dart';

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 10),
            Text(context.tr(title), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(context.tr(message), style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
