import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../security/app_security_runtime.dart';
import 'secure_http_client_stub.dart'
    if (dart.library.io) 'secure_http_client_io.dart'
    as secure_inner;

class SecureHttpClient extends http.BaseClient {
  SecureHttpClient({http.Client? innerClient, Duration? timeout})
    : _innerClient = innerClient ?? secure_inner.createPinnedInnerClient(),
      _timeout = timeout ?? const Duration(seconds: 20),
      _allowedHost = Uri.parse(ApiConfig.baseUrl).host;

  final http.Client _innerClient;
  final Duration _timeout;
  final String _allowedHost;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _validateRequest(request.url);
    _injectSecurityHeaders(request);

    return _innerClient
        .send(request)
        .timeout(
          _timeout,
          onTimeout: () {
            throw TimeoutException('Request timed out. Please try again.');
          },
        );
  }

  void _validateRequest(Uri uri) {
    if (!kReleaseMode) {
      return;
    }

    if (uri.scheme.toLowerCase() != 'https') {
      throw Exception('Insecure HTTP requests are blocked in release builds.');
    }

    if (_allowedHost.isNotEmpty && uri.host != _allowedHost) {
      throw Exception('Unexpected API host blocked for security.');
    }

    const hasPinnedCert = String.fromEnvironment(
      'SMARTBATO_TLS_PINNED_CERT_PEM_B64',
      defaultValue: '',
    );

    if (_looksLikePublicDomain(uri.host) && hasPinnedCert.trim().isEmpty) {
      debugPrint(
        'Release request to ${uri.host} is not pinned. Falling back to the default HTTP client.',
      );
    }
  }

  void _injectSecurityHeaders(http.BaseRequest request) {
    request.headers.putIfAbsent(
      'X-Device-Risk',
      () => AppSecurityRuntime.riskHeader,
    );
    request.headers.putIfAbsent(
      'X-Device-Risk-Reasons',
      () => AppSecurityRuntime.riskReasonsHeader,
    );

    final token = AppSecurityRuntime.attestationToken;
    if (token != null && token.isNotEmpty) {
      request.headers.putIfAbsent('X-Device-Attestation', () => token);
    }
  }

  bool _looksLikePublicDomain(String host) {
    final value = host.trim().toLowerCase();
    if (value.isEmpty) {
      return false;
    }

    if (value == 'localhost' || value == '127.0.0.1') {
      return false;
    }

    final ipV4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    if (ipV4.hasMatch(value)) {
      return false;
    }

    return true;
  }

  @override
  void close() {
    _innerClient.close();
    super.close();
  }
}
