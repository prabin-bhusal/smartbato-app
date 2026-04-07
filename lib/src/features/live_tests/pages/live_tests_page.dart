import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../../core/theme/app_page_shell.dart';
import '../../dashboard/models/analytics_data.dart';
import '../../mock_tests/pages/mock_test_result_page.dart';
import '../services/live_test_reminder_service.dart';
import 'live_test_exam_page.dart';

class LiveTestsPage extends StatefulWidget {
  const LiveTestsPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<LiveTestsPage> createState() => _LiveTestsPageState();
}

class _LiveTestsPageState extends State<LiveTestsPage> {
  late Future<List<AnalyticsLiveTest>> _future;
  Set<int> _enrolledIds = <int>{};
  Set<int> _attemptedStableIds = <int>{};
  final Set<int> _resultLoadingIds = <int>{};
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<List<AnalyticsLiveTest>> _loadData() async {
    await LiveTestReminderService.instance.initialize();
    _enrolledIds = await widget.authController.loadEnrolledLiveTestIds();
    final analytics = await widget.authController.loadAnalyticsData();
    await LiveTestReminderService.instance.syncEnrolledTests(
      tests: analytics.liveTests,
      enrolledServerIds: _enrolledIds,
    );
    _attemptedStableIds = await LiveTestReminderService.instance
        .getAttemptedTestIds();
    return analytics.liveTests;
  }

  Future<void> _viewLiveResult(AnalyticsLiveTest test) async {
    if (_resultLoadingIds.contains(test.stableId)) {
      return;
    }

    setState(() {
      _resultLoadingIds.add(test.stableId);
    });

    if (test.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Result is not available for this live test.'),
        ),
      );
      setState(() {
        _resultLoadingIds.remove(test.stableId);
      });
      return;
    }

    try {
      final report = await widget.authController.loadLiveReport(test.id);
      if (!mounted) {
        return;
      }

      if (report.coinReward != null && report.coinReward!.amount > 0) {
        final rewardMessage = (report.coinReward!.message ?? '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rewardMessage.isNotEmpty
                  ? rewardMessage
                  : 'You received ${report.coinReward!.amount} coins from live test reward.',
            ),
          ),
        );
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MockTestResultPage(
            authController: widget.authController,
            report: report.report,
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
          _resultLoadingIds.remove(test.stableId);
        });
      }
    }
  }

  Future<void> _refresh() async {
    final next = _loadData();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _enroll(AnalyticsLiveTest test) async {
    if (test.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This live test is not available for enrollment yet.'),
        ),
      );
      return;
    }

    final enrolled = _enrolledIds.contains(test.id);
    if (enrolled) {
      return;
    }

    try {
      await widget.authController.enrollLiveTest(test.id);
      await LiveTestReminderService.instance.enrollAndSchedule(test);

      if (!mounted) {
        return;
      }

      setState(() {
        _enrolledIds.add(test.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enrolled in ${test.name} for 50 coins. Reminders set for 1h, 30m, and 5m.',
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
    }
  }

  Future<void> _startLiveTest(AnalyticsLiveTest test) async {
    final now = DateTime.now();
    final startAt = test.startsAt;

    if (test.id <= 0 || !_enrolledIds.contains(test.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enroll first to start this live test.')),
      );
      return;
    }

    if (startAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live test schedule missing. Please try again later.'),
        ),
      );
      return;
    }

    final untilStart = startAt.difference(now);

    if (untilStart.inSeconds > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This test will open ${_fmtStartsIn(untilStart)}.'),
        ),
      );
      return;
    }

    if (untilStart.inSeconds > 0) {
      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LiveTestCountdownGatePage(test: test),
        ),
      );
      return;
    }

    await _beginExam(test);
  }

  Future<void> _beginExam(AnalyticsLiveTest test) async {
    if (test.id <= 0) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This live test is not yet available for mobile exam.'),
        ),
      );
      return;
    }

    try {
      final begin = await widget.authController.beginLiveTest(test.id);

      if (!mounted) {
        return;
      }

      if (begin.alreadyAttempted) {
        await LiveTestReminderService.instance.markAttempted(test);
        if (!mounted) {
          return;
        }

        setState(() {
          _attemptedStableIds.add(test.stableId);
        });

        final loaded = await widget.authController.loadLiveReport(test.id);
        if (!mounted) {
          return;
        }

        if (loaded.coinReward != null && loaded.coinReward!.amount > 0) {
          final rewardMessage = (loaded.coinReward!.message ?? '').trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                rewardMessage.isNotEmpty
                    ? rewardMessage
                    : 'You received ${loaded.coinReward!.amount} coins from live test reward.',
              ),
            ),
          );
        }

        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MockTestResultPage(
              authController: widget.authController,
              report: loaded.report,
              resultTypeLabel: 'Live Test',
              allowPdfDownload: false,
            ),
          ),
        );
        return;
      }

      if (begin.session == null ||
          begin.modelSet == null ||
          begin.subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Live test is not ready yet. Please wait for start time.',
            ),
          ),
        );
        return;
      }

      await LiveTestReminderService.instance.markAttempted(test);
      if (!mounted) {
        return;
      }

      setState(() {
        _attemptedStableIds.add(test.stableId);
      });

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LiveTestExamPage(
            authController: widget.authController,
            beginData: begin,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AnalyticsLiveTest>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorState(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: _refresh,
          );
        }

        final all = snapshot.data ?? <AnalyticsLiveTest>[];
        final now = DateTime.now();
        final upcoming =
            all.where((item) {
              final starts = item.startsAt;
              if (starts == null) {
                return false;
              }

              final state = item.status.toLowerCase();
              return starts.isAfter(now) ||
                  state == 'upcoming' ||
                  state == 'coming_soon';
            }).toList()..sort(
              (a, b) => (a.startsAt ?? DateTime(2099)).compareTo(
                b.startsAt ?? DateTime(2099),
              ),
            );

        final taken =
            all
                .where((item) => _attemptedStableIds.contains(item.stableId))
                .toList()
              ..sort(
                (a, b) => (b.startsAt ?? DateTime(1970)).compareTo(
                  a.startsAt ?? DateTime(1970),
                ),
              );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: AppHeroBanner(
                title: 'Live Tests',
                subtitle: 'Compete in real-time with strict exam mode',
                icon: Icons.live_tv_rounded,
                colors: const [Color(0xFFDC2626), Color(0xFFEA580C)],
                trailing: Chip(
                  label: Text(
                    'Enrolled ${_enrolledIds.length}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  side: BorderSide(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('Unattempted Tests'),
                  ),
                  ButtonSegment<int>(value: 1, label: Text('Attempted Tests')),
                ],
                selected: <int>{_tabIndex},
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return const Color(0xFF0F172A);
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFFDC2626);
                    }
                    return Colors.white;
                  }),
                ),
                onSelectionChanged: (next) {
                  setState(() {
                    _tabIndex = next.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    ...(_tabIndex == 0 ? upcoming : taken).map((test) {
                      final enrolledByServer =
                          test.id > 0 && _enrolledIds.contains(test.id);
                      final canOpen =
                          (test.startsAt ?? DateTime(2099))
                              .difference(now)
                              .inSeconds <=
                          60;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppSurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                test.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Starts: ${_fmtDateTime(test.startsAt)}  |  Duration: ${test.durationMinutes} min  |  Qs: ${test.requiredQuestions}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              if (_tabIndex == 0)
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: enrolledByServer
                                          ? null
                                          : () => _enroll(test),
                                      icon: Icon(
                                        enrolledByServer
                                            ? Icons.verified_rounded
                                            : Icons.event_available_rounded,
                                      ),
                                      label: Text(
                                        enrolledByServer
                                            ? 'Enrolled'
                                            : 'Enroll (50 coins)',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: enrolledByServer
                                            ? () => _startLiveTest(test)
                                            : null,
                                        child: Text(
                                          canOpen
                                              ? 'Open Live Test'
                                              : 'Starts ${_fmtStartsIn((test.startsAt ?? now).difference(now))}',
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      disabledBackgroundColor: const Color(
                                        0xFFDC2626,
                                      ),
                                      disabledForegroundColor: Colors.white,
                                    ),
                                    onPressed:
                                        _resultLoadingIds.contains(
                                          test.stableId,
                                        )
                                        ? null
                                        : () => _viewLiveResult(test),
                                    icon:
                                        _resultLoadingIds.contains(
                                          test.stableId,
                                        )
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.assessment_rounded),
                                    label: Text(
                                      _resultLoadingIds.contains(test.stableId)
                                          ? 'Fetching report...'
                                          : 'View Result',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if ((_tabIndex == 0 ? upcoming : taken).isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            _tabIndex == 0
                                ? 'No unattempted live tests right now.'
                                : 'No attempted live tests yet.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _fmtDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '-';
    }

    final d = dateTime.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $hh:$mm';
  }

  String _fmtStartsIn(Duration duration) {
    if (duration.inSeconds <= 0) {
      return 'now';
    }

    if (duration.inMinutes >= 60) {
      final h = duration.inHours;
      final m = duration.inMinutes % 60;
      return m == 0 ? 'in ${h}h' : 'in ${h}h ${m}m';
    }

    if (duration.inMinutes >= 1) {
      return 'in ${duration.inMinutes}m';
    }

    return 'in ${duration.inSeconds}s';
  }
}

class LiveTestCountdownGatePage extends StatefulWidget {
  const LiveTestCountdownGatePage({super.key, required this.test});

  final AnalyticsLiveTest test;

  @override
  State<LiveTestCountdownGatePage> createState() =>
      _LiveTestCountdownGatePageState();
}

class _LiveTestCountdownGatePageState extends State<LiveTestCountdownGatePage> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recompute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recompute();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _recompute() {
    final start = widget.test.startsAt;
    if (start == null) {
      if (mounted) {
        setState(() {
          _remaining = Duration.zero;
        });
      }
      return;
    }

    final left = start.difference(DateTime.now());
    if (mounted) {
      setState(() {
        _remaining = left.isNegative ? Duration.zero : left;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _remaining.inSeconds <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.live_tv_rounded,
                  color: Colors.white,
                  size: 56,
                ),
                const SizedBox(height: 14),
                Text(
                  widget.test.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  canStart
                      ? 'Live test is starting now.'
                      : 'Live test starts in',
                  style: const TextStyle(color: Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 10),
                Text(
                  _formatDuration(_remaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: canStart
                      ? () {
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Go To Live Test'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Color(0xFF93C5FD)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final total = value.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
