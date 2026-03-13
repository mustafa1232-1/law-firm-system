import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class DecisionsExplorerPage extends ConsumerStatefulWidget {
  const DecisionsExplorerPage({super.key});

  @override
  ConsumerState<DecisionsExplorerPage> createState() =>
      _DecisionsExplorerPageState();
}

class _DecisionsExplorerPageState extends ConsumerState<DecisionsExplorerPage> {
  final _queryController = TextEditingController();
  final _courtController = TextEditingController();
  final _domainController = TextEditingController();
  final _yearController = TextEditingController();

  bool _loading = false;
  bool _syncing = false;
  String? _error;

  String _selectedCaseType = 'الكل';
  String _selectedCourtLevel = 'appellate';

  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _summaryItems = const [];
  int _page = 1;
  int _total = 0;
  final Map<String, _DecisionPageCacheEntry> _searchCache = {};
  final Map<String, List<Map<String, dynamic>>> _summaryCache = {};

  static const int _pageSize = 30;

  static const _caseTypes = <String>[
    'الكل',
    'مدني',
    'جزائي',
    'أحوال شخصية',
    'تجاري',
    'إداري',
    'عمالي',
    'عقاري',
    'تنفيذ',
    'دستوري',
    'إثبات',
    'إجرائي',
    'وقف',
    'أخرى',
  ];

  static const _courtLevels = <({String value, String label})>[
    (value: 'all', label: 'كل المستويات'),
    (value: 'appellate', label: 'استئنافي'),
    (value: 'cassation', label: 'تمييزي'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _courtController.dispose();
    _domainController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool force = false}) async {
    if (force) {
      _clearDecisionCaches();
    }
    await Future.wait([
      _search(page: 1, force: force),
      _loadCaseTypeSummary(force: force),
    ]);
  }

  Map<String, dynamic> _buildSearchQueryParameters() {
    return {
      if (_queryController.text.trim().isNotEmpty)
        'q': _queryController.text.trim(),
      if (_courtController.text.trim().isNotEmpty)
        'court': _courtController.text.trim(),
      if (_domainController.text.trim().isNotEmpty)
        'legalDomain': _domainController.text.trim(),
      if (_selectedCaseType != _caseTypes.first) 'caseType': _selectedCaseType,
      if (_selectedCourtLevel != 'all') 'courtLevel': _selectedCourtLevel,
      if (_yearController.text.trim().isNotEmpty)
        'year': _yearController.text.trim(),
    };
  }

  Future<void> _search({int? page, bool force = false}) async {
    final targetPage = page ?? _page;
    final key = _searchCacheKey(targetPage);
    if (!force) {
      final cached = _searchCache[key];
      if (cached != null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _items = cached.items;
          _total = cached.total;
          _page = targetPage;
          _error = null;
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/decisions/search',
        queryParameters: {
          ..._buildSearchQueryParameters(),
          'limit': _pageSize,
          'page': targetPage,
        },
        options: Options(headers: authHeaders(ref)),
      );
      final data = (response.data as Map).cast<String, dynamic>();
      final items = ((data['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final total = (data['total'] as num?)?.toInt() ?? items.length;

      if (!mounted) {
        return;
      }

      _searchCache[key] = _DecisionPageCacheEntry(items: items, total: total);

      setState(() {
        _items = items;
        _total = total;
        _page = targetPage;
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

  Future<void> _loadCaseTypeSummary({bool force = false}) async {
    final key = _summaryCacheKey();
    if (!force) {
      final cached = _summaryCache[key];
      if (cached != null) {
        if (!mounted) {
          return;
        }
        setState(() => _summaryItems = cached);
        return;
      }
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/decisions/case-type-summary',
        queryParameters: {
          if (_selectedCourtLevel != 'all') 'courtLevel': _selectedCourtLevel,
          if (_yearController.text.trim().isNotEmpty)
            'year': _yearController.text.trim(),
        },
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final items = ((data['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      _summaryCache[key] = items;
      setState(() => _summaryItems = items);
    } catch (_) {
      if (!mounted) {
        return;
      }

      final grouped = _groupItemsByType(_items);
      setState(
        () => _summaryItems = grouped.entries
            .map(
              (entry) => {'caseType': entry.key, 'count': entry.value.length},
            )
            .toList(),
      );
    }
  }

  Future<void> _syncFromPublicSource() async {
    setState(() => _syncing = true);

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/decisions/sync/sjc-appellate',
        data: {
          'startId': 1,
          'endId': 12000,
          'concurrency': 20,
          'maxDecisions': 5000,
          'mode': _selectedCourtLevel == 'all' ? 'all' : 'appellate',
        },
        options: Options(
          headers: authHeaders(ref),
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 15),
        ),
      );

      final payload = (response.data as Map).cast<String, dynamic>();
      final inserted = (payload['insertedCount'] as num?)?.toInt() ?? 0;
      final updated = (payload['updatedCount'] as num?)?.toInt() ?? 0;
      final collected = (payload['collectedCount'] as num?)?.toInt() ?? 0;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت المزامنة: $collected قرار | $inserted جديد | $updated محدّث',
          ),
        ),
      );

      _clearDecisionCaches();
      await Future.wait([
        _search(page: 1, force: true),
        _loadCaseTypeSummary(force: true),
      ]);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _showAddDecisionDialog() async {
    final courtNameController = TextEditingController();
    final decisionNumberController = TextEditingController();
    final decisionDateController = TextEditingController();
    final caseTypeController = TextEditingController();
    final legalDomainController = TextEditingController();
    final summaryController = TextEditingController();
    final fullTextController = TextEditingController();

    String selectedCourtLevel = 'appellate';
    PlatformFile? pickedFile;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة قرار جديد'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        withData: true,
                        type: FileType.custom,
                        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                      );
                      if (result == null || result.files.isEmpty) {
                        return;
                      }
                      setDialogState(() => pickedFile = result.files.first);
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      pickedFile == null
                          ? 'اختيار ملف القرار (PDF/صورة)'
                          : pickedFile!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: courtNameController,
                    decoration: const InputDecoration(labelText: 'اسم المحكمة'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourtLevel,
                    decoration: const InputDecoration(
                      labelText: 'مستوى المحكمة',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'appellate',
                        child: Text('استئنافي'),
                      ),
                      DropdownMenuItem(
                        value: 'cassation',
                        child: Text('تمييزي'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() => selectedCourtLevel = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: decisionNumberController,
                    decoration: const InputDecoration(labelText: 'رقم القرار'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: decisionDateController,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ القرار (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: caseTypeController,
                    decoration: const InputDecoration(
                      labelText: 'نوع القضية (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: legalDomainController,
                    decoration: const InputDecoration(
                      labelText: 'المجال القانوني (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: summaryController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملخص القرار (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fullTextController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'النص الكامل (اختياري)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pickedFile == null || pickedFile!.bytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى اختيار ملف القرار.')),
                  );
                  return;
                }
                if (courtNameController.text.trim().isEmpty ||
                    decisionNumberController.text.trim().isEmpty ||
                    decisionDateController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'اسم المحكمة ورقم القرار وتاريخ القرار مطلوبة.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  final dio = ref.read(dioProvider);
                  final formData = FormData.fromMap({
                    'file': MultipartFile.fromBytes(
                      pickedFile!.bytes!,
                      filename: pickedFile!.name,
                    ),
                    'courtName': courtNameController.text.trim(),
                    'courtLevel': selectedCourtLevel,
                    'decisionNumber': decisionNumberController.text.trim(),
                    'decisionDate': decisionDateController.text.trim(),
                    if (caseTypeController.text.trim().isNotEmpty)
                      'caseType': caseTypeController.text.trim(),
                    if (legalDomainController.text.trim().isNotEmpty)
                      'legalDomain': legalDomainController.text.trim(),
                    if (summaryController.text.trim().isNotEmpty)
                      'summary': summaryController.text.trim(),
                    if (fullTextController.text.trim().isNotEmpty)
                      'fullText': fullTextController.text.trim(),
                  });

                  await dio.post(
                    '/decisions/upload',
                    data: formData,
                    options: Options(
                      headers: authHeaders(ref),
                      contentType: 'multipart/form-data',
                    ),
                  );

                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop(true);
                } catch (error) {
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(parseApiError(error))));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    courtNameController.dispose();
    decisionNumberController.dispose();
    decisionDateController.dispose();
    caseTypeController.dispose();
    legalDomainController.dispose();
    summaryController.dispose();
    fullTextController.dispose();

    if (created == true) {
      await _loadAll(force: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت إضافة القرار بنجاح.')));
    }
  }

  Future<void> _openDecision(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/decisions/$id',
        options: Options(headers: authHeaders(ref)),
      );
      final decision = (response.data as Map).cast<String, dynamic>();
      final similar = ((decision['similarDecisions'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var explaining = false;
          String? explainError;
          Map<String, dynamic>? explanation;

          Future<void> explainDecision(StateSetter setDialogState) async {
            final summary = (decision['summary'] ?? '').toString().trim();
            final fullTextRaw = (decision['fullText'] ?? '').toString().trim();
            final fullText = fullTextRaw.length > 12000
                ? '${fullTextRaw.substring(0, 12000)}\n[تم اختصار النص الكامل لطوله]'
                : fullTextRaw;

            final query = [
              'اشرح القرار القضائي العراقي التالي شرحًا تفصيليًا للمحامي.',
              'المحكمة: ${(decision['courtName'] ?? '-').toString()}',
              'رقم القرار: ${(decision['decisionNumber'] ?? '-').toString()}',
              'نوع القضية: ${(decision['caseType'] ?? '-').toString()}',
              'المجال القانوني: ${(decision['legalDomain'] ?? '-').toString()}',
              if (summary.isNotEmpty) 'ملخص القرار:\n$summary',
              if (fullText.isNotEmpty) 'النص الكامل:\n$fullText',
              'قدّم: معنى القرار، الأساس القانوني، نقاط القوة والضعف، وكيفية توظيفه بالمرافعة.',
            ].join('\n\n');

            setDialogState(() {
              explaining = true;
              explainError = null;
            });

            try {
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

              if (!dialogContext.mounted) {
                return;
              }

              setDialogState(() {
                explanation = (response.data as Map).cast<String, dynamic>();
                explainError = null;
              });
            } catch (error) {
              if (!dialogContext.mounted) {
                return;
              }
              setDialogState(() => explainError = parseApiError(error));
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => explaining = false);
              }
            }
          }

          return StatefulBuilder(
            builder: (context, setDialogState) {
              final confidence = (explanation?['confidence'] as num?)
                  ?.toDouble();

              return AlertDialog(
                title: Text(
                  '${(decision['courtName'] ?? '-').toString()} - ${(decision['decisionNumber'] ?? '-').toString()}',
                ),
                content: SizedBox(
                  width: 980,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                'النوع: ${(decision['caseType'] ?? '-').toString()}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                'المجال: ${(decision['legalDomain'] ?? '-').toString()}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                'المستوى: ${(decision['courtLevel'] ?? '-').toString()}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                'التاريخ: ${_dateOnly(decision['decisionDate'])}',
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: explaining
                                  ? null
                                  : () => explainDecision(setDialogState),
                              icon: explaining
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.psychology_alt_rounded),
                              label: const Text('شرح القرار'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if ((decision['attachmentUrl'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          SelectableText(
                            'رابط ملف القرار: ${(decision['attachmentUrl'] ?? '').toString()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          (decision['summary'] ?? '').toString(),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        if ((decision['fullText'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          Text(
                            'النص الكامل',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            (decision['fullText'] ?? '').toString(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if ((decision['legalArticleReferences'] as List?)
                                ?.isNotEmpty ??
                            false) ...[
                          Text(
                            'المواد القانونية ذات الصلة',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ((decision['legalArticleReferences'] as List?) ??
                                    const [])
                                .join('، '),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if ((decision['constitutionalReferences'] as List?)
                                ?.isNotEmpty ??
                            false) ...[
                          Text(
                            'المواد الدستورية ذات الصلة',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ((decision['constitutionalReferences'] as List?) ??
                                    const [])
                                .join('، '),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (explainError != null) ...[
                          Text(
                            explainError!,
                            style: const TextStyle(
                              color: LexiqColors.crimsonAlert,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (explanation != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: LexiqColors.obsidianBlack.withValues(
                                alpha: 0.32,
                              ),
                              border: Border.all(
                                color: LexiqColors.slateGray.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الشرح التفصيلي للقرار',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (confidence != null) ...[
                                  const SizedBox(height: 8),
                                  Chip(
                                    label: Text(
                                      'مستوى الثقة ${(confidence * 100).toStringAsFixed(0)}%',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                if ((explanation?['summary'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                                  Text(
                                    'المعنى المبسط',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (explanation?['summary'] ?? '').toString(),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if ((explanation?['groundedAnswer'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                                  Text(
                                    'التحليل القانوني',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (explanation?['groundedAnswer'] ?? '')
                                        .toString(),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                _buildExplanationListSection(
                                  context,
                                  title: 'القضايا القانونية المستخرجة',
                                  value: explanation?['extractedIssues'],
                                ),
                                _buildExplanationListSection(
                                  context,
                                  title: 'أسئلة متابعة للمحامي',
                                  value: explanation?['proposedQuestions'],
                                ),
                                _buildExplanationListSection(
                                  context,
                                  title: 'قيود وحدود التحليل',
                                  value: explanation?['limitations'],
                                ),
                                _buildSuggestedAuthoritiesSection(
                                  context,
                                  explanation?['suggestedAuthorities'],
                                ),
                                Text(
                                  ((explanation?['disclaimer'] ??
                                              'هذه المخرجات أولية وتحتاج مراجعة محامٍ بشري.')
                                          as String)
                                      .trim(),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: LexiqColors.brassGold),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          'قرارات مشابهة',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (similar.isEmpty)
                          const Text('لا توجد قرارات مشابهة.')
                        else
                          ...similar.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '- ${(entry['decisionNumber'] ?? '-').toString()} | ${(entry['courtName'] ?? '-').toString()} | ${_dateOnly(entry['decisionDate'])}',
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
                    child: const Text('إغلاق'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    }
  }

  Widget _buildExplanationListSection(
    BuildContext context, {
    required String title,
    required dynamic value,
  }) {
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
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 5),
          ...items.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $entry'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedAuthoritiesSection(
    BuildContext context,
    dynamic value,
  ) {
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
            'المرجعيات المقترحة',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 5),
          ...authorities.map((item) {
            final citation = (item['citation'] ?? '').toString().trim();
            final title = (item['title'] ?? '').toString().trim();
            final snippet = (item['snippet'] ?? '').toString().trim();
            final line = citation.isNotEmpty ? citation : title;
            if (line.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: LexiqColors.obsidianBlack.withValues(alpha: 0.28),
                border: Border.all(
                  color: LexiqColors.slateGray.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• $line'),
                  if (snippet.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
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

  String _searchCacheKey(int page) {
    final params = _buildSearchQueryParameters();
    final sorted = params.keys.toList()..sort();
    final queryKey = sorted.map((key) => '$key=${params[key] ?? ''}').join('&');
    return '$queryKey|page=$page|limit=$_pageSize';
  }

  String _summaryCacheKey() {
    final year = _yearController.text.trim();
    return 'courtLevel=$_selectedCourtLevel|year=$year';
  }

  void _clearDecisionCaches() {
    _searchCache.clear();
    _summaryCache.clear();
  }

  Map<String, List<Map<String, dynamic>>> _groupItemsByType(
    List<Map<String, dynamic>> items,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in items) {
      final rawType = (item['caseType'] ?? '').toString().trim();
      final type = rawType.isEmpty ? 'أخرى' : rawType;
      grouped.putIfAbsent(type, () => []).add(item);
    }

    return grouped;
  }

  String _dateOnly(dynamic value) {
    if (value == null) {
      return '-';
    }
    return value.toString().split('T').first;
  }

  int get _totalPages =>
      _total == 0 ? 1 : ((_total + _pageSize - 1) ~/ _pageSize);

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _page || _loading) {
      return;
    }
    await _search(page: page);
  }

  Widget _buildPaginationPanel(BuildContext context) {
    final totalPages = _totalPages;
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('صفحة $_page من $totalPages'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _page > 1 ? () => _goToPage(_page - 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('السابق'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _page < totalPages
                    ? () => _goToPage(_page + 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('التالي'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupItemsByType(_items);
    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) => b.value.length - a.value.length);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'مستكشف القرارات القضائية',
              subtitle: 'بحث القرارات وتصنيفها وربطها بالقضايا والمرجعيات',
              trailing: OutlinedButton.icon(
                onPressed: _loading ? null : () => _loadAll(force: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث'),
              ),
            ),
            const SizedBox(height: 12),
            _buildFiltersPanel(context),
            const SizedBox(height: 12),
            _buildSummaryPanel(context),
            if (_totalPages > 1) ...[
              const SizedBox(height: 12),
              _buildPaginationPanel(context),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const GlassPanel(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              GlassPanel(
                child: Text(
                  _error!,
                  style: const TextStyle(color: LexiqColors.crimsonAlert),
                ),
              )
            else if (_items.isEmpty)
              const GlassPanel(
                child: Text('لا توجد قرارات مطابقة للفلاتر الحالية.'),
              )
            else
              Column(
                children: [
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'القرارات حسب نوع القضية',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        ...sortedGroups.map(
                          (group) => _DecisionGroupPanel(
                            caseType: group.key,
                            items: group.value,
                            onOpen: _openDecision,
                            dateOnly: _dateOnly,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_totalPages > 1) ...[
                    const SizedBox(height: 12),
                    _buildPaginationPanel(context),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1100;

    final fields = <Widget>[
      SizedBox(
        width: isCompact ? double.infinity : 320,
        child: TextField(
          controller: _queryController,
          onSubmitted: (_) async {
            await _search(page: 1);
            await _loadCaseTypeSummary();
          },
          decoration: const InputDecoration(
            hintText: 'بحث بالنص أو رقم القرار',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: TextField(
          controller: _courtController,
          onSubmitted: (_) async {
            await _search(page: 1);
            await _loadCaseTypeSummary();
          },
          decoration: const InputDecoration(
            labelText: 'المحكمة',
            prefixIcon: Icon(Icons.account_balance_rounded),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: TextField(
          controller: _domainController,
          onSubmitted: (_) async {
            await _search(page: 1);
            await _loadCaseTypeSummary();
          },
          decoration: const InputDecoration(
            labelText: 'المجال القانوني',
            prefixIcon: Icon(Icons.category_outlined),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 130,
        child: TextField(
          controller: _yearController,
          keyboardType: TextInputType.number,
          onSubmitted: (_) async {
            await _search(page: 1);
            await _loadCaseTypeSummary();
          },
          decoration: const InputDecoration(
            labelText: 'السنة',
            hintText: '2026',
            prefixIcon: Icon(Icons.calendar_today_rounded),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: DropdownButtonFormField<String>(
          initialValue: _selectedCaseType,
          decoration: const InputDecoration(labelText: 'نوع القضية'),
          items: _caseTypes
              .map(
                (type) =>
                    DropdownMenuItem<String>(value: type, child: Text(type)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedCaseType = value);
          },
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: DropdownButtonFormField<String>(
          initialValue: _selectedCourtLevel,
          decoration: const InputDecoration(labelText: 'مستوى المحكمة'),
          items: _courtLevels
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.value,
                  child: Text(entry.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedCourtLevel = value);
          },
        ),
      ),
    ];

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فلترة واستعراض القرارات',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: fields),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        await _search(page: 1);
                        await _loadCaseTypeSummary();
                      },
                icon: const Icon(Icons.search_rounded),
                label: const Text('بحث'),
              ),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        _queryController.clear();
                        _courtController.clear();
                        _domainController.clear();
                        _yearController.clear();
                        setState(() {
                          _selectedCaseType = _caseTypes.first;
                          _selectedCourtLevel = 'appellate';
                        });
                        await _loadAll(force: true);
                      },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('إعادة ضبط'),
              ),
              ElevatedButton.icon(
                onPressed: _showAddDecisionDialog,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('إضافة قرار'),
              ),
              ElevatedButton.icon(
                onPressed: _syncing ? null : _syncFromPublicSource,
                icon: _syncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync_rounded),
                label: const Text('جلب القرارات الاستئنافية من المصدر العام'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel(BuildContext context) {
    final total = _total;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryCard(
          title: 'النتائج الحالية',
          value: '$total',
          icon: Icons.gavel_rounded,
          color: LexiqColors.imperialBlue,
        ),
        ..._summaryItems.take(8).map((entry) {
          final caseType = (entry['caseType'] ?? 'أخرى').toString();
          final count = (entry['count'] ?? 0).toString();
          return _SummaryCard(
            title: caseType,
            value: count,
            icon: Icons.folder_special_rounded,
            color: LexiqColors.brassGold,
          );
        }),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _DecisionGroupPanel extends StatelessWidget {
  const _DecisionGroupPanel({
    required this.caseType,
    required this.items,
    required this.onOpen,
    required this.dateOnly,
  });

  final String caseType;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(String id) onOpen;
  final String Function(dynamic value) dateOnly;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      title: Row(
        children: [
          Expanded(
            child: Text(
              caseType,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: LexiqColors.obsidianBlack.withValues(alpha: 0.28),
            ),
            child: Text('${items.length}'),
          ),
        ],
      ),
      children: items.map((item) {
        final id = (item['_id'] ?? '').toString();
        final courtName = (item['courtName'] ?? '-').toString();
        final decisionNumber = (item['decisionNumber'] ?? '-').toString();
        final summary = (item['summary'] ?? '').toString();
        final level = (item['courtLevel'] ?? '-').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: LexiqColors.obsidianBlack.withValues(alpha: 0.28),
            border: Border.all(
              color: LexiqColors.slateGray.withValues(alpha: 0.2),
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
                      '$courtName - $decisionNumber',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateOnly(item['decisionDate']),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('المستوى: $level')),
                  if ((item['legalDomain'] ?? '').toString().trim().isNotEmpty)
                    Chip(
                      label: Text(
                        'المجال: ${(item['legalDomain'] ?? '').toString()}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: id.isEmpty ? null : () => onOpen(id),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('فتح القرار'),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DecisionPageCacheEntry {
  const _DecisionPageCacheEntry({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}
