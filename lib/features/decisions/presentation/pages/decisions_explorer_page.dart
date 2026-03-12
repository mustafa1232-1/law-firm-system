import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class DecisionsExplorerPage extends ConsumerStatefulWidget {
  const DecisionsExplorerPage({super.key});

  @override
  ConsumerState<DecisionsExplorerPage> createState() => _DecisionsExplorerPageState();
}

class _DecisionsExplorerPageState extends ConsumerState<DecisionsExplorerPage> {
  final _queryController = TextEditingController();
  final _courtController = TextEditingController();
  final _domainController = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _courtController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/decisions/search',
        queryParameters: {
          'q': _queryController.text.trim().isEmpty ? 'قرار' : _queryController.text.trim(),
          if (_courtController.text.trim().isNotEmpty) 'court': _courtController.text.trim(),
          if (_domainController.text.trim().isNotEmpty) 'legalDomain': _domainController.text.trim(),
          'limit': 30,
        },
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final items = ((data['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = parseApiError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openDecision(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/decisions/$id', options: Options(headers: authHeaders(ref)));
      final decision = (response.data as Map).cast<String, dynamic>();
      final similar = ((decision['similarDecisions'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${(decision['courtName'] ?? '-').toString()} - ${(decision['decisionNumber'] ?? '-').toString()}'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التاريخ: ${(decision['decisionDate'] ?? '').toString().split('T').first}'),
                  Text('المجال: ${(decision['legalDomain'] ?? '-').toString()}'),
                  const SizedBox(height: 10),
                  Text((decision['summary'] ?? '').toString()),
                  const SizedBox(height: 10),
                  if ((decision['fullText'] ?? '').toString().isNotEmpty)
                    Text((decision['fullText'] ?? '').toString()),
                  const SizedBox(height: 10),
                  Text('المواد القانونية: ${((decision['legalArticleReferences'] as List?) ?? const []).join(', ')}'),
                  Text('المواد الدستورية: ${((decision['constitutionalReferences'] as List?) ?? const []).join(', ')}'),
                  const SizedBox(height: 12),
                  const Text('قرارات مشابهة'),
                  const SizedBox(height: 8),
                  if (similar.isEmpty)
                    const Text('لا توجد قرارات مشابهة.')
                  else
                    ...similar.map(
                      (entry) => Text(
                        '- ${(entry['decisionNumber'] ?? '-').toString()} | ${(entry['courtName'] ?? '-').toString()} | ${(entry['decisionDate'] ?? '').toString().split('T').first}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('Close')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Judicial Decisions Explorer',
            subtitle: 'Decision search, filters, similarity, and authority linking',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _queryController,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: 'ابحث في القرارات القضائية',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _courtController,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(labelText: 'المحكمة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _domainController,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(labelText: 'المجال القانوني'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search_rounded),
                label: Text(context.tr('Search')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Text(_error!)
                    : _items.isEmpty
                        ? const Text('لا توجد قرارات مطابقة.')
                        : Column(
                            children: _items.map((item) {
                              final id = (item['_id'] ?? '').toString();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: id.isEmpty ? null : () => _openDecision(id),
                                leading: const Icon(Icons.account_balance_rounded),
                                title: Text(
                                  '${(item['courtName'] ?? '-').toString()} - ${(item['decisionNumber'] ?? '-').toString()}',
                                ),
                                subtitle: Text(
                                  '${(item['summary'] ?? '').toString()}\n${(item['relevanceReason'] ?? '').toString()}',
                                ),
                                isThreeLine: true,
                                trailing: Text((item['decisionDate'] ?? '').toString().split('T').first),
                              );
                            }).toList(),
                          ),
          ),
        ],
      ),
    );
  }
}
