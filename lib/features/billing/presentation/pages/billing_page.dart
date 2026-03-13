import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _payments = const [];
  List<Map<String, dynamic>> _clients = const [];
  List<Map<String, dynamic>> _cases = const [];
  Map<String, dynamic> _invoiceTotals = const {};
  Map<String, dynamic> _paymentTotals = const {};

  String? _filterCaseId;
  String _filterInvoiceStatus = 'all';

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
          '/billing/invoices',
          queryParameters: {
            'limit': 100,
            if (_filterCaseId != null && _filterCaseId!.isNotEmpty)
              'caseId': _filterCaseId,
            if (_filterInvoiceStatus != 'all') 'status': _filterInvoiceStatus,
          },
          options: Options(headers: authHeaders(ref)),
        ),
        dio.get(
          '/billing/payments',
          queryParameters: {
            'limit': 100,
            if (_filterCaseId != null && _filterCaseId!.isNotEmpty)
              'caseId': _filterCaseId,
          },
          options: Options(headers: authHeaders(ref)),
        ),
        dio.get(
          '/clients',
          queryParameters: const {'limit': 100},
          options: Options(headers: authHeaders(ref)),
        ),
        dio.get(
          '/cases',
          queryParameters: const {'limit': 100},
          options: Options(headers: authHeaders(ref)),
        ),
      ]);

      final invoices =
          ((((responses[0].data as Map).cast<String, dynamic>())['items']
                      as List?) ??
                  const [])
              .map((entry) => (entry as Map).cast<String, dynamic>())
              .toList();

      final payments =
          ((((responses[1].data as Map).cast<String, dynamic>())['items']
                      as List?) ??
                  const [])
              .map((entry) => (entry as Map).cast<String, dynamic>())
              .toList();

      final clients =
          ((((responses[2].data as Map).cast<String, dynamic>())['items']
                      as List?) ??
                  const [])
              .map((entry) => (entry as Map).cast<String, dynamic>())
              .toList();

      final cases =
          ((((responses[3].data as Map).cast<String, dynamic>())['items']
                      as List?) ??
                  const [])
              .map((entry) => (entry as Map).cast<String, dynamic>())
              .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _invoices = invoices;
        _payments = payments;
        _clients = clients;
        _cases = cases;
        _invoiceTotals =
            (((responses[0].data as Map).cast<String, dynamic>())['totals']
                    as Map?)
                ?.cast<String, dynamic>() ??
            const {};
        _paymentTotals =
            (((responses[1].data as Map).cast<String, dynamic>())['totals']
                    as Map?)
                ?.cast<String, dynamic>() ??
            const {};
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

  Future<void> _showCreateInvoiceDialog() async {
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إنشاء عميل قبل إنشاء فاتورة.')),
      );
      return;
    }

    String? selectedClientId = _idOf(_clients.first);
    String? selectedCaseId;

    DateTime issueDate = DateTime.now();
    DateTime? dueDate;

    final invoiceNoController = TextEditingController(
      text: 'INV-${DateTime.now().millisecondsSinceEpoch}',
    );
    final amountController = TextEditingController();
    final currencyController = TextEditingController(text: 'IQD');
    final notesController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إنشاء فاتورة'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: invoiceNoController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الفاتورة *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedClientId,
                    decoration: const InputDecoration(labelText: 'العميل *'),
                    items: _clients
                        .map(
                          (client) => DropdownMenuItem(
                            value: _idOf(client),
                            child: Text((client['fullName'] ?? '-').toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedClientId = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCaseId,
                    decoration: const InputDecoration(
                      labelText: 'القضية (اختياري)',
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
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'المبلغ *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: currencyController,
                    decoration: const InputDecoration(labelText: 'العملة'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ الإصدار'),
                    subtitle: Text(
                      issueDate.toIso8601String().split('T').first,
                    ),
                    trailing: const Icon(Icons.date_range_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: issueDate,
                      );
                      if (picked != null) {
                        setDialogState(() => issueDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ الاستحقاق'),
                    subtitle: Text(
                      dueDate == null
                          ? '-'
                          : dueDate!.toIso8601String().split('T').first,
                    ),
                    trailing: const Icon(Icons.event_available_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: dueDate ?? issueDate,
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                  ),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
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
                final invoiceNumber = invoiceNoController.text.trim();
                final amount = double.tryParse(amountController.text.trim());
                if (invoiceNumber.isEmpty ||
                    selectedClientId == null ||
                    amount == null ||
                    amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('رقم الفاتورة والعميل والمبلغ مطلوبة.'),
                    ),
                  );
                  return;
                }

                try {
                  final dio = ref.read(dioProvider);
                  await dio.post(
                    '/billing/invoices',
                    data: {
                      'invoiceNumber': invoiceNumber,
                      'clientId': selectedClientId,
                      'caseId': selectedCaseId,
                      'amount': amount,
                      'currency': currencyController.text.trim().isEmpty
                          ? 'IQD'
                          : currencyController.text.trim(),
                      'issueDate': issueDate.toIso8601String(),
                      'dueDate': dueDate?.toIso8601String(),
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
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    invoiceNoController.dispose();
    amountController.dispose();
    currencyController.dispose();
    notesController.dispose();

    if (created == true) {
      await _loadData();
    }
  }

  Future<void> _showCreatePaymentDialog(Map<String, dynamic> invoice) async {
    final invoiceId = _idOf(invoice);
    if (invoiceId == null) {
      return;
    }

    final amountController = TextEditingController(
      text: (invoice['amount'] ?? '').toString(),
    );
    final methodController = TextEditingController();
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    DateTime paymentDate = DateTime.now();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'إضافة دفعة - ${(invoice['invoiceNumber'] ?? '').toString()}',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'المبلغ *'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ الدفع'),
                    subtitle: Text(
                      paymentDate.toIso8601String().split('T').first,
                    ),
                    trailing: const Icon(Icons.date_range_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: paymentDate,
                      );
                      if (picked != null) {
                        setDialogState(() => paymentDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: methodController,
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: referenceController,
                    decoration: const InputDecoration(labelText: 'المرجع'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
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
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخل مبلغًا صحيحًا.')),
                  );
                  return;
                }

                try {
                  final dio = ref.read(dioProvider);
                  await dio.post(
                    '/billing/payments',
                    data: {
                      'invoiceId': invoiceId,
                      'amount': amount,
                      'paymentDate': paymentDate.toIso8601String(),
                      'method': methodController.text.trim().isEmpty
                          ? null
                          : methodController.text.trim(),
                      'reference': referenceController.text.trim().isEmpty
                          ? null
                          : referenceController.text.trim(),
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
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    methodController.dispose();
    referenceController.dispose();
    notesController.dispose();

    if (created == true) {
      await _loadData();
    }
  }

  Future<void> _exportInvoice(String invoiceId, String format) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get<List<int>>(
        '/billing/invoices/$invoiceId/export',
        queryParameters: {'format': format},
        options: Options(
          headers: authHeaders(ref),
          responseType: ResponseType.bytes,
        ),
      );

      final bytes = _toUint8List(response.data);
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Empty export payload');
      }

      final suggestedName =
          _extractFilename(response.headers.map['content-disposition']) ??
          'invoice-export.${format == 'txt' ? 'txt' : 'doc'}';
      final savedPath = await saveBytesAsFile(
        bytes: bytes,
        suggestedName: suggestedName,
      );

      if (!mounted) {
        return;
      }

      if (savedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح نافذة الحفظ على هذا النظام.')),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حفظ التصدير: $savedPath')));
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
    final unpaidStats =
        (_invoiceTotals['unpaid'] as Map?)?.cast<String, dynamic>() ?? const {};
    final partialStats =
        (_invoiceTotals['partial'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final paidStats =
        (_invoiceTotals['paid'] as Map?)?.cast<String, dynamic>() ?? const {};
    final allStats =
        (_invoiceTotals['all'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totalPaymentsAmount =
        (_paymentTotals['totalAmount'] as num?)?.toDouble() ?? 0;
    final selectedCaseFilter =
        _cases.any((entry) => _idOf(entry) == _filterCaseId)
        ? _filterCaseId
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Billing & Fees',
            subtitle: 'Fee agreements, invoices, payments, and client balances',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _loading ? null : _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: _showCreateInvoiceDialog,
                  icon: const Icon(Icons.receipt_rounded),
                  label: Text(context.tr('New Invoice')),
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
                  'فلاتر الفوترة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 320,
                      child: DropdownButtonFormField<String?>(
                        initialValue: selectedCaseFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'تصفية حسب القضية',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('كل القضايا'),
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
                            setState(() => _filterCaseId = value),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _filterInvoiceStatus,
                        decoration: const InputDecoration(
                          labelText: 'حالة الفاتورة',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('الكل')),
                          DropdownMenuItem(
                            value: 'unpaid',
                            child: Text('غير مدفوعة'),
                          ),
                          DropdownMenuItem(
                            value: 'partial',
                            child: Text('جزئية'),
                          ),
                          DropdownMenuItem(
                            value: 'paid',
                            child: Text('مدفوعة'),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _filterInvoiceStatus = value ?? 'all',
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _loadData,
                      icon: const Icon(Icons.filter_alt_rounded),
                      label: const Text('تطبيق الفلاتر'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() {
                                _filterCaseId = null;
                                _filterInvoiceStatus = 'all';
                              });
                              _loadData();
                            },
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('إعادة ضبط'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryChip(
                      'إجمالي الفواتير',
                      '${(allStats['count'] as num?)?.toInt() ?? _invoices.length}',
                    ),
                    _summaryChip(
                      'غير مدفوعة',
                      '${(unpaidStats['count'] as num?)?.toInt() ?? 0}',
                    ),
                    _summaryChip(
                      'جزئية',
                      '${(partialStats['count'] as num?)?.toInt() ?? 0}',
                    ),
                    _summaryChip(
                      'مدفوعة',
                      '${(paidStats['count'] as num?)?.toInt() ?? 0}',
                    ),
                    _summaryChip(
                      'إجمالي قيمة الفواتير',
                      'IQD ${((allStats['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                    ),
                    _summaryChip(
                      'إجمالي الدفعات',
                      'IQD ${totalPaymentsAmount.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            GlassPanel(child: Text(_error!))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الفواتير (${_invoices.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_invoices.isEmpty)
                          const Text('لا توجد فواتير بعد.')
                        else
                          ..._invoices.map((invoice) {
                            final client = (invoice['clientId'] is Map)
                                ? (invoice['clientId'] as Map)
                                      .cast<String, dynamic>()
                                : <String, dynamic>{};

                            final caseData = (invoice['caseId'] is Map)
                                ? (invoice['caseId'] as Map)
                                      .cast<String, dynamic>()
                                : <String, dynamic>{};

                            final status = (invoice['status'] ?? 'unpaid')
                                .toString();
                            final invoiceId = _idOf(invoice);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${(invoice['invoiceNumber'] ?? '-').toString()} | ${(invoice['amount'] ?? '-').toString()} ${(invoice['currency'] ?? '').toString()}',
                              ),
                              subtitle: Text(
                                'العميل: ${(client['fullName'] ?? '-').toString()}\nالقضية: ${(caseData['caseNumber'] ?? '-').toString()} ${(caseData['title'] ?? '').toString()}\nالحالة: ${_invoiceStatusLabel(status)}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'pay') {
                                    _showCreatePaymentDialog(invoice);
                                    return;
                                  }
                                  if (invoiceId == null || invoiceId.isEmpty) {
                                    return;
                                  }
                                  if (value == 'export-word') {
                                    _exportInvoice(invoiceId, 'word');
                                  } else if (value == 'export-txt') {
                                    _exportInvoice(invoiceId, 'txt');
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (status != 'paid')
                                    PopupMenuItem<String>(
                                      value: 'pay',
                                      child: Text(context.tr('Pay')),
                                    ),
                                  const PopupMenuItem<String>(
                                    value: 'export-word',
                                    child: Text('تصدير Word'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'export-txt',
                                    child: Text('تصدير TXT'),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الدفعات (${_payments.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_payments.isEmpty)
                          const Text('لا توجد دفعات بعد.')
                        else
                          ..._payments.map((payment) {
                            final invoice = (payment['invoiceId'] is Map)
                                ? (payment['invoiceId'] as Map)
                                      .cast<String, dynamic>()
                                : <String, dynamic>{};
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.payments_outlined),
                              title: Text(
                                (payment['amount'] ?? '-').toString(),
                              ),
                              subtitle: Text(
                                'فاتورة: ${(invoice['invoiceNumber'] ?? '-').toString()} | الحالة: ${_invoiceStatusLabel((invoice['status'] ?? '-').toString())}\n${(payment['paymentDate'] ?? '').toString().split('T').first}',
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
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

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Uint8List? _toUint8List(dynamic payload) {
    if (payload == null) {
      return null;
    }
    if (payload is Uint8List) {
      return payload;
    }
    if (payload is List<int>) {
      return Uint8List.fromList(payload);
    }
    if (payload is List) {
      return Uint8List.fromList(
        payload
            .map((entry) => entry is int ? entry : int.tryParse('$entry') ?? 0)
            .toList(),
      );
    }
    return null;
  }

  String? _extractFilename(List<String>? contentDispositionValues) {
    if (contentDispositionValues == null || contentDispositionValues.isEmpty) {
      return null;
    }

    final raw = contentDispositionValues.join(';');
    final match = RegExp(
      r'filename=\"?([^\";]+)\"?',
      caseSensitive: false,
    ).firstMatch(raw);
    return match?.group(1);
  }

  String _invoiceStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'partial':
        return 'مدفوعة جزئياً';
      case 'overdue':
        return 'متأخرة';
      case 'unpaid':
        return 'غير مدفوعة';
      default:
        return status;
    }
  }
}
