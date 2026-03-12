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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firmNameController = TextEditingController();
  final _firmCategoryController = TextEditingController();
  final _firmEmployeeCountController = TextEditingController(text: '1');
  bool _isCompanyRegistration = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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

    bool success = false;
    if (_isCompanyRegistration) {
      success = await ref.read(authControllerProvider.notifier).registerCompany(
            fullName: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
            firmName: _firmNameController.text,
            firmCategory: _firmCategoryController.text,
            employeeCount: int.tryParse(_firmEmployeeCountController.text.trim()) ?? 1,
          );
    } else {
      success = await ref.read(authControllerProvider.notifier).register(
            fullName: _nameController.text,
            email: _emailController.text,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
                      onChanged: (value) => setState(() => _isCompanyRegistration = value),
                      title: Text(
                        _isCompanyRegistration
                            ? 'تسجيل شركة محاماة'
                            : 'تسجيل مستخدم فردي',
                      ),
                      subtitle: Text(
                        _isCompanyRegistration
                            ? 'إنشاء شركة مع حساب مدير وبيانات القوة العاملة'
                            : 'إنشاء حساب مستخدم مستقل',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: context.tr('Full name')),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'الاسم الكامل مطلوب';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: context.tr('Email')),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'البريد الإلكتروني مطلوب';
                        }
                        if (!text.contains('@')) {
                          return 'البريد الإلكتروني غير صالح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: context.tr('Password')),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.length < 8) {
                          return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: context.tr('Confirm password')),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'كلمتا المرور غير متطابقتين';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_isCompanyRegistration) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firmNameController,
                        decoration: const InputDecoration(labelText: 'اسم الشركة'),
                        validator: (value) {
                          if (!_isCompanyRegistration) {
                            return null;
                          }
                          if ((value ?? '').trim().isEmpty) {
                            return 'اسم الشركة مطلوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firmCategoryController,
                        decoration: const InputDecoration(labelText: 'فئة الشركة'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _firmEmployeeCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'عدد الموظفين'),
                        validator: (value) {
                          if (!_isCompanyRegistration) {
                            return null;
                          }
                          final count = int.tryParse((value ?? '').trim());
                          if (count == null || count <= 0) {
                            return 'أدخل عدد موظفين صحيح';
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(context.tr('Create Account')),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/auth/login'),
                      child: Text(context.tr('Already have an account? Sign in')),
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
