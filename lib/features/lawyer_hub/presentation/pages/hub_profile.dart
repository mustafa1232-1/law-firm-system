import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class LawyerHubPage extends StatelessWidget {
  const LawyerHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Lawyer Intelligence Hub',
            subtitle: 'Active cases, hearings, tasks, and recommended authorities',
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _panel(
                      context,
                      'My Active Cases',
                      ['C-3201 Contract dispute', 'C-3208 Execution file'],
                    ),
                    const SizedBox(height: 12),
                    _panel(
                      context,
                      'Upcoming Hearings',
                      ['09:30 Karkh Court', '11:45 Appeal Court'],
                    ),
                    const SizedBox(height: 12),
                    _panel(
                      context,
                      'Missing Documents',
                      ['Case C-3201: official notice missing'],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Recommended Authorities'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      _authorityRow(
                        context,
                        'Constitutional',
                        'Article 19',
                        'Linked to 2 open cases',
                      ),
                      _authorityRow(
                        context,
                        'Statutory',
                        'Evidence Law Article 7',
                        'Proof pattern match',
                      ),
                      _authorityRow(context, 'Decision', 'Cassation D-9981', 'Similarity 0.78'),
                      _authorityRow(
                        context,
                        'Saved memo',
                        'Jurisdiction objections note',
                        'Research folder: commercial',
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

  Widget _panel(BuildContext context, String title, List<String> lines) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(title), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('- ${context.tr(line)}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authorityRow(BuildContext context, String group, String value, String note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr(group), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(context.tr(value)),
              ],
            ),
          ),
          Text(context.tr(note), style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
