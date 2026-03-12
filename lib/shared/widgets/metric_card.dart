import 'package:flutter/material.dart';
import '../../theme/lexiq_colors.dart';
import '../../core/localization/app_translations.dart';
import 'glass_panel.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.delta,
    this.positive = true,
  });

  final String title;
  final String value;
  final String delta;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(title), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 18,
                color: positive ? LexiqColors.emeraldJustice : LexiqColors.crimsonAlert,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr(delta),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: positive ? LexiqColors.emeraldJustice : LexiqColors.crimsonAlert,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
