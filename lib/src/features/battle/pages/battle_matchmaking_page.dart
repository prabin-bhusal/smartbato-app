import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import 'battle_intro_page.dart';

class BattleMatchmakingPage extends StatefulWidget {
  const BattleMatchmakingPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<BattleMatchmakingPage> createState() => _BattleMatchmakingPageState();
}

class _BattleMatchmakingPageState extends State<BattleMatchmakingPage>
    with TickerProviderStateMixin {
  static const int _autoAssignSeconds = 30;

  Timer? _timer;
  Timer? _activeBattleSyncTimer;
  int _remaining = _autoAssignSeconds;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  bool _navigated = false;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _attachSocket();
    _startActiveBattleSync();
    _startMatchmaking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _activeBattleSyncTimer?.cancel();
    _pulseController.dispose();
    widget.authController.realtimeSocket.off('battle:matched', _handleMatched);
    widget.authController.realtimeSocket.off(
      'battle_match_found',
      _handleMatched,
    );
    super.dispose();
  }

  void _attachSocket() {
    widget.authController.ensureRealtimeConnected();
    widget.authController.realtimeSocket.off('battle:matched', _handleMatched);
    widget.authController.realtimeSocket.off(
      'battle_match_found',
      _handleMatched,
    );
    widget.authController.realtimeSocket.on('battle:matched', _handleMatched);
    widget.authController.realtimeSocket.on(
      'battle_match_found',
      _handleMatched,
    );
  }

  void _startActiveBattleSync() {
    _activeBattleSyncTimer?.cancel();
    _syncActiveBattle();
    _activeBattleSyncTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _syncActiveBattle(),
    );
  }

  Future<void> _syncActiveBattle() async {
    if (!mounted || _navigated) {
      return;
    }
    try {
      final activeBattle = await widget.authController.loadActiveBattle();
      if (!mounted || _navigated) {
        return;
      }
      if (activeBattle != null) {
        _goToIntro(Map<String, dynamic>.from(activeBattle));
      }
    } catch (_) {
      // Ignore transient polling errors while matchmaking is in progress.
    }
  }

  void _handleMatched(dynamic payload) {
    if (!mounted || _navigated || payload is! Map) return;
    final data = Map<String, dynamic>.from(
      payload.map<String, dynamic>((k, v) => MapEntry(k.toString(), v)),
    );
    final battle = data['battle'];
    if (battle is! Map<String, dynamic>) return;
    _goToIntro(Map<String, dynamic>.from(battle));
  }

  Future<void> _startMatchmaking() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await widget.authController.startBattle();
      if (!mounted) return;
      final status = (payload['status'] ?? 'queued').toString();
      final battle = payload['battle'];
      if (status == 'matched' && battle is Map<String, dynamic>) {
        _goToIntro(Map<String, dynamic>.from(battle));
        return;
      }
      setState(() => _loading = false);
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _remaining = _autoAssignSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _acceptAi();
      }
    });
  }

  Future<void> _acceptAi() async {
    if (_navigated) return;
    try {
      final payload = await widget.authController.acceptAiBattle();
      if (!mounted) return;
      final battle = payload['battle'];
      if (battle is Map<String, dynamic>) {
        _goToIntro(Map<String, dynamic>.from(battle));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _cancelAndPop() async {
    if (_navigated || _cancelling) return;
    setState(() => _cancelling = true);
    _timer?.cancel();
    _activeBattleSyncTimer?.cancel();
    widget.authController.realtimeSocket.off('battle:matched', _handleMatched);
    widget.authController.realtimeSocket.off(
      'battle_match_found',
      _handleMatched,
    );
    try {
      await widget.authController.cancelBattleQueue();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  void _goToIntro(Map<String, dynamic> battle) {
    if (_navigated) return;
    _navigated = true;
    _timer?.cancel();
    _activeBattleSyncTimer?.cancel();
    widget.authController.realtimeSocket.off('battle:matched', _handleMatched);
    widget.authController.realtimeSocket.off(
      'battle_match_found',
      _handleMatched,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BattleIntroPage(
          authController: widget.authController,
          battle: battle,
        ),
      ),
    );
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.authController.user?.name ?? '?';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && !_cancelling && !_navigated) _cancelAndPop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (!_loading && _error == null)
                      _cancelling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                              ),
                            )
                          : GestureDetector(
                              onTap: _cancelAndPop,
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 24,
                              ),
                            ),
                    const Spacer(),
                    const Text(
                      'Matchmaking',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _loading ? '—' : _fmt(_remaining),
                        style: TextStyle(
                          color: (!_loading && _remaining <= 10)
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF38BDF8),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                          ),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  for (int i = 0; i < 3; i++)
                                    _PulsingRing(
                                      progress:
                                          (_pulseController.value + i * 0.33) %
                                          1.0,
                                      maxRadius: 100.0 + i * 22,
                                    ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 16,
                              child: _PlayerCard(
                                initial: initial,
                                name: userName,
                                color: const Color(0xFF0EA5E9),
                                isSearching: false,
                              ),
                            ),
                            const Text(
                              'VS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            Positioned(
                              right: 16,
                              child: _PlayerCard(
                                initial: '?',
                                name: _loading ? '…' : 'Searching',
                                color: const Color(0xFF6366F1),
                                isSearching: !_loading,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _loading
                            ? 'Entering queue…'
                            : 'Waiting for a real opponent in your course…',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _loading
                            ? ''
                            : 'If no one joins, an AI opponent will be assigned in ${_fmt(_remaining)}.',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (!_loading)
                        TextButton(
                          onPressed: _cancelling ? null : _cancelAndPop,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                          ),
                          child: const Text('Cancel matchmaking'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingRing extends StatelessWidget {
  const _PulsingRing({required this.progress, required this.maxRadius});

  final double progress;
  final double maxRadius;

  @override
  Widget build(BuildContext context) {
    final radius = maxRadius * progress;
    final opacity = ((1.0 - progress) * 0.4).clamp(0.0, 1.0);
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF0EA5E9).withValues(alpha: opacity),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.initial,
    required this.name,
    required this.color,
    required this.isSearching,
  });

  final String initial;
  final String name;
  final Color color;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          ),
          child: Center(
            child: isSearching
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color.withValues(alpha: 0.7),
                    ),
                  )
                : Text(
                    initial,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
