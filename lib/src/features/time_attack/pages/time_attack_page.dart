import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import '../models/time_attack_models.dart';

class TimeAttackPage extends StatefulWidget {
  const TimeAttackPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<TimeAttackPage> createState() => _TimeAttackPageState();
}

class _TimeAttackPageState extends State<TimeAttackPage>
    with SingleTickerProviderStateMixin {
  // Track last answer result
  bool? _lastIsCorrect;
  late final TabController _tabController;

  bool _loading = true;
  bool _starting = false;
  bool _submitting = false;
  bool _finishing = false;
  String? _error;

  TimeAttackStatusResponse? _status;
  TimeAttackLeaderboardResponse? _leaderboard;
  TimeAttackSessionData? _session;
  TimeAttackQuestion? _question;
  String? _selectedOption;
  int _remainingSeconds = 0;
  Timer? _timer;
  DateTime? _lastAutoSubmitTapAt;

  static const Duration _autoSubmitTapDebounce = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final status = await widget.authController.loadTimeAttackStatus();
      final leaderboard = await widget.authController
          .loadTimeAttackLeaderboard();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
        _leaderboard = leaderboard;
        _session = status.activeSession;
        _question = null;
        _selectedOption = null;
      });

      if (_session != null && _session!.status == 'active') {
        await _resumeSession();
      } else {
        _syncTimerFromSession(null, fallbackDuration: status.durationSeconds);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _resumeSession() async {
    final session = _session;
    if (session == null || session.status != 'active') {
      return;
    }

    try {
      final started = await widget.authController.startTimeAttack();
      if (!mounted) {
        return;
      }

      setState(() {
        _session = started.session;
        _question = started.question;
        _selectedOption = null;
      });
      _syncTimerFromSession(started.session);
    } catch (_) {
      // Keep UI usable even if session resume question fails.
    }
  }

  Future<void> _startOrResume() async {
    if (_starting || _submitting) {
      return;
    }

    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final started = await widget.authController.startTimeAttack();
      if (!mounted) {
        return;
      }

      setState(() {
        _session = started.session;
        _question = started.question;
        _selectedOption = null;
      });

      _syncTimerFromSession(started.session);
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
          _starting = false;
        });
      }
    }
  }

  Future<void> _submitAnswer() async {
    final session = _session;
    final question = _question;
    final selectedOption = _selectedOption;

    if (session == null || question == null || selectedOption == null) {
      return;
    }

    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final response = await widget.authController.submitTimeAttackAnswer(
        sessionId: session.id,
        questionId: question.id,
        selectedOption: selectedOption,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastIsCorrect = response.isCorrect;
        // If correct, correct option is selectedOption, else need to highlight correct
        // We don't have correct option from API, so fallback: highlight only selected as red
      });

      // Wait a moment to show feedback, then go to next question
      await Future.delayed(const Duration(milliseconds: 900));

      setState(() {
        _session = response.session;
        _question = response.nextQuestion;
        _selectedOption = null;
        _lastIsCorrect = null;
      });

      _syncTimerFromSession(response.session);

      if (response.finished || response.nextQuestion == null) {
        await _finishAndShowResult(forceSessionId: response.session.id);
      }
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

  void _syncTimerFromSession(
    TimeAttackSessionData? session, {
    int? fallbackDuration,
  }) {
    _timer?.cancel();

    if (session == null || session.status != 'active') {
      setState(() {
        _remainingSeconds = fallbackDuration ?? 0;
      });
      return;
    }

    final end = session.endedAt;
    if (end == null) {
      setState(() {
        _remainingSeconds = session.durationSeconds;
      });
      return;
    }

    void tick() {
      if (!mounted) {
        return;
      }

      final now = DateTime.now();
      final next = end.difference(now).inSeconds;
      if (next <= 0) {
        setState(() {
          _remainingSeconds = 0;
        });
        _timer?.cancel();
        _finishAndShowResult();
        return;
      }

      setState(() {
        _remainingSeconds = next;
      });
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _finishAndShowResult({int? forceSessionId}) async {
    final activeSession = _session;
    final sessionId = forceSessionId ?? activeSession?.id;
    if (sessionId == null || _finishing) {
      return;
    }

    _finishing = true;

    try {
      final finish = await widget.authController.finishTimeAttack(sessionId);
      if (!mounted) {
        return;
      }

      setState(() {
        _session = finish.session;
        _question = null;
        _selectedOption = null;
        if (_status != null) {
          _status = TimeAttackStatusResponse(
            durationSeconds: _status!.durationSeconds,
            stats: finish.stats,
            activeSession: null,
          );
        }
      });
      _syncTimerFromSession(
        null,
        fallbackDuration: _status?.durationSeconds ?? 60,
      );

      await _reloadLeaderboardOnly();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Time Attack Result'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attempted: ${finish.session.attemptedAnswers}'),
              Text('Correct: ${finish.session.correctAnswers}'),
              Text('Wrong: ${finish.session.wrongAnswers}'),
              const SizedBox(height: 8),
              Text('Best Attempted: ${finish.stats.bestAttemptedAnswers}'),
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
    } catch (_) {
      // If finish call fails due to session already ended, just reload everything.
      await _load();
    } finally {
      _finishing = false;
    }
  }

  Future<void> _reloadLeaderboardOnly() async {
    try {
      final leaderboard = await widget.authController
          .loadTimeAttackLeaderboard();
      if (!mounted) {
        return;
      }
      setState(() {
        _leaderboard = leaderboard;
      });
    } catch (_) {
      // Non-blocking UI refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final status = _status;
    final leaderboard = _leaderboard;

    if (status == null || leaderboard == null) {
      return const Center(child: Text('No Time Attack data available.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AppHeroBanner(
            title: 'Time Attack',
            subtitle:
                'You have 1 minute. Attempt as many questions as possible. The leaderboard resets monthly.',
            icon: Icons.timer_rounded,
            colors: const [Color(0xFF0F766E), Color(0xFF1D4ED8)],
            trailing: Chip(
              label: Text('Time: ${status.durationSeconds}s'),
              backgroundColor: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF475569),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(9),
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '⚡ Play'),
                Tab(text: '🏆 Leaderboard'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPlayTab(status),
              _buildLeaderboardTab(leaderboard),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayTab(TimeAttackStatusResponse status) {
    final session = _session;
    final active = session != null && session.status == 'active';
    final timedOut = active && _remainingSeconds <= 0;

    if (timedOut && !_finishing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        final latest = _session;
        if (latest != null &&
            latest.status == 'active' &&
            _remainingSeconds <= 0) {
          unawaited(_finishAndShowResult());
        }
      });
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statsCard(status.stats),
          const SizedBox(height: 12),
          if (active) ...[
            _activeRunCard(session),
            const SizedBox(height: 12),
            if (timedOut)
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Time is up',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Finalizing your Time Attack result...',
                      style: TextStyle(color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _finishing ? null : _finishAndShowResult,
                        icon: _finishing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.flag_rounded),
                        label: Text(_finishing ? 'Finishing...' : 'Finish Run'),
                      ),
                    ),
                  ],
                ),
              )
            else if (_question != null)
              _questionCard(_question!)
            else
              const AppSurfaceCard(child: Text('Preparing next question...')),
          ] else ...[
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ready for a 60-second sprint?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap start and answer as many questions as possible before time runs out.',
                    style: TextStyle(color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _starting ? null : _startOrResume,
                      icon: _starting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _starting ? 'Starting...' : 'Start Time Attack',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsCard(TimeAttackStatsData stats) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Time Attack Stats',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricPill('Sessions', '${stats.totalSessions}'),
              _metricPill('Total Attempted', '${stats.totalAttemptedAnswers}'),
              _metricPill('Total Correct', '${stats.totalCorrectAnswers}'),
              _metricPill('Best Attempted', '${stats.bestAttemptedAnswers}'),
              _metricPill('Best Correct', '${stats.bestCorrectAnswers}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeRunCard(TimeAttackSessionData session) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Live Run',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  _formatDuration(_remainingSeconds),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                backgroundColor: const Color(0xFFFEE2E2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricPill('Attempted', '${session.attemptedAnswers}'),
              _metricPill('Correct', '${session.correctAnswers}'),
              _metricPill('Wrong', '${session.wrongAnswers}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionCard(TimeAttackQuestion question) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...question.options.map((option) {
            final isSelected = _selectedOption == option.key;
            final isAnswered = _lastIsCorrect != null;
            Color border = const Color(0xFFCBD5E1);
            Color bg = Colors.white;
            if (isAnswered) {
              if (_lastIsCorrect == true && isSelected) {
                // Correct answer selected
                border = const Color(0xFF15803D);
                bg = const Color(0xFFDCFCE7);
              } else if (_lastIsCorrect == false && isSelected) {
                // Incorrect selected
                border = const Color(0xFFB91C1C);
                bg = const Color(0xFFFEE2E2);
              }
            } else if (isSelected) {
              border = const Color(0xFF2563EB);
              bg = const Color(0xFFEFF6FF);
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: isAnswered || _submitting
                    ? null
                    : () {
                        final now = DateTime.now();
                        if (_lastAutoSubmitTapAt != null &&
                            now.difference(_lastAutoSubmitTapAt!) <
                                _autoSubmitTapDebounce) {
                          return;
                        }

                        _lastAutoSubmitTapAt = now;

                        setState(() {
                          _selectedOption = option.key;
                        });
                        unawaited(_submitAnswer());
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Text(option.text),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  _selectedOption == null ||
                      _submitting ||
                      _lastIsCorrect != null
                  ? null
                  : _submitAnswer,
              child: Text(_submitting ? 'Submitting...' : 'Submit & Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(TimeAttackLeaderboardResponse leaderboard) {
    final isMeVisible = leaderboard.leaderboard.any((entry) => entry.isMe);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Monthly Leaderboard',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Resets monthly',
                        style: TextStyle(
                          color: Color(0xFF075985),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  leaderboard.you.rank == null
                      ? 'No rank yet this month'
                      : '#${leaderboard.you.rank}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  leaderboard.resetNote,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metricPill(
                      'Best Attempted',
                      '${leaderboard.you.stats.bestAttemptedAnswers}',
                    ),
                    _metricPill(
                      'Best Correct',
                      '${leaderboard.you.stats.bestCorrectAnswers}',
                    ),
                    if (leaderboard.you.hasPlayedThisMonth)
                      _metricPill(
                        'Sessions',
                        '${leaderboard.you.stats.totalSessions}',
                      ),
                  ],
                ),
                if (leaderboard.you.message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    leaderboard.you.message!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (leaderboard.leaderboard.isEmpty)
            const AppSurfaceCard(
              child: Text('No leaderboard data yet. Be the first to play!'),
            )
          else
            ...leaderboard.leaderboard.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildLeaderboardRow(entry),
              ),
            ),
          if (!isMeVisible && leaderboard.you.rank != null) ...[
            const SizedBox(height: 4),
            _buildMyRankCard(leaderboard),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow(TimeAttackLeaderboardEntry entry) {
    final rankColor = entry.rank == 1
        ? const Color(0xFFF59E0B)
        : entry.rank == 2
        ? const Color(0xFF94A3B8)
        : entry.rank == 3
        ? const Color(0xFFB45309)
        : const Color(0xFF334155);

    return AppSurfaceCard(
      child: Container(
        decoration: BoxDecoration(
          gradient: entry.isMe
              ? const LinearGradient(
                  colors: [Color(0xFFF8FBFF), Color(0xFFE8F1FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: entry.isMe
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0),
            width: entry.isMe ? 1.4 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: entry.rank <= 3
                    ? rankColor.withValues(alpha: 0.18)
                    : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(
                  color: entry.rank <= 3
                      ? rankColor.withValues(alpha: 0.35)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Center(
                child: Text(
                  '#${entry.rank}',
                  style: TextStyle(
                    color: entry.rank <= 3
                        ? rankColor
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isMe)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Best attempted: ${entry.bestAttemptedAnswers} • Best correct: ${entry.bestCorrectAnswers}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
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

  Widget _buildMyRankCard(TimeAttackLeaderboardResponse leaderboard) {
    final rankText = leaderboard.you.rank == null
        ? 'No rank yet'
        : '#${leaderboard.you.rank}';
    final stats = leaderboard.you.stats;

    return AppSurfaceCard(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_pin_circle_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Monthly Rank',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rankText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    leaderboard.you.hasPlayedThisMonth
                        ? 'This card appears below the visible list when you are outside the top results.'
                        : 'Play this month to appear on the leaderboard.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stats.bestAttemptedAnswers}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Best attempted',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1E3A8A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) {
      return '00:00';
    }

    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
