import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
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
          queryParameters: const {'limit': 100},
          options: Options(headers: authHeaders(ref)),
        ),
        dio.get(
          '/billing/payments',
          queryParameters: const {'limit': 100},
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

  @override
  Widget build(BuildContext context) {
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
                          'Invoices (${_invoices.length})',
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
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${(invoice['invoiceNumber'] ?? '-').toString()} | ${(invoice['amount'] ?? '-').toString()} ${(invoice['currency'] ?? '').toString()}',
                              ),
                              subtitle: Text(
                                'العميل: ${(client['fullName'] ?? '-').toString()}\nالقضية: ${(caseData['caseNumber'] ?? '-').toString()} ${(caseData['title'] ?? '').toString()}\nالحالة: $status',
                              ),
                              isThreeLine: true,
                              trailing: status == 'paid'
                                  ? const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.green,
                                    )
                                  : OutlinedButton(
                                      onPressed: () =>
                                          _showCreatePaymentDialog(invoice),
                                      child: const Text('Pay'),
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
                          'Payments (${_payments.length})',
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
                                'فاتورة: ${(invoice['invoiceNumber'] ?? '-').toString()} | الحالة: ${(invoice['status'] ?? '-').toString()}\n${(payment['paymentDate'] ?? '').toString().split('T').first}',
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
}
