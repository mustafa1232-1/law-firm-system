import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class CasesPage extends StatelessWidget {
  const CasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Case Management',
            subtitle: 'Case operations linked to laws, constitution, and decisions',
            trailing: ElevatedButton.icon(
              onPressed: () => context.go('/cases/new'),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('New Case')),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: InputDecoration(
              hintText: context.tr('Search by case number, title, or court'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: DataTable(
              columnSpacing: 18,
              headingTextStyle: Theme.of(context).textTheme.titleSmall,
              columns: [
                DataColumn(label: Text(context.tr('Case No.'))),
                DataColumn(label: Text(context.tr('Title'))),
                DataColumn(label: Text(context.tr('Type'))),
                DataColumn(label: Text(context.tr('Court'))),
                DataColumn(label: Text(context.tr('Status'))),
                DataColumn(label: Text(context.tr('Risk'))),
              ],
              rows: List.generate(6, (index) {
                final risk = [24, 45, 61, 32, 73, 54][index];
                return DataRow(
                  onSelectChanged: (_) => context.go('/cases/case_${index + 1}'),
                  cells: [
                    DataCell(Text('C-${3200 + index}')),
                    DataCell(
                      Text(context.tr('Case file {index}', {'index': '${index + 1}'})),
                    ),
                    DataCell(Text(context.tr(index.isEven ? 'Commercial' : 'Civil'))),
                    DataCell(Text(context.tr('Baghdad Court'))),
                    DataCell(Text(context.tr(index.isEven ? 'Active' : 'Review'))),
                    DataCell(
                      Text(
                        '$risk%',
                        style: TextStyle(
                          color: risk >= 60 ? LexiqColors.crimsonAlert : LexiqColors.emeraldJustice,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
