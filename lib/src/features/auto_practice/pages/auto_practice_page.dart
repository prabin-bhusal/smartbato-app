import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import '../models/auto_practice_models.dart';

class AutoPracticePage extends StatefulWidget {
  const AutoPracticePage({
    super.key,
    required this.authController,
    required this.onBackToDashboard,
  });

  final AuthController authController;
  final VoidCallback onBackToDashboard;

  @override
  State<AutoPracticePage> createState() => _AutoPracticePageState();
}

class _AutoPracticePageState extends State<AutoPracticePage>
    with WidgetsBindingObserver {
  late Future<AutoPracticeConfig> _future;
  AutoPracticeConfig? _config;
  bool _configApplied = false;
  bool _starting = false;
  bool _unlocking = false;
  String? _sessionError;

  final Set<int> _selectedSubjectIds = <int>{};
  final Set<int> _selectedTopicIds = <int>{};

  String _difficulty = 'mixed';
  int _questionCount = 20;
  String _practiceMode = 'quick_practice';
  String _practiceStyle = 'ai_suggested';

  double _questionSpeed = 0.5;
  double _answerSpeed = 0.55;
  int _tickDurationSeconds = 5;
  String _voiceType = 'female';
  bool _autoPlayNext = true;

  String? _sessionId;
  int _totalQuestions = 0;
  int _nextOffset = 0;
  bool _hasMoreBatches = false;
  bool _loadingBatch = false;
  bool _sessionEnded = false;
  bool _sessionPaused = false;
  bool _revealed = false;
  bool _submitting = false;
  bool _audioRunning = false;
  String _audioStage = 'idle';
  String? _selectedOption;
  final List<AutoPracticeQuestion> _questions = <AutoPracticeQuestion>[];
  int _currentIndex = 0;
  int _attempted = 0;
  int _correct = 0;
  int _coinsEarned = 0;
  int _elapsedSessionSeconds = 0;
  int _elapsedQuestionSeconds = 0;
  int _tickCountdown = 0;
  AutoPracticeRecommendationSummary? _recommendationSummary;

  final Stopwatch _sessionStopwatch = Stopwatch();
  final Stopwatch _questionStopwatch = Stopwatch();
  Timer? _sessionTicker;
  Timer? _audioAdvanceTimer;
  FlutterTts? _tts;
  List<dynamic> _voices = const <dynamic>[];

  bool get _sessionActive => _sessionId != null && !_sessionEnded;

  AutoPracticeQuestion? get _currentQuestion {
    if (_currentIndex < 0 || _currentIndex >= _questions.length) {
      return null;
    }

    return _questions[_currentIndex];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _loadConfig();
    _initializeTts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTicker?.cancel();
    _audioAdvanceTimer?.cancel();
    _sessionStopwatch.stop();
    _questionStopwatch.stop();
    _tts?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _sessionActive) {
      _pauseSession();
    }
  }

  Future<AutoPracticeConfig> _loadConfig() async {
    final config = await widget.authController.loadAutoPracticeConfig();
    if (!_configApplied) {
      _difficulty = config.defaults.difficulty;
      _questionCount = config.defaults.questionCount;
      _practiceMode = config.defaults.practiceMode;
      _practiceStyle = config.defaults.practiceStyle;
      _questionSpeed = config.audioDefaults.questionSpeed;
      _answerSpeed = config.audioDefaults.answerSpeed;
      _tickDurationSeconds = config.audioDefaults.tickDurationSeconds;
      _voiceType = config.audioDefaults.voiceType;
      _autoPlayNext = config.audioDefaults.autoPlayNext;
      _configApplied = true;
    }
    _config = config;
    return config;
  }

  Future<void> _refresh() async {
    final next = _loadConfig();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _unlockFeature() async {
    if (_unlocking) {
      return;
    }

    setState(() {
      _unlocking = true;
    });

    try {
      final message = await widget.authController.unlockAutoPracticeFeature();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      await _refresh();
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
          _unlocking = false;
        });
      }
    }
  }

  Future<void> _initializeTts() async {
    final tts = FlutterTts();
    await tts.awaitSpeakCompletion(true);
    await tts.setLanguage('en-US');
    await tts.setVolume(1.0);
    final voices = await tts.getVoices;
    if (!mounted) {
      return;
    }
    setState(() {
      _tts = tts;
      _voices = voices is List<dynamic> ? voices : const <dynamic>[];
    });
  }

  Future<void> _startSession() async {
    final config = _config;
    if (config == null || _starting) {
      return;
    }

    if (config.feature.unlockRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unlock Auto Practice for ${config.feature.unlockCost} coins first.',
          ),
        ),
      );
      return;
    }

    if (config.course == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course first.')),
      );
      return;
    }

    setState(() {
      _starting = true;
      _sessionError = null;
    });

    try {
      final response = await widget.authController.startAutoPracticeSession(
        subjectIds: _selectedSubjectIds.toList()..sort(),
        topicIds: _selectedTopicIds.toList()..sort(),
        difficulty: _difficulty,
        questionCount: _questionCount,
        practiceMode: _practiceMode,
        practiceStyle: _practiceStyle,
      );

      _sessionTicker?.cancel();
      _audioAdvanceTimer?.cancel();
      await _tts?.stop();

      _questions
        ..clear()
        ..addAll(response.batch.questions);

      _sessionId = response.sessionId;
      _totalQuestions = response.questionCount;
      _nextOffset = response.batch.nextOffset;
      _hasMoreBatches = response.batch.hasMore;
      _currentIndex = 0;
      _attempted = 0;
      _correct = 0;
      _coinsEarned = 0;
      _selectedOption = null;
      _revealed = false;
      _sessionEnded = false;
      _sessionPaused = false;
      _sessionError = null;
      _recommendationSummary = response.recommendationSummary;
      _audioStage = 'ready';
      _tickCountdown = _tickDurationSeconds;

      _sessionStopwatch
        ..reset()
        ..start();
      _questionStopwatch
        ..reset()
        ..start();
      _startStopwatchTicker();

      if (mounted) {
        setState(() {});
      }

      _prefetchIfNeeded();

      if (_practiceMode == 'audio_practice') {
        unawaited(_runAudioSequence());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  void _startStopwatchTicker() {
    _sessionTicker?.cancel();
    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _elapsedSessionSeconds = _sessionStopwatch.elapsed.inSeconds;
        _elapsedQuestionSeconds = _questionStopwatch.elapsed.inSeconds;
      });
    });
  }

  Future<void> _loadMoreBatch() async {
    final sessionId = _sessionId;
    if (sessionId == null || _loadingBatch || !_hasMoreBatches) {
      return;
    }

    setState(() {
      _loadingBatch = true;
    });

    try {
      final batch = await widget.authController.loadAutoPracticeBatch(
        sessionId: sessionId,
        offset: _nextOffset,
      );

      final existingIds = _questions.map((item) => item.id).toSet();
      final incoming = batch.questions
          .where((item) => !existingIds.contains(item.id))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _questions.addAll(incoming);
        _nextOffset = batch.nextOffset;
        _hasMoreBatches = batch.hasMore;
      });
    } catch (_) {
      // Keep current cache and let user continue.
    } finally {
      if (mounted) {
        setState(() {
          _loadingBatch = false;
        });
      }
    }
  }

  void _prefetchIfNeeded() {
    final remainingCached = _questions.length - (_currentIndex + 1);
    if (remainingCached <= 5) {
      unawaited(_loadMoreBatch());
    }
  }

  void _selectOption(String optionKey) {
    if (_revealed || _sessionPaused) {
      return;
    }

    setState(() {
      _selectedOption = optionKey;
    });
  }

  void _submitQuickAnswer() {
    if (_submitting || _revealed || _selectedOption == null) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    _revealCurrentQuestion();

    setState(() {
      _submitting = false;
    });
  }

  void _revealCurrentQuestion() {
    final question = _currentQuestion;
    if (question == null || _revealed) {
      return;
    }

    final isCorrect = _selectedOption == question.correctOption;

    _questionStopwatch.stop();

    setState(() {
      _attempted += 1;
      if (isCorrect) {
        _correct += 1;
        _coinsEarned += 1;
      }
      _revealed = true;
      _audioStage = 'review';
    });
  }

  Future<void> _runAudioSequence() async {
    if (!_sessionActive || _sessionPaused || _audioRunning) {
      return;
    }

    final question = _currentQuestion;
    if (question == null) {
      return;
    }

    setState(() {
      _audioRunning = true;
      _revealed = false;
      _audioStage = 'question';
      _tickCountdown = _tickDurationSeconds;
      _selectedOption = null;
    });

    _questionStopwatch
      ..reset()
      ..start();

    try {
      await _applyVoiceSettings();
      if (!_sessionActive || _sessionPaused) {
        return;
      }

      await _tts?.setSpeechRate(_questionSpeed);
      await _tts?.speak(_buildQuestionSpeech(question));

      if (!_sessionActive || _sessionPaused) {
        return;
      }

      await _runTickCountdown();
      if (!_sessionActive || _sessionPaused) {
        return;
      }

      _revealCurrentQuestion();

      setState(() {
        _audioStage = 'answer';
      });

      await _tts?.setSpeechRate(_answerSpeed);
      await _tts?.speak(_buildCorrectAnswerSpeech(question));

      if (!_sessionActive || _sessionPaused) {
        return;
      }

      setState(() {
        _audioStage = 'review';
      });

      if (_autoPlayNext) {
        _audioAdvanceTimer?.cancel();
        _audioAdvanceTimer = Timer(const Duration(seconds: 2), () {
          if (_sessionActive && !_sessionPaused) {
            _nextQuestion();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _audioRunning = false;
        });
      }
    }
  }

  Future<void> _applyVoiceSettings() async {
    final tts = _tts;
    if (tts == null || _voices.isEmpty) {
      return;
    }

    Map<String, dynamic>? selectedVoice;
    var bestScore = -1;

    for (final voice in _voices) {
      if (voice is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(
        voice.map((key, value) => MapEntry(key.toString(), value)),
      );
      final search =
          '${map['name'] ?? ''} ${map['locale'] ?? ''} ${map['gender'] ?? ''}'
              .toLowerCase();
      final locale = (map['locale'] ?? '').toString().toLowerCase();

      var score = 0;
      if (locale.startsWith('en')) {
        score += 20;
      }

      if (_voiceType == 'male') {
        if (search.contains('male') ||
            search.contains('guy') ||
            search.contains('man')) {
          score += 40;
        }
      } else {
        if (search.contains('female') ||
            search.contains('woman') ||
            search.contains('girl')) {
          score += 40;
        }
      }

      if (search.contains('neural') ||
          search.contains('wavenet') ||
          search.contains('enhanced') ||
          search.contains('premium')) {
        score += 10;
      }

      if (search.contains('google')) {
        score += 5;
      }

      if (score > bestScore) {
        bestScore = score;
        selectedVoice = map;
      }
    }

    if (selectedVoice == null) {
      final fallback = _voices
          .whereType<Map>()
          .cast<Map<dynamic, dynamic>>()
          .firstOrNull;
      if (fallback != null) {
        selectedVoice = Map<String, dynamic>.from(
          fallback.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }

    if (selectedVoice == null) {
      return;
    }

    final name = selectedVoice['name'];
    final locale = selectedVoice['locale'];
    if (name != null && locale != null) {
      await tts.setVoice({'name': name, 'locale': locale});
    }

    await tts.setPitch(_voiceType == 'male' ? 0.92 : 1.05);
  }

  String _buildQuestionSpeech(AutoPracticeQuestion question) {
    final questionText = _sanitizeSpeechText(question.question);
    final optionsText = question.options
        .asMap()
        .entries
        .map((entry) {
          final optionLabel = _optionLabel(entry.key);
          final optionText = _sanitizeSpeechText(entry.value.text);
          return 'Option $optionLabel. $optionText.';
        })
        .join(' ');

    return 'Question. $questionText. Options. $optionsText';
  }

  String _buildCorrectAnswerSpeech(AutoPracticeQuestion question) {
    final correctOption = question.options.firstWhere(
      (option) => option.key == question.correctOption,
      orElse: () => const AutoPracticeOption(key: '', text: ''),
    );

    final index = question.options.indexOf(correctOption);
    final label = index >= 0 ? _optionLabel(index) : '';
    final answerText = _sanitizeSpeechText(question.correctAnswerText);

    if (label.isEmpty) {
      return 'Correct answer. $answerText.';
    }

    return 'Correct answer. Option $label. $answerText.';
  }

  String _optionLabel(int index) {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    if (index >= 0 && index < labels.length) {
      return labels[index];
    }

    return (index + 1).toString();
  }

  String _sanitizeSpeechText(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', ' and ')
        .replaceAll('&quot;', ' ')
        .replaceAll('&apos;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _runTickCountdown() async {
    for (var remaining = _tickDurationSeconds; remaining > 0; remaining--) {
      if (!_sessionActive || _sessionPaused) {
        return;
      }

      setState(() {
        _audioStage = 'thinking';
        _tickCountdown = remaining;
      });

      SystemSound.play(SystemSoundType.click);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() {
        _tickCountdown = 0;
      });
    }
  }

  void _pauseSession() {
    if (!_sessionActive || _sessionPaused) {
      return;
    }

    _sessionStopwatch.stop();
    _questionStopwatch.stop();
    _audioAdvanceTimer?.cancel();
    _tts?.stop();

    setState(() {
      _sessionPaused = true;
      _audioStage = 'paused';
    });
  }

  void _resumeSession() {
    if (!_sessionActive || !_sessionPaused) {
      return;
    }

    _sessionStopwatch.start();
    if (!_revealed) {
      _questionStopwatch.start();
    }

    setState(() {
      _sessionPaused = false;
    });

    if (_practiceMode == 'audio_practice' && !_revealed) {
      unawaited(_runAudioSequence());
    }
  }

  void _nextQuestion() {
    _audioAdvanceTimer?.cancel();
    if (!_sessionActive) {
      return;
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _totalQuestions) {
      _endSession();
      return;
    }

    if (nextIndex >= _questions.length) {
      unawaited(_loadMoreBatch());
      return;
    }

    _questionStopwatch
      ..reset()
      ..start();

    setState(() {
      _currentIndex = nextIndex;
      _selectedOption = null;
      _revealed = false;
      _audioStage = 'ready';
      _tickCountdown = _tickDurationSeconds;
      _elapsedQuestionSeconds = 0;
    });

    _prefetchIfNeeded();

    if (_practiceMode == 'audio_practice' && !_sessionPaused) {
      unawaited(_runAudioSequence());
    }
  }

  void _endSession() {
    _audioAdvanceTimer?.cancel();
    _tts?.stop();
    _sessionStopwatch.stop();
    _questionStopwatch.stop();

    setState(() {
      _sessionEnded = true;
      _audioStage = 'ended';
    });
  }

  void _resetToConfiguration() {
    _audioAdvanceTimer?.cancel();
    _sessionTicker?.cancel();
    _tts?.stop();
    _sessionId = null;
    _totalQuestions = 0;
    _nextOffset = 0;
    _hasMoreBatches = false;
    _questions.clear();
    _currentIndex = 0;
    _selectedOption = null;
    _revealed = false;
    _sessionEnded = false;
    _sessionPaused = false;
    _audioRunning = false;
    _audioStage = 'idle';
    _elapsedSessionSeconds = 0;
    _elapsedQuestionSeconds = 0;
    _attempted = 0;
    _correct = 0;
    _coinsEarned = 0;
    _sessionError = null;
    _recommendationSummary = null;
    _sessionStopwatch.reset();
    _questionStopwatch.reset();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AutoPracticeConfig>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _config == null) {
          return const AppPageShell(
            maxWidth: 960,
            children: [
              AppHeroBanner(
                title: 'Auto Practice',
                subtitle: 'Loading your smart revision configuration.',
                icon: Icons.auto_awesome_rounded,
                colors: [
                  Color(0xFFF59E0B),
                  Color(0xFFF97316),
                  Color(0xFFEF4444),
                ],
              ),
              SizedBox(height: 12),
              AppSurfaceCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError && _config == null) {
          return _errorState(
            snapshot.error.toString().replaceFirst('Exception: ', ''),
          );
        }

        final config = snapshot.data ?? _config;
        if (config == null) {
          return _errorState('Unable to load Auto Practice.');
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final controlsInset = _practiceMode == 'audio_practice'
            ? (screenWidth < 560 ? 220.0 : 190.0)
            : (screenWidth < 560 ? 170.0 : 140.0);
        final bottomInset = _sessionActive ? controlsInset : 24.0;

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _sessionActive ? () async {} : _refresh,
              child: AppPageShell(
                maxWidth: 960,
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
                children: [
                  _hero(config),
                  const SizedBox(height: 12),
                  if (_sessionActive || _sessionEnded)
                    ..._sessionContent(config)
                  else
                    ..._configurationContent(config),
                ],
              ),
            ),
            if (_sessionActive) _floatingControls(),
          ],
        );
      },
    );
  }

  Widget _hero(AutoPracticeConfig config) {
    final chips = <Widget>[
      _chip('Course', config.course?.name ?? 'Not selected'),
      _chip('Mode', _practiceMode == 'audio_practice' ? 'Audio' : 'Quick'),
      _chip('Questions', _questionCount.toString()),
      _chip(
        'Style',
        _practiceStyle == 'ai_suggested' ? 'AI Suggested' : 'Custom',
      ),
      _chip('Coins', config.feature.userCoins.toString()),
      if (config.feature.unlockRequired)
        _chip('Unlock', '${config.feature.unlockCost} coins'),
    ];

    return AppHeroBanner(
      title: 'Auto Practice',
      subtitle:
          'Smart revision sessions with quick UI mode and guided audio mode.',
      icon: Icons.auto_awesome_rounded,
      colors: const [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEF4444)],
      trailing: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      side: BorderSide(color: const Color(0xFF0F172A).withValues(alpha: 0.16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  List<Widget> _configurationContent(AutoPracticeConfig config) {
    if (config.feature.unlockRequired) {
      final enoughCoins = config.feature.userCoins >= config.feature.unlockCost;

      return [
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unlock Auto Practice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'One-time cost: ${config.feature.unlockCost} coins. Balance: ${config.feature.userCoins} coins.',
                style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: enoughCoins && !_unlocking ? _unlockFeature : null,
                  icon: _unlocking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_open_rounded),
                  label: Text(
                    enoughCoins ? 'Unlock now' : 'Insufficient coins',
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Practice Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _metaRow(
              'Course',
              config.course?.name ?? 'Select course from settings',
            ),
            const SizedBox(height: 12),
            _sectionLabel('Subjects'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: config.subjects.map((subject) {
                final selected = _selectedSubjectIds.contains(subject.id);
                return FilterChip(
                  label: Text(subject.name),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedSubjectIds.add(subject.id);
                      } else {
                        _selectedSubjectIds.remove(subject.id);
                        _selectedTopicIds.removeWhere(
                          (topicId) => subject.topics.any(
                            (topic) => topic.id == topicId,
                          ),
                        );
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Topics'),
            const SizedBox(height: 8),
            if (_selectedSubjectIds.isEmpty)
              const Text(
                'Select one or more subjects to see their topics.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
              )
            else ...[
              for (final subject in config.subjects)
                if (_selectedSubjectIds.contains(subject.id)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      subject.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subject.topics.map((topic) {
                      return FilterChip(
                        label: Text('${topic.name} (${topic.questionCount})'),
                        selected: _selectedTopicIds.contains(topic.id),
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedTopicIds.add(topic.id);
                            } else {
                              _selectedTopicIds.remove(topic.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
            ],
            const SizedBox(height: 16),
            _sectionLabel('Difficulty'),
            const SizedBox(height: 8),
            _choiceWrap(
              values: const ['easy', 'medium', 'hard', 'mixed'],
              selected: _difficulty,
              labelBuilder: (value) => _titleCase(value),
              onSelected: (value) => setState(() => _difficulty = value),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Question Count'),
            const SizedBox(height: 8),
            _choiceWrap(
              values: const ['10', '20', '50', '100'],
              selected: _questionCount.toString(),
              labelBuilder: (value) => value,
              onSelected: (value) =>
                  setState(() => _questionCount = int.parse(value)),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Practice Mode'),
            const SizedBox(height: 8),
            _choiceWrap(
              values: const ['quick_practice', 'audio_practice'],
              selected: _practiceMode,
              labelBuilder: (value) => value == 'audio_practice'
                  ? 'Audio Practice'
                  : 'Quick Practice',
              onSelected: (value) => setState(() => _practiceMode = value),
            ),
            const SizedBox(height: 16),
            _sectionLabel('Practice Style'),
            const SizedBox(height: 8),
            _choiceWrap(
              values: const ['ai_suggested', 'custom_selection'],
              selected: _practiceStyle,
              labelBuilder: (value) =>
                  value == 'ai_suggested' ? 'AI Suggested' : 'Custom Selection',
              onSelected: (value) => setState(() => _practiceStyle = value),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (_practiceStyle == 'ai_suggested') _aiSuggestionCard(config),
      if (_practiceMode == 'audio_practice') ...[
        const SizedBox(height: 12),
        _audioSettingsCard(config),
      ],
      if (_sessionError != null) ...[
        const SizedBox(height: 12),
        _messageCard(_sessionError!, isError: true),
      ],
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _starting ? null : _startSession,
          icon: _starting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _practiceMode == 'audio_practice'
                      ? Icons.graphic_eq_rounded
                      : Icons.play_arrow_rounded,
                ),
          label: Text(
            _practiceMode == 'audio_practice'
                ? 'Start Audio Practice'
                : 'Start Quick Practice',
          ),
        ),
      ),
    ];
  }

  Widget _aiSuggestionCard(AutoPracticeConfig config) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Suggested Logic',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          ...config.aiGuidance.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _audioSettingsCard(AutoPracticeConfig config) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Customization',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _sliderRow(
            label: 'Question speaking speed',
            value: _questionSpeed,
            min: 0.3,
            max: 0.7,
            onChanged: (value) => setState(() => _questionSpeed = value),
          ),
          const SizedBox(height: 10),
          _sliderRow(
            label: 'Answer speaking speed',
            value: _answerSpeed,
            min: 0.3,
            max: 0.7,
            onChanged: (value) => setState(() => _answerSpeed = value),
          ),
          const SizedBox(height: 10),
          Text(
            'Tick timer duration: $_tickDurationSeconds seconds',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            value: _tickDurationSeconds.toDouble(),
            min: 3,
            max: 15,
            divisions: 12,
            label: '$_tickDurationSeconds s',
            onChanged: (value) =>
                setState(() => _tickDurationSeconds = value.round()),
          ),
          const SizedBox(height: 10),
          _sectionLabel('Voice Type'),
          const SizedBox(height: 8),
          _choiceWrap(
            values: const ['female', 'male'],
            selected: _voiceType,
            labelBuilder: (value) => _titleCase(value),
            onSelected: (value) => setState(() => _voiceType = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto Play Next Question'),
            subtitle: Text(
              config.audioDefaults.backgroundPlaybackSupported
                  ? 'Playback continues while supported by the device TTS engine.'
                  : 'Background playback depends on device support.',
            ),
            value: _autoPlayNext,
            onChanged: (value) => setState(() => _autoPlayNext = value),
          ),
        ],
      ),
    );
  }

  List<Widget> _sessionContent(AutoPracticeConfig config) {
    final question = _currentQuestion;
    final accuracy = _attempted == 0 ? 0.0 : (_correct / _attempted) * 100;
    final currentNumber = _sessionEnded
        ? _attempted.clamp(0, _totalQuestions)
        : (_currentIndex + 1).clamp(
            1,
            _totalQuestions == 0 ? 1 : _totalQuestions,
          );

    return [
      AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _sessionEnded
                        ? 'Session Summary'
                        : (_practiceMode == 'audio_practice'
                              ? 'Audio Practice Session'
                              : 'Quick Practice Session'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_recommendationSummary != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Weak topics: ${_recommendationSummary!.weakTopicCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metricTile('Attempted', '$_attempted'),
                _metricTile('Correct', '$_correct'),
                _metricTile('Accuracy', '${accuracy.toStringAsFixed(1)}%'),
                _metricTile('Coins earned', '$_coinsEarned'),
                _metricTile(
                  'Time spent',
                  _formatDuration(_elapsedSessionSeconds),
                ),
              ],
            ),
            if (_practiceMode == 'audio_practice' && !_sessionEnded) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _totalQuestions == 0
                          ? 0
                          : currentNumber / _totalQuestions,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFF97316),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$currentNumber / $_totalQuestions',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (_sessionError != null) ...[
        _messageCard(_sessionError!, isError: true),
        const SizedBox(height: 12),
      ],
      if (_sessionEnded)
        _summaryCard()
      else if (question == null)
        AppSurfaceCard(
          child: Row(
            children: [
              const Expanded(child: Text('Loading questions...')),
              if (_loadingBatch) const CircularProgressIndicator(),
            ],
          ),
        )
      else
        _questionPanel(question, currentNumber),
    ];
  }

  Widget _summaryCard() {
    final accuracy = _attempted == 0 ? 0.0 : (_correct / _attempted) * 100;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'End Session Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryPill('Questions attempted', '$_attempted'),
              _summaryPill('Correct answers', '$_correct'),
              _summaryPill('Accuracy', '${accuracy.toStringAsFixed(1)}%'),
              _summaryPill('Coins earned', '$_coinsEarned'),
              _summaryPill(
                'Time spent',
                _formatDuration(_elapsedSessionSeconds),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _startSession,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Practice Again'),
              ),
              OutlinedButton.icon(
                onPressed: _resetToConfiguration,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Change Settings'),
              ),
              TextButton.icon(
                onPressed: () {
                  _resetToConfiguration();
                  widget.onBackToDashboard();
                },
                icon: const Icon(Icons.dashboard_customize_rounded),
                label: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionPanel(AutoPracticeQuestion question, int currentNumber) {
    final selectedIsCorrect = _selectedOption == question.correctOption;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(
                'Question $currentNumber of $_totalQuestions',
                const Color(0xFFDBEAFE),
                const Color(0xFF1D4ED8),
              ),
              _tag(
                question.subjectName,
                const Color(0xFFDCFCE7),
                const Color(0xFF166534),
              ),
              _tag(
                question.topicName,
                const Color(0xFFFFEDD5),
                const Color(0xFF9A3412),
              ),
              _tag(
                _titleCase(question.difficultyLabel),
                const Color(0xFFEDE9FE),
                const Color(0xFF5B21B6),
              ),
              _tag(
                'Time ${_formatDuration(_elapsedQuestionSeconds)}',
                const Color(0xFFE0F2FE),
                const Color(0xFF0C4A6E),
              ),
            ],
          ),
          if (_practiceMode == 'audio_practice') ...[
            const SizedBox(height: 12),
            _audioStatusBanner(),
          ],
          const SizedBox(height: 16),
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          ...question.options.map((option) => _optionTile(question, option)),
          const SizedBox(height: 16),
          if (!_revealed && _practiceMode == 'quick_practice')
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedOption == null || _sessionPaused
                    ? null
                    : _submitQuickAnswer,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Submit'),
              ),
            ),
          if (_revealed) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selectedIsCorrect
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedIsCorrect
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        selectedIsCorrect
                            ? Icons.verified_rounded
                            : Icons.cancel_rounded,
                        color: selectedIsCorrect
                            ? const Color(0xFF047857)
                            : const Color(0xFFB91C1C),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selectedIsCorrect ? 'Correct' : 'Incorrect',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selectedIsCorrect
                              ? const Color(0xFF047857)
                              : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Correct answer: ${question.correctAnswerText}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      height: 1.45,
                    ),
                  ),
                  if (question.resources.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Resources: ${question.resources}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_practiceMode == 'quick_practice' || !_autoPlayNext)
                  FilledButton.icon(
                    onPressed: _sessionPaused ? null : _nextQuestion,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next Question'),
                  ),
                OutlinedButton.icon(
                  onPressed: _endSession,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End Session'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _audioStatusBanner() {
    String message;
    switch (_audioStage) {
      case 'question':
        message = 'Reading question aloud...';
        break;
      case 'thinking':
        message = 'Think now. Tick timer: $_tickCountdown s';
        break;
      case 'answer':
        message = 'Reading answer and explanation...';
        break;
      case 'review':
        message = _autoPlayNext
            ? 'Auto-playing next question shortly.'
            : 'Review complete. Tap next when ready.';
        break;
      case 'paused':
        message = 'Session paused.';
        break;
      default:
        message = 'Preparing audio guidance...';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq_rounded, color: Color(0xFFEA580C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionTile(AutoPracticeQuestion question, AutoPracticeOption option) {
    final isSelected = _selectedOption == option.key;
    final isCorrect = question.correctOption == option.key;

    Color border = const Color(0xFFE2E8F0);
    Color background = Colors.white;
    Color foreground = const Color(0xFF0F172A);

    if (_revealed && isCorrect) {
      border = const Color(0xFF34D399);
      background = const Color(0xFFECFDF5);
      foreground = const Color(0xFF065F46);
    } else if (_revealed && isSelected && !isCorrect) {
      border = const Color(0xFFFCA5A5);
      background = const Color(0xFFFEF2F2);
      foreground = const Color(0xFF991B1B);
    } else if (isSelected) {
      border = const Color(0xFF60A5FA);
      background = const Color(0xFFEFF6FF);
      foreground = const Color(0xFF1D4ED8);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _revealed || _sessionPaused
            ? null
            : () => _selectOption(option.key),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: border.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  option.key.replaceFirst('option', ''),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingControls() {
    final questionNumber = (_currentIndex + 1).clamp(
      1,
      _totalQuestions == 0 ? 1 : _totalQuestions,
    );

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;

              return AppSurfaceCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_practiceMode == 'audio_practice') ...[
                      if (compact) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Question $questionNumber of $_totalQuestions',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _totalQuestions == 0
                              ? 0
                              : questionNumber / _totalQuestions,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFF97316),
                          ),
                        ),
                      ] else
                        Row(
                          children: [
                            Text(
                              'Question $questionNumber of $_totalQuestions',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: _totalQuestions == 0
                                    ? 0
                                    : questionNumber / _totalQuestions,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(999),
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFF97316),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_sessionPaused)
                            FilledButton.icon(
                              onPressed: _resumeSession,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Resume'),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: _pauseSession,
                              icon: const Icon(Icons.pause_rounded),
                              label: const Text('Pause'),
                            ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _sessionPaused ? null : _nextQuestion,
                            icon: const Icon(Icons.skip_next_rounded),
                            label: const Text('Next Question'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _endSession,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('End Session'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: AppSurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 34,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _messageCard(String message, {required bool isError}) {
    final background = isError
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFECFDF5);
    final border = isError ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0);
    final foreground = isError
        ? const Color(0xFFB91C1C)
        : const Color(0xFF047857);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }

  Widget _tag(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _choiceWrap({
    required List<String> values,
    required String selected,
    required String Function(String value) labelBuilder,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return ChoiceChip(
          label: Text(labelBuilder(value)),
          selected: selected == value,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$secs';
    }
    return '$minutes:$secs';
  }

  String _titleCase(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
