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
  String? _error;
  String? _note;
  String _selectedCategory = 'الكل';
  _ResultsTab _activeTab = _ResultsTab.laws;

  int _totalLaws = 0;
  int _totalArticles = 0;

  List<Map<String, dynamic>> _laws = const [];
  List<Map<String, dynamic>> _articles = const [];

  static const _smartSearchExamples = <String>[
    'المادة 1',
    'تعويض الضرر',
    'الاختصاص القضائي',
    'قانون 40',
    'الإثبات',
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
        _activeTab = _ResultsTab.laws;
        _note = 'اكتب كلمة أو رقم مادة أو رقم قانون للبحث الذكي.';
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
        _totalArticles =
            (data['totalArticles'] as num?)?.toInt() ?? articles.length;
        _note = (data['note'] ?? '').toString().trim();

        if (laws.isNotEmpty) {
          _activeTab = _ResultsTab.laws;
        } else if (articles.isNotEmpty) {
          _activeTab = _ResultsTab.articles;
        }
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
    return _laws
        .where((law) => _categoryOfLaw(law) == _selectedCategory)
        .toList();
  }

  List<Map<String, dynamic>> _filteredArticles(
    List<Map<String, dynamic>> filteredLaws,
  ) {
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
                onPressed: _loading ? null : _loadInitialLaws,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث'),
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
                      'بحث قانوني ذكي',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ابحث بكلمة أو رقم مادة أو رقم قانون، مع نتائج منظمة بين القوانين والمواد.',
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
                hintText: 'اكتب عبارة البحث القانونية',
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
                label: const Text('بحث ذكي'),
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
                label: const Text('إعادة ضبط'),
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
                      hintText: 'اكتب عبارة البحث القانونية',
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
                  label: const Text('بحث ذكي'),
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
                  label: const Text('إعادة ضبط'),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            'أمثلة بحث سريعة',
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

  Widget _buildStatsPanel(
    BuildContext context, {
    required List<Map<String, dynamic>> filteredLaws,
    required List<Map<String, dynamic>> filteredArticles,
  }) {
    final stats = <({String label, String value, IconData icon, Color color})>[
      (
        label: 'إجمالي القوانين',
        value: _totalLaws.toString(),
        icon: Icons.gavel_rounded,
        color: LexiqColors.imperialBlue,
      ),
      (
        label: 'القوانين المعروضة',
        value: filteredLaws.length.toString(),
        icon: Icons.view_agenda_rounded,
        color: LexiqColors.brassGold,
      ),
      (
        label: 'إجمالي المواد',
        value: _totalArticles.toString(),
        icon: Icons.article_rounded,
        color: LexiqColors.emeraldJustice,
      ),
      (
        label: 'المواد المعروضة',
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
            'تصفية حسب التصنيف',
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
              title: 'القوانين',
              count: lawsCount,
              onTap: () => setState(() => _activeTab = _ResultsTab.laws),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ResultTabButton(
              selected: _activeTab == _ResultsTab.articles,
              icon: Icons.description_rounded,
              title: 'المواد',
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
              Text('جاري تحميل النتائج القانونية...'),
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
          Text('نتائج القوانين', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (laws.isEmpty)
            const _EmptyResultsMessage(
              message: 'لا توجد قوانين مطابقة لمعايير البحث الحالية.',
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
                            tooltip: 'فتح القانون',
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
                                'القانون ${(law['lawNumber'] ?? '-').toString()}',
                          ),
                          _MetaChip(
                            icon: Icons.calendar_today_rounded,
                            text: 'سنة ${(law['year'] ?? '-').toString()}',
                          ),
                          _MetaChip(
                            icon: Icons.account_tree_rounded,
                            text: category,
                          ),
                          if (score.isNotEmpty)
                            _MetaChip(
                              icon: Icons.insights_rounded,
                              text: 'درجة $score',
                            ),
                        ],
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'سبب الصلة: $reason',
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
                          label: const Text('فتح النص الكامل للقانون'),
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
          Text('نتائج المواد', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (articles.isEmpty)
            const _EmptyResultsMessage(
              message: 'لا توجد مواد مطابقة لمعايير البحث الحالية.',
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
                                'المادة ${(article['articleNumber'] ?? '-').toString()}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (score.isNotEmpty)
                              _MetaChip(
                                icon: Icons.auto_graph_rounded,
                                text: 'درجة $score',
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
                            'سبب الصلة: $reason',
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
