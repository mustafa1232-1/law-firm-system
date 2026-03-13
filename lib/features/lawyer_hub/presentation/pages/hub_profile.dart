import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class LawyerHubPage extends ConsumerStatefulWidget {
  const LawyerHubPage({super.key});

  @override
  ConsumerState<LawyerHubPage> createState() => _LawyerHubPageState();
}

class _LawyerHubPageState extends ConsumerState<LawyerHubPage> {
  bool _loading = false;
  bool _runningRecommendations = false;
  String? _error;

  List<Map<String, dynamic>> _cases = const [];
  List<Map<String, dynamic>> _hearings = const [];
  List<Map<String, dynamic>> _tasks = const [];
  List<Map<String, dynamic>> _researchFolders = const [];

  String? _selectedCaseId;
  Map<String, dynamic>? _selectedCaseDetails;
  Map<String, dynamic>? _aiResearchResult;

  @override
  void initState() {
    super.initState();
    _loadHubData();
  }

  Future<void> _loadHubData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final options = Options(headers: authHeaders(ref));

      final responses = await Future.wait([
        dio.get(
          '/cases',
          queryParameters: const {'limit': 100},
          options: options,
        ),
        dio.get(
          '/hearings',
          queryParameters: const {'limit': 100},
          options: options,
        ),
        dio.get(
          '/tasks',
          queryParameters: const {'limit': 100},
          options: options,
        ),
        dio.get('/research/folders', options: options),
      ]);

      final casesData = (responses[0].data as Map).cast<String, dynamic>();
      final hearingsData = (responses[1].data as Map).cast<String, dynamic>();
      final tasksData = (responses[2].data as Map).cast<String, dynamic>();

      final caseItems = ((casesData['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final hearingItems = ((hearingsData['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final taskItems = ((tasksData['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final folderItems = ((responses[3].data as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      final now = DateTime.now();
      hearingItems.sort((a, b) {
        final aDate = DateTime.tryParse((a['hearingDate'] ?? '').toString());
        final bDate = DateTime.tryParse((b['hearingDate'] ?? '').toString());
        return (aDate ?? DateTime(now.year + 10)).compareTo(
          bDate ?? DateTime(now.year + 10),
        );
      });

      taskItems.sort((a, b) {
        final aDate = DateTime.tryParse((a['dueDate'] ?? '').toString());
        final bDate = DateTime.tryParse((b['dueDate'] ?? '').toString());
        return (aDate ?? DateTime(now.year + 10)).compareTo(
          bDate ?? DateTime(now.year + 10),
        );
      });

      final selectedId =
          _selectedCaseId ??
          (caseItems.isNotEmpty ? caseItems.first['_id']?.toString() : null);

      if (!mounted) {
        return;
      }

      setState(() {
        _cases = caseItems;
        _hearings = hearingItems.where((item) {
          final date = DateTime.tryParse(
            (item['hearingDate'] ?? '').toString(),
          );
          return date == null ||
              date.isAfter(now.subtract(const Duration(days: 1)));
        }).toList();
        _tasks = taskItems;
        _researchFolders = folderItems;
        _selectedCaseId = selectedId;
      });

      if (selectedId != null) {
        await _loadCaseDetails(selectedId, silent: true);
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

  Future<void> _loadCaseDetails(String caseId, {bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/cases/$caseId',
        options: Options(headers: authHeaders(ref)),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedCaseDetails = (response.data as Map).cast<String, dynamic>();
        _aiResearchResult = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = parseApiError(error));
    } finally {
      if (!silent && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshAiRecommendations() async {
    final caseDetails = _selectedCaseDetails;
    if (caseDetails == null) {
      return;
    }

    final query = [
      (caseDetails['title'] ?? '').toString(),
      (caseDetails['summary'] ?? '').toString(),
      (caseDetails['facts'] ?? '').toString(),
      (caseDetails['claims'] ?? '').toString(),
    ].where((part) => part.trim().isNotEmpty).join('\n');

    if (query.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إضافة ملخص أو وقائع للقضية أولًا.')),
      );
      return;
    }

    setState(() => _runningRecommendations = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/ai/legal-research',
        data: {
          'query': query,
          'caseId': _selectedCaseId,
          'searchConstitution': true,
          'searchLaws': true,
          'searchDecisions': true,
        },
        options: Options(headers: authHeaders(ref)),
      );

      if (!mounted) {
        return;
      }

      setState(
        () =>
            _aiResearchResult = (response.data as Map).cast<String, dynamic>(),
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
        setState(() => _runningRecommendations = false);
      }
    }
  }

  Future<void> _runCaseAnalysis() async {
    final caseId = _selectedCaseId;
    if (caseId == null) {
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/cases/$caseId/analyze',
        data: const {'context': 'تحليل محدث من مركز ذكاء المحامي'},
        options: Options(headers: authHeaders(ref)),
      );

      await _loadCaseDetails(caseId, silent: true);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث تحليل القضية بنجاح.')),
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

  @override
  Widget build(BuildContext context) {
    final activeCases = _cases.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      return status != 'closed' && status != 'archived';
    }).toList();
    final pendingTasks = _tasks.where((item) {
      final status = (item['status'] ?? '').toString().toLowerCase();
      return status != 'done' && status != 'cancelled';
    }).toList();

    final linkedConstitution =
        ((_selectedCaseDetails?['linkedConstitutionArticleIds'] as List?) ??
                const [])
            .map((item) => item.toString())
            .toList();
    final linkedLaws =
        ((_selectedCaseDetails?['linkedLawArticleIds'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList();
    final linkedDecisions =
        ((_selectedCaseDetails?['linkedDecisionIds'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList();

    final aiAuthorities =
        ((_aiResearchResult?['suggestedAuthorities'] as List?) ?? const [])
            .map((item) => (item as Map).cast<String, dynamic>())
            .toList();
    final selectedCaseValue =
        _cases.any((item) => item['_id']?.toString() == _selectedCaseId)
        ? _selectedCaseId
        : null;
    final isCompact = MediaQuery.sizeOf(context).width < 1100;

    final missingDocs =
        (((_selectedCaseDetails?['aiInsights'] as Map?)
                        ?.cast<String, dynamic>()['missingDocuments']
                    as List?) ??
                const [])
            .map((item) => item.toString())
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Lawyer Intelligence Hub',
            subtitle:
                'Active cases, hearings, tasks, and recommended authorities',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _selectedCaseId == null ? null : _runCaseAnalysis,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('تحليل القضية'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _runningRecommendations
                      ? null
                      : _refreshAiRecommendations,
                  icon: _runningRecommendations
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology_alt_rounded),
                  label: const Text('تحديث التوصيات'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loading ? null : _loadHubData,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.folder_special_rounded,
                            color: LexiqColors.brassGold,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'القضية الحالية',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCaseValue,
                        items: _cases
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item['_id']?.toString(),
                                child: Text(
                                  '${(item['caseNumber'] ?? '-').toString()} - ${(item['title'] ?? '-').toString()}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) {
                            return;
                          }
                          setState(() => _selectedCaseId = value);
                          await _loadCaseDetails(value);
                        },
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _selectedCaseId == null
                              ? null
                              : () => context.go('/cases/$_selectedCaseId'),
                          child: const Text('فتح القضية'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.folder_special_rounded,
                        color: LexiqColors.brassGold,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'القضية الحالية',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCaseValue,
                          items: _cases
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item['_id']?.toString(),
                                  child: Text(
                                    '${(item['caseNumber'] ?? '-').toString()} - ${(item['title'] ?? '-').toString()}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedCaseId = value);
                            await _loadCaseDetails(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _selectedCaseId == null
                            ? null
                            : () => context.go('/cases/$_selectedCaseId'),
                        child: const Text('فتح القضية'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: LexiqColors.crimsonAlert),
              ),
            ),
          if (isCompact) ...[
            _leftHubColumn(context, activeCases, pendingTasks),
            const SizedBox(height: 12),
            _rightHubColumn(
              context,
              linkedConstitution: linkedConstitution,
              linkedLaws: linkedLaws,
              linkedDecisions: linkedDecisions,
              aiAuthorities: aiAuthorities,
              missingDocs: missingDocs,
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _leftHubColumn(context, activeCases, pendingTasks),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _rightHubColumn(
                    context,
                    linkedConstitution: linkedConstitution,
                    linkedLaws: linkedLaws,
                    linkedDecisions: linkedDecisions,
                    aiAuthorities: aiAuthorities,
                    missingDocs: missingDocs,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _leftHubColumn(
    BuildContext context,
    List<Map<String, dynamic>> activeCases,
    List<Map<String, dynamic>> pendingTasks,
  ) {
    return Column(
      children: [
        _listPanel(
          context,
          title: 'قضاياي النشطة (${activeCases.length})',
          icon: Icons.balance_rounded,
          items: activeCases
              .take(8)
              .map(
                (item) =>
                    '${(item['caseNumber'] ?? '-').toString()} - ${(item['title'] ?? '-').toString()}',
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        _listPanel(
          context,
          title: 'الجلسات القادمة (${_hearings.length})',
          icon: Icons.event_available_rounded,
          items: _hearings.take(8).map((item) {
            final date = _dateOnly(item['hearingDate']);
            final caseTitle = ((item['caseId'] as Map?)?['title'] ?? '-')
                .toString();
            return '$date - $caseTitle';
          }).toList(),
        ),
        const SizedBox(height: 12),
        _listPanel(
          context,
          title: 'المهام (${pendingTasks.length})',
          icon: Icons.task_rounded,
          items: pendingTasks.take(8).map((item) {
            final due = _dateOnly(item['dueDate']);
            return '${(item['title'] ?? '-').toString()} (${(item['priority'] ?? '-').toString()}) - $due';
          }).toList(),
        ),
        const SizedBox(height: 12),
        _listPanel(
          context,
          title: 'آخر الأبحاث المحفوظة (${_researchFolders.length})',
          icon: Icons.folder_open_rounded,
          items: _researchFolders
              .take(6)
              .map((item) => (item['title'] ?? '-').toString())
              .toList(),
        ),
      ],
    );
  }

  Widget _rightHubColumn(
    BuildContext context, {
    required List<String> linkedConstitution,
    required List<String> linkedLaws,
    required List<String> linkedDecisions,
    required List<Map<String, dynamic>> aiAuthorities,
    required List<String> missingDocs,
  }) {
    return Column(
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Recommended Authorities'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chipGroup(
                    'مواد دستورية مرتبطة',
                    linkedConstitution,
                    LexiqColors.imperialBlue,
                    authorityType: 'constitution',
                  ),
                  _chipGroup(
                    'مواد قانونية مرتبطة',
                    linkedLaws,
                    LexiqColors.emeraldJustice,
                    authorityType: 'law',
                  ),
                  _chipGroup(
                    'قرارات مرتبطة',
                    linkedDecisions,
                    LexiqColors.brassGold,
                    authorityType: 'decision',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (aiAuthorities.isEmpty)
                const Text(
                  'لا توجد توصيات AI بعد. اختر قضية ثم اضغط "تحديث التوصيات".',
                )
              else
                ...aiAuthorities.take(8).map((entry) {
                  final citation = (entry['citation'] ?? '-').toString();
                  final sourceType = (entry['sourceType'] ?? '-').toString();
                  final authorityId = (entry['id'] ?? '').toString().trim();
                  final canOpen =
                      authorityId.isNotEmpty &&
                      (sourceType == 'constitution' ||
                          sourceType == 'law' ||
                          sourceType == 'decision');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_rounded),
                    title: Text(citation),
                    subtitle: Text('المصدر: $sourceType'),
                    trailing: canOpen
                        ? const Icon(Icons.open_in_new_rounded)
                        : null,
                    onTap: canOpen
                        ? () =>
                              context.go('/authority/$sourceType/$authorityId')
                        : null,
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تنبيهات المستندات الناقصة',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (missingDocs.isEmpty)
                const Text('لا توجد تنبيهات مستندات حاليًا.')
              else
                ...missingDocs.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: LexiqColors.brassGold,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(doc)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go('/cases/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('قضية جديدة'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/research'),
                icon: const Icon(Icons.travel_explore_rounded),
                label: const Text('فتح البحث القانوني'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/ai-workspace'),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('فتح AI Workspace'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _listPanel(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: LexiqColors.brassGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (items.isEmpty)
            const Text('لا توجد بيانات حالياً.')
          else
            ...items.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('- $line'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipGroup(
    String label,
    List<String> values,
    Color color, {
    String? authorityType,
  }) {
    final trimmed = values.where((v) => v.trim().isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (trimmed.isEmpty)
              const Text('لا يوجد')
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: trimmed.take(8).map((entry) {
                  if (authorityType == null) {
                    return Chip(label: Text(entry));
                  }
                  return ActionChip(
                    label: Text(entry),
                    onPressed: () =>
                        context.go('/authority/$authorityType/$entry'),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _dateOnly(dynamic value) {
    final raw = (value ?? '').toString();
    if (raw.isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }
}
