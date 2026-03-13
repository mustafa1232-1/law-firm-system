import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

final _caseDetailsProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, caseId) async {
  final dio = ref.watch(dioProvider);
  final token = ref.read(accessTokenProvider);
  final response = await dio.get(
    '/cases/$caseId',
    options: Options(
      headers: token == null ? const <String, String>{} : {'Authorization': 'Bearer $token'},
    ),
  );
  return (response.data as Map).cast<String, dynamic>();
});

class CaseDetailsPage extends ConsumerStatefulWidget {
  const CaseDetailsPage({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<CaseDetailsPage> createState() => _CaseDetailsPageState();
}

class _CaseDetailsPageState extends ConsumerState<CaseDetailsPage> {
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysis;

  Future<void> _runAnalysis(Map<String, dynamic> caseItem) async {
    setState(() => _isAnalyzing = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/cases/${widget.caseId}/analyze',
        data: const <String, dynamic>{},
        options: Options(headers: authHeaders(ref)),
      );
      if (!mounted) {
        return;
      }

      setState(() => _analysis = (response.data as Map).cast<String, dynamic>());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء تحليل AI للقضية.')),
      );
      ref.invalidate(_caseDetailsProvider(widget.caseId));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCase = ref.watch(_caseDetailsProvider(widget.caseId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: asyncCase.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Text(parseApiError(error)),
        data: (caseItem) {
          final timeline = ((caseItem['timeline'] as List?) ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
          final evidence = <String>[
            ...((caseItem['evidenceList'] as List?) ?? const [])
                .map((e) => e.toString()),
            ...((caseItem['evidenceEntries'] as List?) ?? const [])
                .map((entry) => (entry as Map).cast<String, dynamic>())
                .map((entry) {
                  final desc = (entry['description'] ?? '').toString();
                  final name = (entry['attachmentName'] ?? '').toString();
                  if (name.isEmpty) return desc;
                  if (desc.isEmpty) return name;
                  return '$name | $desc';
                }),
          ].where((item) => item.trim().isNotEmpty).toSet().toList();
          final riskScore = (caseItem['riskScore'] as num?)?.toInt() ?? 0;
          final aiInsights = (caseItem['aiInsights'] as Map?)?.cast<String, dynamic>() ?? const {};
          final suggestions = (_analysis?['suggestions'] as Map?)?.cast<String, dynamic>() ?? const {};
          final caseGenome = (_analysis?['caseGenome'] as Map?)?.cast<String, dynamic>() ??
              ((caseItem['caseGenome'] as Map?)?.cast<String, dynamic>() ?? const {});

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: context.tr('Case Details | {caseId}', {'caseId': widget.caseId}),
                subtitle: 'Case Genome, timeline, evidence, and AI suggestions',
                trailing: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : () => _runAnalysis(caseItem),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: _isAnalyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('Analyze')),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${caseItem['title'] ?? '-'} | ${caseItem['caseNumber'] ?? '-'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(context, 'Type: ${caseItem['caseType'] ?? '-'}'),
                  _pill(context, 'Court: ${caseItem['court'] ?? '-'}'),
                  _pill(context, 'Status: ${caseItem['status'] ?? '-'}'),
                  _pill(context, 'Risk: $riskScore%'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('Timeline'), style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (timeline.isEmpty)
                            const Text('لا يوجد خط زمني بعد.')
                          else
                            ...timeline.map(
                              (entry) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.timeline_rounded),
                                title: Text((entry['title'] ?? '-').toString()),
                                subtitle: Text((entry['details'] ?? '').toString()),
                                trailing: Text(
                                  ((entry['eventDate'] ?? '').toString()).split('T').first,
                                ),
                              ),
                            ),
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
                                context.tr('Evidence Checklist'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              if (evidence.isEmpty)
                                const Text('لم يتم إضافة أدلة بعد.')
                              else
                                ...evidence.map((item) => _evidenceTile(context, item)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('AI Suggestions'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              if (caseGenome.isEmpty && aiInsights.isEmpty && suggestions.isEmpty)
                                const Text('شغّل التحليل لإظهار المقترحات القانونية.')
                              else ...[
                                if (caseGenome['suggestedConstitutionArticles'] != null)
                                  _hint(
                                    context,
                                    'Constitution article',
                                    (caseGenome['suggestedConstitutionArticles'] as List).join(', '),
                                  ),
                                if (caseGenome['suggestedLegalArticles'] != null)
                                  _hint(
                                    context,
                                    'Legal article',
                                    (caseGenome['suggestedLegalArticles'] as List).join(', '),
                                  ),
                                if (caseGenome['similarDecisions'] != null)
                                  _hint(
                                    context,
                                    'Similar decision',
                                    (caseGenome['similarDecisions'] as List).join(', '),
                                  ),
                                if (suggestions['missingDocuments'] is List)
                                  _hint(
                                    context,
                                    'Missing documents',
                                    (suggestions['missingDocuments'] as List).join(' | '),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _evidenceTile(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 18, color: LexiqColors.emeraldJustice),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  Widget _hint(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(title),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
      ),
    );
  }
}

