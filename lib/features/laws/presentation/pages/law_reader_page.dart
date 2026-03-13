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
        const SnackBar(content: Text('تعذر فتح المادة لعدم توفر المعرّف.')),
      );
      return;
    }
    context.go('/laws/${widget.lawId}/articles/$articleId');
  }

  String _articlePreview(Map<String, dynamic> item) {
    final text = (item['text'] ?? '').toString().trim();
    if (text.isEmpty) {
      return 'لا يوجد نص مفهرس لهذه المادة.';
    }
    if (text.length <= 180) {
      return text;
    }
    return '${text.substring(0, 180)}...';
  }

  @override
  Widget build(BuildContext context) {
    final law = _law;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: (law?['title'] ?? 'قارئ القانون').toString(),
              subtitle: 'اختر مادة لفتح صفحة مستقلة تتضمن النص الكامل والشرح',
              trailing: OutlinedButton.icon(
                onPressed: _loading ? null : _loadLaw,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث'),
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
                    Chip(label: Text('عدد المواد: ${_articles.length}')),
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
            'مواد القانون (${_articles.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (_articles.isEmpty)
            const Text('لا توجد مواد مفهرسة لهذا القانون.')
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
                                'المادة ${(item['articleNumber'] ?? '-').toString()}',
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
