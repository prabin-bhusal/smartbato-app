import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import 'battle_matchmaking_page.dart';

class BattlePage extends StatefulWidget {
  const BattlePage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authController,
      builder: (context, _) {
        final authController = widget.authController;
        final coins = authController.user?.coins ?? 0;
        final entryFee = authController.user?.battleEntryFee ?? 10;
        final prizeCoin = authController.user?.battlePrizeCoin ?? 15;
        final canBattle = coins >= entryFee;

        return AppPageShell(
          maxWidth: 860,
          children: [
            AppHeroBanner(
              title: 'Battle Arena',
              subtitle: 'Real-time MCQ battles · 3 minutes · 8 questions',
              icon: Icons.sports_martial_arts_rounded,
              colors: const [Color(0xFF0F766E), Color(0xFF0284C7)],
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xFFFBBF24),
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StakeItem(
                    icon: Icons.arrow_downward_rounded,
                    color: const Color(0xFFEF4444),
                    label: 'Entry',
                    value: '$entryFee',
                  ),
                  const _VertDivider(),
                  _StakeItem(
                    icon: Icons.emoji_events_rounded,
                    color: const Color(0xFFFBBF24),
                    label: 'Prize',
                    value: '$prizeCoin',
                  ),
                  const _VertDivider(),
                  _StakeItem(
                    icon: Icons.timer_rounded,
                    color: const Color(0xFF38BDF8),
                    label: 'Time',
                    value: '3 min',
                  ),
                  const _VertDivider(),
                  _StakeItem(
                    icon: Icons.quiz_rounded,
                    color: const Color(0xFF34D399),
                    label: 'Questions',
                    value: '8',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppSurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(
                            0xFF0284C7,
                          ).withValues(alpha: 0.1),
                          child: Text(
                            (authController.user?.name.isNotEmpty ?? false)
                                ? authController.user!.name[0].toUpperCase()
                                : 'Y',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          authController.user?.name ?? 'You',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(
                            0xFFDC2626,
                          ).withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.person_search_rounded,
                            size: 26,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (canBattle)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.flash_on_rounded),
                      label: Text(
                        'Find Opponent  —  $entryFee coins',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BattleMatchmakingPage(
                            authController: authController,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You need at least $entryFee coins to battle. Earn coins by completing tests and daily login.',
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Use quick matchmaking to find a real opponent in your course.\nIf no one joins in 30s, opponent is auto-assigned.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StakeItem extends StatelessWidget {
  const _StakeItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
        ),
      ],
    ),
  );
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 36,
    color: const Color(0xFFE2E8F0),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}
