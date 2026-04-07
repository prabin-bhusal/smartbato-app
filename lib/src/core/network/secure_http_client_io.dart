import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createPinnedInnerClient() {
  const pemBase64 = String.fromEnvironment(
    'SMARTBATO_TLS_PINNED_CERT_PEM_B64',
    defaultValue: '',
  );

  final trimmed = pemBase64.trim();
  if (trimmed.isEmpty) {
    return http.Client();
  }

  try {
    final certBytes = base64Decode(trimmed);
    final context = SecurityContext(withTrustedRoots: false);
    context.setTrustedCertificatesBytes(certBytes);

    final httpClient = HttpClient(context: context);
    httpClient.badCertificateCallback = (cert, host, port) => false;

    return IOClient(httpClient);
  } catch (error) {
    debugPrint('Pinned TLS init failed, fallback to default client: $error');
    return http.Client();
  }
}
