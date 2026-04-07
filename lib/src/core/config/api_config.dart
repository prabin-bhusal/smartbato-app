import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  // Production URLs for SmartBato
  static const String defaultBaseUrl = 'https://smartbato.com/api';
  static const String defaultSocketUrl = 'https://socket.smartbato.com/';
  static const String localBaseUrl = 'http://192.168.1.76:32882/api';
  static const String localSocketUrl = 'http://192.168.1.76:3001';

  static const String _environment = String.fromEnvironment(
    'SMARTBATO_ENV',
    defaultValue: 'production', //production, local
  );

  static bool get _isLocalEnvironment =>
      _environment.trim().toLowerCase() == 'local';

  static String get baseUrl {
    final overrideBaseUrl = const String.fromEnvironment(
      'SMARTBATO_API_BASE_URL',
      defaultValue: '',
    ).trim();
    final rawUrl = overrideBaseUrl.isNotEmpty
        ? overrideBaseUrl
        : (_isLocalEnvironment ? localBaseUrl : defaultBaseUrl);

    if (!kIsWeb && Platform.isAndroid && rawUrl.contains('localhost')) {
      return rawUrl.replaceAll('localhost', '10.0.2.2');
    }

    return rawUrl;
  }

  static String get socketUrl {
    final overrideSocketUrl = const String.fromEnvironment(
      'SMARTBATO_SOCKET_URL',
      defaultValue: '',
    ).trim();
    final explicitSocketUrl = overrideSocketUrl.isNotEmpty
        ? overrideSocketUrl
        : (_isLocalEnvironment ? localSocketUrl : defaultSocketUrl);

    final normalized = _normalizeSocketHost(explicitSocketUrl);
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  static String _normalizeSocketHost(String rawUrl) {
    if (!kIsWeb && Platform.isAndroid && rawUrl.contains('localhost')) {
      return rawUrl.replaceAll('localhost', '10.0.2.2');
    }

    return rawUrl;
  }
}
