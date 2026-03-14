import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../shared/widgets/glass_panel.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firmNameController = TextEditingController();
  final _firmCategoryController = TextEditingController();
  final _firmEmployeeCountController = TextEditingController(text: '1');

  bool _isCompanyRegistration = false;
  bool _usePhone = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firmNameController.dispose();
    _firmCategoryController.dispose();
    _firmEmployeeCountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final contact = _contactController.text.trim();
    final email = _usePhone ? null : contact;
    final phone = _usePhone ? contact : null;

    bool success = false;
    if (_isCompanyRegistration) {
      success = await ref
          .read(authControllerProvider.notifier)
          .registerCompany(
            fullName: _nameController.text,
            email: email,
            phone: phone,
            password: _passwordController.text,
            firmName: _firmNameController.text,
            firmCategory: _firmCategoryController.text,
            employeeCount:
                int.tryParse(_firmEmployeeCountController.text.trim()) ?? 1,
          );
    } else {
      success = await ref
          .read(authControllerProvider.notifier)
          .register(
            fullName: _nameController.text,
            email: email,
            phone: phone,
            password: _passwordController.text,
          );
    }

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
          constraints: const BoxConstraints(maxWidth: 500),
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
                      context.tr('Create Account'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      value: _isCompanyRegistration,
                      onChanged: (value) =>
                          setState(() => _isCompanyRegistration = value),
                      title: Text(
                        _isCompanyRegistration
                            ? context.tr('Register law firm')
                            : context.tr('Register individual user'),
                      ),
                      subtitle: Text(
                        _isCompanyRegistration
                            ? context.tr(
                                'Create firm account with admin profile and workforce data',
                              )
                            : context.tr('Create standalone user account'),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 14),
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
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: context.tr('Full name'),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return context.tr('Full name is required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactController,
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
                          return _usePhone
                              ? context.tr('Phone number is required')
                              : context.tr('Email is required');
                        }
                        if (_usePhone) {
                          final digits = text.replaceAll(
                            RegExp(r'[^0-9+]'),
                            '',
                          );
                          if (digits.length < 7) {
                            return context.tr('Invalid phone number');
                          }
                          return null;
                        }
                        if (!text.contains('@') || !text.contains('.')) {
                          return context.tr('Invalid email format');
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
                        final text = value ?? '';
                        if (text.length < 8) {
                          return context.tr(
                            'Password must be at least 8 characters',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Confirm password'),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return context.tr('Passwords do not match');
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_isCompanyRegistration) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firmNameController,
                        decoration: InputDecoration(
                          labelText: context.tr('Firm name'),
                        ),
                        validator: (value) {
                          if (!_isCompanyRegistration) {
                            return null;
                          }
                          if ((value ?? '').trim().isEmpty) {
                            return context.tr('Firm name is required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firmCategoryController,
                        decoration: InputDecoration(
                          labelText: context.tr('Firm category'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firmEmployeeCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('Employee count'),
                        ),
                        validator: (value) {
                          if (!_isCompanyRegistration) {
                            return null;
                          }
                          final count = int.tryParse((value ?? '').trim());
                          if (count == null || count <= 0) {
                            return context.tr('Enter valid employee count');
                          }
                          return null;
                        },
                      ),
                    ],
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
                            : Text(context.tr('Create Account')),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/auth/login'),
                      child: Text(
                        context.tr('Already have an account? Sign in'),
                      ),
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
