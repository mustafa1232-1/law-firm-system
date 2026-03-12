import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GlassPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Reset Password'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(context.tr('We will send a reset link to your email address.')),
                  const SizedBox(height: 14),
                  TextField(decoration: InputDecoration(labelText: context.tr('Email'))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/auth/login'),
                      child: Text(context.tr('Send Link')),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/auth/login'),
                    child: Text(context.tr('Back to sign in')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
