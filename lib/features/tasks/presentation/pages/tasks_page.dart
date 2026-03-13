import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  static const _statusOptions = ['open', 'in_progress', 'done', 'cancelled'];
  static const _priorityOptions = ['low', 'medium', 'high', 'urgent'];

  bool _loading = false;
  String? _error;

  String _statusFilter = '';
  List<Map<String, dynamic>> _tasks = const [];
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
          '/tasks',
          queryParameters: {
            'limit': 100,
            if (_statusFilter.isNotEmpty) 'status': _statusFilter,
          },
          options: Options(headers: authHeaders(ref)),
        ),
        dio.get(
          '/cases',
          queryParameters: const {'limit': 100},
          options: Options(headers: authHeaders(ref)),
        ),
      ]);

      final tasksData = (responses[0].data as Map).cast<String, dynamic>();
      final casesData = (responses[1].data as Map).cast<String, dynamic>();

      final tasks = ((tasksData['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      final cases = ((casesData['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _tasks = tasks;
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

  Future<void> _showCreateTaskDialog() async {
    String? selectedCaseId;
    String selectedPriority = 'medium';
    DateTime? dueDate;
    DateTime? reminderDate;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مهمة'),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 600.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'العنوان *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'الوصف'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCaseId,
                    decoration: const InputDecoration(
                      labelText: 'القضية المرتبطة (اختياري)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('بدون ربط'),
                      ),
                      ..._cases.map(
                        (caseItem) => DropdownMenuItem<String?>(
                          value: _idOf(caseItem),
                          child: Text(
                            '${(caseItem['caseNumber'] ?? '-').toString()} - ${(caseItem['title'] ?? '-').toString()}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedCaseId = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPriority,
                    decoration: const InputDecoration(labelText: 'الأولوية'),
                    items: _priorityOptions
                        .map(
                          (priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(_priorityLabel(priority)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(
                      () => selectedPriority = value ?? 'medium',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ الاستحقاق'),
                    subtitle: Text(
                      dueDate == null
                          ? '-'
                          : dueDate!.toIso8601String().split('T').first,
                    ),
                    trailing: const Icon(Icons.event_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: dueDate ?? DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تذكير'),
                    subtitle: Text(
                      reminderDate == null
                          ? '-'
                          : reminderDate!.toIso8601String().split('T').first,
                    ),
                    trailing: const Icon(Icons.alarm_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: reminderDate ?? DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => reminderDate = picked);
                      }
                    },
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
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('عنوان المهمة مطلوب.')),
                  );
                  return;
                }

                try {
                  final dio = ref.read(dioProvider);
                  await dio.post(
                    '/tasks',
                    data: {
                      'title': titleController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'caseId': selectedCaseId,
                      'priority': selectedPriority,
                      'dueDate': dueDate?.toIso8601String(),
                      'reminderAt': reminderDate?.toIso8601String(),
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

    titleController.dispose();
    descriptionController.dispose();

    if (created == true) {
      await _loadData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء المهمة بنجاح.')));
    }
  }

  Future<void> _updateTaskStatus(String taskId, String status) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/tasks/$taskId',
        data: {'status': status},
        options: Options(headers: authHeaders(ref)),
      );
      await _loadData();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Tasks & Reminders',
            subtitle: 'Assign tasks, due dates, priorities, and reminders',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _loading ? null : _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: _showCreateTaskDialog,
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text(context.tr('New Task')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                selected: _statusFilter.isEmpty,
                label: Text(context.tr('all')),
                onSelected: (_) {
                  setState(() => _statusFilter = '');
                  _loadData();
                },
              ),
              ..._statusOptions.map(
                (status) => FilterChip(
                  selected: _statusFilter == status,
                  label: Text(_statusLabel(status)),
                  onSelected: (_) {
                    setState(() => _statusFilter = status);
                    _loadData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Text(_error!)
                : _tasks.isEmpty
                ? const Text('لا توجد مهام بعد.')
                : Column(
                    children: _tasks.map((task) {
                      final taskId = _idOf(task);
                      final caseData = (task['caseId'] is Map)
                          ? (task['caseId'] as Map).cast<String, dynamic>()
                          : <String, dynamic>{};

                      final due = (task['dueDate'] ?? '').toString();
                      final dueLabel = due.isEmpty ? '-' : due.split('T').first;

                      final status = (task['status'] ?? 'open').toString();

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.task_alt_rounded),
                        title: Text((task['title'] ?? '-').toString()),
                        subtitle: Text(
                          'القضية: ${(caseData['caseNumber'] ?? '-').toString()} ${(caseData['title'] ?? '').toString()}\nالأولوية: ${_priorityLabel((task['priority'] ?? '-').toString())} | الاستحقاق: $dueLabel\n${(task['description'] ?? '').toString()}',
                        ),
                        isThreeLine: true,
                        trailing: taskId == null
                            ? null
                            : DropdownButton<String>(
                                value: _statusOptions.contains(status)
                                    ? status
                                    : 'open',
                                items: _statusOptions
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(_statusLabel(value)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null || value == status) {
                                    return;
                                  }
                                  _updateTaskStatus(taskId, value);
                                },
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

  String _statusLabel(String value) {
    switch (value) {
      case 'open':
        return 'مفتوحة';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'done':
        return 'منجزة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return value;
    }
  }

  String _priorityLabel(String value) {
    switch (value) {
      case 'low':
        return 'منخفضة';
      case 'medium':
        return 'متوسطة';
      case 'high':
        return 'عالية';
      case 'urgent':
        return 'عاجلة';
      default:
        return value;
    }
  }
}
