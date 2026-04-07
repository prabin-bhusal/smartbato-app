import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';

import 'core/network/network_controller.dart';
import 'core/realtime/realtime_socket_service.dart';
import 'core/security/device_risk_service.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/session_storage.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/data/auth_api.dart';
import 'features/coins/widgets/coin_gain_overlay_host.dart';
import 'features/content/data/content_api.dart';
import 'features/discussion/data/discussion_api.dart';
import 'features/permissions/permission_controller.dart';
import 'features/permissions/mandatory_permissions_screen.dart';
import 'features/auto_practice/data/auto_practice_api.dart';
import 'features/battle/pages/battle_intro_page.dart';
import 'features/daily_challenge/data/daily_challenge_api.dart';
import 'features/time_attack/data/time_attack_api.dart';
import 'features/help_support/data/support_api.dart';
import 'features/battle/data/battle_api.dart';
import 'features/auth/screens/profile_complete_screen.dart';
import 'features/auth/services/daily_login_reminder_service.dart';
import 'features/dashboard/data/analytics_api.dart';
import 'features/dashboard/data/dashboard_api.dart';
import 'features/live_tests/data/live_test_api.dart';
import 'features/mock_tests/data/mock_test_api.dart';
import 'features/practice_by_topics/data/practice_topics_api.dart';
import 'core/navigation/app_route_observer.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/student_dashboard_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/leaderboard/pages/leaderboard_page.dart';

class SmartBatoApp extends StatefulWidget {
  const SmartBatoApp({super.key});

  @override
  State<SmartBatoApp> createState() => _SmartBatoAppState();
}

class _SmartBatoAppState extends State<SmartBatoApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthController _authController;
  late final NetworkController _networkController;
  late final PermissionController _permissionController;
  bool _dailyReminderScheduled = false;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _appLinksSubscription;
  String? _prefilledReferralCode;
  bool _battleInviteListenerAttached = false;
  bool _battleInviteDialogOpen = false;
  String? _activeBattleInviteCode;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(
      authApi: AuthApi(),
      dashboardApi: DashboardApi(),
      analyticsApi: AnalyticsApi(),
      practiceTopicsApi: PracticeTopicsApi(),
      autoPracticeApi: AutoPracticeApi(),
      dailyChallengeApi: DailyChallengeApi(),
      timeAttackApi: TimeAttackApi(),
      mockTestApi: MockTestApi(),
      liveTestApi: LiveTestApi(),
      contentApi: ContentApi(),
      supportApi: SupportApi(),
      discussionApi: DiscussionApi(),
      battleApi: BattleApi(),
      realtimeSocketService: RealtimeSocketService(),
      deviceRiskService: DeviceRiskService(),
      sessionStorage: SessionStorage(),
    );

    _networkController = NetworkController();
    _permissionController = PermissionController(
      networkController: _networkController,
    );
    _appLinks = AppLinks();
    _networkController.initialize();
    _authController.initialize();
    _permissionController.initialize();
    _authController.addListener(_syncBattleInviteListener);
    _initializeDeepLinks();
  }

  @override
  void dispose() {
    _appLinksSubscription?.cancel();
    _authController.removeListener(_syncBattleInviteListener);
    _authController.dispose();
    _permissionController.dispose();
    _networkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _authController,
        _networkController,
        _permissionController,
      ]),
      builder: (context, child) {
        return MaterialApp(
          key: ValueKey<bool>(_authController.isLoggedIn),
          debugShowCheckedModeBanner: false,
          title: 'SmartBato',
          theme: AppTheme.light,
          navigatorKey: _navigatorKey,
          navigatorObservers: [appRouteObserver],
          builder: (context, child) {
            return CoinGainOverlayHost(
              authController: _authController,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _resolveHome(),
          routes: {
            '/leaderboard': (context) =>
                LeaderboardPage(authController: _authController),
          },
        );
      },
    );
  }

  Widget _resolveHome() {
    if (!_authController.isInitialized ||
        !_networkController.isInitialized ||
        !_permissionController.isInitialized) {
      return const SplashScreen();
    }

    if (!_authController.onboardingSeen) {
      return OnboardingScreen(onFinished: _authController.completeOnboarding);
    }

    if (!_permissionController.hasMandatoryPermissions) {
      return MandatoryPermissionsScreen(
        permissionController: _permissionController,
      );
    }

    _ensureDailyLoginReminderScheduled();

    if (!_authController.isLoggedIn) {
      return LoginScreen(
        authController: _authController,
        prefilledReferralCode: _prefilledReferralCode,
      );
    }

    if (_authController.isSecurityCompromised) {
      return _SecurityBlockedScreen(authController: _authController);
    }

    if (_authController.user?.dataFilled != true) {
      return ProfileCompleteScreen(
        authController: _authController,
        prefilledReferralCode: _prefilledReferralCode,
      );
    }

    return StudentDashboardScreen(authController: _authController);
  }

  void _syncBattleInviteListener() {
    if (_authController.isLoggedIn) {
      _authController.ensureRealtimeConnected();
      if (!_battleInviteListenerAttached) {
        _authController.realtimeSocket.on('battle:invite', _onBattleInvite);
        _authController.realtimeSocket.on(
          'battle:invite_cancelled',
          _onBattleInviteCancelled,
        );
        _battleInviteListenerAttached = true;
      }
      return;
    }

    if (_battleInviteListenerAttached) {
      _authController.realtimeSocket.off('battle:invite', _onBattleInvite);
      _authController.realtimeSocket.off(
        'battle:invite_cancelled',
        _onBattleInviteCancelled,
      );
      _battleInviteListenerAttached = false;
    }
    _activeBattleInviteCode = null;
    _battleInviteDialogOpen = false;
  }

  void _onBattleInvite(dynamic payload) {
    if (!mounted || payload is! Map) {
      return;
    }

    final data = Map<String, dynamic>.from(
      payload.map<String, dynamic>((k, v) => MapEntry(k.toString(), v)),
    );
    final invite = data['invite'];
    if (invite is! Map<String, dynamic>) {
      return;
    }

    final code = (invite['code'] ?? '').toString();
    if (code.isEmpty || _activeBattleInviteCode == code) {
      return;
    }

    _activeBattleInviteCode = code;
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showBattleInviteDialog(context, invite);
    });
  }

  void _onBattleInviteCancelled(dynamic payload) {
    if (!mounted || payload is! Map) {
      return;
    }

    final data = Map<String, dynamic>.from(
      payload.map<String, dynamic>((k, v) => MapEntry(k.toString(), v)),
    );
    final invite = data['invite'];
    if (invite is! Map<String, dynamic>) {
      return;
    }

    final code = (invite['code'] ?? '').toString();
    if (code.isEmpty || _activeBattleInviteCode != code) {
      return;
    }

    _activeBattleInviteCode = null;
    if (_battleInviteDialogOpen &&
        _navigatorKey.currentState?.canPop() == true) {
      _navigatorKey.currentState?.pop();
    }

    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Battle invite was cancelled.')),
    );
  }

  Future<void> _showBattleInviteDialog(
    BuildContext context,
    Map<String, dynamic> invite,
  ) async {
    final host = invite['host'] as Map<String, dynamic>?;
    final hostName = (host?['name'] ?? 'Friend').toString();
    final hostCode = (host?['username'] ?? '').toString();
    final code = (invite['code'] ?? '').toString();
    final expiresAt = DateTime.tryParse(
      (invite['expires_at'] ?? '').toString(),
    );
    var remaining = expiresAt == null
        ? 30
        : expiresAt.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      remaining = 1;
    }
    var accepting = false;
    Timer? timer;
    _battleInviteDialogOpen = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }

            remaining -= 1;
            if (remaining <= 0) {
              timer.cancel();
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
            }
          });

          return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                title: const Text('Battle Challenge Invite'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$hostName challenged you to a battle.'),
                    const SizedBox(height: 8),
                    Text('Host friend code: $hostCode'),
                    Text('Invite code: $code'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Accept within ${remaining.clamp(0, 999)}s',
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: accepting
                        ? null
                        : () {
                            timer?.cancel();
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: accepting || remaining <= 0
                        ? null
                        : () async {
                            setModalState(() => accepting = true);
                            try {
                              final payload = await _authController
                                  .joinBattleInvite(code);
                              if (!dialogContext.mounted) {
                                return;
                              }
                              timer?.cancel();
                              if (Navigator.of(dialogContext).canPop()) {
                                Navigator.of(dialogContext).pop();
                              }

                              final battle = payload['battle'];
                              if (battle is Map<String, dynamic>) {
                                final navContext = _navigatorKey.currentContext;
                                if (navContext == null) {
                                  return;
                                }

                                Navigator.of(navContext).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => BattleIntroPage(
                                      authController: _authController,
                                      battle: Map<String, dynamic>.from(battle),
                                    ),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (!dialogContext.mounted) {
                                return;
                              }
                              timer?.cancel();
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                    child: const Text('Accept'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      timer?.cancel();
      _battleInviteDialogOpen = false;
      _activeBattleInviteCode = null;
    }
  }

  void _ensureDailyLoginReminderScheduled() {
    if (_dailyReminderScheduled || !_permissionController.notificationGranted) {
      return;
    }

    _dailyReminderScheduled = true;
    unawaited(DailyLoginReminderService.instance.initializeAndSchedule());
  }

  Future<void> _initializeDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      _applyReferralFromUri(initialUri);
    } catch (_) {
      // Ignore malformed link at startup.
    }

    _appLinksSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _applyReferralFromUri(uri);
      },
      onError: (_) {
        // Ignore malformed runtime links.
      },
    );
  }

  void _applyReferralFromUri(Uri? uri) {
    if (uri == null) {
      return;
    }

    final raw =
        uri.queryParameters['ref'] ?? uri.queryParameters['referral_code'];
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    final normalized = raw.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    if (normalized.isEmpty) {
      return;
    }

    final capped = normalized.substring(
      0,
      normalized.length > 20 ? 20 : normalized.length,
    );

    if (_prefilledReferralCode == capped) {
      return;
    }

    setState(() {
      _prefilledReferralCode = capped;
    });
  }
}

class _SecurityBlockedScreen extends StatelessWidget {
  const _SecurityBlockedScreen({required this.authController});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final reasons = authController.deviceRiskReport.reasons;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Security Protection Active',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This device failed security checks. For your account safety, exam and wallet flows are blocked on compromised devices.',
                    style: TextStyle(color: Color(0xFF475569), height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  if (reasons.isNotEmpty)
                    ...reasons.map(
                      (reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $reason'),
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      await authController.reevaluateSecurity();
                    },
                    child: const Text('Re-check Security'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () async {
                      await authController.logout();
                    },
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
