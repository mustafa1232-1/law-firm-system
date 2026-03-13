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

class AiWorkspacePage extends ConsumerStatefulWidget {
  const AiWorkspacePage({super.key});

  @override
  ConsumerState<AiWorkspacePage> createState() => _AiWorkspacePageState();
}

class _AiWorkspacePageState extends ConsumerState<AiWorkspacePage> {
  final _queryController = TextEditingController();

  bool _searchConstitution = true;
  bool _searchLaws = true;
  bool _searchDecisions = true;
  bool _searchMyKnowledgeOnly = false;
  bool _loading = false;
  bool _loadingCases = false;
  bool _loadingDocuments = false;

  String? _selectedCaseId;
  final Set<String> _selectedDocumentIds = <String>{};
  List<Map<String, dynamic>> _cases = const [];
  List<Map<String, dynamic>> _documents = const [];

  Map<String, dynamic>? _result;
  String? _error;
  String? _sessionId;
  String? _analysisId;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadCases() async {
    setState(() => _loadingCases = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/cases',
        queryParameters: const {'limit': 200},
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final items = ((data['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      final nextCaseId = _selectedCaseId ?? (items.isNotEmpty ? items.first['_id']?.toString() : null);

      setState(() {
        _cases = items;
        _selectedCaseId = nextCaseId;
      });

      if (nextCaseId != null && nextCaseId.isNotEmpty) {
        await _loadDocumentsForCase(nextCaseId);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = parseApiError(error));
    } finally {
      if (mounted) {
        setState(() => _loadingCases = false);
      }
    }
  }

  Future<void> _loadDocumentsForCase(String caseId) async {
    setState(() {
      _loadingDocuments = true;
      _selectedDocumentIds.clear();
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/documents',
        queryParameters: {
          'caseId': caseId,
          'limit': 300,
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

      setState(() => _documents = items);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _documents = const []);
    } finally {
      if (mounted) {
        setState(() => _loadingDocuments = false);
      }
    }
  }

  Future<void> _pickDocuments() async {
    if (_documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مستندات مرتبطة بهذه القضية.')),
      );
      return;
    }

    final temp = <String>{..._selectedDocumentIds};

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اختر المستندات المرتبطة'),
          content: SizedBox(
            width: 720,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                final item = _documents[index];
                final id = (item['_id'] ?? '').toString();
                final selected = temp.contains(id);
                return CheckboxListTile(
                  value: selected,
                  title: Text((item['title'] ?? '-').toString()),
                  subtitle: Text((item['originalName'] ?? '').toString()),
                  onChanged: (_) {
                    setDialogState(() {
                      if (selected) {
                        temp.remove(id);
                      } else {
                        temp.add(id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('Close')),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedDocumentIds
                    ..clear()
                    ..addAll(temp);
                });
                Navigator.of(context).pop();
              },
              child: const Text('اعتماد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAnalysis() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter case facts or a legal question.'))),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/ai/legal-research',
        data: {
          'query': query,
          'caseId': _selectedCaseId,
          'sessionId': _sessionId,
          'documentIds': _selectedDocumentIds.toList(),
          'searchConstitution': _searchConstitution,
          'searchLaws': _searchLaws,
          'searchDecisions': _searchDecisions,
          'searchMyKnowledgeOnly': _searchMyKnowledgeOnly,
        },
        options: Options(headers: authHeaders(ref)),
      );

      if (!mounted) {
        return;
      }

      final payload = (response.data as Map).cast<String, dynamic>();
      setState(() {
        _result = payload;
        _analysisId = (payload['analysisId'] ?? '').toString().trim().isEmpty
            ? _analysisId
            : (payload['analysisId'] ?? '').toString();
        _sessionId = (payload['sessionId'] ?? '').toString().trim().isEmpty
            ? _sessionId
            : (payload['sessionId'] ?? '').toString();
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

  Future<void> _convertToMemo() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Enter content before converting to memo.'))),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/ai/memo-draft',
        data: {
          'topic': query.split('\n').first,
          'facts': query,
          'caseId': _selectedCaseId,
        },
        options: Options(headers: authHeaders(ref)),
      );

      final memo = (response.data as Map).cast<String, dynamic>();
      if (!mounted) {
        return;
      }

      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text((memo['title'] ?? context.tr('Draft Memo')).toString()),
          content: SingleChildScrollView(
            child: Text((memo['body'] ?? '').toString()),
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
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveAnalysis() async {
    if (_result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Run analysis first to save results.'))),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = await dio.post(
        '/ai/analyses/save',
        data: {
          'sessionId': _sessionId,
          'caseId': _selectedCaseId,
          'analysisType': 'legal-research',
          'inputText': _queryController.text.trim(),
          'output': _result,
          'citations': (_result?['suggestedAuthorities'] as List?) ?? const [],
          'confidenceScore': (_result?['confidence'] as num?)?.toDouble() ?? 0.5,
        },
        options: Options(headers: authHeaders(ref)),
      );

      final data = (payload.data as Map).cast<String, dynamic>();
      setState(() {
        _analysisId = (data['analysisId'] ?? '').toString();
        _sessionId = (data['sessionId'] ?? _sessionId).toString();
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التحليل في قاعدة البيانات بنجاح.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _attachAnalysisToCase() async {
    if ((_analysisId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('شغّل التحليل أولًا أو احفظه ثم أعد المحاولة.')),
      );
      return;
    }
    if ((_selectedCaseId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر القضية المرتبطة أولًا.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/ai/analyses/$_analysisId/attach-case',
        data: {
          'caseId': _selectedCaseId,
        },
        options: Options(headers: authHeaders(ref)),
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم ربط التحليل بالقضية وتحديث ملف القضية.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestedAuthorities = ((_result?['suggestedAuthorities'] as List?) ?? const [])
        .map((entry) => (entry as Map).cast<String, dynamic>())
        .toList();

    final extractedIssues = ((_result?['extractedIssues'] as List?) ?? const [])
        .map((entry) => entry.toString())
        .toList();

    final proposedQuestions = ((_result?['proposedQuestions'] as List?) ?? const [])
        .map((entry) => entry.toString())
        .toList();

    final confidence = (_result?['confidence'] as num?)?.toDouble() ?? 0;

    final selectedCaseValue = _cases.any((entry) => entry['_id']?.toString() == _selectedCaseId)
        ? _selectedCaseId
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'AI Legal Workspace',
            subtitle: 'Grounded legal research and case analysis',
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              children: [
                TextField(
                  controller: _queryController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: context.tr('Describe the case facts or ask a legal question'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
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
                        onChanged: _loadingCases
                            ? null
                            : (value) async {
                                setState(() => _selectedCaseId = value);
                                if (value != null && value.isNotEmpty) {
                                  await _loadDocumentsForCase(value);
                                } else {
                                  setState(() {
                                    _documents = const [];
                                    _selectedDocumentIds.clear();
                                  });
                                }
                              },
                        decoration: InputDecoration(
                          labelText: _loadingCases ? 'جاري تحميل القضايا...' : 'القضية المرتبطة',
                          prefixIcon: const Icon(Icons.balance_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _loadingDocuments ? null : _pickDocuments,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: _loadingDocuments
                                ? 'جاري تحميل المستندات...'
                                : 'المستندات المرتبطة',
                            prefixIcon: const Icon(Icons.description_rounded),
                          ),
                          child: Text(
                            _selectedDocumentIds.isEmpty
                                ? 'اختر المستندات من القضية'
                                : 'تم اختيار ${_selectedDocumentIds.length} مستند',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedDocumentIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedDocumentIds
                        .map(
                          (id) => Chip(
                            label: Text(id.substring(0, id.length > 8 ? 8 : id.length)),
                            onDeleted: () => setState(() => _selectedDocumentIds.remove(id)),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToggleChip(
                      label: 'Search Constitution',
                      selected: _searchConstitution,
                      onChanged: (value) => setState(() => _searchConstitution = value),
                    ),
                    _ToggleChip(
                      label: 'Search Laws',
                      selected: _searchLaws,
                      onChanged: (value) => setState(() => _searchLaws = value),
                    ),
                    _ToggleChip(
                      label: 'Search Decisions',
                      selected: _searchDecisions,
                      onChanged: (value) => setState(() => _searchDecisions = value),
                    ),
                    _ToggleChip(
                      label: 'Only Firm Knowledge',
                      selected: _searchMyKnowledgeOnly,
                      onChanged: (value) => setState(() => _searchMyKnowledgeOnly = value),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 220,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _saveAnalysis,
                        icon: const Icon(Icons.save_alt_rounded),
                        label: Text(context.tr('Save Analysis')),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _runAnalysis,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: Text(context.tr('Run Analysis')),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _convertToMemo,
                        icon: const Icon(Icons.article_rounded),
                        label: Text(context.tr('Convert to Memo')),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _attachAnalysisToCase,
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('إرفاق بالقضية'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Results'), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_error != null)
                        Text(_error!)
                      else if (_result == null)
                        Text(context.tr('Citation-aware grounded answer appears here.'))
                      else ...[
                        Text((_result?['summary'] ?? '').toString()),
                        const SizedBox(height: 8),
                        Text((_result?['groundedAnswer'] ?? '').toString()),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(
                            'AI output is preliminary and must be reviewed by a licensed lawyer.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: LexiqColors.brassGold,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Confidence'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: confidence.clamp(0, 1)),
                          const SizedBox(height: 8),
                          Text('${(confidence * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Suggested Authorities'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (suggestedAuthorities.isEmpty)
                            Text(context.tr('No suggested authorities yet.'))
                          else
                            ...suggestedAuthorities.map((item) {
                              final citation = (item['citation'] ?? '-').toString();
                              final sourceType = (item['sourceType'] ?? '-').toString();
                              return _authority(
                                context,
                                item,
                                '$citation ($sourceType)',
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
                            context.tr('Extracted Issues'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (extractedIssues.isEmpty)
                            Text(context.tr('No extracted issues yet.'))
                          else
                            ...extractedIssues.map((issue) => Text('• $issue')),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('Proposed Questions'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (proposedQuestions.isEmpty)
                            Text(context.tr('No proposed questions yet.'))
                          else
                            ...proposedQuestions.map((question) => Text('• $question')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _authority(
    BuildContext context,
    Map<String, dynamic> source,
    String item,
  ) {
    final sourceType = (source['sourceType'] ?? '').toString();
    final id = (source['id'] ?? '').toString();

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item),
      subtitle: const Text('اضغط لفتح المرجعية والنص القانوني'),
      trailing: const Icon(Icons.open_in_new_rounded),
      onTap: (sourceType.isEmpty || id.isEmpty)
          ? null
          : () => context.go('/authority/$sourceType/$id'),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(context.tr(label)),
      onSelected: onChanged,
    );
  }
}
