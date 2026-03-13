import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  bool _loading = false;
  bool _seeding = false;
  String? _error;

  List<Map<String, dynamic>> _roles = const [];
  List<Map<String, dynamic>> _permissions = const [];

  @override
  void initState() {
    super.initState();
    _loadRbac();
  }

  Future<void> _loadRbac() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final options = Options(headers: authHeaders(ref));
      final responses = await Future.wait([
        dio.get('/admin/roles', options: options),
        dio.get('/admin/permissions', options: options),
      ]);

      final roles = ((responses[0].data as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final permissions = ((responses[1].data as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _roles = roles;
        _permissions = permissions;
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

  Future<void> _seedRbac() async {
    setState(() => _seeding = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/admin/seed-rbac',
        options: Options(headers: authHeaders(ref)),
      );
      await _loadRbac();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تهيئة الأدوار والصلاحيات الافتراضية.'),
        ),
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
        setState(() => _seeding = false);
      }
    }
  }

  Future<void> _showCreatePermissionDialog() async {
    final keyController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final moduleController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء صلاحية جديدة'),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(280.0, 540.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Key * (مثال: cases.read)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: moduleController,
                  decoration: const InputDecoration(
                    labelText: 'Module (اختياري)',
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
              final key = keyController.text.trim();
              final name = nameController.text.trim();
              if (key.isEmpty || name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الـ key والاسم مطلوبان.')),
                );
                return;
              }

              try {
                final dio = ref.read(dioProvider);
                await dio.post(
                  '/admin/permissions',
                  data: {
                    'key': key,
                    'name': name,
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    'module': moduleController.text.trim().isEmpty
                        ? null
                        : moduleController.text.trim(),
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
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    keyController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    moduleController.dispose();

    if (created == true) {
      await _loadRbac();
    }
  }

  Future<void> _showCreateRoleDialog() async {
    final keyController = TextEditingController();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final permissionsController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء دور جديد'),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(280.0, 560.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Key * (مثال: SENIOR_LAWYER)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: permissionsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Permissions (مفصولة بفاصلة)',
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
              final key = keyController.text.trim();
              final name = nameController.text.trim();
              if (key.isEmpty || name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الـ key والاسم مطلوبان.')),
                );
                return;
              }

              try {
                final dio = ref.read(dioProvider);
                await dio.post(
                  '/admin/roles',
                  data: {
                    'key': key,
                    'name': name,
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    'permissions': permissionsController.text
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
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );

    keyController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    permissionsController.dispose();

    if (created == true) {
      await _loadRbac();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Admin Panel',
            subtitle:
                'RBAC, ingestion review workflow, and firm administration',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : _loadRbac,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تحديث'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _seeding ? null : _seedRbac,
                  icon: _seeding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.security_rounded),
                  label: Text(context.tr('RBAC')),
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
            GlassPanel(child: _rolesPanel(context, compact: true)),
            const SizedBox(height: 12),
            GlassPanel(child: _permissionsPanel(context, compact: true)),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: GlassPanel(child: _rolesPanel(context))),
                const SizedBox(width: 12),
                Expanded(child: GlassPanel(child: _permissionsPanel(context))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rolesPanel(BuildContext context, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          Text(
            'الأدوار (${_roles.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCreateRoleDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('دور جديد'),
            ),
          ),
        ] else
          Row(
            children: [
              Text(
                'الأدوار (${_roles.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _showCreateRoleDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('دور جديد'),
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_roles.isEmpty)
          const Text('لا توجد أدوار حتى الآن.')
        else
          ..._roles.map((role) {
            final rolePermissions = ((role['permissions'] as List?) ?? const [])
                .map((entry) => entry.toString())
                .toList();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_rounded),
              title: Text((role['name'] ?? '-').toString()),
              subtitle: Text(
                'Key: ${(role['key'] ?? '-').toString()}\n${rolePermissions.isEmpty ? 'بدون صلاحيات' : rolePermissions.join(', ')}',
              ),
              isThreeLine: true,
            );
          }),
      ],
    );
  }

  Widget _permissionsPanel(BuildContext context, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          Text(
            'الصلاحيات (${_permissions.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCreatePermissionDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('صلاحية جديدة'),
            ),
          ),
        ] else
          Row(
            children: [
              Text(
                'الصلاحيات (${_permissions.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _showCreatePermissionDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('صلاحية جديدة'),
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_permissions.isEmpty)
          const Text('لا توجد صلاحيات حتى الآن.')
        else
          ..._permissions.map((permission) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.vpn_key_rounded),
              title: Text((permission['name'] ?? '-').toString()),
              subtitle: Text(
                'Key: ${(permission['key'] ?? '-').toString()}\n'
                'Module: ${(permission['module'] ?? '-').toString()}',
              ),
              isThreeLine: true,
            );
          }),
      ],
    );
  }
}
