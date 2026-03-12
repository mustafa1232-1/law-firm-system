import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/feature_placeholder_page.dart';

class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FeaturePlaceholderPage(
      title: 'Billing & Fees',
      description: 'Fee agreements, invoices, payments, and client balances',
      highlights: const [
        'Invoice and payment records',
        'Due reminders and expense tracking',
        'Printable billing exports',
      ],
      trailing: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.receipt_rounded),
        label: Text(context.tr('New Invoice')),
      ),
    );
  }
}
