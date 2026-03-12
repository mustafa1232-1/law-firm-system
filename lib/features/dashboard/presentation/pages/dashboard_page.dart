import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/metric_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      const MetricCard(title: 'Active Cases', value: '128', delta: '+12 this month'),
      const MetricCard(title: 'Hearings This Week', value: '34', delta: '+5', positive: true),
      const MetricCard(title: 'Overdue Tasks', value: '7', delta: 'Needs action', positive: false),
      const MetricCard(title: 'Billing Collected', value: 'IQD 42M', delta: '+18%'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Executive Legal Dashboard',
            subtitle: 'Firm operations, litigation activity, and intelligence insights',
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
            ),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              return cards[index]
                  .animate(delay: (index * 80).ms)
                  .fade(duration: 400.ms)
                  .slideY(begin: 0.12);
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Hearing Timeline'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ..._timelineItems().map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(context.tr(item.title))),
                              Text(item.time, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Legal Alerts'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      _alertTile(
                        context,
                        'Missing document in commercial case',
                        'Main contract and formal notice are missing',
                        LexiqColors.crimsonAlert,
                      ),
                      const SizedBox(height: 10),
                      _alertTile(
                        context,
                        'New constitutional relation detected',
                        'Possible relation with Article 19',
                        LexiqColors.brassGold,
                      ),
                      const SizedBox(height: 10),
                      _alertTile(
                        context,
                        'Risk score increased',
                        'Case C-4432 requires stronger evidence',
                        LexiqColors.emeraldJustice,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alertTile(BuildContext context, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr(title), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(context.tr(subtitle), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineEntry> _timelineItems() {
    return const [
      _TimelineEntry('Evidence hearing - Karkh Court', '09:30', LexiqColors.imperialBlue),
      _TimelineEntry('Pleading hearing - Appeal Court', '11:45', LexiqColors.brassGold),
      _TimelineEntry('Execution follow-up', '13:00', LexiqColors.emeraldJustice),
      _TimelineEntry('Memo drafting session', '16:30', LexiqColors.slateGray),
    ];
  }
}

class _TimelineEntry {
  const _TimelineEntry(this.title, this.time, this.color);

  final String title;
  final String time;
  final Color color;
}
