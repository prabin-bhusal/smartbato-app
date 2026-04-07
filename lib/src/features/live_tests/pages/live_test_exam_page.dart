import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/security/screen_security.dart';
import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import '../../mock_tests/models/mock_test_models.dart';
import '../../mock_tests/pages/mock_test_result_page.dart';

class LiveTestExamPage extends StatefulWidget {
  const LiveTestExamPage({
    super.key,
    required this.authController,
    required this.beginData,
  });

  final AuthController authController;
  final MockTestBeginResponse beginData;

  @override
  State<LiveTestExamPage> createState() => _LiveTestExamPageState();
}

class _LiveTestExamPageState extends State<LiveTestExamPage>
    with WidgetsBindingObserver {
  final Map<int, String> _answers = <int, String>{};
  late int _remainingSeconds;
  Timer? _timer;
  int _subjectIndex = 0;
  bool _submitting = false;
  DateTime? _lastViolationAt;

  int get _sessionId => widget.beginData.session!.id;

  int get _totalQuestions => widget.beginData.subjects.fold<int>(
    0,
    (total, subject) => total + subject.questions.length,
  );

  int get _solvedQuestions => _answers.length;

  int get _skippedQuestions =>
      (_totalQuestions - _solvedQuestions).clamp(0, _totalQuestions);

  String get _subjectProgressLabel =>
      'Subject ${_subjectIndex + 1}/${widget.beginData.subjects.length}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.beginData.durationSeconds ?? 15 * 60;
    unawaited(ScreenSecurity.enable());
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(
      ScreenSecurity.applyPolicyForEmail(widget.authController.user?.email),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.resumed) {
      final force = state == AppLifecycleState.resumed;
      _handleViolation(force: force);
    }
  }

  Future<void> _handleViolation({bool force = false}) async {
    final now = DateTime.now();
    final last = _lastViolationAt;
    if (!force && last != null && now.difference(last).inMilliseconds < 1200) {
      return;
    }
    _lastViolationAt = now;

    try {
      final response = await widget.authController.recordLiveViolation(
        _sessionId,
      );
      if (!mounted) {
        return;
      }

      if (response.suspended) {
        _timer?.cancel();
        if (response.report != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => MockTestResultPage(
                authController: widget.authController,
                report: response.report!,
                resultTypeLabel: 'Live Test',
                allowPdfDownload: false,
              ),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Live test suspended due to security violation. Session submitted automatically.',
            ),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Strict Mode Warning'),
          content: const Text(
            'Live test does not allow app switching, screenshot, recording, or screen sharing. Another violation can auto-suspend and submit your session.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Live Test'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Ignore transient errors while app state changes.
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _submit(confirm: false);
        return;
      }

      setState(() {
        _remainingSeconds--;
      });
    });
  }

  Future<void> _submit({bool confirm = true}) async {
    if (_submitting) {
      return;
    }

    if (confirm) {
      final approved =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Submit Live Test'),
              content: Text(
                'Solved: $_solvedQuestions | Skipped: $_skippedQuestions\n\nDo you want to submit now?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep Solving'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Submit'),
                ),
              ],
            ),
          ) ??
          false;

      if (!approved) {
        return;
      }
    }

    setState(() {
      _submitting = true;
    });

    try {
      final total = widget.beginData.durationSeconds ?? 15 * 60;
      final spent = (total - _remainingSeconds).clamp(0, total);

      final response = await widget.authController.submitLiveTest(
        sessionId: _sessionId,
        answers: _answers,
        timeTaken: spent,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MockTestResultPage(
            authController: widget.authController,
            report: response.report,
            resultTypeLabel: 'Live Test',
            allowPdfDownload: false,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = widget.beginData.subjects;
    final active = subjects[_subjectIndex];

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.beginData.modelSet?.name ?? 'Live Test'),
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  _formatDuration(_remainingSeconds),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _StatsStrip(
              total: _totalQuestions,
              solved: _solvedQuestions,
              skipped: _skippedQuestions,
              subjectLabel: _subjectProgressLabel,
            ),
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(subjects.length, (index) {
                    final subject = subjects[index];
                    final answered = subject.questions
                        .where((q) => _answers.containsKey(q.id))
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _subjectIndex == index,
                        onSelected: (_) {
                          setState(() {
                            _subjectIndex = index;
                          });
                        },
                        label: Text(
                          '${subject.subjectName} ($answered/${subject.questions.length})',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                itemCount: active.questions.length,
                itemBuilder: (context, index) {
                  final question = active.questions[index];
                  final selected = _answers[question.id];

                  return _QuestionCard(
                    index: index + 1,
                    question: question,
                    selectedKey: selected,
                    onSelect: (optionKey) {
                      setState(() {
                        _answers[question.id] = optionKey;
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _subjectIndex == 0
                        ? null
                        : () {
                            setState(() {
                              _subjectIndex--;
                            });
                          },
                    child: const Text('Prev Subject'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _subjectIndex == subjects.length - 1
                          ? (_submitting ? null : () => _submit(confirm: true))
                          : () {
                              setState(() {
                                _subjectIndex++;
                              });
                            },
                      child: Text(
                        _subjectIndex == subjects.length - 1
                            ? 'Submit Live Test'
                            : 'Next Subject',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.total,
    required this.solved,
    required this.skipped,
    required this.subjectLabel,
  });

  final int total;
  final int solved;
  final int skipped;
  final String subjectLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatPill(
            label: 'Total',
            value: '$total',
            color: const Color(0xFF1D4ED8),
          ),
          _StatPill(
            label: 'Solved',
            value: '$solved',
            color: const Color(0xFF15803D),
          ),
          _StatPill(
            label: 'Skipped',
            value: '$skipped',
            color: const Color(0xFFB45309),
          ),
          _StatPill(
            label: 'Section',
            value: subjectLabel,
            color: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedKey,
    required this.onSelect,
  });

  final int index;
  final MockTestQuestion question;
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q$index. ${question.question}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...question.options.map((option) {
              final selected = selectedKey == option.key;
              return InkWell(
                onTap: () => onSelect(option.key),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 18,
                        color: selected
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option.text,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
