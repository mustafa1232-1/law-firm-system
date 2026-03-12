import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/notifications',
        queryParameters: const {'limit': 100},
        options: Options(headers: authHeaders(ref)),
      );

      final data = response.data;
      final items = (data is List ? data : const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      setState(() => _items = items);
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

  Future<void> _showCreateNotificationDialog() async {
    final authState = ref.read(authControllerProvider);
    final userId = authState.session?.user.id;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد المستخدم الحالي. أعد تسجيل الدخول.'),
        ),
      );
      return;
    }

    String level = 'info';

    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final entityTypeController = TextEditingController();
    final entityIdController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة إشعار'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'العنوان *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'النص *'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: level,
                    decoration: const InputDecoration(labelText: 'المستوى'),
                    items: const [
                      DropdownMenuItem(value: 'info', child: Text('info')),
                      DropdownMenuItem(
                        value: 'warning',
                        child: Text('warning'),
                      ),
                      DropdownMenuItem(
                        value: 'critical',
                        child: Text('critical'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => level = value ?? 'info'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: entityTypeController,
                    decoration: const InputDecoration(
                      labelText: 'نوع الكيان (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: entityIdController,
                    decoration: const InputDecoration(
                      labelText: 'معرّف الكيان (اختياري)',
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
                if (titleController.text.trim().isEmpty ||
                    messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('العنوان والنص مطلوبان.')),
                  );
                  return;
                }

                try {
                  final dio = ref.read(dioProvider);
                  await dio.post(
                    '/notifications',
                    data: {
                      'userId': userId,
                      'title': titleController.text.trim(),
                      'message': messageController.text.trim(),
                      'level': level,
                      'entityType': entityTypeController.text.trim().isEmpty
                          ? null
                          : entityTypeController.text.trim(),
                      'entityId': entityIdController.text.trim().isEmpty
                          ? null
                          : entityIdController.text.trim(),
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
    messageController.dispose();
    entityTypeController.dispose();
    entityIdController.dispose();

    if (created == true) {
      await _loadNotifications();
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/notifications/$id/read',
        options: Options(headers: authHeaders(ref)),
      );
      await _loadNotifications();
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
            title: 'Notifications Center',
            subtitle:
                'Legal alerts, case updates, hearing reminders, and AI notices',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _loading ? null : _loadNotifications,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: _showCreateNotificationDialog,
                  icon: const Icon(Icons.add_alert_rounded),
                  label: const Text('New Notification'),
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
                : _items.isEmpty
                ? const Text('لا توجد إشعارات بعد.')
                : Column(
                    children: _items.map((notification) {
                      final id = (notification['_id'] ?? '').toString();
                      final isRead = (notification['isRead'] as bool?) ?? false;
                      final level = (notification['level'] ?? 'info')
                          .toString();

                      Color levelColor = Colors.blueGrey;
                      if (level == 'warning') {
                        levelColor = Colors.orange;
                      } else if (level == 'critical') {
                        levelColor = Colors.red;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isRead ? Colors.white10 : Colors.white30,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.notifications_active_rounded,
                            color: levelColor,
                          ),
                          title: Text(
                            (notification['title'] ?? '-').toString(),
                          ),
                          subtitle: Text(
                            '${(notification['message'] ?? '').toString()}\n${(notification['createdAt'] ?? '').toString().replaceFirst('T', ' ').split('.').first}',
                          ),
                          isThreeLine: true,
                          trailing: isRead
                              ? const Text('Read')
                              : TextButton(
                                  onPressed: id.isEmpty
                                      ? null
                                      : () => _markAsRead(id),
                                  child: const Text('Mark read'),
                                ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
