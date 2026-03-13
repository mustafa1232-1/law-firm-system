import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../config/app_config.dart';
import '../utils/text_encoding_sanitizer.dart';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final authController = ref.read(authControllerProvider.notifier);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!_isAuthEndpoint(options.path)) {
          final token = authController.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        response.data = sanitizeMojibakeInData(response.data);
        handler.next(response);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final requestOptions = error.requestOptions;
        final alreadyRetried = requestOptions.extra['__retried'] == true;

        if (statusCode == 401 &&
            !_isAuthEndpoint(requestOptions.path) &&
            !alreadyRetried) {
          final refreshedToken = await authController.refreshAccessToken();
          if (refreshedToken != null && refreshedToken.isNotEmpty) {
            final retried = requestOptions.copyWith(
              headers: <String, dynamic>{
                ...requestOptions.headers,
                'Authorization': 'Bearer $refreshedToken',
              },
              extra: <String, dynamic>{
                ...requestOptions.extra,
                '__retried': true,
              },
            );

            try {
              final response = await dio.fetch<dynamic>(retried);
              return handler.resolve(response);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            } catch (_) {
              // Fall through to original error.
            }
          }
        }

        handler.next(error);
      },
    ),
  );

  return dio;
});

bool _isAuthEndpoint(String path) {
  return path.contains('/auth/login') ||
      path.contains('/auth/register') ||
      path.contains('/auth/refresh') ||
      path.contains('/auth/logout');
}
