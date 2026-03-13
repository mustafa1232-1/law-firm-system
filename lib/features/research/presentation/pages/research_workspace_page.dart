import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class ResearchWorkspacePage extends ConsumerStatefulWidget {
  const ResearchWorkspacePage({super.key});

  @override
  ConsumerState<ResearchWorkspacePage> createState() =>
      _ResearchWorkspacePageState();
}

class _ResearchWorkspacePageState extends ConsumerState<ResearchWorkspacePage> {
  final _queryController = TextEditingController();
  final _courtController = TextEditingController();
  final _domainController = TextEditingController();

  bool _loading = false;
  bool _loadingFolders = false;
  String? _error;
  String _type = 'all';

  List<Map<String, dynamic>> _results = const [];
  final List<Map<String, dynamic>> _pinned = [];

  List<Map<String, dynamic>> _folders = const [];
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _courtController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    setState(() => _loadingFolders = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/research/folders',
        options: Options(headers: authHeaders(ref)),
      );

      final folders = ((response.data as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _folders = folders;
        _selectedFolderId =
            _selectedFolderId ??
            (folders.isNotEmpty ? folders.first['_id']?.toString() : null);
      });
    } catch (_) {
      // Keep search usable even if folders fail.
    } finally {
      if (mounted) {
        setState(() => _loadingFolders = false);
      }
    }
  }

  Future<void> _createFolder() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مجلد بحث جديد'),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(280.0, 500.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'العنوان *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
            ],
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
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('عنوان المجلد مطلوب.')),
                );
                return;
              }

              try {
                final dio = ref.read(dioProvider);
                await dio.post(
                  '/research/folders',
                  data: {
                    'title': title,
                    'description': descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
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

    titleController.dispose();
    descriptionController.dispose();

    if (created == true) {
      await _loadFolders();
    }
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please enter search query first.'))),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/research/search',
        queryParameters: {
          'q': query,
          if (_type != 'all') 'type': _type,
          if (_courtController.text.trim().isNotEmpty)
            'court': _courtController.text.trim(),
          if (_domainController.text.trim().isNotEmpty)
            'legalDomain': _domainController.text.trim(),
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

      setState(() => _results = items);
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

  void _togglePin(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null) {
      return;
    }

    final existingIndex = _pinned.indexWhere(
      (entry) => entry['id']?.toString() == id,
    );
    setState(() {
      if (existingIndex >= 0) {
        _pinned.removeAt(existingIndex);
      } else {
        _pinned.add(item);
      }
    });
  }

  bool _isPinned(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null) {
      return false;
    }

    return _pinned.any((entry) => entry['id']?.toString() == id);
  }

  Future<void> _openCompareDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Compare Mode')),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(280.0, 760.0),
          child: _pinned.length < 2
              ? Text(context.tr('Pin at least two authorities to compare.'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _pinned.length,
                  itemBuilder: (context, index) {
                    final item = _pinned[index];
                    return ListTile(
                      title: Text((item['title'] ?? '-').toString()),
                      subtitle: Text((item['snippet'] ?? '').toString()),
                    );
                  },
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
  }

  Future<void> _savePinnedToFolder() async {
    if (_pinned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ثبت مرجعاً واحداً على الأقل قبل الحفظ.')),
      );
      return;
    }

    final folderId = _selectedFolderId;
    if (folderId == null || folderId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أنشئ مجلد بحث أولاً.')));
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      final headers = Options(headers: authHeaders(ref));

      for (final item in _pinned) {
        final authorityType = (item['type'] ?? 'note').toString();
        final authorityId = (item['id'] ?? '').toString();
        if (authorityId.isEmpty) {
          continue;
        }

        await dio.post(
          '/research/folders/$folderId/authorities',
          data: {
            'authorityType': authorityType,
            'authorityId': authorityId,
            'citation': (item['title'] ?? '-').toString(),
            'notes': (item['relevanceReason'] ?? '').toString(),
          },
          options: headers,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ ${_pinned.length} مرجع في المجلد.')),
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

  Future<void> _previewFolderAuthorities() async {
    final folderId = _selectedFolderId;
    if (folderId == null || folderId.isEmpty) {
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/research/folders/$folderId/authorities',
        options: Options(headers: authHeaders(ref)),
      );

      final items = ((response.data as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('محتوى المجلد'),
          content: SizedBox(
            width: MediaQuery.sizeOf(context).width.clamp(280.0, 760.0),
            child: items.isEmpty
                ? const Text('المجلد فارغ.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text((item['citation'] ?? '-').toString()),
                        subtitle: Text(
                          (item['authorityType'] ?? '-').toString(),
                        ),
                      );
                    },
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
    final selectedFolderValue =
        _folders.any((folder) => folder['_id']?.toString() == _selectedFolderId)
        ? _selectedFolderId
        : null;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 1100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Research Workspace',
            subtitle:
                'Constitution, laws, and decision search with pinned citations',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadingFolders ? null : _createFolder,
                  icon: const Icon(Icons.create_new_folder_rounded),
                  label: const Text('مجلد جديد'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _savePinnedToFolder,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ المثبت'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              children: [
                if (isCompact) ...[
                  TextField(
                    controller: _queryController,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: context.tr(
                        'Search laws, constitution, and decisions',
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _courtController,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(labelText: 'المحكمة'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _domainController,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(labelText: 'المجال'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('الكل')),
                      DropdownMenuItem(
                        value: 'constitution',
                        child: Text('دستور'),
                      ),
                      DropdownMenuItem(value: 'law', child: Text('قوانين')),
                      DropdownMenuItem(
                        value: 'decision',
                        child: Text('قرارات'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _type = value ?? 'all'),
                    decoration: const InputDecoration(labelText: 'النوع'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.search_rounded),
                      label: _loading
                          ? const Text('...')
                          : Text(context.tr('Search')),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _queryController,
                          onSubmitted: (_) => _search(),
                          decoration: InputDecoration(
                            hintText: context.tr(
                              'Search laws, constitution, and decisions',
                            ),
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _courtController,
                          onSubmitted: (_) => _search(),
                          decoration: const InputDecoration(
                            labelText: 'المحكمة',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _domainController,
                          onSubmitted: (_) => _search(),
                          decoration: const InputDecoration(
                            labelText: 'المجال',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('الكل')),
                            DropdownMenuItem(
                              value: 'constitution',
                              child: Text('دستور'),
                            ),
                            DropdownMenuItem(
                              value: 'law',
                              child: Text('قوانين'),
                            ),
                            DropdownMenuItem(
                              value: 'decision',
                              child: Text('قرارات'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _type = value ?? 'all'),
                          decoration: const InputDecoration(labelText: 'النوع'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _search,
                        icon: const Icon(Icons.search_rounded),
                        label: _loading
                            ? const Text('...')
                            : Text(context.tr('Search')),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (isCompact) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedFolderValue,
                    items: _folders
                        .map(
                          (folder) => DropdownMenuItem<String>(
                            value: folder['_id']?.toString(),
                            child: Text((folder['title'] ?? '-').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedFolderId = value),
                    decoration: const InputDecoration(
                      labelText: 'مجلد الحفظ',
                      prefixIcon: Icon(Icons.folder_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _selectedFolderId == null
                          ? null
                          : _previewFolderAuthorities,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('عرض المجلد'),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedFolderValue,
                          items: _folders
                              .map(
                                (folder) => DropdownMenuItem<String>(
                                  value: folder['_id']?.toString(),
                                  child: Text(
                                    (folder['title'] ?? '-').toString(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedFolderId = value),
                          decoration: const InputDecoration(
                            labelText: 'مجلد الحفظ',
                            prefixIcon: Icon(Icons.folder_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _selectedFolderId == null
                            ? null
                            : _previewFolderAuthorities,
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('عرض المجلد'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isCompact) ...[
            _resultsPanel(context),
            const SizedBox(height: 12),
            _sidePanels(context),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _resultsPanel(context)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _sidePanels(context)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _resultsPanel(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Search Results'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: LexiqColors.crimsonAlert),
            ),
          if (_error == null && _results.isEmpty && !_loading)
            Text(
              context.tr(
                'No results yet. Start by typing a legal question or term.',
              ),
            )
          else
            ..._results.map((item) {
              final pinned = _isPinned(item);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.description_rounded,
                  color: pinned ? Colors.amber : null,
                ),
                title: Text((item['title'] ?? '-').toString()),
                subtitle: Text(
                  '${(item['snippet'] ?? '').toString()}\n${(item['relevanceReason'] ?? '').toString()}',
                ),
                trailing: IconButton(
                  icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
                  onPressed: () => _togglePin(item),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _sidePanels(BuildContext context) {
    return Column(
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Pinned Citations'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_pinned.isEmpty)
                Text(context.tr('No pinned citations yet.'))
              else
                ..._pinned.map(
                  (item) => _pin(context, (item['title'] ?? '-').toString()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Compare Mode'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(context.tr('Split panel for law + decision + notes')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openCompareDialog,
                icon: const Icon(Icons.compare_arrows_rounded),
                label: Text(context.tr('Open Compare')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pin(BuildContext context, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.bookmark_rounded, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
