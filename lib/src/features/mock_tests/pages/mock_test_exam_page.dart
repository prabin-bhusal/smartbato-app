import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../../core/security/screen_security.dart';
import '../../../core/theme/app_page_shell.dart';
import '../models/mock_test_models.dart';
import 'mock_test_result_page.dart';

class MockTestExamPage extends StatefulWidget {
  const MockTestExamPage({
    super.key,
    required this.authController,
    required this.beginData,
  });

  final AuthController authController;
  final MockTestBeginResponse beginData;

  @override
  State<MockTestExamPage> createState() => _MockTestExamPageState();
}

class _MockTestExamPageState extends State<MockTestExamPage>
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
      final response = await widget.authController.recordMockViolation(
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
              ),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam suspended after repeated app switching.'),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      if (response.warningCount <= 2) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Warning ${response.warningCount}/2'),
            content: const Text(
              'Do not switch apps, screenshot, record, or screen-share during the test. Repeated violations will auto-suspend the exam and submit it.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue Test'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // Ignore transient errors while app is backgrounding.
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _submitAuto();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });
    });
  }

  Future<void> _submitAuto() async {
    if (_submitting) {
      return;
    }

    await _submit(confirm: false);
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
              title: const Text('Submit Test'),
              content: const Text(
                'Are you sure you want to submit your answers?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
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

      final response = await widget.authController.submitMockTest(
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.beginData.modelSet?.name ?? 'Mock Test'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _formatDuration(_remainingSeconds),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFF8FAFC),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TopPill(
                  label: 'Total',
                  value: '$_totalQuestions',
                  color: const Color(0xFF1D4ED8),
                ),
                _TopPill(
                  label: 'Solved',
                  value: '$_solvedQuestions',
                  color: const Color(0xFF15803D),
                ),
                _TopPill(
                  label: 'Skipped',
                  value: '$_skippedQuestions',
                  color: const Color(0xFFB45309),
                ),
                _TopPill(
                  label: 'Section',
                  value: _subjectProgressLabel,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: active.questions.length,
              itemBuilder: (context, index) {
                final question = active.questions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _safeHtmlText(
                          'Q${index + 1}. ${question.question}',
                          textStyle: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
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
                        const SizedBox(height: 8),
                        ...question.options.asMap().entries.map(
                          (optEntry) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: RadioListTile<String>(
                              value: optEntry.value.key,
                              groupValue: _answers[question.id],
                              onChanged: (val) {
                                setState(() {
                                  _answers[question.id] = val!;
                                });
                              },
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _safeHtmlText(
                                    optEntry.value.text,
                                    textStyle: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  if (optEntry.value.images.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final imgUrl
                                            in optEntry.value.images)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: Image.network(
                                              imgUrl,
                                              height: 60,
                                              fit: BoxFit.contain,
                                              errorBuilder: (c, e, s) =>
                                                  const Icon(
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          ? 'Submit Test'
                          : 'Next Subject',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _safeHtmlText(String value, {TextStyle? textStyle}) {
    return Text(_safeTextFromHtml(value), style: textStyle);
  }

  String _safeTextFromHtml(String input) {
    var text = input;

    // Normalize common line breaks before stripping tags.
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');

    // Remove HTML tags.
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode a few common entities.
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // Collapse excessive blank lines.
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return text;
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
