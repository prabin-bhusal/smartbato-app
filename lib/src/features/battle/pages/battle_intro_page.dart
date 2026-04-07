import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import '../data/battle_opponent_alias.dart';
import 'battle_questions_page.dart';

class BattleIntroPage extends StatefulWidget {
  const BattleIntroPage({
    super.key,
    required this.authController,
    required this.battle,
  });

  final AuthController authController;
  final Map<String, dynamic> battle;

  @override
  State<BattleIntroPage> createState() => _BattleIntroPageState();
}

class _BattleIntroPageState extends State<BattleIntroPage> {
  // Phase 0 = VS screen (2 s), 1 = "3", 2 = "2", 3 = "1", 4 = "GO!"
  int _phase = 0;
  bool _navigating = false;
  Timer? _timer;

  static const _phaseDurations = [2000, 1000, 1000, 1000, 600];

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNext() {
    final ms = _phaseDurations[_phase.clamp(0, _phaseDurations.length - 1)];
    _timer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      final next = _phase + 1;
      if (next >= _phaseDurations.length) {
        _goToQuestions();
        return;
      }
      setState(() => _phase = next);
      _scheduleNext();
    });
  }

  void _goToQuestions() {
    if (_navigating) return;
    _navigating = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BattleQuestionsPage(
          authController: widget.authController,
          battle: widget.battle,
        ),
      ),
    );
  }

  ({String myName, String opponentName, bool isAi}) _resolveNames() {
    final myId = widget.authController.user?.id ?? 0;
    final participants =
        (widget.battle['participants'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

    String myName = widget.authController.user?.name ?? 'You';
    String opponentName = '?';
    bool isAi = true;

    for (final p in participants) {
      final user = p['user'] as Map<String, dynamic>?;
      final uid = (user?['id'] as num?)?.toInt() ?? -1;
      if (uid == myId) {
        myName = (user?['name'] as String?) ?? myName;
      } else {
        isAi = (p['is_ai'] as bool?) ?? true;
        final battleId = (widget.battle['id'] as num?)?.toInt();
        opponentName = isAi
            ? pickSystemOpponentAlias(battleId: battleId)
            : ((user?['name'] as String?) ?? 'Opponent');
      }
    }
    return (myName: myName, opponentName: opponentName, isAi: isAi);
  }

  @override
  Widget build(BuildContext context) {
    final names = _resolveNames();

    if (_phase == 0) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        'Battle Intro',
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppSurfaceCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _IntroPlayerCard(
                                name: names.myName,
                                color: const Color(0xFF0EA5E9),
                                subtitle: 'You',
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'VS',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 5,
                                  ),
                                ),
                              ),
                              _IntroPlayerCard(
                                name: names.opponentName,
                                color: const Color(0xFFEF4444),
                                subtitle: 'Opponent',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Battle starts shortly. Stay ready for the first question.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    const countdownLabels = ['', '3', '2', '1', 'GO!'];
    final label = countdownLabels[_phase.clamp(0, countdownLabels.length - 1)];
    final isGo = _phase == 4;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: AppSurfaceCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Starting Battle',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: animation,
                          curve: Curves.elasticOut,
                        ),
                        child: child,
                      ),
                      child: Text(
                        label,
                        key: ValueKey(_phase),
                        style: TextStyle(
                          color: isGo
                              ? const Color(0xFF059669)
                              : const Color(0xFF0F172A),
                          fontSize: isGo ? 72 : 104,
                          fontWeight: FontWeight.w900,
                          letterSpacing: isGo ? 4 : 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isGo ? 'Good luck.' : 'Get ready for the first question.',
                      style: const TextStyle(color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPlayerCard extends StatelessWidget {
  const _IntroPlayerCard({
    required this.name,
    required this.color,
    required this.subtitle,
  });

  final String name;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color, width: 2.5),
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: color,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 90,
          child: Text(
            name,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 12),
        ),
      ],
    );
  }
}
