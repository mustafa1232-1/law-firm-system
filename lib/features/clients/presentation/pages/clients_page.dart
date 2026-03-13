import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _searchController = TextEditingController();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _clients = const [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/clients',
        queryParameters: {
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
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

      setState(() => _clients = items);
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

  Future<void> _showCreateClientDialog() async {
    final fullNameController = TextEditingController();
    final companyController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final tagsController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة عميل جديد'),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(280.0, 520.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل *',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: companyController,
                  decoration: const InputDecoration(labelText: 'اسم الشركة'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'الهاتف'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'وسوم (مفصولة بفاصلة)',
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
              final fullName = fullNameController.text.trim();
              if (fullName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الاسم الكامل مطلوب.')),
                );
                return;
              }

              try {
                final dio = ref.read(dioProvider);
                await dio.post(
                  '/clients',
                  data: {
                    'fullName': fullName,
                    'companyName': companyController.text.trim().isEmpty
                        ? null
                        : companyController.text.trim(),
                    'phone': phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),
                    'address': addressController.text.trim().isEmpty
                        ? null
                        : addressController.text.trim(),
                    'tags': tagsController.text
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
    );

    fullNameController.dispose();
    companyController.dispose();
    phoneController.dispose();
    addressController.dispose();
    tagsController.dispose();

    if (created == true) {
      await _loadClients();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء العميل بنجاح.')));
    }
  }

  Future<void> _deleteClient(String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا العميل؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      await dio.delete(
        '/clients/$id',
        options: Options(headers: authHeaders(ref)),
      );
      await _loadClients();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف العميل.')));
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
    final isCompact = MediaQuery.sizeOf(context).width < 720;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Clients',
            subtitle:
                'Client records, contacts, and legal engagement management',
            trailing: ElevatedButton.icon(
              onPressed: _showCreateClientDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(context.tr('New Client')),
            ),
          ),
          const SizedBox(height: 12),
          if (isCompact) ...[
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadClients(),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الشركة أو الهاتف',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _loadClients,
                icon: const Icon(Icons.search_rounded),
                label: Text(context.tr('Search')),
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadClients(),
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو الشركة أو الهاتف',
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _loadClients,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(context.tr('Search')),
                ),
              ],
            ),
          const SizedBox(height: 12),
          GlassPanel(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Text(_error!)
                : _clients.isEmpty
                ? const Text('لا يوجد عملاء بعد.')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      columns: const [
                        DataColumn(label: Text('الاسم')),
                        DataColumn(label: Text('الشركة')),
                        DataColumn(label: Text('الهاتف')),
                        DataColumn(label: Text('آخر قضية')),
                        DataColumn(label: Text('نوعها')),
                        DataColumn(label: Text('وسوم')),
                        DataColumn(label: Text('إجراءات')),
                      ],
                      rows: _clients.map((client) {
                        final id = (client['_id'] ?? '').toString();
                        return DataRow(
                          cells: [
                            DataCell(
                              Text((client['fullName'] ?? '-').toString()),
                            ),
                            DataCell(
                              Text((client['companyName'] ?? '-').toString()),
                            ),
                            DataCell(Text((client['phone'] ?? '-').toString())),
                            DataCell(
                              Text(
                                (client['latestCaseTitle'] ?? '-').toString(),
                              ),
                            ),
                            DataCell(
                              Text(
                                (client['latestCaseType'] ?? '-').toString(),
                              ),
                            ),
                            DataCell(
                              Text(
                                ((client['tags'] as List?) ?? const [])
                                    .map((entry) => entry.toString())
                                    .join(', '),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                onPressed: id.isEmpty
                                    ? null
                                    : () => _deleteClient(id),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
