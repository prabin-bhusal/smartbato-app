import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_risk_report.dart';

class DeviceRiskService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.app/security',
  );

  Future<DeviceRiskReport> evaluateRisk() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceRisk',
      );
      return DeviceRiskReport.fromJson(result);
    } catch (_) {
      return const DeviceRiskReport(
        isRooted: false,
        isJailbroken: false,
        isEmulator: false,
        isHooked: false,
        isDebuggerAttached: false,
      );
    }
  }

  Future<String?> fetchAttestationToken() async {
    try {
      final token = await _channel.invokeMethod<String>('getAttestationToken');
      return _withProviderPrefix(token);
    } catch (_) {
      return null;
    }
  }

  String? _withProviderPrefix(String? token) {
    final value = token?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.contains(':')) {
      return value;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'play_integrity:$value';
      case TargetPlatform.iOS:
        return 'app_attest:$value';
      default:
        return value;
    }
  }
}
