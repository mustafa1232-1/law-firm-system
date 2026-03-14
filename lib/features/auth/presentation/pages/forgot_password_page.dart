import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/network/api_helpers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/glass_panel.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _identifierController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loadingRequest = false;
  bool _loadingReset = false;
  bool _usePhone = false;

  String? _challengeId;
  String? _debugResetCode;
  String? _requestMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestResetCode() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showError(
        _usePhone
            ? context.tr('Please enter phone number.')
            : context.tr('Please enter email.'),
      );
      return;
    }

    if (!_usePhone &&
        (!identifier.contains('@') || !identifier.contains('.'))) {
      _showError(context.tr('Invalid email format'));
      return;
    }

    if (_usePhone && identifier.replaceAll(RegExp(r'[^0-9+]'), '').length < 7) {
      _showError(context.tr('Invalid phone number'));
      return;
    }

    setState(() {
      _loadingRequest = true;
      _requestMessage = null;
      _challengeId = null;
      _debugResetCode = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/forgot-password',
        data: {'identifier': identifier},
      );
      final data = (response.data as Map).cast<String, dynamic>();

      setState(() {
        _challengeId = data['challengeId']?.toString();
        _debugResetCode = data['resetCode']?.toString();
        _requestMessage = (data['message'] ?? '').toString();
      });

      if (_debugResetCode != null && _debugResetCode!.isNotEmpty) {
        _codeController.text = _debugResetCode!;
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _requestMessage?.isNotEmpty == true
                ? _requestMessage!
                : context.tr('Password reset request sent successfully.'),
          ),
        ),
      );
    } catch (error) {
      _showError(parseApiError(error));
    } finally {
      if (mounted) {
        setState(() => _loadingRequest = false);
      }
    }
  }

  Future<void> _confirmReset() async {
    final challengeId = _challengeId;
    if (challengeId == null || challengeId.isEmpty) {
      _showError(context.tr('Request a reset code first.'));
      return;
    }

    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError(context.tr('Enter reset code.'));
      return;
    }

    final password = _passwordController.text;
    if (password.length < 8) {
      _showError(context.tr('Password must be at least 8 characters'));
      return;
    }

    if (password != _confirmPasswordController.text) {
      _showError(context.tr('Passwords do not match'));
      return;
    }

    setState(() => _loadingReset = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/auth/reset-password',
        data: {
          'challengeId': challengeId,
          'code': code,
          'newPassword': password,
        },
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Password reset completed.'))),
      );
      context.go('/auth/login');
    } on DioException catch (error) {
      _showError(parseApiError(error));
    } catch (error) {
      _showError(parseApiError(error));
    } finally {
      if (mounted) {
        setState(() => _loadingReset = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final showResetForm = _challengeId != null && _challengeId!.isNotEmpty;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
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
                  Text(
                    _usePhone
                        ? context.tr(
                            'Enter your phone to receive a reset code.',
                          )
                        : context.tr(
                            'Enter your email to receive a reset code.',
                          ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        selected: !_usePhone,
                        label: Text(context.tr('Use Email')),
                        onSelected: (_) => setState(() => _usePhone = false),
                      ),
                      ChoiceChip(
                        selected: _usePhone,
                        label: Text(context.tr('Use Phone')),
                        onSelected: (_) => setState(() => _usePhone = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _identifierController,
                    keyboardType: _usePhone
                        ? TextInputType.phone
                        : TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _usePhone
                          ? context.tr('Phone number')
                          : context.tr('Email'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loadingRequest ? null : _requestResetCode,
                      icon: _loadingRequest
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(context.tr('Send reset code')),
                    ),
                  ),
                  if (_requestMessage != null &&
                      _requestMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _requestMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (_debugResetCode != null &&
                      _debugResetCode!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${context.tr('Reset code')}: $_debugResetCode',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  if (showResetForm) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: context.tr('Reset code'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.tr('New password'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Confirm new password'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loadingReset ? null : _confirmReset,
                        icon: _loadingReset
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_reset_rounded),
                        label: Text(context.tr('Confirm reset')),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
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
