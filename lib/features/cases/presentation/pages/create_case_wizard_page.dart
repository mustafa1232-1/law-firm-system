import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

const _iraqiCaseTypes = <String>[
  'مدنية',
  'تجارية',
  'جنائية',
  'أحوال شخصية',
  'عمالية',
  'إدارية',
  'عقارية',
  'ضريبية',
  'دستورية',
  'تنفيذ',
  'تحكيم',
  'أخرى',
];

class CreateCaseWizardPage extends ConsumerStatefulWidget {
  const CreateCaseWizardPage({super.key});

  @override
  ConsumerState<CreateCaseWizardPage> createState() => _CreateCaseWizardPageState();
}

class _CreateCaseWizardPageState extends ConsumerState<CreateCaseWizardPage> {
  int currentStep = 0;
  bool isSubmitting = false;

  final _caseNumberController = TextEditingController();
  final _internalReferenceController = TextEditingController();
  final _titleController = TextEditingController();
  final _courtController = TextEditingController();
  final _governorateController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _oppositePartyController = TextEditingController();
  final _summaryController = TextEditingController();
  final _factsController = TextEditingController();
  final _claimsController = TextEditingController();
  final _evidenceController = TextEditingController();
  final _analysisContextController = TextEditingController();

  String _caseType = _iraqiCaseTypes.last;

  @override
  void dispose() {
    _caseNumberController.dispose();
    _internalReferenceController.dispose();
    _titleController.dispose();
    _courtController.dispose();
    _governorateController.dispose();
    _clientIdController.dispose();
    _oppositePartyController.dispose();
    _summaryController.dispose();
    _factsController.dispose();
    _claimsController.dispose();
    _evidenceController.dispose();
    _analysisContextController.dispose();
    super.dispose();
  }

  Future<void> _createCase() async {
    if (_caseNumberController.text.trim().isEmpty || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم القضية والعنوان مطلوبان.')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/cases',
        data: {
          'caseNumber': _caseNumberController.text.trim(),
          'internalReference': _internalReferenceController.text.trim(),
          'title': _titleController.text.trim(),
          'caseType': _caseType,
          'court': _courtController.text.trim(),
          'governorate': _governorateController.text.trim(),
          'clientId': _clientIdController.text.trim().isEmpty ? null : _clientIdController.text.trim(),
          'oppositeParty': _oppositePartyController.text.trim(),
          'summary': _summaryController.text.trim(),
          'facts': _factsController.text.trim(),
          'claims': _claimsController.text.trim(),
          'evidenceList': _evidenceController.text
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        },
        options: Options(headers: authHeaders(ref)),
      );

      final created = (response.data as Map).cast<String, dynamic>();
      final id = (created['_id'] ?? created['id']).toString();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء القضية بنجاح.')),
      );
      context.go('/cases/$id');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  void _onContinue() {
    if (currentStep < 5) {
      setState(() => currentStep++);
      return;
    }
    _createCase();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Create New Case Wizard',
              subtitle: 'Basic info, parties, facts, claims, documents, AI analysis',
              trailing: TextButton(
                onPressed: () => context.go('/cases'),
                child: Text(context.tr('Close')),
              ),
            ),
            const SizedBox(height: 12),
            Stepper(
              currentStep: currentStep,
              onStepContinue: isSubmitting ? null : _onContinue,
              onStepCancel: () {
                if (currentStep > 0) {
                  setState(() => currentStep--);
                }
              },
              controlsBuilder: (context, details) {
                return Row(
                  children: [
                    ElevatedButton(
                      onPressed: isSubmitting ? null : details.onStepContinue,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr(currentStep == 5 ? 'Create' : 'Next')),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: Text(context.tr('Back')),
                    ),
                  ],
                );
              },
              steps: [
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
                        items: _iraqiCaseTypes
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _caseType = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      _input(context, _courtController, 'Court'),
                      _input(context, _governorateController, 'Governorate'),
                    ],
                  ),
                ),
                Step(
                  title: Text(context.tr('Parties')),
                  content: Column(
                    children: [
                      _input(context, _clientIdController, 'Client ID (optional)'),
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
                    ],
                  ),
                ),
                Step(
                  title: Text(context.tr('Claims')),
                  content: _input(context, _claimsController, 'Claims', maxLines: 4),
                ),
                Step(
                  title: Text(context.tr('Documents')),
                  content: _input(
                    context,
                    _evidenceController,
                    'Evidence Checklist (one per line)',
                    maxLines: 5,
                  ),
                ),
                Step(
                  title: Text(context.tr('AI Initial Analysis')),
                  content: _input(
                    context,
                    _analysisContextController,
                    'Optional AI context to run after opening case details',
                    maxLines: 4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    BuildContext context,
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: context.tr(label)),
      ),
    );
  }
}
