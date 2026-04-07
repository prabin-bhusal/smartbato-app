import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../models/daily_challenge_models.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class DailyChallengeExamPage extends StatefulWidget {
  const DailyChallengeExamPage({
    super.key,
    required this.authController,
    required this.attempt,
    required this.questions,
  });

  final AuthController authController;
  final DailyChallengeAttemptData attempt;
  final List<DailyChallengeQuestion> questions;

  @override
  State<DailyChallengeExamPage> createState() => _DailyChallengeExamPageState();
}

class _DailyChallengeExamPageState extends State<DailyChallengeExamPage> {
  int _index = 0;
  late int _remainingSeconds;
  Timer? _timer;
  bool _submitting = false;

  final Map<int, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.attempt.durationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _submitting) {
        return;
      }
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _submit();
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final timeTaken = widget.attempt.durationSeconds - _remainingSeconds;

    try {
      final response = await widget.authController.submitDailyChallenge(
        attemptId: widget.attempt.id,
        answers: _answers,
        timeTaken: timeTaken < 0 ? 0 : timeTaken,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Daily Challenge Result'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Correct: ${response.attempt.correctAnswers}/${response.attempt.totalQuestions}',
              ),
              Text(
                'Accuracy: ${response.attempt.accuracy.toStringAsFixed(1)}%',
              ),
              Text('Coins earned: +${response.attempt.coinsEarned}'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_index];
    final selected = _answers[question.id];

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Challenge')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (_index + 1) / widget.questions.length,
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            Text(
              'Question ${_index + 1} of ${widget.questions.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              question.topicName,
              style: const TextStyle(
                color: Color(0xFF0F766E),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HtmlWidget(
                      question.question,
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    if (question.images.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final imgUrl in question.images)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imgUrl,
                                height: 120,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) =>
                                    const Icon(Icons.broken_image_rounded),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    ...question.options.map((option) {
                      return RadioListTile<String>(
                        value: option.key,
                        groupValue: selected,
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _answers[question.id] = value;
                                });
                              },
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HtmlWidget(
                              option.text,
                              textStyle: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (option.images.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final imgUrl in option.images)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        imgUrl,
                                        height: 60,
                                        fit: BoxFit.contain,
                                        errorBuilder: (c, e, s) => const Icon(
                                          Icons.broken_image_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_index > 0)
                  OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                            _index -= 1;
                          }),
                    child: const Text('Previous'),
                  ),
                const Spacer(),
                if (_index < widget.questions.length - 1)
                  FilledButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                            _index += 1;
                          }),
                    child: const Text('Next'),
                  )
                else
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Submitting...' : 'Submit'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // _formatDuration removed (unused)
}
