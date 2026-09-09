import 'package:flutter/foundation.dart';

class ApiConfig {
  static const Map<String, String> imageRequestHeaders = {
    'User-Agent': 'Kanaf Flutter Android',
  };

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

  static String get backendOriginUrl {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme) {
      return _withoutTrailingSlash(
          baseUrl.replaceFirst(RegExp(r'/api/?$'), ''));
    }
    return _withoutTrailingSlash(
      uri.replace(path: '', query: '', fragment: '').toString(),
    );
  }

  static String? buildImageUrl(String? image) {
    final trimmed = image?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      _logImageUrl(trimmed, trimmed);
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      final resolved = 'https:$trimmed';
      _logImageUrl(trimmed, resolved);
      return resolved;
    }

    final firstSegment = trimmed.split('/').first;
    final looksLikeHost = !trimmed.startsWith('/') &&
        firstSegment.contains('.') &&
        !firstSegment.contains(' ') &&
        !firstSegment.contains('\\');
    if (looksLikeHost) {
      final resolved = 'https://$trimmed';
      _logImageUrl(trimmed, resolved);
      return resolved;
    }

    final origin = Uri.parse('$backendOriginUrl/');
    final path = trimmed.replaceFirst(RegExp(r'^/+'), '');
    final resolved = origin.resolve(path).toString();
    _logImageUrl(trimmed, resolved);
    return resolved;
  }

  static String resolveBackendUrl(String value) => buildImageUrl(value) ?? '';

  static void _logImageUrl(String source, String resolved) {
    if (!kDebugMode) return;
    debugPrint('Kanaf image url source="$source" resolved="$resolved"');
  }

  static void logImageLoadError({
    required String source,
    required String resolved,
    required Object error,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'Kanaf image load failed RAW IMAGE VALUE="$source" '
      'FINAL IMAGE URL="$resolved" error="$error"',
    );
  }

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
