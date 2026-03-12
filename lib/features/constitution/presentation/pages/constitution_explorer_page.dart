import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class ConstitutionExplorerPage extends ConsumerStatefulWidget {
  const ConstitutionExplorerPage({super.key});

  @override
  ConsumerState<ConstitutionExplorerPage> createState() => _ConstitutionExplorerPageState();
}

class _ConstitutionExplorerPageState extends ConsumerState<ConstitutionExplorerPage> {
  final _searchController = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final query = _searchController.text.trim();
      final response = await dio.get(
        query.isEmpty ? '/constitution/articles' : '/constitution/search',
        queryParameters: {
          if (query.isNotEmpty) 'q': query,
          'limit': 50,
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

  Future<void> _openArticle(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/constitution/articles/$id',
        options: Options(headers: authHeaders(ref)),
      );

      final article = (response.data as Map).cast<String, dynamic>();
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('المادة ${article['articleNumber'] ?? '-'}'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((article['title'] ?? '').toString().isNotEmpty)
                    Text(
                      (article['title'] ?? '').toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 8),
                  Text((article['text'] ?? '').toString()),
                  const SizedBox(height: 12),
                  Text('الفصل: ${(article['chapter'] ?? '-').toString()}'),
                  Text('القسم: ${(article['section'] ?? '-').toString()}'),
                  const SizedBox(height: 10),
                  Text(
                    'مخرجات AI المتعلقة بالمادة هي اقتراحات أولية وتحتاج مراجعة قانونية بشرية.',
                    style: Theme.of(context).textTheme.bodySmall,
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
            title: 'Constitution Explorer',
            subtitle: 'Structured Iraqi constitution knowledge module',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadArticles(),
                  decoration: const InputDecoration(
                    hintText: 'ابحث برقم المادة أو كلمات دستورية',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _loading ? null : _loadArticles,
                icon: const Icon(Icons.search_rounded),
                label: Text(context.tr('Search Articles')),
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
                        ? const Text('لا توجد مواد مطابقة.')
                        : Column(
                            children: _items.map((item) {
                              final id = (item['_id'] ?? '').toString();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: id.isEmpty ? null : () => _openArticle(id),
                                leading: const Icon(Icons.gavel_rounded),
                                title: Text(
                                  'المادة ${(item['articleNumber'] ?? '-').toString()} - ${(item['title'] ?? '').toString()}',
                                ),
                                subtitle: Text((item['text'] ?? '').toString()),
                                isThreeLine: true,
                                trailing: const Icon(Icons.open_in_new_rounded),
                              );
                            }).toList(),
                          ),
          ),
        ],
      ),
    );
  }
}
