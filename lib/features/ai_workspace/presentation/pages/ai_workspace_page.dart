import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class AiWorkspacePage extends StatelessWidget {
  const AiWorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'AI Legal Workspace',
            subtitle: 'Grounded legal research and case analysis',
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              children: [
                TextField(
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: context.tr('Describe the case facts or ask a legal question'),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToggleChip(label: 'Search Constitution', selected: true),
                    _ToggleChip(label: 'Search Laws', selected: true),
                    _ToggleChip(label: 'Search Decisions', selected: true),
                    _ToggleChip(label: 'Only Firm Knowledge', selected: false),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.save_alt_rounded),
                        label: Text(context.tr('Save Analysis')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.article_rounded),
                        label: Text(context.tr('Convert to Memo')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Results'), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(context.tr('Citation-aware grounded answer appears here.')),
                      const SizedBox(height: 10),
                      Text(
                        context.tr(
                          'AI output is preliminary and must be reviewed by a licensed lawyer.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LexiqColors.brassGold),
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
                            context.tr('Confidence'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(value: 0.68),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('68% based on indexed coverage and matching citations'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Suggested Authorities'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _authority(context, 'Constitution Article 19'),
                          _authority(context, 'Civil Law Article 112'),
                          _authority(context, 'Decision D-9821'),
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

  Widget _authority(BuildContext context, String item) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr(item)),
      trailing: const Icon(Icons.push_pin_outlined),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(context.tr(label)),
      onSelected: (_) {},
    );
  }
}
