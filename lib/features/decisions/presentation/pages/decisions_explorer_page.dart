import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../theme/lexiq_colors.dart';

class DecisionsExplorerPage extends ConsumerStatefulWidget {
  const DecisionsExplorerPage({super.key});

  @override
  ConsumerState<DecisionsExplorerPage> createState() =>
      _DecisionsExplorerPageState();
}

class _DecisionsExplorerPageState extends ConsumerState<DecisionsExplorerPage> {
  final _queryController = TextEditingController();
  final _courtController = TextEditingController();
  final _domainController = TextEditingController();
  final _yearController = TextEditingController();

  bool _loading = false;
  bool _syncing = false;
  String? _error;

  String _selectedCaseType = 'Ø§Ù„ÙƒÙ„';
  String _selectedCourtLevel = 'appellate';

  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _summaryItems = const [];

  static const _caseTypes = <String>[
    'Ø§Ù„ÙƒÙ„',
    'Ù…Ø¯Ù†ÙŠ',
    'Ø¬Ø²Ø§Ø¦ÙŠ',
    'Ø£Ø­ÙˆØ§Ù„ Ø´Ø®ØµÙŠØ©',
    'ØªØ¬Ø§Ø±ÙŠ',
    'Ø¥Ø¯Ø§Ø±ÙŠ',
    'Ø¹Ù…Ø§Ù„ÙŠ',
    'Ø¹Ù‚Ø§Ø±ÙŠ',
    'ØªÙ†ÙÙŠØ°',
    'Ø¯Ø³ØªÙˆØ±ÙŠ',
    'Ø¥Ø«Ø¨Ø§Øª',
    'Ø¥Ø¬Ø±Ø§Ø¦ÙŠ',
    'ÙˆÙ‚Ù',
    'Ø£Ø®Ø±Ù‰',
  ];

  static const _courtLevels = <({String value, String label})>[
    (value: 'all', label: 'ÙƒÙ„ Ø§Ù„Ù…Ø³ØªÙˆÙŠØ§Øª'),
    (value: 'appellate', label: 'Ø§Ø³ØªØ¦Ù†Ø§ÙÙŠ'),
    (value: 'cassation', label: 'ØªÙ…ÙŠÙŠØ²ÙŠ'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _courtController.dispose();
    _domainController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_search(), _loadCaseTypeSummary()]);
  }

  Map<String, dynamic> _buildSearchQueryParameters() {
    return {
      if (_queryController.text.trim().isNotEmpty)
        'q': _queryController.text.trim(),
      if (_courtController.text.trim().isNotEmpty)
        'court': _courtController.text.trim(),
      if (_domainController.text.trim().isNotEmpty)
        'legalDomain': _domainController.text.trim(),
      if (_selectedCaseType != _caseTypes.first) 'caseType': _selectedCaseType,
      if (_selectedCourtLevel != 'all') 'courtLevel': _selectedCourtLevel,
      if (_yearController.text.trim().isNotEmpty)
        'year': _yearController.text.trim(),
    };
  }

  Future<List<Map<String, dynamic>>> _loadAllDecisionPages(
    Dio dio,
    Map<String, dynamic> baseQueryParameters,
  ) async {
    const pageSize = 100;
    const maxPages = 500;

    final allItems = <Map<String, dynamic>>[];
    var page = 1;
    var total = 1;

    while (allItems.length < total && page <= maxPages) {
      final response = await dio.get(
        '/decisions/search',
        queryParameters: {
          ...baseQueryParameters,
          'limit': pageSize,
          'page': page,
        },
        options: Options(headers: authHeaders(ref)),
      );

      final data = (response.data as Map).cast<String, dynamic>();
      final pageItems = ((data['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      total =
          (data['total'] as num?)?.toInt() ??
          (allItems.length + pageItems.length);
      allItems.addAll(pageItems);

      if (pageItems.isEmpty || pageItems.length < pageSize) {
        break;
      }

      page++;
    }

    return allItems;
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final items = await _loadAllDecisionPages(
        dio,
        _buildSearchQueryParameters(),
      );

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

  Future<void> _loadCaseTypeSummary() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/decisions/case-type-summary',
        queryParameters: {
          if (_selectedCourtLevel != 'all') 'courtLevel': _selectedCourtLevel,
          if (_yearController.text.trim().isNotEmpty)
            'year': _yearController.text.trim(),
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

      setState(() => _summaryItems = items);
    } catch (_) {
      if (!mounted) {
        return;
      }

      final grouped = _groupItemsByType(_items);
      setState(
        () => _summaryItems = grouped.entries
            .map(
              (entry) => {'caseType': entry.key, 'count': entry.value.length},
            )
            .toList(),
      );
    }
  }

  Future<void> _syncFromPublicSource() async {
    setState(() => _syncing = true);

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/decisions/sync/sjc-appellate',
        data: {
          'startId': 1,
          'endId': 25000,
          'concurrency': 25,
          'maxDecisions': 10000,
          'mode': _selectedCourtLevel == 'all' ? 'all' : 'appellate',
        },
        options: Options(headers: authHeaders(ref)),
      );

      final payload = (response.data as Map).cast<String, dynamic>();
      final inserted = (payload['insertedCount'] as num?)?.toInt() ?? 0;
      final updated = (payload['updatedCount'] as num?)?.toInt() ?? 0;
      final collected = (payload['collectedCount'] as num?)?.toInt() ?? 0;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ØªÙ…Øª Ø§Ù„Ù…Ø²Ø§Ù…Ù†Ø©: $collected Ù‚Ø±Ø§Ø± | $inserted Ø¬Ø¯ÙŠØ¯ | $updated Ù…Ø­Ø¯Ù‘Ø«',
          ),
        ),
      );

      await _loadAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _showAddDecisionDialog() async {
    final courtNameController = TextEditingController();
    final decisionNumberController = TextEditingController();
    final decisionDateController = TextEditingController();
    final caseTypeController = TextEditingController();
    final legalDomainController = TextEditingController();
    final summaryController = TextEditingController();
    final fullTextController = TextEditingController();

    String selectedCourtLevel = 'appellate';
    PlatformFile? pickedFile;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ø¥Ø¶Ø§ÙØ© Ù‚Ø±Ø§Ø± Ø¬Ø¯ÙŠØ¯'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        withData: true,
                        type: FileType.custom,
                        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                      );
                      if (result == null || result.files.isEmpty) {
                        return;
                      }
                      setDialogState(() => pickedFile = result.files.first);
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      pickedFile == null
                          ? 'Ø§Ø®ØªÙŠØ§Ø± Ù…Ù„Ù Ø§Ù„Ù‚Ø±Ø§Ø± (PDF/ØµÙˆØ±Ø©)'
                          : pickedFile!.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: courtNameController,
                    decoration: const InputDecoration(
                      labelText: 'Ø§Ø³Ù… Ø§Ù„Ù…Ø­ÙƒÙ…Ø©',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourtLevel,
                    decoration: const InputDecoration(
                      labelText: 'Ù…Ø³ØªÙˆÙ‰ Ø§Ù„Ù…Ø­ÙƒÙ…Ø©',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'appellate',
                        child: Text('Ø§Ø³ØªØ¦Ù†Ø§ÙÙŠ'),
                      ),
                      DropdownMenuItem(
                        value: 'cassation',
                        child: Text('ØªÙ…ÙŠÙŠØ²ÙŠ'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() => selectedCourtLevel = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: decisionNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Ø±Ù‚Ù… Ø§Ù„Ù‚Ø±Ø§Ø±',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: decisionDateController,
                    decoration: const InputDecoration(
                      labelText: 'ØªØ§Ø±ÙŠØ® Ø§Ù„Ù‚Ø±Ø§Ø± (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: caseTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Ù†ÙˆØ¹ Ø§Ù„Ù‚Ø¶ÙŠØ© (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: legalDomainController,
                    decoration: const InputDecoration(
                      labelText:
                          'Ø§Ù„Ù…Ø¬Ø§Ù„ Ø§Ù„Ù‚Ø§Ù†ÙˆÙ†ÙŠ (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: summaryController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ù…Ù„Ø®Øµ Ø§Ù„Ù‚Ø±Ø§Ø± (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fullTextController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Ø§Ù„Ù†Øµ Ø§Ù„ÙƒØ§Ù…Ù„ (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Ø¥ØºÙ„Ø§Ù‚'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pickedFile == null || pickedFile!.bytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ÙŠØ±Ø¬Ù‰ Ø§Ø®ØªÙŠØ§Ø± Ù…Ù„Ù Ø§Ù„Ù‚Ø±Ø§Ø±.',
                      ),
                    ),
                  );
                  return;
                }
                if (courtNameController.text.trim().isEmpty ||
                    decisionNumberController.text.trim().isEmpty ||
                    decisionDateController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ø§Ø³Ù… Ø§Ù„Ù…Ø­ÙƒÙ…Ø© ÙˆØ±Ù‚Ù… Ø§Ù„Ù‚Ø±Ø§Ø± ÙˆØªØ§Ø±ÙŠØ® Ø§Ù„Ù‚Ø±Ø§Ø± Ù…Ø·Ù„ÙˆØ¨Ø©.',
                      ),
                    ),
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
                    'courtName': courtNameController.text.trim(),
                    'courtLevel': selectedCourtLevel,
                    'decisionNumber': decisionNumberController.text.trim(),
                    'decisionDate': decisionDateController.text.trim(),
                    if (caseTypeController.text.trim().isNotEmpty)
                      'caseType': caseTypeController.text.trim(),
                    if (legalDomainController.text.trim().isNotEmpty)
                      'legalDomain': legalDomainController.text.trim(),
                    if (summaryController.text.trim().isNotEmpty)
                      'summary': summaryController.text.trim(),
                    if (fullTextController.text.trim().isNotEmpty)
                      'fullText': fullTextController.text.trim(),
                  });

                  await dio.post(
                    '/decisions/upload',
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
              child: const Text('Ø­ÙØ¸'),
            ),
          ],
        ),
      ),
    );

    courtNameController.dispose();
    decisionNumberController.dispose();
    decisionDateController.dispose();
    caseTypeController.dispose();
    legalDomainController.dispose();
    summaryController.dispose();
    fullTextController.dispose();

    if (created == true) {
      await _loadAll();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ØªÙ…Øª Ø¥Ø¶Ø§ÙØ© Ø§Ù„Ù‚Ø±Ø§Ø± Ø¨Ù†Ø¬Ø§Ø­.'),
        ),
      );
    }
  }

  Future<void> _openDecision(String id) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/decisions/$id',
        options: Options(headers: authHeaders(ref)),
      );
      final decision = (response.data as Map).cast<String, dynamic>();
      final similar = ((decision['similarDecisions'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            '${(decision['courtName'] ?? '-').toString()} - ${(decision['decisionNumber'] ?? '-').toString()}',
          ),
          content: SizedBox(
            width: 980,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          'Ø§Ù„Ù†ÙˆØ¹: ${(decision['caseType'] ?? '-').toString()}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Ø§Ù„Ù…Ø¬Ø§Ù„: ${(decision['legalDomain'] ?? '-').toString()}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Ø§Ù„Ù…Ø³ØªÙˆÙ‰: ${(decision['courtLevel'] ?? '-').toString()}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          'Ø§Ù„ØªØ§Ø±ÙŠØ®: ${_dateOnly(decision['decisionDate'])}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if ((decision['attachmentUrl'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty) ...[
                    SelectableText(
                      'رابط ملف القرار: ${(decision['attachmentUrl'] ?? '').toString()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    (decision['summary'] ?? '').toString(),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  if ((decision['fullText'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty) ...[
                    Text(
                      'Ø§Ù„Ù†Øµ Ø§Ù„ÙƒØ§Ù…Ù„',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    SelectableText((decision['fullText'] ?? '').toString()),
                    const SizedBox(height: 12),
                  ],
                  if ((decision['legalArticleReferences'] as List?)
                          ?.isNotEmpty ??
                      false) ...[
                    Text(
                      'Ø§Ù„Ù…ÙˆØ§Ø¯ Ø§Ù„Ù‚Ø§Ù†ÙˆÙ†ÙŠØ© Ø°Ø§Øª Ø§Ù„ØµÙ„Ø©',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ((decision['legalArticleReferences'] as List?) ??
                              const [])
                          .join('ØŒ '),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if ((decision['constitutionalReferences'] as List?)
                          ?.isNotEmpty ??
                      false) ...[
                    Text(
                      'Ø§Ù„Ù…ÙˆØ§Ø¯ Ø§Ù„Ø¯Ø³ØªÙˆØ±ÙŠØ© Ø°Ø§Øª Ø§Ù„ØµÙ„Ø©',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ((decision['constitutionalReferences'] as List?) ??
                              const [])
                          .join('ØŒ '),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Ù‚Ø±Ø§Ø±Ø§Øª Ù…Ø´Ø§Ø¨Ù‡Ø©',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (similar.isEmpty)
                    const Text('Ù„Ø§ ØªÙˆØ¬Ø¯ Ù‚Ø±Ø§Ø±Ø§Øª Ù…Ø´Ø§Ø¨Ù‡Ø©.')
                  else
                    ...similar.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '- ${(entry['decisionNumber'] ?? '-').toString()} | ${(entry['courtName'] ?? '-').toString()} | ${_dateOnly(entry['decisionDate'])}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ø¥ØºÙ„Ø§Ù‚'),
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

  Map<String, List<Map<String, dynamic>>> _groupItemsByType(
    List<Map<String, dynamic>> items,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in items) {
      final rawType = (item['caseType'] ?? '').toString().trim();
      final type = rawType.isEmpty ? 'Ø£Ø®Ø±Ù‰' : rawType;
      grouped.putIfAbsent(type, () => []).add(item);
    }

    return grouped;
  }

  String _dateOnly(dynamic value) {
    if (value == null) {
      return '-';
    }
    return value.toString().split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupItemsByType(_items);
    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) => b.value.length - a.value.length);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Ù…Ø³ØªÙƒØ´Ù Ø§Ù„Ù‚Ø±Ø§Ø±Ø§Øª Ø§Ù„Ù‚Ø¶Ø§Ø¦ÙŠØ©',
              subtitle:
                  'Ø¨Ø­Ø« Ø§Ù„Ù‚Ø±Ø§Ø±Ø§Øª ÙˆØªØµÙ†ÙŠÙÙ‡Ø§ ÙˆØ±Ø¨Ø·Ù‡Ø§ Ø¨Ø§Ù„Ù‚Ø¶Ø§ÙŠØ§ ÙˆØ§Ù„Ù…Ø±Ø¬Ø¹ÙŠØ§Øª',
              trailing: OutlinedButton.icon(
                onPressed: _loading ? null : _loadAll,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('ØªØ­Ø¯ÙŠØ«'),
              ),
            ),
            const SizedBox(height: 12),
            _buildFiltersPanel(context),
            const SizedBox(height: 12),
            _buildSummaryPanel(context),
            const SizedBox(height: 12),
            if (_loading)
              const GlassPanel(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              GlassPanel(
                child: Text(
                  _error!,
                  style: const TextStyle(color: LexiqColors.crimsonAlert),
                ),
              )
            else if (_items.isEmpty)
              const GlassPanel(
                child: Text(
                  'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù‚Ø±Ø§Ø±Ø§Øª Ù…Ø·Ø§Ø¨Ù‚Ø© Ù„Ù„ÙÙ„Ø§ØªØ± Ø§Ù„Ø­Ø§Ù„ÙŠØ©.',
                ),
              )
            else
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ø§Ù„Ù‚Ø±Ø§Ø±Ø§Øª Ø­Ø³Ø¨ Ù†ÙˆØ¹ Ø§Ù„Ù‚Ø¶ÙŠØ©',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    ...sortedGroups.map(
                      (group) => _DecisionGroupPanel(
                        caseType: group.key,
                        items: group.value,
                        onOpen: _openDecision,
                        dateOnly: _dateOnly,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1100;

    final fields = <Widget>[
      SizedBox(
        width: isCompact ? double.infinity : 320,
        child: TextField(
          controller: _queryController,
          onSubmitted: (_) async {
            await _search();
            await _loadCaseTypeSummary();
          },
          decoration: const InputDecoration(
            hintText: 'Ø¨Ø­Ø« Ø¨Ø§Ù„Ù†Øµ Ø£Ùˆ Ø±Ù‚Ù… Ø§Ù„Ù‚Ø±Ø§Ø±',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: TextField(
          controller: _courtController,
          onSubmitted: (_) async {
            await _search();
            await _loadCaseTypeSummary();
          },
          decoration: const InputDecoration(
            labelText: 'Ø§Ù„Ù…Ø­ÙƒÙ…Ø©',
            prefixIcon: Icon(Icons.account_balance_rounded),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: TextField(
          controller: _domainController,
          onSubmitted: (_) async {
            await _search();
            await _loadCaseTypeSummary();
          },
          decoration: const InputDecoration(
            labelText: 'Ø§Ù„Ù…Ø¬Ø§Ù„ Ø§Ù„Ù‚Ø§Ù†ÙˆÙ†ÙŠ',
            prefixIcon: Icon(Icons.category_outlined),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 130,
        child: TextField(
          controller: _yearController,
          keyboardType: TextInputType.number,
          onSubmitted: (_) async {
            await _search();
            await _loadCaseTypeSummary();
          },
          decoration: const InputDecoration(
            labelText: 'Ø§Ù„Ø³Ù†Ø©',
            hintText: '2026',
            prefixIcon: Icon(Icons.calendar_today_rounded),
          ),
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: DropdownButtonFormField<String>(
          initialValue: _selectedCaseType,
          decoration: const InputDecoration(labelText: 'Ù†ÙˆØ¹ Ø§Ù„Ù‚Ø¶ÙŠØ©'),
          items: _caseTypes
              .map(
                (type) =>
                    DropdownMenuItem<String>(value: type, child: Text(type)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedCaseType = value);
          },
        ),
      ),
      SizedBox(
        width: isCompact ? double.infinity : 220,
        child: DropdownButtonFormField<String>(
          initialValue: _selectedCourtLevel,
          decoration: const InputDecoration(
            labelText: 'Ù…Ø³ØªÙˆÙ‰ Ø§Ù„Ù…Ø­ÙƒÙ…Ø©',
          ),
          items: _courtLevels
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.value,
                  child: Text(entry.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedCourtLevel = value);
          },
        ),
      ),
    ];

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ÙÙ„ØªØ±Ø© ÙˆØ§Ø³ØªØ¹Ø±Ø§Ø¶ Ø§Ù„Ù‚Ø±Ø§Ø±Ø§Øª',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: fields),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        await _search();
                        await _loadCaseTypeSummary();
                      },
                icon: const Icon(Icons.search_rounded),
                label: const Text('Ø¨Ø­Ø«'),
              ),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        _queryController.clear();
                        _courtController.clear();
                        _domainController.clear();
                        _yearController.clear();
                        setState(() {
                          _selectedCaseType = _caseTypes.first;
                          _selectedCourtLevel = 'appellate';
                        });
                        await _loadAll();
                      },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Ø¥Ø¹Ø§Ø¯Ø© Ø¶Ø¨Ø·'),
              ),
              ElevatedButton.icon(
                onPressed: _showAddDecisionDialog,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('إضافة قرار'),
              ),
              ElevatedButton.icon(
                onPressed: _syncing ? null : _syncFromPublicSource,
                icon: _syncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync_rounded),
                label: const Text(
                  'Ø¬Ù„Ø¨ Ø§Ù„Ù‚Ø±Ø§Ø±Ø§Øª Ø§Ù„Ø§Ø³ØªØ¦Ù†Ø§ÙÙŠØ© Ù…Ù† Ø§Ù„Ù…ØµØ¯Ø± Ø§Ù„Ø¹Ø§Ù…',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel(BuildContext context) {
    final total = _items.length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryCard(
          title: 'Ø§Ù„Ù†ØªØ§Ø¦Ø¬ Ø§Ù„Ø­Ø§Ù„ÙŠØ©',
          value: '$total',
          icon: Icons.gavel_rounded,
          color: LexiqColors.imperialBlue,
        ),
        ..._summaryItems.take(8).map((entry) {
          final caseType = (entry['caseType'] ?? 'Ø£Ø®Ø±Ù‰').toString();
          final count = (entry['count'] ?? 0).toString();
          return _SummaryCard(
            title: caseType,
            value: count,
            icon: Icons.folder_special_rounded,
            color: LexiqColors.brassGold,
          );
        }),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.2),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: LexiqColors.slateGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionGroupPanel extends StatelessWidget {
  const _DecisionGroupPanel({
    required this.caseType,
    required this.items,
    required this.onOpen,
    required this.dateOnly,
  });

  final String caseType;
  final List<Map<String, dynamic>> items;
  final Future<void> Function(String id) onOpen;
  final String Function(dynamic value) dateOnly;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 10),
      title: Row(
        children: [
          Expanded(
            child: Text(
              caseType,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: LexiqColors.obsidianBlack.withValues(alpha: 0.28),
            ),
            child: Text('${items.length}'),
          ),
        ],
      ),
      children: items.map((item) {
        final id = (item['_id'] ?? '').toString();
        final courtName = (item['courtName'] ?? '-').toString();
        final decisionNumber = (item['decisionNumber'] ?? '-').toString();
        final summary = (item['summary'] ?? '').toString();
        final level = (item['courtLevel'] ?? '-').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: LexiqColors.obsidianBlack.withValues(alpha: 0.28),
            border: Border.all(
              color: LexiqColors.slateGray.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '$courtName - $decisionNumber',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateOnly(item['decisionDate']),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Ø§Ù„Ù…Ø³ØªÙˆÙ‰: $level')),
                  if ((item['legalDomain'] ?? '').toString().trim().isNotEmpty)
                    Chip(
                      label: Text(
                        'Ø§Ù„Ù…Ø¬Ø§Ù„: ${(item['legalDomain'] ?? '').toString()}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: id.isEmpty ? null : () => onOpen(id),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('ÙØªØ­ Ø§Ù„Ù‚Ø±Ø§Ø±'),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
