import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  final _searchController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _documents = const [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/documents',
        queryParameters: {
          if (_searchController.text.trim().isNotEmpty) 'search': _searchController.text.trim(),
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

  Future<void> _showCreateDocumentDialog() async {
    final titleController = TextEditingController();
    final originalNameController = TextEditingController();
    final mimeTypeController = TextEditingController(text: 'application/pdf');
    final caseIdController = TextEditingController();
    final sizeController = TextEditingController();
    final extractedTextController = TextEditingController();
    final tagsController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفع مستند (Metadata فقط)'),
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
                  controller: originalNameController,
                  decoration: const InputDecoration(labelText: 'اسم الملف الأصلي *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mimeTypeController,
                  decoration: const InputDecoration(labelText: 'MIME Type *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: caseIdController,
                  decoration: const InputDecoration(labelText: 'Case ID (اختياري)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الحجم بالبايت (اختياري)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(labelText: 'وسوم (مفصولة بفاصلة)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: extractedTextController,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'نص مستخرج (اختياري)'),
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
              final title = titleController.text.trim();
              final originalName = originalNameController.text.trim();
              final mimeType = mimeTypeController.text.trim();

              if (title.isEmpty || originalName.isEmpty || mimeType.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('العنوان واسم الملف وMIME Type مطلوبة.')),
                );
                return;
              }

              try {
                final dio = ref.read(dioProvider);
                await dio.post(
                  '/documents',
                  data: {
                    'title': title,
                    'originalName': originalName,
                    'mimeType': mimeType,
                    'caseId': caseIdController.text.trim().isEmpty
                        ? null
                        : caseIdController.text.trim(),
                    'sizeBytes': int.tryParse(sizeController.text.trim()),
                    'extractedText': extractedTextController.text.trim().isEmpty
                        ? null
                        : extractedTextController.text.trim(),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(parseApiError(error))),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    titleController.dispose();
    originalNameController.dispose();
    mimeTypeController.dispose();
    caseIdController.dispose();
    sizeController.dispose();
    extractedTextController.dispose();
    tagsController.dispose();

    if (created == true) {
      await _loadDocuments();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء المستند بنجاح.')),
      );
    }
  }

  Future<void> _analyzeDocument(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/documents/$id/analyze',
        data: const {'customPrompt': 'تحليل قانوني أولي'},
        options: Options(headers: authHeaders(ref)),
      );

      final result = (response.data as Map).cast<String, dynamic>();
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('نتيجة تحليل المستند'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((result['summary'] ?? '').toString()),
                  const SizedBox(height: 12),
                  Text('Entities: ${(result['extractedEntities'] ?? {}).toString()}'),
                  const SizedBox(height: 12),
                  Text((result['disclaimer'] ?? '').toString()),
                ],
              ),
            ),
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
            title: 'Documents / Archive',
            subtitle: 'Upload, OCR, extract entities, and archive document versions',
            trailing: ElevatedButton.icon(
              onPressed: _showCreateDocumentDialog,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(context.tr('Upload Document')),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _loadDocuments(),
                  decoration: const InputDecoration(
                    hintText: 'ابحث في عنوان المستند أو اسم الملف',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _loading ? null : _loadDocuments,
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
                    : _documents.isEmpty
                        ? const Text('لا توجد مستندات بعد.')
                        : Column(
                            children: _documents.map((document) {
                              final id = (document['_id'] ?? '').toString();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.description_outlined),
                                title: Text((document['title'] ?? '-').toString()),
                                subtitle: Text(
                                  '${(document['originalName'] ?? '-').toString()}\n${(document['mimeType'] ?? '-').toString()} | ${(document['storagePath'] ?? '-').toString()}',
                                ),
                                isThreeLine: true,
                                trailing: OutlinedButton.icon(
                                  onPressed: id.isEmpty ? null : () => _analyzeDocument(id),
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: const Text('Analyze'),
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
