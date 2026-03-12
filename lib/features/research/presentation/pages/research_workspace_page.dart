import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class ResearchWorkspacePage extends StatelessWidget {
  const ResearchWorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Research Workspace',
            subtitle: 'Constitution, laws, and decision search with pinned citations',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.tr('Search laws, constitution, and decisions'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_alt_rounded),
                label: Text(context.tr('Filters')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Search Results'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(8, (index) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_rounded),
                          title: Text(
                            context.tr('Legal result {index}', {'index': '${index + 1}'}),
                          ),
                          subtitle: Text(
                            context.tr('Snippet + relevance reason + linked authorities'),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.push_pin_outlined),
                            onPressed: () {},
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Pinned Citations'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _pin(context, 'Constitution Article 19'),
                          _pin(context, 'Law 40 / Article 12'),
                          _pin(context, 'Decision D-2231'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Compare Mode'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(context.tr('Split panel for law + decision + notes')),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.compare_arrows_rounded),
                            label: Text(context.tr('Open Compare')),
                          ),
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

  Widget _pin(BuildContext context, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.bookmark_rounded, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(context.tr(value))),
        ],
      ),
    );
  }
}
