import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

class AppSecurityGuard {
  static void assertSecureRuntimeConfig() {
    if (!kReleaseMode) {
      return;
    }

    final uri = Uri.parse(ApiConfig.baseUrl);

    if (uri.scheme.toLowerCase() != 'https') {
      throw StateError(
        'Release build requires HTTPS API base URL. Configure SMARTBATO_API_BASE_URL with https://.',
      );
    }

    final host = uri.host.toLowerCase();

    if (host == 'localhost' || host == '127.0.0.1') {
      throw StateError('Release build cannot use localhost API host.');
    }

    final ip = InternetAddress.tryParse(host);
    if (ip != null &&
        ip.type == InternetAddressType.IPv4 &&
        _isPrivateIpv4(ip)) {
      throw StateError('Release build cannot use private-network API IP.');
    }

    const pinnedCertPemBase64 = String.fromEnvironment(
      'SMARTBATO_TLS_PINNED_CERT_PEM_B64',
      defaultValue: '',
    );

    if (_looksLikePublicDomain(host) && pinnedCertPemBase64.trim().isEmpty) {
      debugPrint(
        'Release build is running without TLS pinning for $host. The app will start, but certificate pinning is disabled.',
      );
    }
  }

  static bool _isPrivateIpv4(InternetAddress ip) {
    final octets = ip.address.split('.').map(int.parse).toList(growable: false);
    if (octets.length != 4) {
      return false;
    }

    final a = octets[0];
    final b = octets[1];

    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    if (a == 127) return true;

    return false;
  }

  static bool _looksLikePublicDomain(String host) {
    if (host.isEmpty) {
      return false;
    }

    if (host == 'localhost' || host == '127.0.0.1') {
      return false;
    }

    final ip = InternetAddress.tryParse(host);
    if (ip != null) {
      return false;
    }

    return true;
  }
}
