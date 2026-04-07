import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../../core/theme/app_snackbar.dart';
import '../../auth/auth_controller.dart';
import '../models/practice_topics_models.dart';
import 'practice_topic_session_page.dart';

class PracticeByTopicsPage extends StatefulWidget {
  const PracticeByTopicsPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<PracticeByTopicsPage> createState() => _PracticeByTopicsPageState();
}

class _PracticeByTopicsPageState extends State<PracticeByTopicsPage> {
  late Future<PracticeTopicsMap> _future;
  bool _unlocking = false;
  final Map<int, GlobalKey> _guidedItemKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _future = widget.authController.loadPracticeTopicsMap();
  }

  Future<void> _refresh() async {
    final next = widget.authController.loadPracticeTopicsMap();
    setState(() {
      _future = next;
    });

    await Future.wait([next, widget.authController.refreshCurrentUser()]);
  }

  Future<void> _unlockFeature() async {
    setState(() {
      _unlocking = true;
    });

    try {
      final message = await widget.authController.unlockPracticeTopicsFeature();
      if (mounted) {
        AppSnackbar.success(context, message);
      }
      await _refresh();
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
          _unlocking = false;
        });
      }
    }
  }

  Future<void> _openTopic(PracticeTopicNode topic) async {
    // Allow practice if EITHER progression-unlocked OR coin-unlocked
    if (!topic.isUnlocked && !topic.isTopicLevelUnlocked) {
      AppSnackbar.warning(
        context,
        'This level is locked. Optional instant unlock is available with coins.',
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeTopicSessionPage(
          authController: widget.authController,
          topic: topic,
        ),
      ),
    );

    if (mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PracticeTopicsMap>(
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

        final data = snapshot.data;
        if (data == null) {
          return _ErrorState(
            message: 'No practice map found.',
            onRetry: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: AppPageShell(
            maxWidth: 900,
            children: [
              _hero(data.feature),
              const SizedBox(height: 12),
              _summaryStrip(data),
              const SizedBox(height: 12),
              if (data.feature.unlockRequired)
                _unlockCard(data.feature)
              else if (data.subjects.isEmpty)
                _emptyCard()
              else
                ...data.subjects.map(_subjectCard),
            ],
          ),
        );
      },
    );
  }

  Widget _hero(PracticeTopicsFeature feature) {
    final chips = <Widget>[
      _chip('Coins', feature.userCoins.toString()),
      if (!feature.isUnlocked)
        _chip('Unlock cost', '${feature.unlockCost} coins'),
      if (!feature.isUnlocked) _chip('Status', 'Locked'),
    ];

    return AppHeroBanner(
      title: 'Practice By Topics',
      subtitle:
          'Follow a clear syllabus path with gentle progression, quick feedback, and optional coin unlocks.',
      icon: Icons.topic,
      colors: const [Color(0xFF0F766E), Color(0xFF2563EB)],
      trailing: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _summaryStrip(PracticeTopicsMap data) {
    final totalSubjects = data.subjects.length;
    final totalTopics = data.subjects.fold<int>(
      0,
      (sum, subject) =>
          sum +
          subject.topicGroups.fold<int>(
            0,
            (count, group) => count + group.topics.length,
          ),
    );
    final masteredTopics = data.subjects.fold<int>(
      0,
      (sum, subject) =>
          sum +
          subject.topicGroups.fold<int>(
            0,
            (count, group) =>
                count + group.topics.where((topic) => topic.isCompleted).length,
          ),
    );

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _miniStat(
              'Subjects',
              totalSubjects.toString(),
              Icons.menu_book_rounded,
              const Color(0xFFDBEAFE),
              const Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniStat(
              'Topics',
              totalTopics.toString(),
              Icons.topic_rounded,
              const Color(0xFFD1FAE5),
              const Color(0xFF0F766E),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniStat(
              'Mastered',
              '$masteredTopics/$totalTopics',
              Icons.emoji_events_rounded,
              const Color(0xFFFEF3C7),
              const Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    String label,
    String value,
    IconData icon,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.82),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      side: BorderSide(color: const Color(0xFF0F172A).withValues(alpha: 0.16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: const Color(0xFF0F172A),
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  Widget _unlockCard(PracticeTopicsFeature feature) {
    final enoughCoins = feature.userCoins >= feature.unlockCost;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlock Practice Trail',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'One-time cost: ${feature.unlockCost} coins. Your balance: ${feature.userCoins}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFB45309),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enoughCoins && !_unlocking ? _unlockFeature : null,
              icon: _unlocking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_open_rounded),
              label: Text(enoughCoins ? 'Unlock now' : 'Insufficient coins'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return const AppSurfaceCard(
      padding: EdgeInsets.all(16),
      child: Text('No topics found for your active course.'),
    );
  }

  Widget _subjectCard(PracticeTopicSubject subject) {
    final masteryPercent = subject.availableQuestions == 0
        ? 0.0
        : (subject.masteredQuestions / subject.availableQuestions).clamp(
            0.0,
            1.0,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurfaceCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          initiallyExpanded: true,
          onExpansionChanged: (expanded) {
            if (!expanded) {
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _focusGuidedTopicInSubject(subject);
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            subject.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          subtitle: Text(
            '${subject.masteredQuestions}/${subject.availableQuestions} mastered • ${(masteryPercent * 100).toStringAsFixed(0)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.expand_less_rounded,
              color: Color(0xFF2563EB),
              size: 18,
            ),
          ),
          children: subject.topicGroups.map(_groupSection).toList(),
        ),
      ),
    );
  }

  Widget _groupSection(PracticeTopicGroup group) {
    final topics = group.topics;
    final guidedTopicId = _guidedTopicId(topics);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                group.name,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...topics.asMap().entries.map((entry) {
            return _pathItem(
              topic: entry.value,
              index: entry.key,
              total: topics.length,
              isGuided: entry.value.id == guidedTopicId,
              guidedKey: entry.value.id == guidedTopicId
                  ? _guidedKeyForTopic(entry.value.id)
                  : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _pathItem({
    required PracticeTopicNode topic,
    required int index,
    required int total,
    required bool isGuided,
    GlobalKey? guidedKey,
  }) {
    final canPractice = _canPracticeTopic(topic);
    final canUnlock = _canUnlockTopic(topic);
    final isCompleted = topic.isCompleted;

    final markerBackground = isCompleted
        ? const Color(0xFFDCFCE7)
        : canPractice
        ? const Color(0xFFDBEAFE)
        : const Color(0xFFF1F5F9);
    final markerForeground = isCompleted
        ? const Color(0xFF166534)
        : canPractice
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF64748B);
    final connectorColor = isCompleted
        ? const Color(0xFF86EFAC)
        : canPractice
        ? const Color(0xFFBFDBFE)
        : const Color(0xFFE2E8F0);

    return Padding(
      key: guidedKey,
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2,
                  height: 10,
                  color: index == 0 ? Colors.transparent : connectorColor,
                ),
                Container(
                  width: 24,
                  height: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isGuided)
                        _PulseHalo(color: markerForeground, size: 24),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: markerBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: markerForeground.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check_rounded
                              : canPractice
                              ? Icons.play_arrow_rounded
                              : Icons.lock_outline_rounded,
                          color: markerForeground,
                          size: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 10,
                  color: index == total - 1
                      ? Colors.transparent
                      : connectorColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: canUnlock
                ? _lockedTopicCard(topic)
                : _topicCard(topic, canPractice, isGuided),
          ),
        ],
      ),
    );
  }

  Widget _lockedTopicCard(PracticeTopicNode topic) {
    final enoughCoins =
        (widget.authController.user?.coins ?? 0) >= topic.topicUnlockCost;
    final missingCoins = enoughCoins
        ? 0
        : topic.topicUnlockCost - (widget.authController.user?.coins ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1C84C)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7CC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Color(0xFFB45309),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level ${topic.sequenceOrder}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  topic.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C2D12),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: Color(0xFFB45309),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Optional instant unlock: ${topic.topicUnlockCost} coins',
                        style: const TextStyle(
                          fontSize: 10.8,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: enoughCoins && !_unlocking
                ? () => _unlockTopic(topic)
                : null,
            icon: _unlocking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_open_rounded, size: 16),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 38),
            ),
            label: Text(
              enoughCoins ? 'Unlock' : 'Need $missingCoins more',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topicCard(PracticeTopicNode topic, bool canPractice, bool isGuided) {
    final progress = (topic.progress / 100).clamp(0.0, 1.0);
    final background = canPractice
        ? const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canPractice ? () => _openTopic(topic) : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canPractice
                  ? const Color(0xFFBFDBFE)
                  : const Color(0xFFD6DEE8),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: topic.isCompleted
                          ? const Color(0xFFDCFCE7)
                          : canPractice
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      topic.isCompleted
                          ? Icons.check_rounded
                          : canPractice
                          ? Icons.play_arrow_rounded
                          : Icons.lock_rounded,
                      color: topic.isCompleted
                          ? const Color(0xFF166534)
                          : canPractice
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level ${topic.sequenceOrder}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          topic.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: canPractice
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    canPractice
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.lock_outline_rounded,
                    size: 13,
                    color: canPractice
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF94A3B8),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    topic.isCompleted
                        ? const Color(0xFF16A34A)
                        : canPractice
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isGuided && canPractice)
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _openTopic(topic),
                      child: _statusChip(
                        'Continue here',
                        const Color(0xFFE0F2FE),
                        const Color(0xFF0C4A6E),
                      ),
                    ),
                  _statusChip(
                    topic.isCompleted
                        ? 'Completed'
                        : canPractice
                        ? 'Ready to practice'
                        : 'Locked',
                    topic.isCompleted
                        ? const Color(0xFFDCFCE7)
                        : canPractice
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFE2E8F0),
                    topic.isCompleted
                        ? const Color(0xFF166534)
                        : canPractice
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF475569),
                  ),
                  Text(
                    '${topic.progress.toStringAsFixed(0)}% mastery',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'streak ${topic.streak}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  bool _canPracticeTopic(PracticeTopicNode topic) {
    if (topic.sequenceOrder == 1) {
      return true;
    }

    return topic.isUnlocked || topic.isTopicLevelUnlocked;
  }

  bool _canUnlockTopic(PracticeTopicNode topic) {
    if (topic.sequenceOrder == 1) {
      return false;
    }

    return !topic.isTopicLevelUnlocked && !topic.isUnlocked;
  }

  Future<void> _unlockTopic(PracticeTopicNode topic) async {
    setState(() {
      _unlocking = true;
    });

    try {
      final message = await widget.authController.unlockPracticeTopicLevel(
        topic.id,
      );
      if (mounted) {
        AppSnackbar.success(context, message);
      }
      await _refresh();
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
          _unlocking = false;
        });
      }
    }
  }

  GlobalKey _guidedKeyForTopic(int topicId) {
    return _guidedItemKeys.putIfAbsent(topicId, GlobalKey.new);
  }

  void _focusGuidedTopicInSubject(PracticeTopicSubject subject) {
    for (final group in subject.topicGroups) {
      final guidedTopicId = _guidedTopicId(group.topics);
      if (guidedTopicId == null) {
        continue;
      }
      final key = _guidedItemKeys[guidedTopicId];
      final guidedContext = key?.currentContext;
      if (guidedContext == null) {
        continue;
      }

      Scrollable.ensureVisible(
        guidedContext,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
      return;
    }
  }

  int? _guidedTopicId(List<PracticeTopicNode> topics) {
    for (final topic in topics) {
      if (_canPracticeTopic(topic) && !topic.isCompleted) {
        return topic.id;
      }
    }

    for (final topic in topics) {
      if (_canPracticeTopic(topic)) {
        return topic.id;
      }
    }

    return null;
  }
}

class _PulseHalo extends StatefulWidget {
  const _PulseHalo({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<_PulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.22,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: _opacity.value),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
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
