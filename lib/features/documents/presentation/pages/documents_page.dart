import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
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
    final caseIdController = TextEditingController();
    final extractedTextController = TextEditingController();
    final tagsController = TextEditingController();
    PlatformFile? pickedFile;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('رفع مستند'),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 560.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        withData: true,
                      );
                      if (result == null || result.files.isEmpty) {
                        return;
                      }
                      setDialogState(() => pickedFile = result.files.first);
                      if (titleController.text.trim().isEmpty) {
                        titleController.text = pickedFile!.name;
                      }
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      pickedFile == null ? 'اختيار ملف' : pickedFile!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'العنوان (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: caseIdController,
                    decoration: const InputDecoration(
                      labelText: 'Case ID (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'وسوم (مفصولة بفاصلة)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: extractedTextController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'نص مستخرج (اختياري)',
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
                if (pickedFile == null || pickedFile!.bytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اختيار ملف مطلوب.')),
                  );
                  return;
                }

                try {
                  final dio = ref.read(dioProvider);
                  final formData = FormData.fromMap({
                    'file': MultipartFile.fromBytes(
                      pickedFile!.bytes!,
                      filename: pickedFile!.name,
                    ),
                    if (titleController.text.trim().isNotEmpty)
                      'title': titleController.text.trim(),
                    if (caseIdController.text.trim().isNotEmpty)
                      'caseId': caseIdController.text.trim(),
                    if (tagsController.text.trim().isNotEmpty)
                      'tags': tagsController.text.trim(),
                    if (extractedTextController.text.trim().isNotEmpty)
                      'extractedText': extractedTextController.text.trim(),
                  });

                  await dio.post(
                    '/documents/upload',
                    data: formData,
                    options: Options(
                      headers: authHeaders(ref),
                      contentType: 'multipart/form-data',
                    ),
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
    caseIdController.dispose();
    extractedTextController.dispose();
    tagsController.dispose();

    if (created == true) {
      await _loadDocuments();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء المستند بنجاح.')));
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
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 620.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((result['summary'] ?? '').toString()),
                  const SizedBox(height: 12),
                  Text(
                    'الكيانات: ${(result['extractedEntities'] ?? {}).toString()}',
                  ),
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
            title: 'Documents / Archive',
            subtitle:
                'Upload, OCR, extract entities, and archive document versions',
            trailing: ElevatedButton.icon(
              onPressed: _showCreateDocumentDialog,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(context.tr('Upload Document')),
            ),
          ),
          const SizedBox(height: 12),
          if (isCompact) ...[
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadDocuments(),
              decoration: const InputDecoration(
                hintText: 'ابحث في عنوان المستند أو اسم الملف',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _loadDocuments,
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
                          onPressed: id.isEmpty
                              ? null
                              : () => _analyzeDocument(id),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(context.tr('Analyze')),
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
