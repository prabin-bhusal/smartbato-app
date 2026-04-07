import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../../core/theme/app_snackbar.dart';
import '../../auth/auth_controller.dart';
import '../models/practice_topics_models.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class PracticeTopicSessionPage extends StatefulWidget {
  const PracticeTopicSessionPage({
    super.key,
    required this.authController,
    required this.topic,
  });

  final AuthController authController;
  final PracticeTopicNode topic;

  @override
  State<PracticeTopicSessionPage> createState() =>
      _PracticeTopicSessionPageState();
}

class _PracticeTopicSessionPageState extends State<PracticeTopicSessionPage> {
  PracticeTopicQuestion? _question;
  PracticeTopicAnswerResult? _result;
  String? _selectedOption;
  String? _hintText;
  String? _error;
  bool _loading = true;
  bool _submitting = false;
  bool _loadingHint = false;
  late Stopwatch _stopwatch;
  Timer? _ticker;
  int _elapsedSeconds = 0;
  int _sessionCorrect = 0;
  int _sessionIncorrect = 0;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _loading = true;
      _result = null;
      _selectedOption = null;
      _hintText = null;
      _error = null;
    });

    try {
      final question = await widget.authController.loadPracticeTopicQuestion(
        widget.topic.id,
      );
      final options = [...question.options]..shuffle(Random());

      setState(() {
        _question = PracticeTopicQuestion(
          id: question.id,
          question: question.question,
          options: options,
          difficulty: question.difficulty,
          hasHint: question.hasHint,
        );
      });

      _stopwatch
        ..reset()
        ..start();
      _startTicker();
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _submit(String optionKey) async {
    final question = _question;
    if (question == null || _submitting || _result != null) {
      return;
    }

    setState(() {
      _submitting = true;
      _selectedOption = optionKey;
    });

    _stopwatch.stop();
    _stopTicker();

    try {
      final response = await widget.authController.submitPracticeTopicAnswer(
        questionId: question.id,
        selectedOption: optionKey,
        timeTaken: _stopwatch.elapsed.inSeconds,
      );

      setState(() {
        _result = response;
        if (response.isCorrect) {
          _sessionCorrect++;
        } else {
          _sessionIncorrect++;
        }
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  void _startTicker() {
    _stopTicker();
    _elapsedSeconds = 0;

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _elapsedSeconds = _stopwatch.elapsed.inSeconds;
      });
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _showHint() async {
    final question = _question;
    if (question == null || _loadingHint || _hintText != null) {
      return;
    }

    setState(() {
      _loadingHint = true;
    });

    try {
      final hint = await widget.authController.fetchPracticeTopicHint(
        question.id,
      );
      setState(() {
        _hintText = hint;
      });
    } catch (error) {
      if (mounted) {
        AppSnackbar.error(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingHint = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Topic: ${widget.topic.name}')),
      body: RefreshIndicator(
        onRefresh: _loadQuestion,
        child: AppPageShell(
          maxWidth: 860,
          children: [
            AppHeroBanner(
              title: widget.topic.name,
              subtitle:
                  'Level ${widget.topic.sequenceOrder} session with progressive mastery feedback.',
              icon: Icons.psychology_alt_rounded,
              colors: const [Color(0xFF0F766E), Color(0xFF2563EB)],
            ),
            const SizedBox(height: 12),
            _sessionStrip(),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _errorState()
            else if (_question == null)
              const Text('No question available.')
            else
              _questionCard(_question!),
          ],
        ),
      ),
    );
  }

  Widget _sessionStrip() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _pill(
              'Correct',
              _sessionCorrect.toString(),
              const Color(0xFFBBF7D0),
              const Color(0xFF166534),
            ),
            const SizedBox(width: 8),
            _pill(
              'Incorrect',
              _sessionIncorrect.toString(),
              const Color(0xFFFECACA),
              const Color(0xFF991B1B),
            ),
            const Spacer(),
            _pill(
              'Level',
              '#${widget.topic.sequenceOrder}',
              const Color(0xFFE0E7FF),
              const Color(0xFF1E3A8A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value, Color bg, Color fg) {
    return Chip(
      label: Text(
        '$label: $value',
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  Widget _questionCard(PracticeTopicQuestion question) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(
                  'Difficulty ${question.difficulty}',
                  style: const TextStyle(
                    color: Color(0xFF1E40AF),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: const Color(0xFFDBEAFE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
              Chip(
                label: Text(
                  'Time: ${_elapsedSeconds}s',
                  style: const TextStyle(
                    color: Color(0xFF0C4A6E),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: const Color(0xFFE0F2FE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
              ),
              Tooltip(
                message:
                    'Hint costs 1 coin. No coin is deducted if hint is unavailable.',
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Render question as rich text and show images if present
          HtmlWidget(
            question.question,
            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loadingHint || _hintText != null ? null : _showHint,
              icon: _loadingHint
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lightbulb_rounded),
              label: Text(
                _hintText == null ? 'Show Hint (-1 coin)' : 'Hint Loaded',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hint cost: 1 coin. If no hint exists for this question, coin is not deducted.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
          if (_hintText != null && _hintText!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                _hintText!,
                style: const TextStyle(color: Color(0xFF92400E)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...question.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _optionTile(option),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            _resultCard(_result!),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadQuestion,
                icon: const Icon(Icons.navigate_next_rounded),
                label: const Text('Next Question'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionTile(PracticeTopicOption option) {
    final isSelected = _selectedOption == option.key;
    final result = _result;

    Color border = const Color(0xFFCBD5E1);
    Color bg = Colors.white;

    if (result != null) {
      if (option.key == result.correctOption) {
        border = const Color(0xFF15803D);
        bg = const Color(0xFFDCFCE7);
      } else if (isSelected && option.key != result.correctOption) {
        border = const Color(0xFFB91C1C);
        bg = const Color(0xFFFEE2E2);
      }
    } else if (isSelected) {
      border = const Color(0xFF2563EB);
      bg = const Color(0xFFEFF6FF);
    }

    return InkWell(
      onTap: result == null && !_submitting ? () => _submit(option.key) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
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
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.broken_image_rounded, size: 20),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultCard(PracticeTopicAnswerResult result) {
    final questionsLeftToMaster =
        result.topicTotalQuestions - result.topicMasteredQuestions;
    final questionStreakLeft = result.questionStreakLeftToMaster;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.isCorrect
            ? const Color(0xFFECFDF5)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isCorrect
              ? const Color(0xFF86EFAC)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                result.isCorrect ? 'Correct answer' : 'Incorrect answer',
                style: TextStyle(
                  color: result.isCorrect
                      ? const Color(0xFF166534)
                      : const Color(0xFF991B1B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (result.isCorrect)
                Chip(
                  label: Text(
                    'Question streak: ${result.questionStreak}/${result.questionMasterStreak}',
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: const Color(0xFFBBF7D0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
            ],
          ),
          if (result.isCorrect) ...[
            const SizedBox(height: 6),
            Text(
              result.questionIsMastered
                  ? 'Great! This question is mastered.'
                  : 'You are $questionStreakLeft correct streak away from mastering this question.',
              style: TextStyle(
                color: result.questionIsMastered
                    ? const Color(0xFF166534)
                    : const Color(0xFFB45309),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Topic Progress',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (result.topicMasteryPercent / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${result.topicMasteredQuestions}/${result.topicTotalQuestions} mastered',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (questionsLeftToMaster > 0)
                      Text(
                        '${questionsLeftToMaster} left to master',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      Text(
                        'Topic mastered! 🎉',
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mastery: ${result.topicMasteryPercent.toStringAsFixed(1)}% | Band: ${result.difficultyBandLabel}',
            style: const TextStyle(color: Color(0xFF334155), fontSize: 11),
          ),
          if ((result.solution ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solution',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.solution!,
                    style: const TextStyle(color: Color(0xFF92400E)),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'No solution provided for this question.',
              style: TextStyle(color: Color(0xFF334155), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        children: [
          Text(
            _error ?? 'Failed to load.',
            style: const TextStyle(color: Color(0xFF92400E)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loadQuestion,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
