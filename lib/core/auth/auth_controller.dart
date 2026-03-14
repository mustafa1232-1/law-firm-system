import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_client.dart';
import 'auth_models.dart';

const _sessionStorageKey = 'lexiq_auth_session_v1';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref);
  },
);

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
  Future<String?>? _refreshInFlight;

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

      state = state.copyWith(session: session, clearError: true);

      if (_isAccessTokenExpired(session.accessToken)) {
        final refreshedToken = await refreshAccessToken();
        if (refreshedToken == null) {
          await _clearSessionLocal();
          return;
        }
      }

      state = state.copyWith(isBootstrapping: false, clearError: true);
    } catch (_) {
      state = state.copyWith(isBootstrapping: false, clearSession: true);
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final dio = _ref.read(dioProvider);
      final trimmedIdentifier = identifier.trim();
      if (trimmedIdentifier.isEmpty) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'أدخل البريد الإلكتروني أو رقم الهاتف.',
        );
        return false;
      }
      final response = await dio.post(
        '/auth/login',
        data: {'identifier': trimmedIdentifier, 'password': password},
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
    String? email,
    String? phone,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final trimmedEmail = email?.trim();
      final trimmedPhone = phone?.trim();
      if ((trimmedEmail == null || trimmedEmail.isEmpty) &&
          (trimmedPhone == null || trimmedPhone.isEmpty)) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'أدخل البريد الإلكتروني أو رقم الهاتف.',
        );
        return false;
      }

      final dio = _ref.read(dioProvider);
      final response = await dio.post(
        '/auth/register',
        data: {
          'fullName': fullName.trim(),
          if (trimmedEmail != null && trimmedEmail.isNotEmpty)
            'email': trimmedEmail,
          if (trimmedPhone != null && trimmedPhone.isNotEmpty)
            'phone': trimmedPhone,
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
    String? email,
    String? phone,
    required String password,
    required String firmName,
    required String firmCategory,
    required int employeeCount,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final trimmedEmail = email?.trim();
      final trimmedPhone = phone?.trim();
      if ((trimmedEmail == null || trimmedEmail.isEmpty) &&
          (trimmedPhone == null || trimmedPhone.isEmpty)) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'أدخل البريد الإلكتروني أو رقم الهاتف.',
        );
        return false;
      }

      final dio = _ref.read(dioProvider);
      await dio.post(
        '/firms/register-company',
        data: {
          'name': firmName.trim(),
          'category': firmCategory.trim().isEmpty
              ? 'أخرى'
              : firmCategory.trim(),
          'employeeCount': employeeCount <= 0 ? 1 : employeeCount,
          'adminFullName': fullName.trim(),
          if (trimmedEmail != null && trimmedEmail.isNotEmpty)
            'adminEmail': trimmedEmail,
          if (trimmedPhone != null && trimmedPhone.isNotEmpty)
            'adminPhone': trimmedPhone,
          'adminPassword': password,
        },
      );

      final loginIdentifier = (trimmedEmail ?? trimmedPhone ?? '').trim();
      final loginSuccess = await login(
        identifier: loginIdentifier,
        password: password,
      );
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
      await _clearSessionLocal();
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

  Future<void> updateSessionFirm({
    required String firmId,
    List<String>? roles,
  }) async {
    final current = state.session;
    if (current == null) {
      return;
    }

    final mergedRoles = roles ?? current.user.roles;
    final updated = AuthSession(
      accessToken: current.accessToken,
      refreshToken: current.refreshToken,
      user: AuthUser(
        id: current.user.id,
        email: current.user.email,
        roles: mergedRoles,
        firmId: firmId,
      ),
    );

    await _saveSession(updated);
    state = state.copyWith(session: updated, clearError: true);
  }

  String? get accessToken {
    final token = state.session?.accessToken;
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  Future<String?> refreshAccessToken() async {
    final existing = state.session;
    if (existing == null) {
      return null;
    }

    if (_refreshInFlight != null) {
      return _refreshInFlight;
    }

    final future = _refreshAccessTokenInternal(existing);
    _refreshInFlight = future;

    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<String?> _refreshAccessTokenInternal(AuthSession existing) async {
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post(
        '/auth/refresh',
        data: {'refreshToken': existing.refreshToken},
      );

      final refreshed = AuthSession.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );

      await _saveSession(refreshed);
      state = state.copyWith(
        session: refreshed,
        isBootstrapping: false,
        clearError: true,
      );
      return refreshed.accessToken;
    } catch (_) {
      await _clearSessionLocal();
      return null;
    }
  }

  Future<void> _clearSessionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
    state = state.copyWith(
      isBootstrapping: false,
      clearSession: true,
      clearError: true,
    );
  }

  bool _isAccessTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return false;
      }

      final payloadRaw = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) {
        return false;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return expiry.isBefore(DateTime.now().add(const Duration(seconds: 30)));
    } catch (_) {
      return false;
    }
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
