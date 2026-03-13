import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      final endpoint = query.isEmpty ? '/constitution/articles' : '/constitution/search';
      final baseParams = <String, dynamic>{
        if (query.isNotEmpty) 'q': query,
        'limit': 100,
      };

      final firstResponse = await dio.get(
        endpoint,
        queryParameters: baseParams,
        options: Options(headers: authHeaders(ref)),
      );

      final firstData = (firstResponse.data as Map).cast<String, dynamic>();
      final total = ((firstData['total'] as num?) ?? 0).toInt();
      final items = ((firstData['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (query.isEmpty && total > items.length) {
        var page = 2;
        while (items.length < total) {
          final pageResponse = await dio.get(
            endpoint,
            queryParameters: {
              ...baseParams,
              'page': page,
            },
            options: Options(headers: authHeaders(ref)),
          );

          final pageData = (pageResponse.data as Map).cast<String, dynamic>();
          final pageItems = ((pageData['items'] as List?) ?? const [])
              .map((entry) => (entry as Map).cast<String, dynamic>())
              .toList();

          if (pageItems.isEmpty) {
            break;
          }
          items.addAll(pageItems);
          page += 1;
        }
      }

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

  void _openArticle(String id) {
    context.go('/constitution/articles/$id');
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
                              final text = (item['text'] ?? '').toString();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: id.isEmpty ? null : () => _openArticle(id),
                                leading: const Icon(Icons.gavel_rounded),
                                title: Text(
                                  'المادة ${(item['articleNumber'] ?? '-').toString()} - ${(item['title'] ?? '').toString()}',
                                ),
                                subtitle: Text(
                                  text.length > 220 ? '${text.substring(0, 220)}...' : text,
                                ),
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
