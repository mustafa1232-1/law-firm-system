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
  ConsumerState<LawArticleReaderPage> createState() =>
      _LawArticleReaderPageState();
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

    final raw =
        (item['paragraphs'] as List?)
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
          'focusQuestion': _loc(
            context,
            'اشرح المادة شرحًا تفصيليًا عمليًا للمحامي مع تحليل البنود.',
            'Explain this legal article in a detailed practical way for a lawyer with clause-level analysis.',
          ),
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

  bool _isArabic(BuildContext context) => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('ar');

  String _loc(BuildContext context, String ar, String en) =>
      _isArabic(context) ? ar : en;

  @override
  Widget build(BuildContext context) {
    final item = _article;
    final law =
        (item?['lawId'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final paragraphs = _resolveParagraphs(item);

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
                'قارئ المادة القانونية',
                'Law Article Reader',
              ),
              subtitle: _loc(
                context,
                'نص المادة، البنود، والشرح التفصيلي المدعوم بالذكاء الاصطناعي',
                'Article text, clauses, and AI-powered detailed explanation.',
              ),
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/laws/${widget.lawId}'),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      _loc(context, 'العودة للمواد', 'Back to articles'),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadArticle,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_loc(context, 'تحديث', 'Refresh')),
                  ),
                  ElevatedButton.icon(
                    onPressed: _explaining || item == null
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
            else if (item == null)
              GlassPanel(
                child: Text(
                  _loc(
                    context,
                    'تعذر تحميل المادة القانونية.',
                    'Failed to load legal article.',
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
                          'المادة: ${(item['articleNumber'] ?? '-').toString()}',
                          'Article: ${(item['articleNumber'] ?? '-').toString()}',
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        _loc(
                          context,
                          'القانون: ${(law['lawNumber'] ?? '-').toString()}',
                          'Law: ${(law['lawNumber'] ?? '-').toString()}',
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
                          'المجال: ${(law['legalDomain'] ?? '-').toString()}',
                          'Domain: ${(law['legalDomain'] ?? '-').toString()}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (law['title'] ??
                              _loc(context, 'مادة قانونية', 'Legal Article'))
                          .toString(),
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
                              color: LexiqColors.obsidianBlack.withValues(
                                alpha: 0.32,
                              ),
                              border: Border.all(
                                color: LexiqColors.slateGray.withValues(
                                  alpha: 0.2,
                                ),
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
                        _loc(
                          context,
                          'الشرح التفصيلي للمادة',
                          'Detailed Article Explanation',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if ((_explanation?['plainMeaning'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        Text(
                          _loc(context, 'المعنى المبسط', 'Plain Meaning'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text((_explanation?['plainMeaning'] ?? '').toString()),
                        const SizedBox(height: 10),
                      ],
                      if ((_explanation?['detailedExplanation'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        Text(
                          _loc(context, 'الشرح المفصل', 'Detailed Explanation'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (_explanation?['detailedExplanation'] ?? '')
                              .toString(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _buildListSection(
                        context,
                        _loc(context, 'الأركان القانونية', 'Legal Elements'),
                        _explanation?['legalElements'],
                      ),
                      _buildListSection(
                        context,
                        _loc(
                          context,
                          'سيناريوهات التطبيق',
                          'Application Scenarios',
                        ),
                        _explanation?['applicationScenarios'],
                      ),
                      _buildListSection(
                        context,
                        _loc(context, 'ملاحظات إجرائية', 'Procedural Notes'),
                        _explanation?['proceduralNotes'],
                      ),
                      _buildListSection(
                        context,
                        _loc(context, 'مخاطر محتملة', 'Potential Risks'),
                        _explanation?['potentialRisks'],
                      ),
                      _buildListSection(
                        context,
                        _loc(
                          context,
                          'زوايا دفاع محتملة',
                          'Potential Defense Angles',
                        ),
                        _explanation?['defenseAngles'],
                      ),
                      _buildListSection(
                        context,
                        _loc(
                          context,
                          'قائمة عمل للمحامي',
                          'Lawyer Practical Checklist',
                        ),
                        _explanation?['practicalChecklist'],
                      ),
                      _buildListSection(
                        context,
                        _loc(context, 'أسئلة متابعة', 'Follow-up Questions'),
                        _explanation?['proposedQuestions'],
                      ),
                      const SizedBox(height: 6),
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
}
