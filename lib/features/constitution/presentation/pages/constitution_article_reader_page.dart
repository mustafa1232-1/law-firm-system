import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

      setState(() {
        _article = (response.data as Map).cast<String, dynamic>();
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

  Future<void> _explainArticle() async {
    final article = _article;
    if (article == null) {
      return;
    }

    setState(() => _explaining = true);
    try {
      final dio = ref.read(dioProvider);
      final query = [
        _loc(
          context,
          'اشرح المادة ${(article['articleNumber'] ?? '-').toString()} من الدستور العراقي شرحًا تفصيليًا للمحامي.',
          'Explain article ${(article['articleNumber'] ?? '-').toString()} of the Iraqi constitution in a detailed way for a lawyer.',
        ),
        _loc(context, 'نص المادة:', 'Article text:'),
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
      setState(
        () => _explanation = (response.data as Map).cast<String, dynamic>(),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _explaining = false);
      }
    }
  }

  Widget _buildListSection(BuildContext context, String title, dynamic value) {
    final items =
        (value as List?)
            ?.map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList() ??
        const <String>[];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...items.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('• $entry'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthoritiesSection(BuildContext context, dynamic value) {
    final authorities =
        (value as List?)
            ?.map(
              (entry) =>
                  (entry as Map?)?.cast<String, dynamic>() ??
                  const <String, dynamic>{},
            )
            .where((entry) => entry.isNotEmpty)
            .toList() ??
        const <Map<String, dynamic>>[];

    if (authorities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _loc(context, 'المرجعيات المقترحة', 'Suggested Authorities'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...authorities.map((item) {
            final sourceType = (item['sourceType'] ?? '').toString().trim();
            final citation = (item['citation'] ?? '').toString().trim();
            final title = (item['title'] ?? '').toString().trim();
            final id = (item['id'] ?? '').toString().trim();
            final snippet = (item['snippet'] ?? '').toString().trim();
            final canOpen =
                id.isNotEmpty &&
                (sourceType == 'constitution' ||
                    sourceType == 'law' ||
                    sourceType == 'decision');

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: LexiqColors.obsidianBlack.withValues(alpha: 0.32),
                border: Border.all(
                  color: LexiqColors.slateGray.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (citation.isNotEmpty) ...[
                    if (title.isNotEmpty) const SizedBox(height: 4),
                    Text(citation),
                  ],
                  if (snippet.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      snippet,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (canOpen) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/authority/$sourceType/$id'),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(
                        _loc(context, 'فتح المرجع', 'Open Authority'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isArabic(BuildContext context) => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('ar');

  String _loc(BuildContext context, String ar, String en) =>
      _isArabic(context) ? ar : en;

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
    final confidence = (_explanation?['confidence'] as num?)?.toDouble();

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
              title: _loc(
                context,
                'المادة الدستورية ${(article?['articleNumber'] ?? '-').toString()}',
                'Constitution Article ${(article?['articleNumber'] ?? '-').toString()}',
              ),
              subtitle: _loc(
                context,
                'قارئ دستوري كامل مع شرح تفصيلي للمحامي',
                'Full constitution reader with detailed lawyer-oriented explanation.',
              ),
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadArticle,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_loc(context, 'تحديث', 'Refresh')),
                  ),
                  ElevatedButton.icon(
                    onPressed: _explaining || article == null
                        ? null
                        : _explainArticle,
                    icon: _explaining
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_alt_rounded),
                    label: Text(
                      _loc(context, 'شرح تفصيلي', 'Detailed Explanation'),
                    ),
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
              GlassPanel(
                child: Text(
                  _loc(
                    context,
                    'تعذر تحميل المادة الدستورية.',
                    'Failed to load constitution article.',
                  ),
                ),
              )
            else ...[
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loc(
                        context,
                        'المادة ${(article['articleNumber'] ?? '-').toString()}',
                        'Article ${(article['articleNumber'] ?? '-').toString()}',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if ((article['title'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
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
                        Chip(
                          label: Text(
                            _loc(
                              context,
                              'الباب: ${(article['chapter'] ?? '-').toString()}',
                              'Chapter: ${(article['chapter'] ?? '-').toString()}',
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            _loc(
                              context,
                              'القسم: ${(article['section'] ?? '-').toString()}',
                              'Section: ${(article['section'] ?? '-').toString()}',
                            ),
                          ),
                        ),
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
                    Text(
                      _loc(context, 'النص الكامل', 'Full Text'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
                              color: LexiqColors.slateGray.withValues(
                                alpha: 0.2,
                              ),
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
                        _loc(
                          context,
                          'شرح المادة الدستورية',
                          'Constitution Article Explanation',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (confidence != null) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            _loc(
                              context,
                              'مستوى الثقة ${(confidence * 100).toStringAsFixed(0)}%',
                              'Confidence ${(confidence * 100).toStringAsFixed(0)}%',
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if ((_explanation?['summary'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        Text(
                          _loc(context, 'المعنى المبسط', 'Plain Meaning'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text((_explanation?['summary'] ?? '').toString()),
                        const SizedBox(height: 10),
                      ],
                      if ((_explanation?['groundedAnswer'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        Text(
                          _loc(context, 'الشرح المفصل', 'Detailed Explanation'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (_explanation?['groundedAnswer'] ?? '').toString(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _buildListSection(
                        context,
                        _loc(
                          context,
                          'القضايا القانونية المستخرجة',
                          'Extracted Legal Issues',
                        ),
                        _explanation?['extractedIssues'],
                      ),
                      _buildListSection(
                        context,
                        _loc(
                          context,
                          'أسئلة متابعة للمحامي',
                          'Follow-up Questions for Lawyer',
                        ),
                        _explanation?['proposedQuestions'],
                      ),
                      _buildListSection(
                        context,
                        _loc(
                          context,
                          'قيود وحدود التحليل',
                          'Analysis Limits and Constraints',
                        ),
                        _explanation?['limitations'],
                      ),
                      _buildAuthoritiesSection(
                        context,
                        _explanation?['suggestedAuthorities'],
                      ),
                      Text(
                        ((_explanation?['disclaimer'] ??
                                    _loc(
                                      context,
                                      'هذه المخرجات أولية وتحتاج مراجعة محامٍ بشري.',
                                      'These outputs are preliminary and require review by a licensed lawyer.',
                                    ))
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

  List<String> _extractParagraphs(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      return const [];
    }

    final chunks = cleaned
        .split(
          RegExp(
            r'(?=\b(?:اولاً|ثانياً|ثالثاً|رابعاً|خامساً|سادساً|سابعاً|ثامناً|تاسعاً|عاشراً)\b)',
          ),
        )
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
