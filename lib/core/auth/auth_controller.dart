import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_client.dart';
import 'auth_models.dart';

const _sessionStorageKey = 'lexiq_auth_session_v1';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

final accessTokenProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).session?.accessToken;
});

final authHeaderProvider = Provider<Map<String, String>>((ref) {
  final token = ref.watch(accessTokenProvider);
  if (token == null || token.isEmpty) {
    return const {};
  }

  return {'Authorization': 'Bearer $token'};
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(AuthState.initial) {
    _restoreSession();
  }

  final Ref _ref;

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionStorageKey);
      if (raw == null || raw.isEmpty) {
        state = state.copyWith(isBootstrapping: false, clearError: true);
        return;
      }

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = AuthSession.fromJson(json);
      if (session.accessToken.isEmpty ||
          session.refreshToken.isEmpty ||
          session.user.id.isEmpty) {
        await prefs.remove(_sessionStorageKey);
        state = state.copyWith(
          isBootstrapping: false,
          clearSession: true,
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        isBootstrapping: false,
        session: session,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(isBootstrapping: false, clearSession: true);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final session = AuthSession.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );

      await _saveSession(session);
      state = state.copyWith(
        isSubmitting: false,
        session: session,
        clearError: true,
      );
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _extractApiError(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'حدث خطأ غير متوقع أثناء تسجيل الدخول.',
      );
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post(
        '/auth/register',
        data: {
          'fullName': fullName.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      final session = AuthSession.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );

      await _saveSession(session);
      state = state.copyWith(
        isSubmitting: false,
        session: session,
        clearError: true,
      );
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _extractApiError(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'تعذر إنشاء الحساب الآن.',
      );
      return false;
    }
  }

  Future<bool> registerCompany({
    required String fullName,
    required String email,
    required String password,
    required String firmName,
    required String firmCategory,
    required int employeeCount,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final dio = _ref.read(dioProvider);
      await dio.post(
        '/firms/register-company',
        data: {
          'name': firmName.trim(),
          'category': firmCategory.trim().isEmpty ? 'أخرى' : firmCategory.trim(),
          'employeeCount': employeeCount <= 0 ? 1 : employeeCount,
          'adminFullName': fullName.trim(),
          'adminEmail': email.trim(),
          'adminPassword': password,
        },
      );

      final loginSuccess = await login(email: email, password: password);
      if (loginSuccess) {
        return true;
      }

      state = state.copyWith(
        isSubmitting: false,
        errorMessage:
            'تم إنشاء الشركة لكن فشل تسجيل الدخول التلقائي. حاول تسجيل الدخول يدويًا.',
      );
      return false;
    } on DioException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _extractApiError(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'تعذر إنشاء حساب الشركة الآن.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    final session = state.session;
    if (session == null) {
      return;
    }

    try {
      final dio = _ref.read(dioProvider);
      await dio.post(
        '/auth/logout',
        data: {'refreshToken': session.refreshToken},
        options: Options(
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        ),
      );
    } catch (_) {
      // Ignore remote logout errors and clear local session.
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionStorageKey);
      state = state.copyWith(clearSession: true, clearError: true);
    }
  }

  Future<void> clearError() async {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(clearError: true);
  }

  Future<void> _saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
  }
}

String _extractApiError(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    if (message is List && message.isNotEmpty) {
      return message.join('\n');
    }
    final errorField = data['error'];
    if (errorField is String && errorField.trim().isNotEmpty) {
      return errorField;
    }
  }

  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return 'تعذر الاتصال بالخادم. تأكد من رابط API وتشغيل الباك اند.';
  }

  return 'فشل تنفيذ الطلب. يرجى المحاولة مجددًا.';
}
