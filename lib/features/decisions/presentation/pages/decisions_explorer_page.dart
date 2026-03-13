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
  int _total = 0;
  final Map<String, _DecisionCacheEntry> _searchCache = {};

  static const int _batchSize = 100;

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
    await _loadAllDecisions(force: force);
    await _loadCaseTypeSummary();
  }

  Map<String, dynamic> _buildSearchQueryParameters({
    bool includeCaseType = false,
  }) {
    return {
      if (_queryController.text.trim().isNotEmpty)
        'q': _queryController.text.trim(),
      if (_courtController.text.trim().isNotEmpty)
        'court': _courtController.text.trim(),
      if (_domainController.text.trim().isNotEmpty)
        'legalDomain': _domainController.text.trim(),
      if (includeCaseType && _selectedCaseType != _caseTypes.first)
        'caseType': _selectedCaseType,
      if (_selectedCourtLevel != 'all') 'courtLevel': _selectedCourtLevel,
      if (_yearController.text.trim().isNotEmpty)
        'year': _yearController.text.trim(),
    };
  }

  Future<void> _loadAllDecisions({bool force = false}) async {
    final key = _searchCacheKey();
    if (!force) {
      final cached = _searchCache[key];
      if (cached != null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _items = cached.items;
          _total = cached.total;
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
      final allItems = <Map<String, dynamic>>[];
      var total = 0;
      var page = 1;

      while (true) {
        final response = await dio.get(
          '/decisions/search',
          queryParameters: {
            ..._buildSearchQueryParameters(),
            'limit': _batchSize,
            'page': page,
          },
          options: Options(headers: authHeaders(ref)),
        );
        final data = (response.data as Map).cast<String, dynamic>();
        final items = ((data['items'] as List?) ?? const [])
            .map((entry) => (entry as Map).cast<String, dynamic>())
            .toList();

        if (page == 1) {
          total = (data['total'] as num?)?.toInt() ?? items.length;
        }

        if (items.isEmpty) {
          break;
        }

        allItems.addAll(items);

        if (allItems.length >= total) {
          break;
        }

        page += 1;

        if (page > 10000) {
          break;
        }
      }

      if (!mounted) {
        return;
      }

      final normalizedTotal = total > 0 ? total : allItems.length;
      _searchCache[key] = _DecisionCacheEntry(
        items: allItems,
        total: normalizedTotal,
      );

      setState(() {
        _items = allItems;
        _total = normalizedTotal;
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

  Future<void> _loadCaseTypeSummary() async {
    if (!mounted) {
      return;
    }

    final grouped = _groupItemsByType(_items);
    final summary =
        grouped.entries
            .map(
              (entry) => {'caseType': entry.key, 'count': entry.value.length},
            )
            .toList()
          ..sort((a, b) {
            final countA = (a['count'] as num?)?.toInt() ?? 0;
            final countB = (b['count'] as num?)?.toInt() ?? 0;
            if (countA != countB) {
              return countB.compareTo(countA);
            }
            return (a['caseType'] ?? '').toString().compareTo(
              (b['caseType'] ?? '').toString(),
            );
          });

    setState(() => _summaryItems = summary);
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
            _loc(
              context,
              'تمت المزامنة: $collected قرار | $inserted جديد | $updated محدّث',
              'Sync completed: $collected decisions | $inserted inserted | $updated updated',
            ),
          ),
        ),
      );

      _clearDecisionCaches();
      await _loadAll(force: true);
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
          title: Text(_loc(context, 'إضافة قرار جديد', 'Add New Decision')),
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
                          ? _loc(
                              context,
                              'اختيار ملف القرار (PDF/صورة)',
                              'Choose decision file (PDF/Image)',
                            )
                          : pickedFile!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: courtNameController,
                    decoration: InputDecoration(
                      labelText: _loc(context, 'اسم المحكمة', 'Court Name'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourtLevel,
                    decoration: InputDecoration(
                      labelText: _loc(context, 'مستوى المحكمة', 'Court Level'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'appellate',
                        child: Text(_loc(context, 'استئنافي', 'Appellate')),
                      ),
                      DropdownMenuItem(
                        value: 'cassation',
                        child: Text(_loc(context, 'تمييزي', 'Cassation')),
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
                    decoration: InputDecoration(
                      labelText: _loc(context, 'رقم القرار', 'Decision Number'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: decisionDateController,
                    decoration: InputDecoration(
                      labelText: _loc(
                        context,
                        'تاريخ القرار (YYYY-MM-DD)',
                        'Decision Date (YYYY-MM-DD)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: caseTypeController,
                    decoration: InputDecoration(
                      labelText: _loc(
                        context,
                        'نوع القضية (اختياري)',
                        'Case Type (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: legalDomainController,
                    decoration: InputDecoration(
                      labelText: _loc(
                        context,
                        'المجال القانوني (اختياري)',
                        'Legal Domain (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: summaryController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: _loc(
                        context,
                        'ملخص القرار (اختياري)',
                        'Decision Summary (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fullTextController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: _loc(
                        context,
                        'النص الكامل (اختياري)',
                        'Full Text (optional)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_loc(context, 'إغلاق', 'Close')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pickedFile == null || pickedFile!.bytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _loc(
                          context,
                          'يرجى اختيار ملف القرار.',
                          'Please select the decision file.',
                        ),
                      ),
                    ),
                  );
                  return;
                }
                if (courtNameController.text.trim().isEmpty ||
                    decisionNumberController.text.trim().isEmpty ||
                    decisionDateController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _loc(
                          context,
                          'اسم المحكمة ورقم القرار وتاريخ القرار مطلوبة.',
                          'Court name, decision number, and date are required.',
                        ),
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
              child: Text(_loc(context, 'حفظ', 'Save')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _loc(
              context,
              'تمت إضافة القرار بنجاح.',
              'Decision added successfully.',
            ),
          ),
        ),
      );
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
                ? '${fullTextRaw.substring(0, 12000)}\n${_loc(dialogContext, '[تم اختصار النص الكامل لطوله]', '[Full text truncated due to length]')}'
                : fullTextRaw;

            final query = [
              _loc(
                dialogContext,
                'اشرح القرار القضائي العراقي التالي شرحًا تفصيليًا للمحامي.',
                'Explain the following Iraqi judicial decision in detail for a lawyer.',
              ),
              _loc(
                dialogContext,
                'المحكمة: ${(decision['courtName'] ?? '-').toString()}',
                'Court: ${(decision['courtName'] ?? '-').toString()}',
              ),
              _loc(
                dialogContext,
                'رقم القرار: ${(decision['decisionNumber'] ?? '-').toString()}',
                'Decision Number: ${(decision['decisionNumber'] ?? '-').toString()}',
              ),
              _loc(
                dialogContext,
                'نوع القضية: ${(decision['caseType'] ?? '-').toString()}',
                'Case Type: ${(decision['caseType'] ?? '-').toString()}',
              ),
              _loc(
                dialogContext,
                'المجال القانوني: ${(decision['legalDomain'] ?? '-').toString()}',
                'Legal Domain: ${(decision['legalDomain'] ?? '-').toString()}',
              ),
              if (summary.isNotEmpty)
                _loc(
                  dialogContext,
                  'ملخص القرار:\n$summary',
                  'Decision Summary:\n$summary',
                ),
              if (fullText.isNotEmpty)
                _loc(
                  dialogContext,
                  'النص الكامل:\n$fullText',
                  'Full Text:\n$fullText',
                ),
              _loc(
                dialogContext,
                'قدّم: معنى القرار، الأساس القانوني، نقاط القوة والضعف، وكيفية توظيفه بالمرافعة.',
                'Provide: decision meaning, legal basis, strengths and weaknesses, and advocacy usage.',
              ),
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
                                _loc(
                                  context,
                                  'النوع: ${(decision['caseType'] ?? '-').toString()}',
                                  'Type: ${(decision['caseType'] ?? '-').toString()}',
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                _loc(
                                  context,
                                  'المجال: ${(decision['legalDomain'] ?? '-').toString()}',
                                  'Domain: ${(decision['legalDomain'] ?? '-').toString()}',
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                _loc(
                                  context,
                                  'المستوى: ${(decision['courtLevel'] ?? '-').toString()}',
                                  'Level: ${(decision['courtLevel'] ?? '-').toString()}',
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                _loc(
                                  context,
                                  'التاريخ: ${_dateOnly(decision['decisionDate'])}',
                                  'Date: ${_dateOnly(decision['decisionDate'])}',
                                ),
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
                              label: Text(
                                _loc(context, 'شرح القرار', 'Explain Decision'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if ((decision['attachmentUrl'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          SelectableText(
                            _loc(
                              context,
                              'رابط ملف القرار: ${(decision['attachmentUrl'] ?? '').toString()}',
                              'Decision File URL: ${(decision['attachmentUrl'] ?? '').toString()}',
                            ),
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
                            _loc(context, 'النص الكامل', 'Full Text'),
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
                            _loc(
                              context,
                              'المواد القانونية ذات الصلة',
                              'Related Legal Articles',
                            ),
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
                            _loc(
                              context,
                              'المواد الدستورية ذات الصلة',
                              'Related Constitutional Articles',
                            ),
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
                                  _loc(
                                    context,
                                    'الشرح التفصيلي للقرار',
                                    'Detailed Decision Explanation',
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
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
                                if ((explanation?['summary'] ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                                  Text(
                                    _loc(
                                      context,
                                      'المعنى المبسط',
                                      'Plain Meaning',
                                    ),
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
                                    _loc(
                                      context,
                                      'التحليل القانوني',
                                      'Legal Analysis',
                                    ),
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
                                  title: _loc(
                                    context,
                                    'القضايا القانونية المستخرجة',
                                    'Extracted Legal Issues',
                                  ),
                                  value: explanation?['extractedIssues'],
                                ),
                                _buildExplanationListSection(
                                  context,
                                  title: _loc(
                                    context,
                                    'أسئلة متابعة للمحامي',
                                    'Follow-up Questions',
                                  ),
                                  value: explanation?['proposedQuestions'],
                                ),
                                _buildExplanationListSection(
                                  context,
                                  title: _loc(
                                    context,
                                    'قيود وحدود التحليل',
                                    'Analysis Limits',
                                  ),
                                  value: explanation?['limitations'],
                                ),
                                _buildSuggestedAuthoritiesSection(
                                  context,
                                  explanation?['suggestedAuthorities'],
                                ),
                                Text(
                                  ((explanation?['disclaimer'] ??
                                              _loc(
                                                context,
                                                'هذه المخرجات أولية وتحتاج مراجعة محامٍ بشري.',
                                                'These outputs are preliminary and require human legal review.',
                                              ))
                                          as String)
                                      .trim(),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: LexiqColors.brassGold),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          _loc(context, 'قرارات مشابهة', 'Similar Decisions'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (similar.isEmpty)
                          Text(
                            _loc(
                              context,
                              'لا توجد قرارات مشابهة.',
                              'No similar decisions.',
                            ),
                          )
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
                    child: Text(_loc(context, 'إغلاق', 'Close')),
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
            _loc(context, 'المرجعيات المقترحة', 'Suggested Authorities'),
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

  String _searchCacheKey() {
    final params = _buildSearchQueryParameters();
    final sorted = params.keys.toList()..sort();
    final queryKey = sorted.map((key) => '$key=${params[key] ?? ''}').join('&');
    return '$queryKey|limit=$_batchSize';
  }

  void _clearDecisionCaches() {
    _searchCache.clear();
  }

  bool _isArabic(BuildContext context) => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('ar');

  String _loc(BuildContext context, String ar, String en) =>
      _isArabic(context) ? ar : en;

  String _localizeCourtLevelLabel(BuildContext context, String level) {
    switch (level) {
      case 'appellate':
        return _loc(context, 'استئنافي', 'Appellate');
      case 'cassation':
        return _loc(context, 'تمييزي', 'Cassation');
      case 'all':
      default:
        return _loc(context, 'كل المستويات', 'All levels');
    }
  }

  String _localizeCaseType(BuildContext context, String caseType) {
    const arToEn = <String, String>{
      'الكل': 'All',
      'مدني': 'Civil',
      'جزائي': 'Criminal',
      'جنائي': 'Criminal',
      'أحوال شخصية': 'Personal Status',
      'تجاري': 'Commercial',
      'إداري': 'Administrative',
      'عمالي': 'Labor',
      'عقاري': 'Real Estate',
      'تنفيذ': 'Enforcement',
      'دستوري': 'Constitutional',
      'إثبات': 'Evidence',
      'إجرائي': 'Procedural',
      'وقف': 'Endowment',
      'أخرى': 'Other',
      'other': 'Other',
    };
    const enToAr = <String, String>{
      'all': 'الكل',
      'civil': 'مدني',
      'criminal': 'جزائي',
      'personal status': 'أحوال شخصية',
      'commercial': 'تجاري',
      'administrative': 'إداري',
      'labor': 'عمالي',
      'real estate': 'عقاري',
      'enforcement': 'تنفيذ',
      'constitutional': 'دستوري',
      'evidence': 'إثبات',
      'procedural': 'إجرائي',
      'endowment': 'وقف',
      'other': 'أخرى',
    };
    final raw = caseType.trim();
    if (_isArabic(context)) {
      return enToAr[raw.toLowerCase()] ?? raw;
    }
    return arToEn[raw] ?? raw;
  }

  String _canonicalCaseType(String caseType) {
    final raw = caseType.trim();
    if (raw.isEmpty) {
      return 'أخرى';
    }

    const enToAr = <String, String>{
      'all': 'الكل',
      'civil': 'مدني',
      'criminal': 'جزائي',
      'personal status': 'أحوال شخصية',
      'commercial': 'تجاري',
      'administrative': 'إداري',
      'labor': 'عمالي',
      'real estate': 'عقاري',
      'enforcement': 'تنفيذ',
      'constitutional': 'دستوري',
      'evidence': 'إثبات',
      'procedural': 'إجرائي',
      'endowment': 'وقف',
      'other': 'أخرى',
    };

    return enToAr[raw.toLowerCase()] ?? raw;
  }

  Map<String, List<Map<String, dynamic>>> _groupItemsByType(
    List<Map<String, dynamic>> items,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in items) {
      final rawType = (item['caseType'] ?? '').toString().trim();
      final type = _canonicalCaseType(rawType);
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

  @override
  Widget build(BuildContext context) {
    final selectedType = _canonicalCaseType(_selectedCaseType);
    final visibleItems = selectedType == _caseTypes.first
        ? _items
        : _items
              .where(
                (item) =>
                    _canonicalCaseType((item['caseType'] ?? '').toString()) ==
                    selectedType,
              )
              .toList();

    final grouped = _groupItemsByType(visibleItems);
    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) => b.value.length - a.value.length);

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
                'مستكشف القرارات القضائية',
                'Judicial Decisions Explorer',
              ),
              subtitle: _loc(
                context,
                'بحث القرارات وتصنيفها وربطها بالقضايا والمرجعيات',
                'Search, classify, and link decisions to cases and authorities.',
              ),
              trailing: OutlinedButton.icon(
                onPressed: _loading ? null : () => _loadAll(force: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_loc(context, 'تحديث', 'Refresh')),
              ),
            ),
            const SizedBox(height: 12),
            _buildFiltersPanel(context),
            const SizedBox(height: 12),
            _buildSummaryPanel(context),
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
            else if (visibleItems.isEmpty)
              GlassPanel(
                child: Text(
                  _loc(
                    context,
                    selectedType == _caseTypes.first
                        ? 'لا توجد قرارات مطابقة للفلاتر الحالية.'
                        : 'لا توجد قرارات ضمن نوع القضية المحدد.',
                    selectedType == _caseTypes.first
                        ? 'No decisions match the current filters.'
                        : 'No decisions for the selected case type.',
                  ),
                ),
              )
            else
              Column(
                children: [
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loc(
                            context,
                            'القرارات حسب نوع القضية',
                            'Decisions by Case Type',
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        ...sortedGroups.map(
                          (group) => _DecisionGroupPanel(
                            caseType: _localizeCaseType(context, group.key),
                            items: group.value,
                            onOpen: _openDecision,
                            dateOnly: _dateOnly,
                          ),
                        ),
                      ],
                    ),
                  ),
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
            await _loadAll();
          },
          decoration: InputDecoration(
            hintText: _loc(
              context,
              'بحث بالنص أو رقم القرار',
              'Search by text or decision number',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: TextField(
          controller: _courtController,
          onSubmitted: (_) async {
            await _loadAll();
          },
          decoration: InputDecoration(
            labelText: _loc(context, 'المحكمة', 'Court'),
            prefixIcon: const Icon(Icons.account_balance_rounded),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: TextField(
          controller: _domainController,
          onSubmitted: (_) async {
            await _loadAll();
          },
          decoration: InputDecoration(
            labelText: _loc(context, 'المجال القانوني', 'Legal Domain'),
            prefixIcon: const Icon(Icons.category_outlined),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 130,
        child: TextField(
          controller: _yearController,
          keyboardType: TextInputType.number,
          onSubmitted: (_) async {
            await _loadAll();
          },
          decoration: InputDecoration(
            labelText: _loc(context, 'السنة', 'Year'),
            hintText: '2026',
            prefixIcon: const Icon(Icons.calendar_today_rounded),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: DropdownButtonFormField<String>(
          initialValue: _selectedCaseType,
          decoration: InputDecoration(
            labelText: _loc(context, 'نوع القضية', 'Case Type'),
          ),
          items: _caseTypes
              .map(
                (type) => DropdownMenuItem<String>(
                  value: type,
                  child: Text(_localizeCaseType(context, type)),
                ),
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
          decoration: InputDecoration(
            labelText: _loc(context, 'مستوى المحكمة', 'Court Level'),
          ),
          items: _courtLevels
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.value,
                  child: Text(_localizeCourtLevelLabel(context, entry.value)),
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
            _loc(
              context,
              'فلترة واستعراض القرارات',
              'Filter and Browse Decisions',
            ),
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
                        await _loadAll();
                      },
                icon: const Icon(Icons.search_rounded),
                label: Text(_loc(context, 'بحث', 'Search')),
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
                label: Text(_loc(context, 'إعادة ضبط', 'Reset')),
              ),
              ElevatedButton.icon(
                onPressed: _showAddDecisionDialog,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(_loc(context, 'إضافة قرار', 'Add Decision')),
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
                label: Text(
                  _loc(
                    context,
                    'جلب القرارات الاستئنافية من المصدر العام',
                    'Sync appellate decisions from public source',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel(BuildContext context) {
    final total = _total;
    final selectedType = _canonicalCaseType(_selectedCaseType);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final summaryCardWidth = switch (maxWidth) {
          < 560 => maxWidth,
          < 1000 => (maxWidth - 10) / 2,
          _ => 220.0,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _loc(
                context,
                'عداد القرارات حسب نوع القضية (اضغط على النوع للعرض)',
                'Decision counters by case type (tap a type to view)',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryCard(
                  width: summaryCardWidth,
                  title: _selectedCourtLevel == 'appellate'
                      ? _loc(
                          context,
                          'كل الأنواع (استئنافي)',
                          'All Types (Appellate)',
                        )
                      : _loc(context, 'كل الأنواع', 'All Types'),
                  value: '$total',
                  icon: Icons.gavel_rounded,
                  color: LexiqColors.imperialBlue,
                  selected: selectedType == _caseTypes.first,
                  onTap: () =>
                      setState(() => _selectedCaseType = _caseTypes.first),
                ),
                ..._summaryItems.map((entry) {
                  final rawType = _canonicalCaseType(
                    (entry['caseType'] ?? 'other').toString(),
                  );
                  final caseType = _localizeCaseType(context, rawType);
                  final count = (entry['count'] ?? 0).toString();
                  final selected = selectedType == rawType;
                  return _SummaryCard(
                    width: summaryCardWidth,
                    title: caseType,
                    value: count,
                    icon: Icons.folder_special_rounded,
                    color: selected
                        ? LexiqColors.imperialBlue
                        : LexiqColors.brassGold,
                    selected: selected,
                    onTap: () => setState(() => _selectedCaseType = rawType),
                  );
                }),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.9)
                  : Colors.transparent,
              width: 1.3,
            ),
          ),
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
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected
                              ? LexiqColors.ivoryText
                              : LexiqColors.slateGray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
              ],
            ),
          ),
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

  bool _isArabic(BuildContext context) => Localizations.localeOf(
    context,
  ).languageCode.toLowerCase().startsWith('ar');

  String _loc(BuildContext context, String ar, String en) =>
      _isArabic(context) ? ar : en;

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
                  Chip(
                    label: Text(
                      _loc(context, 'المستوى: $level', 'Level: $level'),
                    ),
                  ),
                  if ((item['legalDomain'] ?? '').toString().trim().isNotEmpty)
                    Chip(
                      label: Text(
                        _loc(
                          context,
                          'المجال: ${(item['legalDomain'] ?? '').toString()}',
                          'Domain: ${(item['legalDomain'] ?? '').toString()}',
                        ),
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
                  label: Text(_loc(context, 'فتح القرار', 'Open Decision')),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DecisionCacheEntry {
  const _DecisionCacheEntry({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;
}
