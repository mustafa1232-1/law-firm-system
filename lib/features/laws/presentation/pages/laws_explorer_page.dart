import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class LawsExplorerPage extends ConsumerStatefulWidget {
  const LawsExplorerPage({super.key});

  @override
  ConsumerState<LawsExplorerPage> createState() => _LawsExplorerPageState();
}

class _LawsExplorerPageState extends ConsumerState<LawsExplorerPage> {
  final _searchController = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _laws = const [];
  List<Map<String, dynamic>> _articles = const [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final query = _searchController.text.trim();
      final response = await dio.get(
        '/laws/search',
        queryParameters: {'q': query.isEmpty ? 'قانون' : query, 'limit': 30},
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

  Future<void> _openLaw(String lawId) async {
    try {
      final dio = ref.read(dioProvider);
      final lawResponse = await dio.get('/laws/$lawId', options: Options(headers: authHeaders(ref)));
      final articlesResponse = await dio.get(
        '/laws/$lawId/articles',
        queryParameters: const {'limit': 100},
        options: Options(headers: authHeaders(ref)),
      );

      final law = (lawResponse.data as Map).cast<String, dynamic>();
      final lawArticles = ((((articlesResponse.data as Map).cast<String, dynamic>())['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text((law['title'] ?? 'قانون').toString()),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('رقم القانون: ${(law['lawNumber'] ?? '-').toString()} / ${(law['year'] ?? '-').toString()}'),
                  const SizedBox(height: 8),
                  Text('الجهة المصدرة: ${(law['issuingBody'] ?? '-').toString()}'),
                  Text('المجال: ${(law['legalDomain'] ?? '-').toString()}'),
                  const SizedBox(height: 12),
                  const Text('المواد'),
                  const SizedBox(height: 8),
                  if (lawArticles.isEmpty)
                    const Text('لا توجد مواد مرتبطة.')
                  else
                    ...lawArticles.map(
                      (article) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'م ${article['articleNumber']}: ${(article['text'] ?? '').toString()}',
                        ),
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
            title: 'Iraqi Laws Explorer',
            subtitle: 'Law documents, articles, amendments, and legal classification',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: 'ابحث في القوانين والمواد',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search_rounded),
                label: Text(context.tr('Browse Laws')),
              ),
            ],
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
                        Text('القوانين (${_laws.length})', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_laws.isEmpty)
                          const Text('لا توجد قوانين مطابقة.')
                        else
                          ..._laws.map((law) {
                            final lawId = (law['_id'] ?? '').toString();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: lawId.isEmpty ? null : () => _openLaw(lawId),
                              title: Text((law['title'] ?? '-').toString()),
                              subtitle: Text(
                                'رقم ${(law['lawNumber'] ?? '-').toString()} / ${(law['year'] ?? '-').toString()}',
                              ),
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
                        Text('المواد (${_articles.length})', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_articles.isEmpty)
                          const Text('لا توجد مواد مطابقة.')
                        else
                          ..._articles.map(
                            (article) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.article_outlined),
                              title: Text('المادة ${(article['articleNumber'] ?? '-').toString()}'),
                              subtitle: Text((article['text'] ?? '').toString()),
                              isThreeLine: true,
                            ),
                          ),
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
