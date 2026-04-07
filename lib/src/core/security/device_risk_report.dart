class DeviceRiskReport {
  const DeviceRiskReport({
    required this.isRooted,
    required this.isJailbroken,
    required this.isEmulator,
    required this.isHooked,
    required this.isDebuggerAttached,
  });

  final bool isRooted;
  final bool isJailbroken;
  final bool isEmulator;
  final bool isHooked;
  final bool isDebuggerAttached;

  bool get isCompromised =>
      isRooted || isJailbroken || isEmulator || isHooked || isDebuggerAttached;

  List<String> get reasons {
    final values = <String>[];
    if (isRooted) values.add('rooted-device');
    if (isJailbroken) values.add('jailbroken-device');
    if (isEmulator) values.add('emulator-detected');
    if (isHooked) values.add('hooking-tool-detected');
    if (isDebuggerAttached) values.add('debugger-attached');
    return values;
  }

  factory DeviceRiskReport.fromJson(Map<dynamic, dynamic>? raw) {
    final json = raw ?? const <dynamic, dynamic>{};
    return DeviceRiskReport(
      isRooted: json['isRooted'] == true,
      isJailbroken: json['isJailbroken'] == true,
      isEmulator: json['isEmulator'] == true,
      isHooked: json['isHooked'] == true,
      isDebuggerAttached: json['isDebuggerAttached'] == true,
    );
  }
}
