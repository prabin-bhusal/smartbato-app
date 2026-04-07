import 'device_risk_report.dart';

class AppSecurityRuntime {
  static DeviceRiskReport _riskReport = const DeviceRiskReport(
    isRooted: false,
    isJailbroken: false,
    isEmulator: false,
    isHooked: false,
    isDebuggerAttached: false,
  );

  static String? _attestationToken;

  static DeviceRiskReport get riskReport => _riskReport;

  static String get riskHeader {
    if (_riskReport.isCompromised) {
      return 'high';
    }
    return 'low';
  }

  static String get riskReasonsHeader {
    final reasons = _riskReport.reasons;
    return reasons.isEmpty ? 'none' : reasons.join(',');
  }

  static String? get attestationToken => _attestationToken;

  static void updateRisk(DeviceRiskReport report) {
    _riskReport = report;
  }

  static void updateAttestationToken(String? token) {
    final value = token?.trim();
    _attestationToken = (value == null || value.isEmpty) ? null : value;
  }
}
