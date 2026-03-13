import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class ConstitutionArticleReaderPage extends ConsumerStatefulWidget {
  const ConstitutionArticleReaderPage({super.key, required this.articleId});

  final String articleId;

  @override
  ConsumerState<ConstitutionArticleReaderPage> createState() =>
      _ConstitutionArticleReaderPageState();
}

class _ConstitutionArticleReaderPageState
    extends ConsumerState<ConstitutionArticleReaderPage> {
  bool _loading = false;
  bool _explaining = false;
  String? _error;
  Map<String, dynamic>? _article;
  Map<String, dynamic>? _explanation;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/constitution/articles/${widget.articleId}',
        options: Options(headers: authHeaders(ref)),
      );

      if (!mounted) {
        return;
      }

      setState(() => _article = (response.data as Map).cast<String, dynamic>());
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

  Future<void> _explainArticle() async {
    final article = _article;
    if (article == null) {
      return;
    }

    setState(() => _explaining = true);
    try {
      final dio = ref.read(dioProvider);
      final query = [
        'اشرح المادة ${(article['articleNumber'] ?? '-').toString()} من الدستور العراقي شرحًا مبسطًا للمحامي.',
        'نص المادة:',
        (article['text'] ?? '').toString(),
      ].join('\n');

      final response = await dio.post(
        '/ai/legal-research',
        data: {
          'query': query,
          'searchConstitution': true,
          'searchLaws': false,
          'searchDecisions': false,
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

  @override
  Widget build(BuildContext context) {
    final article = _article;
    final text = (article?['text'] ?? '').toString();
    final apiParagraphs = ((article?['paragraphs'] as List?) ?? const [])
        .map((entry) => entry.toString())
        .where((entry) => entry.trim().isNotEmpty)
        .toList();
    final paragraphs = apiParagraphs.isNotEmpty
        ? apiParagraphs
        : _extractParagraphs(text);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title:
                'المادة الدستورية ${(article?['articleNumber'] ?? '-').toString()}',
            subtitle: 'قارئ دستوري كامل مع شرح مبسط للمحامي',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : _loadArticle,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تحديث'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _explaining ? null : _explainArticle,
                  icon: _explaining
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology_alt_rounded),
                  label: const Text('شرح مبسط'),
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
          else if (article == null)
            const GlassPanel(child: Text('تعذر تحميل المادة الدستورية.'))
          else ...[
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المادة ${(article['articleNumber'] ?? '-').toString()}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if ((article['title'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      (article['title'] ?? '').toString(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('الباب: ${(article['chapter'] ?? '-').toString()}')),
                      Chip(label: Text('القسم: ${(article['section'] ?? '-').toString()}')),
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
                  Text('النص الكامل', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (paragraphs.isEmpty)
                    Text(text)
                  else
                    ...paragraphs.asMap().entries.map(
                      (entry) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: LexiqColors.slateGray.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          '${entry.key + 1}. ${entry.value}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_explanation != null)
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الشرح المبسط (AI)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text((_explanation?['summary'] ?? '').toString()),
                    const SizedBox(height: 8),
                    Text((_explanation?['groundedAnswer'] ?? '').toString()),
                    const SizedBox(height: 10),
                    Text(
                      ((_explanation?['disclaimer'] ??
                              'هذه المخرجات أولية وتحتاج مراجعة محامٍ بشري.') as String)
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
    );
  }

  List<String> _extractParagraphs(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      return const [];
    }

    final chunks = cleaned
        .split(RegExp(r'(?=\b(?:اولاً|ثانياً|ثالثاً|رابعاً|خامساً|سادساً|سابعاً|ثامناً|تاسعاً|عاشراً)\b)'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    if (chunks.length > 1) {
      return chunks;
    }

    return cleaned
        .split(RegExp(r'(?<=[\.؛])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
