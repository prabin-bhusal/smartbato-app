import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import '../../practice_by_topics/models/practice_topics_models.dart';

class SkillTreeVisualizationPage extends StatefulWidget {
  const SkillTreeVisualizationPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<SkillTreeVisualizationPage> createState() =>
      _SkillTreeVisualizationPageState();
}

class _SkillTreeVisualizationPageState
    extends State<SkillTreeVisualizationPage> {
  late Future<PracticeTopicsMap> _future;

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
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skill Tree Visualization')),
      body: FutureBuilder<PracticeTopicsMap>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry: _refresh,
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return _ErrorState(
              message: 'Unable to load syllabus skill tree.',
              onRetry: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: AppPageShell(
              maxWidth: 1080,
              children: [
                _Hero(
                  feature: data.feature,
                  subjectCount: data.subjects.length,
                ),
                const SizedBox(height: 12),
                const _Legend(),
                const SizedBox(height: 12),
                if (data.subjects.isEmpty)
                  const AppSurfaceCard(
                    child: Text(
                      'No syllabus topics found for your active course.',
                    ),
                  )
                else
                  ...data.subjects.map(
                    (subject) => _SubjectTreeCard(subject: subject),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.feature, required this.subjectCount});

  final PracticeTopicsFeature feature;
  final int subjectCount;

  @override
  Widget build(BuildContext context) {
    final statusText = feature.isUnlocked ? 'Unlocked' : 'Locked';

    return AppHeroBanner(
      title: 'Course Skill Tree',
      subtitle:
          'Visual topic-map of your selected course syllabus with progression order and mastery status.',
      icon: Icons.account_tree_rounded,
      colors: const [Color(0xFF0F766E), Color(0xFF1D4ED8)],
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip('Subjects', '$subjectCount'),
          _chip('Status', statusText),
          _chip('Coins', '${feature.userCoins}'),
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
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const [
          _LegendPill(
            text: 'Completed',
            background: Color(0xFFDCFCE7),
            foreground: Color(0xFF166534),
            icon: Icons.check_circle_rounded,
          ),
          _LegendPill(
            text: 'Unlocked',
            background: Color(0xFFDBEAFE),
            foreground: Color(0xFF1E40AF),
            icon: Icons.lock_open_rounded,
          ),
          _LegendPill(
            text: 'Locked',
            background: Color(0xFFF1F5F9),
            foreground: Color(0xFF475569),
            icon: Icons.lock_rounded,
          ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({
    required this.text,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SubjectTreeCard extends StatelessWidget {
  const _SubjectTreeCard({required this.subject});

  final PracticeTopicSubject subject;

  @override
  Widget build(BuildContext context) {
    final groups = subject.topicGroups
        .where((group) => group.topics.isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurfaceCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          title: Text(
            subject.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'Mastered ${subject.masteredQuestions}/${subject.availableQuestions} questions',
          ),
          initiallyExpanded: true,
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          children: [
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No topic groups available.'),
                ),
              )
            else
              ...groups.map((group) => _TopicGroupTree(group: group)),
          ],
        ),
      ),
    );
  }
}

class _TopicGroupTree extends StatelessWidget {
  const _TopicGroupTree({required this.group});

  final PracticeTopicGroup group;

  @override
  Widget build(BuildContext context) {
    final sortedTopics = [...group.topics]
      ..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < sortedTopics.length; i++) ...[
                  _TopicNodeCard(topic: sortedTopics[i]),
                  if (i < sortedTopics.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 28,
                        left: 6,
                        right: 6,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.blueGrey.shade300,
                        size: 20,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicNodeCard extends StatelessWidget {
  const _TopicNodeCard({required this.topic});

  final PracticeTopicNode topic;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(topic);

    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: style.badgeBackground,
                child: Text(
                  '${topic.sequenceOrder}',
                  style: TextStyle(
                    color: style.badgeForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  topic.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${topic.masteredQuestions}/${topic.availableQuestions} mastered • ${topic.attemptedQuestions} attempted',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (topic.progress.clamp(0, 100)) / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(style.progress),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Progress ${topic.progress.toStringAsFixed(1)}% • Streak ${topic.streak}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(style.icon, size: 15, color: style.badgeForeground),
              const SizedBox(width: 5),
              Text(
                style.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: style.badgeForeground,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _TopicVisualStyle _styleFor(PracticeTopicNode node) {
    if (node.isCompleted) {
      return const _TopicVisualStyle(
        background: Color(0xFFECFDF5),
        border: Color(0xFFA7F3D0),
        badgeBackground: Color(0xFFBBF7D0),
        badgeForeground: Color(0xFF166534),
        progress: Color(0xFF16A34A),
        icon: Icons.check_circle_rounded,
        label: 'Completed',
      );
    }

    if (node.isUnlocked) {
      return const _TopicVisualStyle(
        background: Color(0xFFEFF6FF),
        border: Color(0xFFBFDBFE),
        badgeBackground: Color(0xFFDBEAFE),
        badgeForeground: Color(0xFF1E40AF),
        progress: Color(0xFF2563EB),
        icon: Icons.lock_open_rounded,
        label: 'Unlocked',
      );
    }

    return const _TopicVisualStyle(
      background: Color(0xFFF8FAFC),
      border: Color(0xFFE2E8F0),
      badgeBackground: Color(0xFFE2E8F0),
      badgeForeground: Color(0xFF475569),
      progress: Color(0xFF94A3B8),
      icon: Icons.lock_rounded,
      label: 'Locked',
    );
  }
}

class _TopicVisualStyle {
  const _TopicVisualStyle({
    required this.background,
    required this.border,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.progress,
    required this.icon,
    required this.label,
  });

  final Color background;
  final Color border;
  final Color badgeBackground;
  final Color badgeForeground;
  final Color progress;
  final IconData icon;
  final String label;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
