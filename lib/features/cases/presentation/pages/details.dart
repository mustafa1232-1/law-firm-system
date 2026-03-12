import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class CaseDetailsPage extends StatelessWidget {
  const CaseDetailsPage({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: context.tr('Case Details | {caseId}', {'caseId': caseId}),
            subtitle: 'Case Genome, timeline, evidence, and AI suggestions',
            trailing: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(context.tr('Analyze')),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Timeline'), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...List.generate(
                        5,
                        (index) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.timeline_rounded),
                          title: Text(
                            context.tr('Legal event {index}', {'index': '${index + 1}'}),
                          ),
                          subtitle: Text(context.tr('Procedural activity and notes.')),
                          trailing: Text('2026-0${index + 1}-1$index'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Evidence Checklist'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _check(context, 'Main contract', true),
                          _check(context, 'Formal notice', true),
                          _check(context, 'Expert report', false),
                          _check(context, 'Ownership document', false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('AI Suggestions'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _hint(context, 'Constitution article', 'Article 19 (right to litigation)'),
                          _hint(context, 'Legal article', 'Evidence law, burden of proof'),
                          _hint(context, 'Similar decision', 'Decision D-9821'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _check(BuildContext context, String label, bool value) {
    return CheckboxListTile(
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      onChanged: (_) {},
      title: Text(context.tr(label)),
    );
  }

  Widget _hint(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(title),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(context.tr(body)),
          ],
        ),
      ),
    );
  }
}
