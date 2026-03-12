import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _caseIdController = TextEditingController();
  final _documentIdsController = TextEditingController();

  bool _searchConstitution = true;
  bool _searchLaws = true;
  bool _searchDecisions = true;
  bool _searchMyKnowledgeOnly = false;
  bool _loading = false;

  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    _caseIdController.dispose();
    _documentIdsController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال وصف القضية أو السؤال القانوني.')),
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
          'caseId': _caseIdController.text.trim().isEmpty ? null : _caseIdController.text.trim(),
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
      setState(() => _result = (response.data as Map).cast<String, dynamic>());
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
        const SnackBar(content: Text('أدخل موضوعًا قبل تحويله إلى مذكرة.')),
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
          'caseId': _caseIdController.text.trim().isEmpty ? null : _caseIdController.text.trim(),
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
          title: Text((memo['title'] ?? 'Draft Memo').toString()),
          content: SingleChildScrollView(
            child: Text((memo['body'] ?? '').toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestedAuthorities = ((_result?['suggestedAuthorities'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final extractedIssues = ((_result?['extractedIssues'] as List?) ?? const []).map((e) => e.toString()).toList();
    final proposedQuestions = ((_result?['proposedQuestions'] as List?) ?? const []).map((e) => e.toString()).toList();
    final confidence = (_result?['confidence'] as num?)?.toDouble() ?? 0;

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
                      child: TextField(
                        controller: _caseIdController,
                        decoration: const InputDecoration(labelText: 'Attached case ID'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _documentIdsController,
                        decoration: const InputDecoration(labelText: 'Attached document IDs'),
                      ),
                    ),
                  ],
                ),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم حفظ التحليل في الجلسة الحالية.')),
                                );
                              },
                        icon: const Icon(Icons.save_alt_rounded),
                        label: Text(context.tr('Save Analysis')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _runAnalysis,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Run Analysis'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _convertToMemo,
                        icon: const Icon(Icons.article_rounded),
                        label: Text(context.tr('Convert to Memo')),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: LexiqColors.brassGold),
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
                            const Text('لا توجد مراجع مقترحة بعد.')
                          else
                            ...suggestedAuthorities.map((item) {
                              final citation = (item['citation'] ?? '-').toString();
                              final sourceType = (item['sourceType'] ?? '-').toString();
                              return _authority(context, '$citation ($sourceType)');
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Extracted Issues', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (extractedIssues.isEmpty)
                            const Text('لا توجد نقاط مستخرجة بعد.')
                          else
                            ...extractedIssues.map((issue) => Text('• $issue')),
                          const SizedBox(height: 12),
                          const Text('Proposed Questions', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (proposedQuestions.isEmpty)
                            const Text('لا توجد أسئلة مقترحة بعد.')
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

  Widget _authority(BuildContext context, String item) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item),
      trailing: const Icon(Icons.push_pin_outlined),
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
