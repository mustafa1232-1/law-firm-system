import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

final _caseSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final _casesListProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final token = ref.read(accessTokenProvider);
  final q = ref.watch(_caseSearchProvider);
  final response = await dio.get(
    '/cases',
    queryParameters: {if (q.isNotEmpty) 'q': q},
    options: Options(
      headers: token == null ? const <String, String>{} : {'Authorization': 'Bearer $token'},
    ),
  );

  return (response.data as Map).cast<String, dynamic>();
});

class CasesPage extends ConsumerStatefulWidget {
  const CasesPage({super.key});

  @override
  ConsumerState<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends ConsumerState<CasesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    ref.read(_caseSearchProvider.notifier).state = _searchController.text.trim();
    ref.invalidate(_casesListProvider);
  }

  Future<void> _refresh() async {
    ref.invalidate(_casesListProvider);
    await ref.read(_casesListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final asyncCases = ref.watch(_casesListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Case Management',
            subtitle: 'Case operations linked to laws, constitution, and decisions',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => context.go('/cases/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.tr('New Case')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onSubmitted: (_) => _applySearch(),
            decoration: InputDecoration(
              hintText: context.tr('Search by case number, title, or court'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: _applySearch,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          GlassPanel(
            child: asyncCases.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(parseApiError(error)),
              ),
              data: (data) {
                final items = ((data['items'] as List?) ?? const []);
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('لا توجد قضايا بعد. أنشئ أول قضية من زر "قضية جديدة".'),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
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
                    rows: items.map<DataRow>((rawItem) {
                      final item = (rawItem as Map).cast<String, dynamic>();
                      final id = (item['_id'] ?? item['id']).toString();
                      final risk = (item['riskScore'] as num?)?.toInt() ?? 0;
                      final caseNumber = (item['caseNumber'] ?? '-').toString();
                      final title = (item['title'] ?? '-').toString();
                      final type = (item['caseType'] ?? '-').toString();
                      final court = (item['court'] ?? '-').toString();
                      final status = (item['status'] ?? '-').toString();

                      return DataRow(
                        onSelectChanged: (_) => context.go('/cases/$id'),
                        cells: [
                          DataCell(Text(caseNumber)),
                          DataCell(Text(title)),
                          DataCell(Text(type)),
                          DataCell(Text(court)),
                          DataCell(Text(status)),
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
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
