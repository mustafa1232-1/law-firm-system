import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _usePhone = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          identifier: _identifierController.text,
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (success) {
      context.go('/dashboard');
      return;
    }

    final error = ref.read(authControllerProvider).errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GlassPanel(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Sign In'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(context.tr('Access your LexIQ Iraq legal workspace.')),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          selected: !_usePhone,
                          onSelected: (_) => setState(() => _usePhone = false),
                          label: Text(context.tr('Use Email')),
                        ),
                        ChoiceChip(
                          selected: _usePhone,
                          onSelected: (_) => setState(() => _usePhone = true),
                          label: Text(context.tr('Use Phone')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _identifierController,
                      keyboardType: _usePhone
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: _usePhone
                            ? context.tr('Phone number')
                            : context.tr('Email'),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return context.tr('Field is required');
                        }
                        if (!_usePhone &&
                            (!text.contains('@') || !text.contains('.'))) {
                          return context.tr('Invalid email format');
                        }
                        if (_usePhone &&
                            text.replaceAll(RegExp(r'[^0-9+]'), '').length <
                                7) {
                          return context.tr('Invalid phone number');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Password'),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return context.tr('Password is required');
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isSubmitting ? null : _submit,
                        child: authState.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.tr('Sign In')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  context.go('/auth/forgot-password'),
                              child: Text(context.tr('Forgot password?')),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => context.go('/auth/register'),
                              child: Text(context.tr('Create account')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
