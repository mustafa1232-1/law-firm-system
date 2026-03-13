import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class LawReaderPage extends ConsumerStatefulWidget {
  const LawReaderPage({
    super.key,
    required this.lawId,
    this.initialArticleNumber,
  });

  final String lawId;
  final String? initialArticleNumber;

  @override
  ConsumerState<LawReaderPage> createState() => _LawReaderPageState();
}

class _LawReaderPageState extends ConsumerState<LawReaderPage> {
  bool _loading = false;
  bool _explaining = false;
  String? _error;

  Map<String, dynamic>? _law;
  List<Map<String, dynamic>> _articles = const [];
  Map<String, dynamic>? _selectedArticle;
  Map<String, dynamic>? _explanation;

  @override
  void initState() {
    super.initState();
    _loadLaw();
  }

  Future<List<Map<String, dynamic>>> _fetchAllLawArticles(Dio dio) async {
    const pageSize = 150;
    var page = 1;
    final items = <Map<String, dynamic>>[];

    while (true) {
      final response = await dio.get(
        '/laws/${widget.lawId}/articles',
        queryParameters: {'page': page, 'limit': pageSize},
        options: Options(headers: authHeaders(ref)),
      );

      final payload = (response.data as Map).cast<String, dynamic>();
      final pageItems = ((payload['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final total = (payload['total'] as num?)?.toInt() ?? 0;

      items.addAll(pageItems);
      if (pageItems.length < pageSize || items.length >= total) {
        break;
      }
      page += 1;
    }

    return items;
  }

  Future<void> _loadLaw() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final lawResponse = await dio.get(
        '/laws/${widget.lawId}',
        options: Options(headers: authHeaders(ref)),
      );
      final law = (lawResponse.data as Map).cast<String, dynamic>();
      final articles = await _fetchAllLawArticles(dio);

      Map<String, dynamic>? selected;
      if (widget.initialArticleNumber != null &&
          widget.initialArticleNumber!.isNotEmpty) {
        selected = articles.firstWhere(
          (item) =>
              (item['articleNumber'] ?? '').toString() ==
              widget.initialArticleNumber,
          orElse: () => articles.isNotEmpty ? articles.first : <String, dynamic>{},
        );
        if (selected.isEmpty) {
          selected = null;
        }
      } else {
        selected = articles.isNotEmpty ? articles.first : null;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _law = law;
        _articles = articles;
        _selectedArticle = selected;
        _explanation = null;
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

  Future<void> _explainSelectedArticle() async {
    final law = _law;
    final selected = _selectedArticle;
    if (law == null || selected == null) {
      return;
    }

    setState(() => _explaining = true);
    try {
      final dio = ref.read(dioProvider);
      final query = [
        'اشرح المادة ${(selected['articleNumber'] ?? '-').toString()} من ${(law['title'] ?? 'القانون').toString()} شرحًا عمليًا للمحامي.',
        'نص المادة:',
        (selected['text'] ?? '').toString(),
      ].join('\n');

      final response = await dio.post(
        '/ai/legal-research',
        data: {
          'query': query,
          'searchConstitution': true,
          'searchLaws': true,
          'searchDecisions': true,
        },
        options: Options(headers: authHeaders(ref)),
      );

      if (!mounted) {
        return;
      }
      setState(() => _explanation = (response.data as Map).cast<String, dynamic>());
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _explaining = false);
      }
    }
  }

  List<String> _resolveParagraphs(Map<String, dynamic>? selected) {
    if (selected == null) {
      return const [];
    }

    final raw = (selected['paragraphs'] as List?)
            ?.map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList() ??
        const [];

    if (raw.isNotEmpty) {
      return raw;
    }

    final text = (selected['text'] ?? '').toString().trim();
    if (text.isEmpty) {
      return const [];
    }

    return text
        .split(RegExp(r'\n+'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final law = _law;
    final selected = _selectedArticle;
    final isWide = MediaQuery.sizeOf(context).width >= 1200;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: (law?['title'] ?? 'قارئ القانون').toString(),
              subtitle: 'عرض نصوص مواد القانون كاملة مع التفريعات',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadLaw,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('تحديث'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _explaining || selected == null
                        ? null
                        : _explainSelectedArticle,
                    icon: _explaining
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_alt_rounded),
                    label: const Text('شرح المادة'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              GlassPanel(
                child: Text(
                  _error!,
                  style: const TextStyle(color: LexiqColors.crimsonAlert),
                ),
              )
            else if (law == null)
              const GlassPanel(child: Text('تعذر تحميل بيانات القانون.'))
            else ...[
              GlassPanel(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('رقم القانون: ${(law['lawNumber'] ?? '-').toString()}')),
                    Chip(label: Text('السنة: ${(law['year'] ?? '-').toString()}')),
                    Chip(label: Text('الجهة: ${(law['issuingBody'] ?? '-').toString()}')),
                    Chip(label: Text('المجال: ${(law['legalDomain'] ?? '-').toString()}')),
                    if ((law['sourceName'] ?? '').toString().trim().isNotEmpty)
                      Chip(label: Text('المصدر: ${(law['sourceName'] ?? '-').toString()}')),
                  ],
                ),
              ),
              if ((law['sourceUrl'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رابط المرجع',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      SelectableText((law['sourceUrl'] ?? '').toString()),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _articlesPanel(context)),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: _readerPanel(context, selected)),
                  ],
                )
              else ...[
                _articlesPanel(context),
                const SizedBox(height: 12),
                _readerPanel(context, selected),
              ],
              const SizedBox(height: 12),
              if (_explanation != null)
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شرح المادة (AI)',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text((_explanation?['summary'] ?? '').toString()),
                      const SizedBox(height: 8),
                      Text((_explanation?['groundedAnswer'] ?? '').toString()),
                      const SizedBox(height: 10),
                      Text(
                        ((_explanation?['disclaimer'] ??
                                    'هذه المخرجات أولية وتحتاج مراجعة محامٍ بشري.')
                                as String)
                            .trim(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: LexiqColors.brassGold,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _articlesPanel(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مواد القانون (${_articles.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (_articles.isEmpty)
            const Text('لا توجد مواد مفهرسة لهذا القانون.')
          else
            SizedBox(
              height: 680,
              child: ListView.separated(
                itemCount: _articles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = _articles[index];
                  final isSelected =
                      item['_id']?.toString() == _selectedArticle?['_id']?.toString();
                  return InkWell(
                    onTap: () => setState(() {
                      _selectedArticle = item;
                      _explanation = null;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? LexiqColors.imperialBlue
                              : LexiqColors.slateGray.withValues(alpha: 0.22),
                        ),
                        color: isSelected
                            ? LexiqColors.imperialBlue.withValues(alpha: 0.12)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'المادة ${(item['articleNumber'] ?? '-').toString()}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const Icon(Icons.chevron_left_rounded),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _readerPanel(BuildContext context, Map<String, dynamic>? selected) {
    final paragraphs = _resolveParagraphs(selected);

    return GlassPanel(
      child: selected == null
          ? const Text('اختر مادة من القائمة لعرض النص الكامل.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المادة ${(selected['articleNumber'] ?? '-').toString()}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                if (paragraphs.isEmpty)
                  Text(
                    (selected['text'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodyLarge,
                  )
                else
                  ...paragraphs.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: LexiqColors.obsidianBlack.withValues(alpha: 0.32),
                              border: Border.all(
                                color: LexiqColors.slateGray.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              entry.value,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
    );
  }
}
