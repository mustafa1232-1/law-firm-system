import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _featuredReferences = <_LawReference>[
    _LawReference(
      title: 'Iraqi Civil Code No. 40 of 1951',
      sourceUrl:
          'http://jafbase.fr/docAsie/Irak/code%20civil%20irakien%201951.pdf',
      lawNumber: '40',
    ),
    _LawReference(
      title: 'Iraqi Penal Code No. 111 of 1969',
      sourceUrl:
          'https://www.rwi.uzh.ch/dam/jcr:00000000-0c03-6a0c-ffff-ffff96be3560/penalcode1969.pdf',
      lawNumber: '111',
    ),
    _LawReference(
      title:
          'Law of Discipline of State and Public Sector Employees No. 14 of 1991',
      sourceUrl: 'https://www.moj.gov.iq/upload/pdf/4466.pdf',
      lawNumber: '14',
    ),
  ];

  final _searchController = TextEditingController();

  bool _loading = false;
  String? _error;
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _laws = const [];
  List<Map<String, dynamic>> _articles = const [];

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

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reference URL copied')));
  }

  String _categoryOfLaw(Map<String, dynamic> law) {
    final domain = (law['legalDomain'] ?? '').toString().trim();
    if (domain.isEmpty) {
      return 'Other';
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
    if (_selectedCategory == 'All') {
      return _laws;
    }
    return _laws
        .where((law) => _categoryOfLaw(law) == _selectedCategory)
        .toList();
  }

  List<Map<String, dynamic>> _filteredArticles(
    List<Map<String, dynamic>> filteredLaws,
  ) {
    if (_selectedCategory == 'All') {
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
    final values = <String>{'All'};
    for (final law in _laws) {
      values.add(_categoryOfLaw(law));
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  Map<String, dynamic>? _findLawByNumber(String lawNumber) {
    for (final law in _laws) {
      if ((law['lawNumber'] ?? '').toString() == lawNumber) {
        return law;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filteredLaws = _filteredLaws();
    final filteredArticles = _filteredArticles(filteredLaws);
    final categories = _availableCategories();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Iraqi Laws Explorer',
            subtitle: 'Browse law documents and indexed legal articles',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: 'Search laws or legal text...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadInitialLaws,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reload'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Law Categories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map(
                        (category) => ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = category),
                        ),
                      )
                      .toList(),
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
                  'Official References',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ..._featuredReferences.map((reference) {
                  final linkedLaw = _findLawByNumber(reference.lawNumber);
                  final linkedLawId = linkedLaw == null
                      ? null
                      : _lawId(linkedLaw);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: LexiqColors.slateGray.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reference.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(reference.sourceUrl),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _copyUrl(reference.sourceUrl),
                              icon: const Icon(Icons.copy_all_rounded),
                              label: const Text('Copy URL'),
                            ),
                            if (linkedLawId != null)
                              ElevatedButton.icon(
                                onPressed: () => _openLaw(linkedLawId),
                                icon: const Icon(Icons.menu_book_rounded),
                                label: const Text('Open in App'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
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
                          'Laws (${filteredLaws.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (filteredLaws.isEmpty)
                          const Text(
                            'No laws matched the current filter/search.',
                          )
                        else
                          ...filteredLaws.map((law) {
                            final lawId = _lawId(law);
                            final category = _categoryOfLaw(law);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: lawId == null
                                  ? null
                                  : () => _openLaw(lawId),
                              title: Text((law['title'] ?? '-').toString()),
                              subtitle: Text(
                                'No. ${(law['lawNumber'] ?? '-').toString()} / ${(law['year'] ?? '-').toString()}\n'
                                'Category: $category',
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
                          'Articles (${filteredArticles.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (filteredArticles.isEmpty)
                          const Text('No indexed articles for this result set.')
                        else
                          ...filteredArticles.map((article) {
                            final text = (article['text'] ?? '').toString();
                            final lawRef = article['lawId'];
                            final lawTitle = lawRef is Map
                                ? (lawRef['title'] ?? '').toString()
                                : '';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.article_outlined),
                              title: Text(
                                'Article ${(article['articleNumber'] ?? '-').toString()}',
                              ),
                              subtitle: Text(
                                '${lawTitle.isEmpty ? '' : '$lawTitle\n'}$text',
                              ),
                              isThreeLine: true,
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
    );
  }
}

class _LawReference {
  const _LawReference({
    required this.title,
    required this.sourceUrl,
    required this.lawNumber,
  });

  final String title;
  final String sourceUrl;
  final String lawNumber;
}
