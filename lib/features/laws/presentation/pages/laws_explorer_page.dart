import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class LawsExplorerPage extends ConsumerStatefulWidget {
  const LawsExplorerPage({super.key});

  @override
  ConsumerState<LawsExplorerPage> createState() => _LawsExplorerPageState();
}

class _LawsExplorerPageState extends ConsumerState<LawsExplorerPage> {
  final _searchController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _note;
  String _selectedCategory = 'الكل';
  int _totalLaws = 0;
  int _totalArticles = 0;

  List<Map<String, dynamic>> _laws = const [];
  List<Map<String, dynamic>> _articles = const [];

  static const _smartSearchExamples = <String>[
    'المادة 1',
    'تعويض الضرر',
    'الاختصاص القضائي',
    'قانون 40',
    'إثبات',
    'العقد والالتزام',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialLaws();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialLaws() async {
    setState(() {
      _loading = true;
      _error = null;
      _note = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/laws',
        queryParameters: const {'limit': 100, 'page': 1},
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final laws = ((data['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _laws = laws;
        _articles = const [];
        _totalLaws = (data['total'] as num?)?.toInt() ?? laws.length;
        _totalArticles = 0;
        _note = 'اكتب كلمة أو رقم مادة أو رقم قانون وسيعمل البحث الذكي تلقائيًا.';
      });
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

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      await _loadInitialLaws();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _note = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/laws/search',
        queryParameters: {'q': query, 'limit': 100, 'page': 1},
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final laws = ((data['laws'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final articles = ((data['articles'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _laws = laws;
        _articles = articles;
        _totalLaws = (data['totalLaws'] as num?)?.toInt() ?? laws.length;
        _totalArticles = (data['totalArticles'] as num?)?.toInt() ?? articles.length;
        _note = (data['note'] ?? '').toString().trim();
      });
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

  void _openLaw(String lawId) {
    context.go('/laws/$lawId');
  }

  void _openArticleFromSearch(Map<String, dynamic> article) {
    final articleId = (article['_id'] ?? article['id'])?.toString();
    if (articleId == null || articleId.isEmpty) {
      return;
    }

    final lawRef = article['lawId'];
    String? lawId;
    if (lawRef is Map) {
      lawId = (lawRef['_id'] ?? lawRef['id'])?.toString();
    } else if (lawRef is String) {
      lawId = lawRef;
    }

    if (lawId == null || lawId.isEmpty) {
      return;
    }
    context.go('/laws/$lawId/articles/$articleId');
  }

  String _categoryOfLaw(Map<String, dynamic> law) {
    final domain = (law['legalDomain'] ?? '').toString().trim();
    if (domain.isEmpty) {
      return 'غير مصنف';
    }
    return domain;
  }

  String? _lawId(Map<String, dynamic> law) {
    final id = law['_id'] ?? law['id'];
    if (id == null) {
      return null;
    }
    return id.toString();
  }

  List<Map<String, dynamic>> _filteredLaws() {
    if (_selectedCategory == 'الكل') {
      return _laws;
    }
    return _laws.where((law) => _categoryOfLaw(law) == _selectedCategory).toList();
  }

  List<Map<String, dynamic>> _filteredArticles(List<Map<String, dynamic>> filteredLaws) {
    if (_selectedCategory == 'الكل') {
      return _articles;
    }

    final lawIds = filteredLaws.map(_lawId).whereType<String>().toSet();
    if (lawIds.isEmpty) {
      return const [];
    }

    return _articles.where((article) {
      final lawRef = article['lawId'];
      if (lawRef is Map) {
        final refId = (lawRef['_id'] ?? lawRef['id'])?.toString();
        return refId != null && lawIds.contains(refId);
      }
      if (lawRef is String) {
        return lawIds.contains(lawRef);
      }
      return false;
    }).toList();
  }

  List<String> _availableCategories() {
    final values = <String>{'الكل'};
    for (final law in _laws) {
      values.add(_categoryOfLaw(law));
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  String _articleSnippet(Map<String, dynamic> article) {
    final value = (article['text'] ?? '').toString().replaceAll('\n', ' ').trim();
    if (value.length <= 220) {
      return value;
    }
    return '${value.substring(0, 220)}...';
  }

  @override
  Widget build(BuildContext context) {
    final filteredLaws = _filteredLaws();
    final filteredArticles = _filteredArticles(filteredLaws);
    final categories = _availableCategories();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'مستكشف القوانين العراقية',
              subtitle: 'بحث ذكي شامل في القوانين والمواد مع ترتيب النتائج حسب الصلة',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: 'ابحث بكلمة أو رقم مادة أو رقم قانون أو موضوع قانوني',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('بحث ذكي'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _loadInitialLaws,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة ضبط'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أمثلة بحث ذكي',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _smartSearchExamples
                        .map(
                          (example) => ActionChip(
                            label: Text(example),
                            onPressed: () {
                              _searchController.text = example;
                              _search();
                            },
                          ),
                        )
                        .toList(),
                  ),
                  if ((_note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _note!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: LexiqColors.slateGray,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('القوانين: $_totalLaws')),
                      Chip(label: Text('المواد: $_totalArticles')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تصنيف القوانين', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (category) => ChoiceChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (_) => setState(() => _selectedCategory = category),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              GlassPanel(child: Text(_error!))
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نتائج القوانين (${filteredLaws.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (filteredLaws.isEmpty)
                            const Text('لا توجد قوانين مطابقة لمعايير البحث الحالية.')
                          else
                            ...filteredLaws.map((law) {
                              final lawId = _lawId(law);
                              final category = _categoryOfLaw(law);
                              final reason = (law['relevanceReason'] ?? '').toString().trim();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: lawId == null ? null : () => _openLaw(lawId),
                                title: Text((law['title'] ?? '-').toString()),
                                subtitle: Text(
                                  'قانون ${(law['lawNumber'] ?? '-').toString()} / ${(law['year'] ?? '-').toString()}\n'
                                  'التصنيف: $category${reason.isEmpty ? '' : '\nسبب الصلة: $reason'}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.open_in_new_rounded),
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
                            'نتائج المواد (${filteredArticles.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (filteredArticles.isEmpty)
                            const Text('لا توجد مواد مطابقة لمعايير البحث الحالية.')
                          else
                            ...filteredArticles.map((article) {
                              final lawRef = article['lawId'];
                              final lawTitle = lawRef is Map
                                  ? (lawRef['title'] ?? '').toString()
                                  : '';
                              final reason = (article['relevanceReason'] ?? '').toString().trim();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: () => _openArticleFromSearch(article),
                                leading: const Icon(Icons.article_outlined),
                                title: Text(
                                  'المادة ${(article['articleNumber'] ?? '-').toString()}',
                                ),
                                subtitle: Text(
                                  '${lawTitle.isEmpty ? '' : '$lawTitle\n'}'
                                  '${_articleSnippet(article)}'
                                  '${reason.isEmpty ? '' : '\nسبب الصلة: $reason'}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.open_in_new_rounded),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
