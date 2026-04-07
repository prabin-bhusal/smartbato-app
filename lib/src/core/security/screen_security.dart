import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenSecurity {
  static const platform = MethodChannel('com.example.app/security');
  static const Set<String> _captureAllowList = <String>{'test@gmail.com'};

  static Future<void> enable() async {
    if (kIsWeb) {
      return;
    }

    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod<void>('enableSecureWindow');
      } catch (e) {
        // Keep app running even if secure flag fails.
        debugPrint('Failed to enable secure window: $e');
      }
    }
  }

  static Future<void> disable() async {
    if (kIsWeb) {
      return;
    }

    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod<void>('disableSecureWindow');
      } catch (e) {
        // Keep app running even if secure flag update fails.
        debugPrint('Failed to disable secure window: $e');
      }
    }
  }

  static Future<void> applyPolicyForEmail(String? email) async {
    final normalized = (email ?? '').trim().toLowerCase();
    if (_captureAllowList.contains(normalized)) {
      await disable();
      return;
    }
    await enable();
  }
}
