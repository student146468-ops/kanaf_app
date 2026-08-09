import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String productionBaseUrl = String.fromEnvironment(
    'PRODUCTION_API_BASE_URL',
    defaultValue: 'https://kanafapp.pythonanywhere.com/api',
  );

  static String get baseUrl => resolveBaseUrl(
        configuredBaseUrl: configuredBaseUrl,
        isWeb: kIsWeb,
        isDebug: kDebugMode,
        targetPlatform: defaultTargetPlatform,
      );

  static Uri get registerUri => Uri.parse('$baseUrl/auth/register/');

  @visibleForTesting
  static String resolveBaseUrl({
    String configuredBaseUrl = '',
    required bool isWeb,
    required bool isDebug,
    required TargetPlatform targetPlatform,
  }) {
    final explicitBaseUrl = configuredBaseUrl.trim();
    if (explicitBaseUrl.isNotEmpty) {
      return _withoutTrailingSlash(explicitBaseUrl);
    }

    return _withoutTrailingSlash(productionBaseUrl);
  }

  static String _withoutTrailingSlash(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }
}
