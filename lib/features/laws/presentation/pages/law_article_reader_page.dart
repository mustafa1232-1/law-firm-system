import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class LawArticleReaderPage extends ConsumerStatefulWidget {
  const LawArticleReaderPage({
    super.key,
    required this.lawId,
    required this.articleId,
  });

  final String lawId;
  final String articleId;

  @override
  ConsumerState<LawArticleReaderPage> createState() => _LawArticleReaderPageState();
}

class _LawArticleReaderPageState extends ConsumerState<LawArticleReaderPage> {
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
        '/laws/articles/${widget.articleId}',
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

  List<String> _resolveParagraphs(Map<String, dynamic>? item) {
    if (item == null) {
      return const [];
    }

    final raw = (item['paragraphs'] as List?)
            ?.map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList() ??
        const [];

    if (raw.isNotEmpty) {
      return raw;
    }

    final text = (item['text'] ?? '').toString().trim();
    if (text.isEmpty) {
      return const [];
    }

    return text
        .split(RegExp(r'\n+'))
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  Future<void> _explainArticle() async {
    if (_article == null) {
      return;
    }

    setState(() => _explaining = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/ai/explain-law-article',
        data: {
          'articleId': widget.articleId,
          'focusQuestion': 'اشرح المادة شرحًا تفصيليًا عمليًا للمحامي مع تحليل البنود.',
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

  Widget _buildListSection(
    BuildContext context,
    String title,
    dynamic value,
  ) {
    final items = (value as List?)
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

  @override
  Widget build(BuildContext context) {
    final item = _article;
    final law = (item?['lawId'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final paragraphs = _resolveParagraphs(item);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'قارئ المادة القانونية',
              subtitle: 'نص المادة، البنود، والشرح التفصيلي المدعوم بالذكاء الاصطناعي',
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/laws/${widget.lawId}'),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('العودة للمواد'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadArticle,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('تحديث'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _explaining || item == null ? null : _explainArticle,
                    icon: _explaining
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_alt_rounded),
                    label: const Text('شرح تفصيلي'),
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
            else if (item == null)
              const GlassPanel(child: Text('تعذر تحميل المادة القانونية.'))
            else ...[
              GlassPanel(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('المادة: ${(item['articleNumber'] ?? '-').toString()}')),
                    Chip(label: Text('القانون: ${(law['lawNumber'] ?? '-').toString()}')),
                    Chip(label: Text('السنة: ${(law['year'] ?? '-').toString()}')),
                    Chip(label: Text('المجال: ${(law['legalDomain'] ?? '-').toString()}')),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (law['title'] ?? 'مادة قانونية').toString(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (paragraphs.isEmpty)
                      Text(
                        (item['text'] ?? '').toString(),
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
              ),
              const SizedBox(height: 12),
              if (_explanation != null)
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الشرح التفصيلي للمادة',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if ((_explanation?['plainMeaning'] ?? '').toString().trim().isNotEmpty) ...[
                        Text('المعنى المبسط', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text((_explanation?['plainMeaning'] ?? '').toString()),
                        const SizedBox(height: 10),
                      ],
                      if ((_explanation?['detailedExplanation'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        Text('الشرح المفصل', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text((_explanation?['detailedExplanation'] ?? '').toString()),
                        const SizedBox(height: 10),
                      ],
                      _buildListSection(context, 'الأركان القانونية', _explanation?['legalElements']),
                      _buildListSection(
                        context,
                        'سيناريوهات التطبيق',
                        _explanation?['applicationScenarios'],
                      ),
                      _buildListSection(
                        context,
                        'ملاحظات إجرائية',
                        _explanation?['proceduralNotes'],
                      ),
                      _buildListSection(
                        context,
                        'مخاطر محتملة',
                        _explanation?['potentialRisks'],
                      ),
                      _buildListSection(
                        context,
                        'زوايا دفاع محتملة',
                        _explanation?['defenseAngles'],
                      ),
                      _buildListSection(
                        context,
                        'قائمة عمل للمحامي',
                        _explanation?['practicalChecklist'],
                      ),
                      _buildListSection(
                        context,
                        'أسئلة متابعة',
                        _explanation?['proposedQuestions'],
                      ),
                      const SizedBox(height: 6),
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
}
