import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../models/daily_challenge_models.dart';
import 'daily_challenge_exam_page.dart';

class DailyChallengePage extends StatefulWidget {
  const DailyChallengePage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<DailyChallengePage> createState() => _DailyChallengePageState();
}

class _DailyChallengePageState extends State<DailyChallengePage> {
  late Future<DailyChallengeStatus> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.authController.loadDailyChallengeStatus();
  }

  Future<void> _reload() async {
    final next = widget.authController.loadDailyChallengeStatus();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _startChallenge() async {
    try {
      final begin = await widget.authController.beginDailyChallenge();
      if (!mounted) return;

      if (begin.questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No questions available right now.')),
        );
        return;
      }

      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => DailyChallengeExamPage(
            authController: widget.authController,
            attempt: begin.attempt,
            questions: begin.questions,
          ),
        ),
      );

      if (done == true && mounted) {
        await _reload();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailyChallengeStatus>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString().replaceFirst('Exception: ', '')),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }

        final status = snapshot.data;
        if (status == null) {
          return const Center(child: Text('No daily challenge data found.'));
        }

        final attempt = status.attempt;
        final canStart = status.canStart || attempt?.status == 'active';

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Daily Challenge',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '10 weakness-based questions every day. Earn 1 coin for every ${status.correctPerCoin} correct answers.',
                style: const TextStyle(color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('Questions', '${status.questionCount}'),
                      _kv(
                        'Duration',
                        '${status.durationSeconds ~/ 60} minutes',
                      ),
                      _kv(
                        'Reward Rule',
                        '1 coin / ${status.correctPerCoin} correct',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (attempt != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Attempt',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        _kv('Status', attempt.status),
                        _kv(
                          'Score',
                          '${attempt.correctAnswers}/${attempt.totalQuestions} (${attempt.accuracy.toStringAsFixed(1)}%)',
                        ),
                        _kv('Coins Earned', '+${attempt.coinsEarned}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: canStart ? _startChallenge : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  attempt?.status == 'active'
                      ? 'Resume Today\'s Challenge'
                      : attempt?.status == 'submitted'
                      ? 'Already Completed Today'
                      : 'Start Daily Challenge',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(key, style: const TextStyle(color: Color(0xFF64748B))),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
