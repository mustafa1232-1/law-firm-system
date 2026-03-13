import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

const _iraqiCaseTypes = <String>[
  'مدنية','تجارية','جنائية','أحوال شخصية','عمالية','إدارية','عقارية','ضريبية','دستورية','تنفيذ','تحكيم','أخرى',
];

class CreateCaseWizardPage extends ConsumerStatefulWidget {
  const CreateCaseWizardPage({super.key});

  @override
  ConsumerState<CreateCaseWizardPage> createState() => _CreateCaseWizardPageState();
}

class _CreateCaseWizardPageState extends ConsumerState<CreateCaseWizardPage> {
  int currentStep = 0;
  bool isSubmitting = false;
  bool _loadingCourts = false;
  bool _loadingClients = false;

  final _caseNumberController = TextEditingController();
  final _internalReferenceController = TextEditingController();
  final _titleController = TextEditingController();
  final _courtController = TextEditingController();
  final _governorateController = TextEditingController();
  final _courtSearchController = TextEditingController();

  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientAddressController = TextEditingController();
  final _oppositePartyController = TextEditingController();

  final _summaryController = TextEditingController();
  final _factsController = TextEditingController();
  final _claimsController = TextEditingController();

  final _contractAmountController = TextEditingController();
  final _initialPaymentController = TextEditingController();
  final _secondPaymentAmountController = TextEditingController();

  String _caseType = _iraqiCaseTypes.last;
  String? _selectedCourtId;
  String? _selectedClientId;
  DateTime _contractDate = DateTime.now();
  DateTime? _secondPaymentDueDate;

  List<Map<String, dynamic>> _courts = const [];
  List<Map<String, dynamic>> _clientSuggestions = const [];
  final List<_EvidenceRowData> _evidenceRows = [];
  final List<_InstallmentRowData> _additionalInstallments = [];

  @override
  void initState() {
    super.initState();
    _loadCourts();
    _addEvidenceRows(count: 3);
  }

  @override
  void dispose() {
    _caseNumberController.dispose();
    _internalReferenceController.dispose();
    _titleController.dispose();
    _courtController.dispose();
    _governorateController.dispose();
    _courtSearchController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _clientAddressController.dispose();
    _oppositePartyController.dispose();
    _summaryController.dispose();
    _factsController.dispose();
    _claimsController.dispose();
    _contractAmountController.dispose();
    _initialPaymentController.dispose();
    _secondPaymentAmountController.dispose();
    for (final row in _evidenceRows) { row.dispose(); }
    for (final row in _additionalInstallments) { row.dispose(); }
    super.dispose();
  }

  Future<void> _loadCourts({String q = ''}) async {
    setState(() => _loadingCourts = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/courts',
        queryParameters: {'limit': 80, if (q.trim().isNotEmpty) 'q': q.trim()},
        options: Options(headers: authHeaders(ref)),
      );
      final data = (response.data as Map).cast<String, dynamic>();
      final items = ((data['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() => _courts = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _courts = const []);
    } finally {
      if (mounted) setState(() => _loadingCourts = false);
    }
  }

  Future<void> _searchClients(String query) async {
    final value = query.trim();
    if (value.length < 2) {
      setState(() { _clientSuggestions = const []; _selectedClientId = null; });
      return;
    }

    setState(() => _loadingClients = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/clients',
        queryParameters: {'search': value, 'limit': 10},
        options: Options(headers: authHeaders(ref)),
      );
      final data = (response.data as Map).cast<String, dynamic>();
      final items = ((data['items'] as List?) ?? const [])
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      if (!mounted) return;

      String? autoId;
      for (final item in items) {
        final name = (item['fullName'] ?? '').toString().trim().toLowerCase();
        if (name == value.toLowerCase()) { autoId = _idOf(item); break; }
      }

      setState(() {
        _clientSuggestions = items;
        _selectedClientId = autoId;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _clientSuggestions = const []);
    } finally {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  void _applyCourtSelection(String? courtId) {
    if (courtId == null || courtId.isEmpty) {
      setState(() => _selectedCourtId = null);
      return;
    }
    final selected = _courts.firstWhere((item) => _idOf(item) == courtId, orElse: () => <String, dynamic>{});
    setState(() {
      _selectedCourtId = courtId;
      _courtController.text = (selected['name'] ?? '').toString();
      final governorate = (selected['governorate'] ?? '').toString();
      if (governorate.isNotEmpty) _governorateController.text = governorate;
    });
  }

  void _applyClientSelection(Map<String, dynamic> client) {
    setState(() {
      _selectedClientId = _idOf(client);
      _clientNameController.text = (client['fullName'] ?? '').toString();
      _clientPhoneController.text = (client['phone'] ?? '').toString();
      _clientAddressController.text = (client['address'] ?? '').toString();
    });
  }

  void _addEvidenceRows({int count = 1}) {
    for (var i = 0; i < count && _evidenceRows.length < 100; i++) {
      _evidenceRows.add(_EvidenceRowData());
    }
    setState(() {});
  }

  Future<void> _pickEvidenceFile(int index) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    setState(() => _evidenceRows[index].file = picked.files.first);
  }

  void _addInstallmentRow() {
    if (_additionalInstallments.length >= 100) return;
    setState(() => _additionalInstallments.add(_InstallmentRowData()));
  }

  Future<void> _createCase() async {
    if (_caseNumberController.text.trim().isEmpty || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم القضية وعنوان القضية مطلوبان.')));
      return;
    }
    if (_clientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسم العميل مطلوب.')));
      return;
    }

    final contractAmount = double.tryParse(_contractAmountController.text.trim()) ?? 0;
    final initialPayment = double.tryParse(_initialPaymentController.text.trim()) ?? 0;
    final secondPaymentAmount = double.tryParse(_secondPaymentAmountController.text.trim()) ?? 0;

    final selectedCourt = _courts.firstWhere((item) => _idOf(item) == _selectedCourtId, orElse: () => <String, dynamic>{});
    final evidenceEntries = _evidenceRows
        .map((row) => {'attachmentName': row.file?.name, 'description': row.descriptionController.text.trim().isEmpty ? null : row.descriptionController.text.trim()})
        .where((row) => (row['attachmentName'] ?? '').toString().isNotEmpty || (row['description'] ?? '').toString().isNotEmpty)
        .toList();

    final additionalInstallments = _additionalInstallments
        .map((row) {
          final amount = double.tryParse(row.amountController.text.trim()) ?? 0;
          if (amount <= 0 || row.dueDate == null) return null;
          return {'amount': amount, 'dueDate': row.dueDate!.toIso8601String(), 'label': row.labelController.text.trim().isEmpty ? null : row.labelController.text.trim()};
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    setState(() => isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/cases',
        data: {
          'caseNumber': _caseNumberController.text.trim(),
          'internalReference': _internalReferenceController.text.trim(),
          'title': _titleController.text.trim(),
          'caseType': _caseType,
          'courtId': _selectedCourtId,
          'court': _courtController.text.trim().isEmpty ? null : _courtController.text.trim(),
          'governorate': _governorateController.text.trim().isEmpty ? null : _governorateController.text.trim(),
          'courtCity': selectedCourt['city'],
          'courtDistrict': selectedCourt['district'],
          'courtArea': selectedCourt['area'],
          'courtLocationDescription': selectedCourt['addressDescription'],
          'clientId': _selectedClientId,
          if (_selectedClientId == null) 'newClient': {
            'fullName': _clientNameController.text.trim(),
            'phone': _clientPhoneController.text.trim().isEmpty ? null : _clientPhoneController.text.trim(),
            'address': _clientAddressController.text.trim().isEmpty ? null : _clientAddressController.text.trim(),
          },
          'oppositeParty': _oppositePartyController.text.trim().isEmpty ? null : _oppositePartyController.text.trim(),
          'summary': _summaryController.text.trim().isEmpty ? null : _summaryController.text.trim(),
          'facts': _factsController.text.trim().isEmpty ? null : _factsController.text.trim(),
          'claims': _claimsController.text.trim().isEmpty ? null : _claimsController.text.trim(),
          'evidenceEntries': evidenceEntries,
          'evidenceList': evidenceEntries.map((entry) => (entry['description'] ?? '').toString()).where((entry) => entry.trim().isNotEmpty).toList(),
          'contractDate': _contractDate.toIso8601String(),
          'contractAmount': contractAmount,
          'initialPayment': initialPayment,
          'secondPaymentAmount': secondPaymentAmount,
          'secondPaymentDueDate': _secondPaymentDueDate?.toIso8601String(),
          'additionalInstallments': additionalInstallments,
          'fees': contractAmount,
        },
        options: Options(headers: authHeaders(ref)),
      );

      final created = (response.data as Map).cast<String, dynamic>();
      final caseId = (created['_id'] ?? created['id']).toString();

      final uploadedEntries = <Map<String, dynamic>>[];
      final linkedDocumentIds = <String>[];
      for (final row in _evidenceRows) {
        final description = row.descriptionController.text.trim();
        final file = row.file;
        String? documentId;
        if (file != null) {
          final bytes = file.bytes;
          if (bytes != null) {
            final formData = FormData.fromMap({
              'file': MultipartFile.fromBytes(bytes, filename: file.name),
              'title': description.isEmpty ? file.name : description,
              'caseId': caseId,
              'tags': 'evidence,case-intake',
            });

            final docResponse = await dio.post(
              '/documents/upload',
              data: formData,
              options: Options(
                headers: authHeaders(ref),
                contentType: 'multipart/form-data',
              ),
            );
            final docData = (docResponse.data as Map).cast<String, dynamic>();
            documentId = (docData['_id'] ?? docData['id'])?.toString();
            if (documentId != null && documentId.isNotEmpty) {
              linkedDocumentIds.add(documentId);
            }
          }
        }

        if (description.isNotEmpty || file != null) {
          uploadedEntries.add({'documentId': documentId, 'attachmentName': file?.name, 'description': description.isEmpty ? null : description});
        }
      }

      if (uploadedEntries.isNotEmpty || linkedDocumentIds.isNotEmpty) {
        await dio.patch('/cases/$caseId',
          data: {
            'evidenceEntries': uploadedEntries,
            'evidenceList': uploadedEntries.map((entry) => (entry['description'] ?? '').toString()).where((entry) => entry.trim().isNotEmpty).toList(),
            'documentIds': linkedDocumentIds,
          },
          options: Options(headers: authHeaders(ref)),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء القضية وربط البيانات بنجاح.')));
      context.go('/cases/$caseId');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseApiError(error))));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = <Step>[
      Step(
        title: Text(context.tr('Basic Info')),
        content: Column(
          children: [
            _input(context, _caseNumberController, 'Case Number'),
            _input(context, _internalReferenceController, 'Internal Ref'),
            _input(context, _titleController, 'Title'),
            DropdownButtonFormField<String>(
              initialValue: _caseType,
              decoration: InputDecoration(labelText: context.tr('Case Type')),
              items: _iraqiCaseTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (value) { if (value != null) setState(() => _caseType = value); },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _courtSearchController,
              onSubmitted: (value) => _loadCourts(q: value),
              decoration: InputDecoration(
                labelText: 'ابحث عن المحكمة',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _loadingCourts ? null : () => _loadCourts(q: _courtSearchController.text),
                  icon: _loadingCourts ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>('court-${_selectedCourtId ?? 'none'}-${_courts.length}'),
              initialValue: _selectedCourtId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'المحكمة'),
              items: _courts.map((court) => DropdownMenuItem(value: _idOf(court), child: Text(_courtDisplayLabel(court), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _applyCourtSelection,
            ),
            const SizedBox(height: 10),
            _input(context, _courtController, 'Court'),
            _input(context, _governorateController, 'Governorate'),
          ],
        ),
      ),
      Step(
        title: const Text('العميل والخصم'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _clientNameController,
              onChanged: (value) { _selectedClientId = null; _searchClients(value); },
              decoration: InputDecoration(
                labelText: 'اسم العميل *',
                prefixIcon: const Icon(Icons.person_search_rounded),
                helperText: _selectedClientId == null ? 'يمكن البحث عن عميل موجود أو كتابة اسم جديد' : 'معرّف العميل: $_selectedClientId',
              ),
            ),
            if (_loadingClients)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_clientSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 170),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _clientSuggestions.length,
                  itemBuilder: (context, index) {
                    final client = _clientSuggestions[index];
                    return ListTile(
                      dense: true,
                      onTap: () => _applyClientSelection(client),
                      title: Text((client['fullName'] ?? '-').toString()),
                      subtitle: Text('المعرف: ${_idOf(client) ?? '-'} | الهاتف: ${(client['phone'] ?? '-').toString()}'),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            _input(context, _clientPhoneController, 'الهاتف'),
            _input(context, _clientAddressController, 'العنوان'),
            _input(context, _oppositePartyController, 'Opposite Party'),
          ],
        ),
      ),
      Step(
        title: Text(context.tr('Facts')),
        content: Column(
          children: [
            _input(context, _summaryController, 'Summary', maxLines: 3),
            _input(context, _factsController, 'Facts Summary', maxLines: 5),
            _input(context, _claimsController, 'Claims', maxLines: 4),
          ],
        ),
      ),
      Step(
        title: const Text('قائمة الأدلة'),
        content: Column(
          children: [
            const Align(alignment: Alignment.centerRight, child: Text('لكل صف: عمود ملف اختياري + عمود وصف الدليل (حتى 100 صف).')),
            const SizedBox(height: 10),
            ..._evidenceRows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickEvidenceFile(index),
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(row.file == null ? 'رفع ملف' : row.file!.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: row.descriptionController,
                        decoration: InputDecoration(labelText: 'وصف الدليل ${index + 1}'),
                      ),
                    ),
                    if (_evidenceRows.length > 1)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _evidenceRows[index].dispose();
                            _evidenceRows.removeAt(index);
                          });
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _evidenceRows.length >= 100 ? null : () => _addEvidenceRows(),
                icon: const Icon(Icons.add_rounded),
                label: Text('إضافة صف دليل (${_evidenceRows.length}/100)'),
              ),
            ),
          ],
        ),
      ),
      Step(
        title: const Text('الأتعاب والفواتير'),
        content: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاريخ العقد'),
              subtitle: Text('${_contractDate.year}-${_contractDate.month.toString().padLeft(2, '0')}-${_contractDate.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.event_rounded),
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: _contractDate);
                if (picked != null) setState(() => _contractDate = picked);
              },
            ),
            _input(context, _contractAmountController, 'قيمة العقد (IQD)', keyboardType: TextInputType.number),
            _input(context, _initialPaymentController, 'الدفعة الأولى (IQD)', keyboardType: TextInputType.number),
            Row(
              children: [
                Expanded(child: _input(context, _secondPaymentAmountController, 'قيمة الدفعة الثانية (IQD)', keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: _secondPaymentDueDate ?? _contractDate.add(const Duration(days: 30)));
                      if (picked != null) setState(() => _secondPaymentDueDate = picked);
                    },
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(_secondPaymentDueDate == null ? 'تاريخ استحقاق الثانية' : '${_secondPaymentDueDate!.year}-${_secondPaymentDueDate!.month.toString().padLeft(2, '0')}-${_secondPaymentDueDate!.day.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._additionalInstallments.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: row.labelController, decoration: const InputDecoration(labelText: 'اسم الدفعة'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: row.amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'القيمة'))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: row.dueDate ?? _contractDate.add(const Duration(days: 45)));
                          if (picked != null) setState(() => row.dueDate = picked);
                        },
                        child: Text(row.dueDate == null ? 'تاريخ الاستحقاق' : '${row.dueDate!.year}-${row.dueDate!.month.toString().padLeft(2, '0')}-${row.dueDate!.day.toString().padLeft(2, '0')}'),
                      ),
                    ),
                    IconButton(onPressed: () { setState(() { row.dispose(); _additionalInstallments.removeAt(index); }); }, icon: const Icon(Icons.delete_outline_rounded)),
                  ],
                ),
              );
            }),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _addInstallmentRow, icon: const Icon(Icons.add_rounded), label: const Text('إضافة دفعة إضافية'))),
          ],
        ),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Create New Case Wizard',
              subtitle: 'Basic info, client, evidence, and payment plan',
              trailing: TextButton(onPressed: () => context.go('/cases'), child: Text(context.tr('Close'))),
            ),
            const SizedBox(height: 12),
            Stepper(
              currentStep: currentStep,
              onStepContinue: isSubmitting ? null : () {
                if (currentStep < steps.length - 1) { setState(() => currentStep++); return; }
                _createCase();
              },
              onStepCancel: () { if (currentStep > 0) setState(() => currentStep--); },
              controlsBuilder: (context, details) => Row(
                children: [
                  ElevatedButton(
                    onPressed: isSubmitting ? null : details.onStepContinue,
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(context.tr(currentStep == steps.length - 1 ? 'Create' : 'Next')),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: details.onStepCancel, child: Text(context.tr('Back'))),
                ],
              ),
              steps: steps,
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(BuildContext context, TextEditingController controller, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(controller: controller, maxLines: maxLines, keyboardType: keyboardType, decoration: InputDecoration(labelText: context.tr(label))),
    );
  }

  String? _idOf(Map<String, dynamic> value) {
    final id = value['_id'] ?? value['id'];
    if (id == null) return null;
    return id.toString();
  }

  String _courtDisplayLabel(Map<String, dynamic> court) {
    final name = (court['name'] ?? '-').toString();
    final governorate = (court['governorate'] ?? '').toString();
    final city = (court['city'] ?? '').toString();
    final location = [governorate, city].where((item) => item.trim().isNotEmpty).join(' - ');
    return location.isEmpty ? name : '$name | $location';
  }
}

class _EvidenceRowData {
  _EvidenceRowData() : descriptionController = TextEditingController();
  final TextEditingController descriptionController;
  PlatformFile? file;
  void dispose() => descriptionController.dispose();
}

class _InstallmentRowData {
  _InstallmentRowData() : labelController = TextEditingController(), amountController = TextEditingController();
  final TextEditingController labelController;
  final TextEditingController amountController;
  DateTime? dueDate;
  void dispose() { labelController.dispose(); amountController.dispose(); }
}
