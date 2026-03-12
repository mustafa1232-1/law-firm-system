import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

Map<String, String> authHeaders(WidgetRef ref) {
  return ref.read(authHeaderProvider);
}

String parseApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.join('\n');
      }
      final err = data['error'];
      if (err is String && err.trim().isNotEmpty) {
        return err;
      }
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'تعذر الاتصال بالخادم. تأكد من API_BASE_URL.';
    }
  }

  return 'حدث خطأ غير متوقع أثناء تنفيذ الطلب.';
}
