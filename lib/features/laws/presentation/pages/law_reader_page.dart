import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  String? _error;

  Map<String, dynamic>? _law;
  List<Map<String, dynamic>> _articles = const [];
  bool _handledInitialOpen = false;

  @override
  void initState() {
    super.initState();
    _loadLaw();
  }

  Future<List<Map<String, dynamic>>> _fetchAllLawArticles(Dio dio) async {
    const pageSize = 100;
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

      if (!mounted) {
        return;
      }

      setState(() {
        _law = law;
        _articles = articles;
      });

      if (!_handledInitialOpen &&
          widget.initialArticleNumber != null &&
          widget.initialArticleNumber!.trim().isNotEmpty) {
        _handledInitialOpen = true;
        final article = articles.cast<Map<String, dynamic>?>().firstWhere(
          (item) =>
              (item?['articleNumber'] ?? '').toString() ==
              widget.initialArticleNumber,
          orElse: () => null,
        );
        if (article != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openArticle(article);
            }
          });
        }
      }
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

  void _openArticle(Map<String, dynamic> article) {
    final articleId = article['_id']?.toString();
    if (articleId == null || articleId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _loc(
              context,
              'تعذر فتح المادة لعدم توفر المعرّف.',
              'Unable to open article because ID is missing.',
            ),
          ),
        ),
      );
      return;
    }
    context.go('/laws/${widget.lawId}/articles/$articleId');
  }

  String _articlePreview(Map<String, dynamic> item) {
    final text = (item['text'] ?? '').toString().trim();
    if (text.isEmpty) {
      return _loc(
        context,
        'لا يوجد نص مفهرس لهذه المادة.',
        'No indexed text available for this article.',
      );
    }
    if (text.length <= 180) {
      return text;
    }
    return '${text.substring(0, 180)}...';
  }

  bool _isArabic(BuildContext context) => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('ar');

  String _loc(BuildContext context, String ar, String en) =>
      _isArabic(context) ? ar : en;

  @override
  Widget build(BuildContext context) {
    final law = _law;

    return Directionality(
      textDirection:
          Localizations.localeOf(
            context,
          ).languageCode.toLowerCase().startsWith('ar')
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title:
                  (law?['title'] ?? _loc(context, 'قارئ القانون', 'Law Reader'))
                      .toString(),
              subtitle: _loc(
                context,
                'اختر مادة لفتح صفحة مستقلة تتضمن النص الكامل والشرح',
                'Select an article to open a dedicated page with full text and explanation.',
              ),
              trailing: OutlinedButton.icon(
                onPressed: _loading ? null : _loadLaw,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_loc(context, 'تحديث', 'Refresh')),
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
              GlassPanel(
                child: Text(
                  _loc(
                    context,
                    'تعذر تحميل بيانات القانون.',
                    'Failed to load law data.',
                  ),
                ),
              )
            else ...[
              GlassPanel(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        _loc(
                          context,
                          'رقم القانون: ${(law['lawNumber'] ?? '-').toString()}',
                          'Law No.: ${(law['lawNumber'] ?? '-').toString()}',
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        _loc(
                          context,
                          'السنة: ${(law['year'] ?? '-').toString()}',
                          'Year: ${(law['year'] ?? '-').toString()}',
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        _loc(
                          context,
                          'الجهة: ${(law['issuingBody'] ?? '-').toString()}',
                          'Issuing body: ${(law['issuingBody'] ?? '-').toString()}',
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        _loc(
                          context,
                          'المجال: ${(law['legalDomain'] ?? '-').toString()}',
                          'Domain: ${(law['legalDomain'] ?? '-').toString()}',
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        _loc(
                          context,
                          'عدد المواد: ${_articles.length}',
                          'Articles count: ${_articles.length}',
                        ),
                      ),
                    ),
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
                        _loc(context, 'رابط المرجع', 'Source URL'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      SelectableText((law['sourceUrl'] ?? '').toString()),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _articlesPanel(context),
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
            _loc(
              context,
              'مواد القانون (${_articles.length})',
              'Law Articles (${_articles.length})',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (_articles.isEmpty)
            Text(
              _loc(
                context,
                'لا توجد مواد مفهرسة لهذا القانون.',
                'No indexed articles found for this law.',
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _articles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = _articles[index];
                return InkWell(
                  onTap: () => _openArticle(item),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: LexiqColors.slateGray.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _loc(
                                  context,
                                  'المادة ${(item['articleNumber'] ?? '-').toString()}',
                                  'Article ${(item['articleNumber'] ?? '-').toString()}',
                                ),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _articlePreview(item),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.open_in_new_rounded),
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
