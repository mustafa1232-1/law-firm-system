import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

enum _ResultsTab { laws, articles }

class LawsExplorerPage extends ConsumerStatefulWidget {
  const LawsExplorerPage({super.key});

  @override
  ConsumerState<LawsExplorerPage> createState() => _LawsExplorerPageState();
}

class _LawsExplorerPageState extends ConsumerState<LawsExplorerPage> {
  final _searchController = TextEditingController();

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _note;
  String _selectedCategory = 'Ø§Ù„ÙƒÙ„';
  _ResultsTab _activeTab = _ResultsTab.laws;
  bool _searchMode = false;
  String _activeQuery = '';
  bool _hasMore = false;
  int _page = 1;

  int _totalLaws = 0;
  int _totalArticles = 0;

  List<Map<String, dynamic>> _laws = const [];
  List<Map<String, dynamic>> _articles = const [];
  final Map<String, _LawsSearchCacheEntry> _cache = {};

  static const int _pageSize = 30;

  static const _smartSearchExamples = <String>[
    'Ø§Ù„Ù…Ø§Ø¯Ø© 1',
    'ØªØ¹ÙˆÙŠØ¶ Ø§Ù„Ø¶Ø±Ø±',
    'Ø§Ù„Ø§Ø®ØªØµØ§Øµ Ø§Ù„Ù‚Ø¶Ø§Ø¦ÙŠ',
    'Ù‚Ø§Ù†ÙˆÙ† 40',
    'Ø§Ù„Ø¥Ø«Ø¨Ø§Øª',
    'Ø§Ù„Ø¹Ù‚Ø¯ ÙˆØ§Ù„Ø§Ù„ØªØ²Ø§Ù…',
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
    await _fetchBrowse(page: 1, append: false);
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      await _loadInitialLaws();
      return;
    }

    await _fetchSearch(query: query, page: 1, append: false);
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) {
      return;
    }

    if (_searchMode) {
      await _fetchSearch(query: _activeQuery, page: _page + 1, append: true);
      return;
    }

    await _fetchBrowse(page: _page + 1, append: true);
  }

  Future<void> _fetchBrowse({
    required int page,
    required bool append,
    bool force = false,
  }) async {
    final key = _cacheKey(mode: 'browse', query: '', page: page);

    if (!force) {
      final cached = _cache[key];
      if (cached != null) {
        _applyBrowsePayload(
          laws: cached.laws,
          totalLaws: cached.totalLaws,
          page: page,
          append: append,
          note: cached.note,
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _note = null;
      }
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/laws',
        queryParameters: {'limit': _pageSize, 'page': page},
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final laws = ((data['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final totalLaws = (data['total'] as num?)?.toInt() ?? laws.length;
      const note = 'اكتب كلمة أو رقم مادة أو رقم قانون للبحث الذكي.';

      _cache[key] = _LawsSearchCacheEntry(
        laws: laws,
        articles: const [],
        totalLaws: totalLaws,
        totalArticles: 0,
        note: note,
      );

      _applyBrowsePayload(
        laws: laws,
        totalLaws: totalLaws,
        page: page,
        append: append,
        note: note,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = parseApiError(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchSearch({
    required String query,
    required int page,
    required bool append,
    bool force = false,
  }) async {
    final normalizedQuery = query.trim();
    final key = _cacheKey(mode: 'search', query: normalizedQuery, page: page);

    if (!force) {
      final cached = _cache[key];
      if (cached != null) {
        _applySearchPayload(
          laws: cached.laws,
          articles: cached.articles,
          totalLaws: cached.totalLaws,
          totalArticles: cached.totalArticles,
          page: page,
          append: append,
          query: normalizedQuery,
          note: cached.note,
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _note = null;
      }
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/laws/search',
        queryParameters: {
          'q': normalizedQuery,
          'limit': _pageSize,
          'page': page,
        },
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final laws = ((data['laws'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final articles = ((data['articles'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final totalLaws = (data['totalLaws'] as num?)?.toInt() ?? laws.length;
      final totalArticles =
          (data['totalArticles'] as num?)?.toInt() ?? articles.length;
      final note = (data['note'] ?? '').toString().trim();

      _cache[key] = _LawsSearchCacheEntry(
        laws: laws,
        articles: articles,
        totalLaws: totalLaws,
        totalArticles: totalArticles,
        note: note,
      );

      _applySearchPayload(
        laws: laws,
        articles: articles,
        totalLaws: totalLaws,
        totalArticles: totalArticles,
        page: page,
        append: append,
        query: normalizedQuery,
        note: note,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = parseApiError(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _applyBrowsePayload({
    required List<Map<String, dynamic>> laws,
    required int totalLaws,
    required int page,
    required bool append,
    required String note,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _laws = append ? _mergeUniqueById(_laws, laws) : laws;
      _articles = const [];
      _totalLaws = totalLaws;
      _totalArticles = 0;
      _searchMode = false;
      _activeQuery = '';
      _page = page;
      _hasMore = _laws.length < _totalLaws;
      _activeTab = _ResultsTab.laws;
      _note = note;
    });
  }

  void _applySearchPayload({
    required List<Map<String, dynamic>> laws,
    required List<Map<String, dynamic>> articles,
    required int totalLaws,
    required int totalArticles,
    required int page,
    required bool append,
    required String query,
    required String note,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _laws = append ? _mergeUniqueById(_laws, laws) : laws;
      _articles = append ? _mergeUniqueById(_articles, articles) : articles;
      _totalLaws = totalLaws;
      _totalArticles = totalArticles;
      _searchMode = true;
      _activeQuery = query;
      _page = page;
      _hasMore = _laws.length < _totalLaws || _articles.length < _totalArticles;
      _note = note;

      if (!append) {
        if (_laws.isNotEmpty) {
          _activeTab = _ResultsTab.laws;
        } else if (_articles.isNotEmpty) {
          _activeTab = _ResultsTab.articles;
        }
      }
    });
  }

  String _cacheKey({
    required String mode,
    required String query,
    required int page,
  }) {
    final normalized = query.trim().toLowerCase();
    return '$mode|$normalized|$page';
  }

  List<Map<String, dynamic>> _mergeUniqueById(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> incoming,
  ) {
    final map = <String, Map<String, dynamic>>{};

    for (final item in current) {
      map[_idForMap(item)] = item;
    }
    for (final item in incoming) {
      map[_idForMap(item)] = item;
    }

    return map.values.toList();
  }

  String _idForMap(Map<String, dynamic> item) {
    final id = (item['_id'] ?? item['id'])?.toString();
    if (id != null && id.trim().isNotEmpty) {
      return id;
    }

    final articleNo = (item['articleNumber'] ?? '').toString();
    final lawRef = item['lawId'];
    if (lawRef is Map) {
      final lawId = (lawRef['_id'] ?? lawRef['id'] ?? '').toString();
      return 'article:$lawId:$articleNo';
    }
    if (lawRef is String && lawRef.trim().isNotEmpty) {
      return 'article:$lawRef:$articleNo';
    }

    final title = (item['title'] ?? '').toString();
    return '$title::$articleNo::${item.hashCode}';
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
      return 'ØºÙŠØ± Ù…ØµÙ†Ù';
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
    if (_selectedCategory == 'Ø§Ù„ÙƒÙ„') {
      return _laws;
    }
    return _laws
        .where((law) => _categoryOfLaw(law) == _selectedCategory)
        .toList();
  }

  List<Map<String, dynamic>> _filteredArticles(
    List<Map<String, dynamic>> filteredLaws,
  ) {
    if (_selectedCategory == 'Ø§Ù„ÙƒÙ„') {
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
    final values = <String>{'Ø§Ù„ÙƒÙ„'};
    for (final law in _laws) {
      values.add(_categoryOfLaw(law));
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  String _articleSnippet(Map<String, dynamic> article) {
    final value = (article['text'] ?? '')
        .toString()
        .replaceAll('\n', ' ')
        .trim();
    if (value.length <= 280) {
      return value;
    }
    return '${value.substring(0, 280)}...';
  }

  String _lawTitle(Map<String, dynamic> article) {
    final lawRef = article['lawId'];
    if (lawRef is Map) {
      return (lawRef['title'] ?? '').toString().trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final filteredLaws = _filteredLaws();
    final filteredArticles = _filteredArticles(filteredLaws);
    final categories = _availableCategories();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Iraqi Laws Explorer',
              subtitle:
                  'Law documents, articles, amendments, and legal classification',
              trailing: OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        final query = _searchController.text.trim();
                        _cache.clear();
                        if (query.isEmpty) {
                          await _fetchBrowse(
                            page: 1,
                            append: false,
                            force: true,
                          );
                        } else {
                          await _fetchSearch(
                            query: query,
                            page: 1,
                            append: false,
                            force: true,
                          );
                        }
                      },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('ØªØ­Ø¯ÙŠØ«'),
              ),
            ),
            const SizedBox(height: 12),
            _buildSearchPanel(context),
            const SizedBox(height: 12),
            _buildStatsPanel(
              context,
              filteredLaws: filteredLaws,
              filteredArticles: filteredArticles,
            ),
            const SizedBox(height: 12),
            _buildCategoryPanel(context, categories),
            const SizedBox(height: 12),
            _buildResultTabPanel(
              context,
              lawsCount: filteredLaws.length,
              articlesCount: filteredArticles.length,
            ),
            const SizedBox(height: 12),
            if (_loading)
              _buildLoadingPanel()
            else if (_error != null)
              _buildErrorPanel(_error!)
            else if (_activeTab == _ResultsTab.laws)
              _buildLawsResultPanel(context, filteredLaws)
            else
              _buildArticlesResultPanel(context, filteredArticles),
            if (!_loading && _error == null && _hasMore) ...[
              const SizedBox(height: 12),
              _buildLoadMorePanel(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: LexiqColors.imperialBlue.withValues(alpha: 0.18),
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: LexiqColors.ivoryText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ø¨Ø­Ø« Ù‚Ø§Ù†ÙˆÙ†ÙŠ Ø°ÙƒÙŠ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ø§Ø¨Ø­Ø« Ø¨ÙƒÙ„Ù…Ø© Ø£Ùˆ Ø±Ù‚Ù… Ù…Ø§Ø¯Ø© Ø£Ùˆ Ø±Ù‚Ù… Ù‚Ø§Ù†ÙˆÙ†ØŒ Ù…Ø¹ Ù†ØªØ§Ø¦Ø¬ Ù…Ù†Ø¸Ù…Ø© Ø¨ÙŠÙ† Ø§Ù„Ù‚ÙˆØ§Ù†ÙŠÙ† ÙˆØ§Ù„Ù…ÙˆØ§Ø¯.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: LexiqColors.slateGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isCompact) ...[
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Ø§ÙƒØªØ¨ Ø¹Ø¨Ø§Ø±Ø© Ø§Ù„Ø¨Ø­Ø« Ø§Ù„Ù‚Ø§Ù†ÙˆÙ†ÙŠØ©',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Ø¨Ø­Ø« Ø°ÙƒÙŠ'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        _searchController.clear();
                        setState(() {});
                        _loadInitialLaws();
                      },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Ø¥Ø¹Ø§Ø¯Ø© Ø¶Ø¨Ø·'),
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _search(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText:
                          'Ø§ÙƒØªØ¨ Ø¹Ø¨Ø§Ø±Ø© Ø§Ù„Ø¨Ø­Ø« Ø§Ù„Ù‚Ø§Ù†ÙˆÙ†ÙŠØ©',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Ø¨Ø­Ø« Ø°ÙƒÙŠ'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          _searchController.clear();
                          setState(() {});
                          _loadInitialLaws();
                        },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Ø¥Ø¹Ø§Ø¯Ø© Ø¶Ø¨Ø·'),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            'Ø£Ù…Ø«Ù„Ø© Ø¨Ø­Ø« Ø³Ø±ÙŠØ¹Ø©',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: LexiqColors.brassGold),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _smartSearchExamples
                  .map(
                    (example) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ActionChip(
                        label: Text(example),
                        onPressed: () {
                          _searchController.text = example;
                          _search();
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if ((_note ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: LexiqColors.obsidianBlack.withValues(alpha: 0.24),
                border: Border.all(
                  color: LexiqColors.slateGray.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                _note!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: LexiqColors.slateGray),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadMorePanel() {
    return GlassPanel(
      child: Center(
        child: SizedBox(
          width: 240,
          child: ElevatedButton.icon(
            onPressed: _loadingMore ? null : _loadMore,
            icon: _loadingMore
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(_loadingMore ? 'جاري تحميل المزيد...' : 'تحميل المزيد'),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPanel(
    BuildContext context, {
    required List<Map<String, dynamic>> filteredLaws,
    required List<Map<String, dynamic>> filteredArticles,
  }) {
    final stats = <({String label, String value, IconData icon, Color color})>[
      (
        label: 'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù‚ÙˆØ§Ù†ÙŠÙ†',
        value: _totalLaws.toString(),
        icon: Icons.gavel_rounded,
        color: LexiqColors.imperialBlue,
      ),
      (
        label: 'Ø§Ù„Ù‚ÙˆØ§Ù†ÙŠÙ† Ø§Ù„Ù…Ø¹Ø±ÙˆØ¶Ø©',
        value: filteredLaws.length.toString(),
        icon: Icons.view_agenda_rounded,
        color: LexiqColors.brassGold,
      ),
      (
        label: 'Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…ÙˆØ§Ø¯',
        value: _totalArticles.toString(),
        icon: Icons.article_rounded,
        color: LexiqColors.emeraldJustice,
      ),
      (
        label: 'Ø§Ù„Ù…ÙˆØ§Ø¯ Ø§Ù„Ù…Ø¹Ø±ÙˆØ¶Ø©',
        value: filteredArticles.length.toString(),
        icon: Icons.tune_rounded,
        color: LexiqColors.slateGray,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: stats
          .map(
            (stat) => _StatTile(
              label: stat.label,
              value: stat.value,
              icon: stat.icon,
              color: stat.color,
            ),
          )
          .toList(),
    );
  }

  Widget _buildCategoryPanel(BuildContext context, List<String> categories) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ØªØµÙÙŠØ© Ø­Ø³Ø¨ Ø§Ù„ØªØµÙ†ÙŠÙ',
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
    );
  }

  Widget _buildResultTabPanel(
    BuildContext context, {
    required int lawsCount,
    required int articlesCount,
  }) {
    return GlassPanel(
      child: Row(
        children: [
          Expanded(
            child: _ResultTabButton(
              selected: _activeTab == _ResultsTab.laws,
              icon: Icons.menu_book_rounded,
              title: 'Ø§Ù„Ù‚ÙˆØ§Ù†ÙŠÙ†',
              count: lawsCount,
              onTap: () => setState(() => _activeTab = _ResultsTab.laws),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ResultTabButton(
              selected: _activeTab == _ResultsTab.articles,
              icon: Icons.description_rounded,
              title: 'Ø§Ù„Ù…ÙˆØ§Ø¯',
              count: articlesCount,
              onTap: () => setState(() => _activeTab = _ResultsTab.articles),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPanel() {
    return const GlassPanel(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('Ø¬Ø§Ø±ÙŠ ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ù†ØªØ§Ø¦Ø¬ Ø§Ù„Ù‚Ø§Ù†ÙˆÙ†ÙŠØ©...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPanel(String message) {
    return GlassPanel(
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: LexiqColors.crimsonAlert,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: LexiqColors.crimsonAlert),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLawsResultPanel(
    BuildContext context,
    List<Map<String, dynamic>> laws,
  ) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ù†ØªØ§Ø¦Ø¬ Ø§Ù„Ù‚ÙˆØ§Ù†ÙŠÙ†',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (laws.isEmpty)
            const _EmptyResultsMessage(
              message:
                  'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù‚ÙˆØ§Ù†ÙŠÙ† Ù…Ø·Ø§Ø¨Ù‚Ø© Ù„Ù…Ø¹Ø§ÙŠÙŠØ± Ø§Ù„Ø¨Ø­Ø« Ø§Ù„Ø­Ø§Ù„ÙŠØ©.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: laws.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final law = laws[index];
                final lawId = _lawId(law);
                final category = _categoryOfLaw(law);
                final reason = (law['relevanceReason'] ?? '').toString().trim();
                final score = (law['relevanceScore'] ?? '').toString().trim();

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: LexiqColors.obsidianBlack.withValues(alpha: 0.28),
                    border: Border.all(
                      color: LexiqColors.slateGray.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              (law['title'] ?? '-').toString(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: lawId == null
                                ? null
                                : () => _openLaw(lawId),
                            icon: const Icon(Icons.arrow_outward_rounded),
                            tooltip: 'ÙØªØ­ Ø§Ù„Ù‚Ø§Ù†ÙˆÙ†',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaChip(
                            icon: Icons.numbers_rounded,
                            text:
                                'Ø§Ù„Ù‚Ø§Ù†ÙˆÙ† ${(law['lawNumber'] ?? '-').toString()}',
                          ),
                          _MetaChip(
                            icon: Icons.calendar_today_rounded,
                            text: 'Ø³Ù†Ø© ${(law['year'] ?? '-').toString()}',
                          ),
                          _MetaChip(
                            icon: Icons.account_tree_rounded,
                            text: category,
                          ),
                          if (score.isNotEmpty)
                            _MetaChip(
                              icon: Icons.insights_rounded,
                              text: 'Ø¯Ø±Ø¬Ø© $score',
                            ),
                        ],
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Ø³Ø¨Ø¨ Ø§Ù„ØµÙ„Ø©: $reason',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: LexiqColors.slateGray),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: lawId == null
                              ? null
                              : () => _openLaw(lawId),
                          icon: const Icon(Icons.menu_book_rounded),
                          label: const Text(
                            'ÙØªØ­ Ø§Ù„Ù†Øµ Ø§Ù„ÙƒØ§Ù…Ù„ Ù„Ù„Ù‚Ø§Ù†ÙˆÙ†',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildArticlesResultPanel(
    BuildContext context,
    List<Map<String, dynamic>> articles,
  ) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ù†ØªØ§Ø¦Ø¬ Ø§Ù„Ù…ÙˆØ§Ø¯',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (articles.isEmpty)
            const _EmptyResultsMessage(
              message:
                  'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…ÙˆØ§Ø¯ Ù…Ø·Ø§Ø¨Ù‚Ø© Ù„Ù…Ø¹Ø§ÙŠÙŠØ± Ø§Ù„Ø¨Ø­Ø« Ø§Ù„Ø­Ø§Ù„ÙŠØ©.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: articles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final article = articles[index];
                final lawTitle = _lawTitle(article);
                final score = (article['relevanceScore'] ?? '')
                    .toString()
                    .trim();
                final reason = (article['relevanceReason'] ?? '')
                    .toString()
                    .trim();

                return InkWell(
                  onTap: () => _openArticleFromSearch(article),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: LexiqColors.deepNavy.withValues(alpha: 0.36),
                      border: Border.all(
                        color: LexiqColors.imperialBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: LexiqColors.imperialBlue.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              child: Text(
                                'Ø§Ù„Ù…Ø§Ø¯Ø© ${(article['articleNumber'] ?? '-').toString()}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (score.isNotEmpty)
                              _MetaChip(
                                icon: Icons.auto_graph_rounded,
                                text: 'Ø¯Ø±Ø¬Ø© $score',
                              ),
                            const Spacer(),
                            const Icon(Icons.open_in_new_rounded),
                          ],
                        ),
                        if (lawTitle.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            lawTitle,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: LexiqColors.brassGold),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          _articleSnippet(article),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Ø³Ø¨Ø¨ Ø§Ù„ØµÙ„Ø©: $reason',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: LexiqColors.slateGray),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.2),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: LexiqColors.slateGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTabButton extends StatelessWidget {
  const _ResultTabButton({
    required this.selected,
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? LexiqColors.imperialBlue.withValues(alpha: 0.7)
        : LexiqColors.slateGray.withValues(alpha: 0.25);
    final bgColor = selected
        ? LexiqColors.imperialBlue.withValues(alpha: 0.16)
        : LexiqColors.obsidianBlack.withValues(alpha: 0.22);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          color: bgColor,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? LexiqColors.ivoryText : LexiqColors.slateGray,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: LexiqColors.obsidianBlack.withValues(alpha: 0.4),
              ),
              child: Text(
                count.toString(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: LexiqColors.slateGray.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: LexiqColors.slateGray),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _EmptyResultsMessage extends StatelessWidget {
  const _EmptyResultsMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: LexiqColors.obsidianBlack.withValues(alpha: 0.2),
        border: Border.all(
          color: LexiqColors.slateGray.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: LexiqColors.slateGray),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _LawsSearchCacheEntry {
  const _LawsSearchCacheEntry({
    required this.laws,
    required this.articles,
    required this.totalLaws,
    required this.totalArticles,
    required this.note,
  });

  final List<Map<String, dynamic>> laws;
  final List<Map<String, dynamic>> articles;
  final int totalLaws;
  final int totalArticles;
  final String note;
}
