import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class ResearchWorkspacePage extends ConsumerStatefulWidget {
  const ResearchWorkspacePage({super.key});

  @override
  ConsumerState<ResearchWorkspacePage> createState() => _ResearchWorkspacePageState();
}

class _ResearchWorkspacePageState extends ConsumerState<ResearchWorkspacePage> {
  final _queryController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = const [];
  final List<Map<String, dynamic>> _pinned = [];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
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
        queryParameters: {'q': query},
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

    final existingIndex = _pinned.indexWhere((entry) => entry['id']?.toString() == id);
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

  void _openCompareDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Compare Mode')),
        content: SizedBox(
          width: 700,
          child: _pinned.isEmpty
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Research Workspace',
            subtitle: 'Constitution, laws, and decision search with pinned citations',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: context.tr('Search laws, constitution, and decisions'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search_rounded),
                label: _loading ? const Text('...') : Text(context.tr('Search')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Search Results'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_error != null) Text(_error!),
                      if (_error == null && _results.isEmpty && !_loading)
                        Text(context.tr('No results yet. Start by typing a legal question or term.'))
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
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
                              (item) => _pin(
                                context,
                                (item['title'] ?? '-').toString(),
                              ),
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
                ),
              ),
            ],
          ),
        ],
      ),
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
