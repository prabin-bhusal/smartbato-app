import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import 'battle_results_page.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

enum _Phase { answering, waiting }

class BattleQuestionsPage extends StatefulWidget {
  const BattleQuestionsPage({
    super.key,
    required this.authController,
    required this.battle,
  });

  final AuthController authController;
  final Map<String, dynamic> battle;

  @override
  State<BattleQuestionsPage> createState() => _BattleQuestionsPageState();
}

class _BattleQuestionsPageState extends State<BattleQuestionsPage>
    with WidgetsBindingObserver {
  late Map<String, dynamic> _battle;
  Timer? _timer;
  Timer? _heartbeatTimer;
  int _remaining = 180;
  int _pauseRemaining = 0;
  int _currentIndex = 0;
  final Map<int, String> _selectedAnswers = {};
  final Map<int, int> _questionElapsedMs = {};
  DateTime? _questionOpenedAt;
  _Phase _phase = _Phase.answering;
  bool _submitting = false;
  String? _error;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _battle = widget.battle;
    _pauseRemaining = _computePauseRemaining(_battle);
    _syncPhaseFromBattle();
    _questionOpenedAt = DateTime.now();
    _startTimer();
    _startHeartbeat();
    _attachSocket();
    final battleId = (_battle['id'] as num?)?.toInt() ?? 0;
    if (battleId > 0) {
      widget.authController.realtimeSocket.joinBattle(battleId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    final rt = widget.authController.realtimeSocket;
    rt.off('battle:state_updated', _handleStateUpdated);
    rt.off('battle:finish', _handleStateUpdated);
    rt.off('battle_progress_update', _handleStateUpdated);
    rt.off('battle_finish', _handleStateUpdated);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sendHeartbeat();
    }
  }

  void _attachSocket() {
    final rt = widget.authController.realtimeSocket;
    rt.off('battle:state_updated', _handleStateUpdated);
    rt.off('battle:finish', _handleStateUpdated);
    rt.off('battle_progress_update', _handleStateUpdated);
    rt.off('battle_finish', _handleStateUpdated);
    rt.on('battle:state_updated', _handleStateUpdated);
    rt.on('battle:finish', _handleStateUpdated);
    rt.on('battle_progress_update', _handleStateUpdated);
    rt.on('battle_finish', _handleStateUpdated);
  }

  void _handleStateUpdated(dynamic payload) {
    if (!mounted || payload is! Map) return;
    final data = Map<String, dynamic>.from(
      payload.map<String, dynamic>((k, v) => MapEntry(k.toString(), v)),
    );
    final incoming = data['battle'];
    if (incoming is! Map<String, dynamic>) return;
    final incomingId = (incoming['id'] as num?)?.toInt() ?? 0;
    final myId = (_battle['id'] as num?)?.toInt() ?? 0;
    if (myId > 0 && incomingId != myId) return;
    _applyIncomingBattle(incoming);
  }

  void _startTimer() {
    _timer?.cancel();
    _remaining = _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_isPaused) {
        setState(() {
          _pauseRemaining = _computePauseRemaining(_battle);
        });
        return;
      }
      final r = _computeRemaining();
      setState(() => _remaining = r);
      if (r <= 0) {
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendHeartbeat();
    });
  }

  Future<void> _sendHeartbeat() async {
    final battleId = (_battle['id'] as num?)?.toInt() ?? 0;
    if (battleId <= 0 || !mounted) {
      return;
    }

    try {
      final payload = await widget.authController.heartbeatBattle(battleId);
      if (!mounted) return;
      final battle = payload['battle'];
      if (battle is Map<String, dynamic>) {
        _applyIncomingBattle(Map<String, dynamic>.from(battle));
      }
    } catch (_) {
      // Ignore transient connectivity errors; periodic heartbeat retries.
    }
  }

  void _applyIncomingBattle(Map<String, dynamic> incoming) {
    if (!mounted) return;
    setState(() {
      _battle = incoming;
      _pauseRemaining = _computePauseRemaining(incoming);
      _syncPhaseFromBattle();
    });
    if ((incoming['status'] ?? '').toString() == 'completed') {
      _goToResults(incoming);
    }
  }

  bool get _isPaused => (_battle['status'] ?? '').toString() == 'paused';

  int _computePauseRemaining(Map<String, dynamic> battle) {
    final pause = battle['pause'];
    if (pause is! Map<String, dynamic>) {
      return 0;
    }
    final direct = (pause['seconds_remaining'] as num?)?.toInt();
    if (direct != null && direct > 0) {
      return direct;
    }
    final deadlineRaw = (pause['resume_deadline_at'] ?? '').toString();
    final deadline = DateTime.tryParse(deadlineRaw)?.toLocal();
    if (deadline == null) {
      return 0;
    }
    final diff = deadline.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  bool _hasSubmittedCurrentUser() {
    final me = widget.authController.user?.id ?? 0;
    final participants = (_battle['participants'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();

    for (final participant in participants) {
      final user = participant['user'] as Map<String, dynamic>?;
      final uid = (user?['id'] as num?)?.toInt() ?? 0;
      if (uid == me) {
        final submittedAt = (participant['submitted_at'] ?? '').toString();
        return submittedAt.isNotEmpty;
      }
    }

    return false;
  }

  void _syncPhaseFromBattle() {
    if ((_battle['status'] ?? '').toString() == 'completed') {
      return;
    }
    if (_isPaused || _hasSubmittedCurrentUser()) {
      _phase = _Phase.waiting;
      return;
    }
    _phase = _Phase.answering;
  }

  int _computeRemaining() {
    final endsAtRaw = (_battle['ends_at'] ?? '').toString();
    if (endsAtRaw.isNotEmpty) {
      final endsAt = DateTime.tryParse(endsAtRaw)?.toLocal();
      if (endsAt != null) {
        final s = endsAt.difference(DateTime.now()).inSeconds;
        return s < 0 ? 0 : s;
      }
    }
    final duration = (_battle['duration_seconds'] as num?)?.toInt() ?? 180;
    final startedAt = DateTime.tryParse(
      (_battle['started_at'] ?? '').toString(),
    )?.toLocal();
    if (startedAt == null) return duration;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final r = duration - elapsed;
    return r < 0 ? 0 : r;
  }

  void _captureTime() {
    final qs = _questions;
    if (qs.isEmpty || _currentIndex >= qs.length) return;
    final bqId =
        (qs[_currentIndex]['battle_question_id'] as num?)?.toInt() ?? 0;
    if (bqId <= 0) return;
    final opened = _questionOpenedAt;
    if (opened == null) {
      _questionOpenedAt = DateTime.now();
      return;
    }
    final delta = DateTime.now().difference(opened).inMilliseconds;
    if (delta > 0) {
      _questionElapsedMs[bqId] = (_questionElapsedMs[bqId] ?? 0) + delta;
    }
    _questionOpenedAt = DateTime.now();
  }

  void _selectAnswer(int bqId, String key) {
    _captureTime();
    setState(() => _selectedAnswers[bqId] = key);
    _questionOpenedAt = DateTime.now();
  }

  void _goToQuestion(int index) {
    if (index < 0 || index >= _questions.length) return;
    _captureTime();
    setState(() => _currentIndex = index);
    _questionOpenedAt = DateTime.now();
  }

  Future<void> _autoSubmit() => _submit(auto: true);

  Future<void> _submit({bool auto = false}) async {
    if (_submitting || _phase == _Phase.waiting) return;
    if (_isPaused) {
      setState(() {
        _error = 'Battle paused while opponent reconnects.';
      });
      return;
    }
    _captureTime();
    final battleId = (_battle['id'] as num?)?.toInt() ?? 0;
    if (battleId <= 0) return;

    final answers = _questions
        .map((q) {
          final bqId = (q['battle_question_id'] as num?)?.toInt() ?? 0;
          if (bqId <= 0) return null;
          return <String, dynamic>{
            'battle_question_id': bqId,
            'selected_option_key': _selectedAnswers[bqId],
            'time_taken_ms': _questionElapsedMs[bqId] ?? 0,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final payload = await widget.authController.submitBattleAnswers(
        battleId: battleId,
        answers: answers,
      );
      if (!mounted) return;
      final updated = payload['battle'];
      if (updated is Map<String, dynamic>) {
        _applyIncomingBattle(Map<String, dynamic>.from(updated));
        if ((updated['status'] ?? '').toString() == 'completed') {
          _goToResults(updated);
          return;
        }
      }
      // Opponent not yet done — show waiting screen
      _timer?.cancel();
      setState(() {
        _submitting = false;
        _phase = _Phase.waiting;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = auto
            ? 'Auto-submit failed. Please tap Submit.'
            : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _goToResults(Map<String, dynamic> finished) {
    if (_navigated) return;
    _navigated = true;
    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BattleResultsPage(
          authController: widget.authController,
          battle: finished,
          selectedAnswers: Map<int, String>.from(_selectedAnswers),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _questions =>
      ((_battle['questions'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.waiting) {
      final myId = widget.authController.user?.id ?? 0;
      final pause = _battle['pause'] as Map<String, dynamic>?;
      final pausedBy = (pause?['paused_by_user_id'] as num?)?.toInt() ?? 0;
      final isAiBattle = (_battle['is_ai'] as bool?) ?? false;
      return _WaitingScreen(
        battle: _battle,
        isPaused: _isPaused,
        pauseRemaining: _pauseRemaining,
        pausedByMe: pausedBy == myId,
        isAiBattle: isAiBattle,
      );
    }

    final qs = _questions;

    if (qs.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No questions found.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Back to Arena'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = qs[_currentIndex.clamp(0, qs.length - 1)];
    final bqId = (q['battle_question_id'] as num?)?.toInt() ?? 0;
    final selected = _selectedAnswers[bqId];
    final options = (q['options'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final isUrgent = _remaining <= 20;
    final answered = qs.where((x) {
      final id = (x['battle_question_id'] as num?)?.toInt() ?? 0;
      return _selectedAnswers[id]?.isNotEmpty ?? false;
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: List.generate(qs.length, (i) {
                        final id2 =
                            (qs[i]['battle_question_id'] as num?)?.toInt() ?? 0;
                        final isAns =
                            _selectedAnswers[id2]?.isNotEmpty ?? false;
                        final isActive = i == _currentIndex;
                        return GestureDetector(
                          onTap: () => _goToQuestion(i),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? const Color(0xFF0EA5E9)
                                  : isAns
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF1E293B),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF38BDF8)
                                    : isAns
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : isAns
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFF475569),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isUrgent
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          size: 14,
                          color: isUrgent
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _fmt(_remaining),
                          style: TextStyle(
                            color: isUrgent
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF38BDF8),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Question body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Q ${_currentIndex + 1} / ${qs.length}  ·  $answered answered',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Render question as rich text and show images if present
                    HtmlWidget(
                      (q['question'] ?? '').toString().trim().isEmpty
                          ? 'Question text not available.'
                          : (q['question'] ?? '').toString(),
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    if ((q['images'] as List<dynamic>? ?? []).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final imgUrl in (q['images'] as List<dynamic>))
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imgUrl.toString(),
                                height: 120,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) =>
                                    const Icon(Icons.broken_image_rounded),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    ...options.map((opt) {
                      final key = (opt['key'] ?? '').toString();
                      final text = (opt['text'] ?? '').toString();
                      final isSel = selected == key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: _submitting
                              ? null
                              : _isPaused
                              ? null
                              : () => _selectAnswer(bqId, key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(
                                      0xFF0284C7,
                                    ).withValues(alpha: 0.15)
                                  : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSel
                                    ? const Color(0xFF0EA5E9)
                                    : const Color(0xFF334155),
                                width: isSel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSel
                                        ? const Color(0xFF0EA5E9)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSel
                                          ? const Color(0xFF0EA5E9)
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                  child: isSel
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      HtmlWidget(
                                        text,
                                        textStyle: TextStyle(
                                          color: isSel
                                              ? Colors.white
                                              : const Color(0xFFCBD5E1),
                                          fontSize: 14,
                                          fontWeight: isSel
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                      if ((opt['images'] as List<dynamic>? ??
                                              [])
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            for (final imgUrl
                                                in (opt['images']
                                                    as List<dynamic>))
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Image.network(
                                                  imgUrl.toString(),
                                                  height: 60,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (c, e, s) =>
                                                      const Icon(
                                                        Icons
                                                            .broken_image_rounded,
                                                        size: 20,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              color: const Color(0xFF0B1120),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    OutlinedButton(
                      onPressed: () => _goToQuestion(_currentIndex - 1),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      child: const Text('Prev'),
                    ),
                  if (_currentIndex > 0) const SizedBox(width: 8),
                  if (_currentIndex < qs.length - 1)
                    OutlinedButton(
                      onPressed: () => _goToQuestion(_currentIndex + 1),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      child: const Text('Next'),
                    ),
                  const Spacer(),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: (_submitting || _isPaused)
                          ? null
                          : () => _submit(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        _submitting ? 'Submitting…' : 'Submit Battle',
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
}

class _WaitingScreen extends StatelessWidget {
  const _WaitingScreen({
    required this.battle,
    required this.isPaused,
    required this.pauseRemaining,
    required this.pausedByMe,
    required this.isAiBattle,
  });

  final Map<String, dynamic> battle;
  final bool isPaused;
  final int pauseRemaining;
  final bool pausedByMe;
  final bool isAiBattle;

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final total = (battle['questions'] as List<dynamic>?)?.length ?? 0;
    final title = !isPaused
        ? 'Waiting for opponent...'
        : pausedByMe
        ? (isAiBattle ? 'Connection lost' : 'Reconnecting your battle...')
        : (isAiBattle ? 'You are back online' : 'Opponent disconnected');

    final subtitle = !isPaused
        ? '$total questions answered. Results appear automatically.'
        : pausedByMe
        ? 'You have ${_fmt(pauseRemaining)} to reconnect. If not, this round will be awarded to the opponent.'
        : (isAiBattle
              ? 'Battle will continue automatically now that your connection is restored.'
              : 'Battle paused for ${_fmt(pauseRemaining)}. If opponent does not return, you win automatically.');

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    color: Color(0xFF0EA5E9),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isPaused) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'Reconnect window: ${_fmt(pauseRemaining)}',
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
