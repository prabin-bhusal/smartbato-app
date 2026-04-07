import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/core/security/app_security_guard.dart';
import 'src/core/security/screen_security.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AppSecurityGuard.assertSecureRuntimeConfig();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await ScreenSecurity.enable();
    runApp(const SmartBatoApp());
  } catch (error, stackTrace) {
    debugPrint('SmartBato startup failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _StartupErrorScreen(message: _startupErrorMessage(error)),
      ),
    );
  }
}

String _startupErrorMessage(Object error) {
  final message = error.toString().replaceFirst('StateError: ', '');

  if (message.contains('SMARTBATO_TLS_PINNED_CERT_PEM_B64')) {
    return '$message\n\nRelease builds using the production API host need the pinned TLS certificate define. Add SMARTBATO_TLS_PINNED_CERT_PEM_B64 when building release, or switch the release config to a non-public test host for local testing.';
  }

  if (message.contains('SMARTBATO_API_BASE_URL')) {
    return '$message\n\nThe release API base URL must use https://.';
  }

  return message;
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF090F1F), Color(0xFF123574), Color(0xFF0A5C6E)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                color: const Color(0xF21E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0x33FFFFFF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'SmartBato could not start',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFDDE7FF),
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
