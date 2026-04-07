import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import '../data/battle_opponent_alias.dart';
import 'battle_matchmaking_page.dart';

class BattleResultsPage extends StatelessWidget {
  const BattleResultsPage({
    super.key,
    required this.authController,
    required this.battle,
    this.selectedAnswers = const {},
  });

  final AuthController authController;
  final Map<String, dynamic> battle;
  final Map<int, String> selectedAnswers;

  @override
  Widget build(BuildContext context) {
    final myId = authController.user?.id ?? 0;
    final participants = (battle['participants'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    Map<String, dynamic>? myP;
    Map<String, dynamic>? oppP;
    for (final p in participants) {
      final uid = ((p['user'] as Map?) ?? {})['id'];
      if ((uid as num?)?.toInt() == myId) {
        myP = p;
      } else {
        oppP = p;
      }
    }

    final winnerUserId = (battle['winner_user_id'] as num?)?.toInt();
    final winnerIsAi = (battle['winner_is_ai'] as bool?) ?? false;
    final iWon =
        winnerUserId != null && winnerUserId > 0 && winnerUserId == myId;
    final isDraw = (winnerUserId == null || winnerUserId == 0) && !winnerIsAi;

    final questions = (battle['questions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final myScore = (myP?['correct_answers'] as num?)?.toInt() ?? 0;
    final oppScore = (oppP?['correct_answers'] as num?)?.toInt() ?? 0;
    final myTime = (myP?['time_taken_seconds'] as num?)?.toInt() ?? 0;
    final oppTime = (oppP?['time_taken_seconds'] as num?)?.toInt() ?? 0;

    final myName = ((myP?['user'] as Map?) ?? {})['name']?.toString() ?? 'You';
    final isAiOpp = (oppP?['is_ai'] as bool?) ?? true;
    final battleId = (battle['id'] as num?)?.toInt();
    final oppName = isAiOpp
        ? pickSystemOpponentAlias(battleId: battleId)
        : (((oppP?['user'] as Map?) ?? {})['name']?.toString() ?? 'Opponent');
    final prizeCoin = (battle['prize_coin'] as num?)?.toInt() ?? 15;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AppPageShell(
        maxWidth: 860,
        children: [
          AppHeroBanner(
            title: iWon
                ? 'You Won!'
                : isDraw
                ? 'It\'s a Draw'
                : 'Good Effort',
            subtitle: iWon
                ? '+$prizeCoin coins awarded.'
                : 'Review the battle and start another round when ready.',
            icon: iWon
                ? Icons.emoji_events_rounded
                : isDraw
                ? Icons.handshake_rounded
                : Icons.sentiment_dissatisfied_rounded,
            colors: iWon
                ? const [Color(0xFF0F766E), Color(0xFF059669)]
                : isDraw
                ? const [Color(0xFF1D4ED8), Color(0xFF3B82F6)]
                : const [Color(0xFF991B1B), Color(0xFFDC2626)],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ScoreCard(
                  name: myName,
                  score: myScore,
                  total: questions.length,
                  timeSec: myTime,
                  color: const Color(0xFF0EA5E9),
                  isWinner: iWon,
                  label: 'You',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScoreCard(
                  name: oppName,
                  score: oppScore,
                  total: questions.length,
                  timeSec: oppTime,
                  color: isAiOpp
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFEF4444),
                  isWinner: !iWon && !isDraw,
                  label: 'Opponent',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.flash_on_rounded),
              label: const Text(
                'Battle Again',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              onPressed: () {
                Navigator.of(context)
                  ..popUntil((route) => route.isFirst)
                  ..push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          BattleMatchmakingPage(authController: authController),
                    ),
                  );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to Battle Arena'),
            ),
          ),
          const SizedBox(height: 16),
          if (questions.isNotEmpty)
            AppSurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Answers',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Quick review of the questions you answered in this battle.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ...questions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final q = entry.value;
                    final bqId =
                        (q['battle_question_id'] as num?)?.toInt() ?? 0;
                    final correctKey = (q['correct_option_key'] ?? '')
                        .toString();
                    final myAnswer = selectedAnswers[bqId] ?? '';
                    final isSkipped = myAnswer.isEmpty;
                    final isCorrect =
                        !isSkipped &&
                        correctKey.isNotEmpty &&
                        myAnswer == correctKey;

                    final Color dotColor;
                    final IconData dotIcon;
                    if (isSkipped) {
                      dotColor = const Color(0xFF475569);
                      dotIcon = Icons.remove_rounded;
                    } else if (isCorrect) {
                      dotColor = const Color(0xFF34D399);
                      dotIcon = Icons.check_rounded;
                    } else {
                      dotColor = const Color(0xFFEF4444);
                      dotIcon = Icons.close_rounded;
                    }

                    final qText = (q['question'] ?? '').toString();
                    final preview = qText.length > 60
                        ? '${qText.substring(0, 60)}…'
                        : qText;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor.withValues(alpha: 0.12),
                              border: Border.all(
                                color: dotColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Icon(dotIcon, color: dotColor, size: 13),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Q${i + 1}: $preview',
                              style: TextStyle(
                                color: isSkipped
                                    ? const Color(0xFF475569)
                                    : const Color(0xFF334155),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.name,
    required this.score,
    required this.total,
    required this.timeSec,
    required this.color,
    required this.isWinner,
    required this.label,
  });

  final String name;
  final int score;
  final int total;
  final int timeSec;
  final Color color;
  final bool isWinner;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFBBF24),
                size: 18,
              ),
            ),
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            '$score / $total',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const Text(
            'correct',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            '${timeSec}s',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
