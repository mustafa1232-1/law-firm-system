import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class HearingsCalendarPage extends ConsumerStatefulWidget {
  const HearingsCalendarPage({super.key});

  @override
  ConsumerState<HearingsCalendarPage> createState() =>
      _HearingsCalendarPageState();
}

class _HearingsCalendarPageState extends ConsumerState<HearingsCalendarPage> {
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _hearings = const [];
  List<Map<String, dynamic>> _cases = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final responses = await Future.wait([
        dio.get(
          '/hearings',
          queryParameters: const {'limit': 100},
          options: Options(headers: authHeaders(ref)),
        ),
        dio.get(
          '/cases',
          queryParameters: const {'limit': 100},
          options: Options(headers: authHeaders(ref)),
        ),
      ]);

      final hearingsData = (responses[0].data as Map).cast<String, dynamic>();
      final casesData = (responses[1].data as Map).cast<String, dynamic>();

      final hearings = ((hearingsData['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      final cases = ((casesData['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _hearings = hearings;
        _cases = cases;
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

  Future<void> _showCreateHearingDialog() async {
    if (_cases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إنشاء جلسة بدون وجود قضية واحدة على الأقل.'),
        ),
      );
      return;
    }

    String? selectedCaseId = _idOf(_cases.first);
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));

    final courtController = TextEditingController();
    final roomController = TextEditingController();
    final judgeController = TextEditingController();
    final notesController = TextEditingController();
    final requiredDocsController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إنشاء جلسة'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCaseId,
                    decoration: const InputDecoration(labelText: 'القضية *'),
                    items: _cases
                        .map(
                          (caseItem) => DropdownMenuItem(
                            value: _idOf(caseItem),
                            child: Text(
                              '${(caseItem['caseNumber'] ?? '-').toString()} - ${(caseItem['title'] ?? '-').toString()}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedCaseId = value),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ ووقت الجلسة *'),
                    subtitle: Text(
                      selectedDateTime
                          .toIso8601String()
                          .replaceFirst('T', ' ')
                          .substring(0, 16),
                    ),
                    trailing: const Icon(Icons.event_rounded),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: selectedDateTime,
                      );
                      if (date == null) {
                        return;
                      }

                      if (!context.mounted) {
                        return;
                      }

                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                      );

                      if (time == null) {
                        return;
                      }

                      setDialogState(() {
                        selectedDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: courtController,
                    decoration: const InputDecoration(labelText: 'المحكمة'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(labelText: 'القاعة'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: judgeController,
                    decoration: const InputDecoration(labelText: 'القاضي'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: requiredDocsController,
                    decoration: const InputDecoration(
                      labelText: 'المستندات المطلوبة (مفصولة بفاصلة)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('Close')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedCaseId == null || selectedCaseId!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اختيار القضية مطلوب.')),
                  );
                  return;
                }

                try {
                  final dio = ref.read(dioProvider);
                  await dio.post(
                    '/hearings',
                    data: {
                      'caseId': selectedCaseId,
                      'hearingDate': selectedDateTime.toIso8601String(),
                      'court': courtController.text.trim().isEmpty
                          ? null
                          : courtController.text.trim(),
                      'room': roomController.text.trim().isEmpty
                          ? null
                          : roomController.text.trim(),
                      'judge': judgeController.text.trim().isEmpty
                          ? null
                          : judgeController.text.trim(),
                      'notes': notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                      'requiredDocuments': requiredDocsController.text
                          .split(',')
                          .map((entry) => entry.trim())
                          .where((entry) => entry.isNotEmpty)
                          .toList(),
                    },
                    options: Options(headers: authHeaders(ref)),
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

    courtController.dispose();
    roomController.dispose();
    judgeController.dispose();
    notesController.dispose();
    requiredDocsController.dispose();

    if (created == true) {
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء الجلسة بنجاح.')));
    }
  }

  Future<void> _showUpdateOutcomeDialog(Map<String, dynamic> hearing) async {
    final hearingId = _idOf(hearing);
    if (hearingId == null) {
      return;
    }

    final outcomeController = TextEditingController(
      text: (hearing['outcome'] ?? '').toString(),
    );
    final nextActionController = TextEditingController(
      text: (hearing['nextAction'] ?? '').toString(),
    );
    final notesController = TextEditingController(
      text: (hearing['notes'] ?? '').toString(),
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديث نتيجة الجلسة'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: outcomeController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'النتيجة'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nextActionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'الإجراء التالي',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Close')),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final dio = ref.read(dioProvider);
                await dio.patch(
                  '/hearings/$hearingId',
                  data: {
                    'outcome': outcomeController.text.trim().isEmpty
                        ? null
                        : outcomeController.text.trim(),
                    'nextAction': nextActionController.text.trim().isEmpty
                        ? null
                        : nextActionController.text.trim(),
                    'notes': notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  },
                  options: Options(headers: authHeaders(ref)),
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
            child: const Text('تحديث'),
          ),
        ],
      ),
    );

    outcomeController.dispose();
    nextActionController.dispose();
    notesController.dispose();

    if (updated == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Hearings Calendar',
            subtitle: 'Schedule hearings and track outcomes and next actions',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _loading ? null : _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: _showCreateHearingDialog,
                  icon: const Icon(Icons.add_alert_rounded),
                  label: Text(context.tr('New Hearing')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Text(_error!)
                : _hearings.isEmpty
                ? const Text('لا توجد جلسات بعد.')
                : Column(
                    children: _hearings.map((hearing) {
                      final caseData = (hearing['caseId'] is Map)
                          ? (hearing['caseId'] as Map).cast<String, dynamic>()
                          : <String, dynamic>{};

                      final dateLabel = (hearing['hearingDate'] ?? '')
                          .toString()
                          .replaceFirst('T', ' ')
                          .split('.')
                          .first;

                      final requiredDocs =
                          ((hearing['requiredDocuments'] as List?) ?? const [])
                              .map((entry) => entry.toString())
                              .toList();

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_note_rounded),
                        title: Text(
                          '${(caseData['caseNumber'] ?? '-').toString()} - ${(caseData['title'] ?? '-').toString()}',
                        ),
                        subtitle: Text(
                          'التاريخ: $dateLabel\nالمحكمة: ${(hearing['court'] ?? '-').toString()} | القاضي: ${(hearing['judge'] ?? '-').toString()}\nالنتيجة: ${(hearing['outcome'] ?? '-').toString()}\nالمستندات: ${requiredDocs.isEmpty ? '-' : requiredDocs.join(' | ')}',
                        ),
                        isThreeLine: true,
                        trailing: OutlinedButton(
                          onPressed: () => _showUpdateOutcomeDialog(hearing),
                          child: const Text('Update'),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  String? _idOf(Map<String, dynamic> value) {
    final id = value['_id'] ?? value['id'];
    if (id == null) {
      return null;
    }
    return id.toString();
  }
}
