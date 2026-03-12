import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../../../shared/widgets/section_header.dart';

class CreateCaseWizardPage extends StatefulWidget {
  const CreateCaseWizardPage({super.key});

  @override
  State<CreateCaseWizardPage> createState() => _CreateCaseWizardPageState();
}

class _CreateCaseWizardPageState extends State<CreateCaseWizardPage> {
  int currentStep = 0;

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
              onStepContinue: () {
                if (currentStep < 5) {
                  setState(() => currentStep++);
                } else {
                  context.go('/cases/case_new');
                }
              },
              onStepCancel: () {
                if (currentStep > 0) {
                  setState(() => currentStep--);
                }
              },
              controlsBuilder: (context, details) {
                return Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(context.tr(currentStep == 5 ? 'Create' : 'Next')),
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
                  content: const _WizardStep(
                    fields: ['Case Number', 'Title', 'Case Type', 'Court'],
                  ),
                ),
                Step(
                  title: Text(context.tr('Parties')),
                  content: const _WizardStep(
                    fields: ['Client', 'Opposite Party', 'Assigned Lawyers'],
                  ),
                ),
                Step(
                  title: Text(context.tr('Facts')),
                  content: const _WizardStep(fields: ['Facts Summary', 'Timeline Events']),
                ),
                Step(
                  title: Text(context.tr('Claims')),
                  content: const _WizardStep(fields: ['Claims', 'Defenses', 'Counter Arguments']),
                ),
                Step(
                  title: Text(context.tr('Documents')),
                  content: const _WizardStep(
                    fields: ['Upload Core Documents', 'Evidence Checklist'],
                  ),
                ),
                Step(
                  title: Text(context.tr('AI Initial Analysis')),
                  content: const _WizardStep(fields: ['Case Genome Suggestions', 'Risk Snapshot']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardStep extends StatelessWidget {
  const _WizardStep({required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: fields
          .map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(decoration: InputDecoration(labelText: context.tr(field))),
              ))
          .toList(),
    );
  }
}
