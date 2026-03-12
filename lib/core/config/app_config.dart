import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.subtitle,
    required this.apiBaseUrl,
  });

  final String appName;
  final String subtitle;
  final String apiBaseUrl;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  const appName = String.fromEnvironment('APP_NAME', defaultValue: 'LexIQ Iraq');
  const subtitle = String.fromEnvironment(
    'APP_SUBTITLE',
    defaultValue: 'Iraqi Legal Intelligence Platform',
  );
  const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api/v1',
  );

  return const AppConfig(
    appName: appName,
    subtitle: subtitle,
    apiBaseUrl: apiBaseUrl,
  );
});
