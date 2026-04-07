import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../time_attack/pages/time_attack_page.dart';
import 'skill_tree_visualization_page.dart';
import '../models/analytics_data.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late Future<AnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.authController.loadAnalyticsData();
  }

  Future<void> _refresh() async {
    final next = widget.authController.loadAnalyticsData();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyticsData>(
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
            message: 'No analytics data found.',
            onRetry: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderSection(data: data),
                const SizedBox(height: 16),
                const _SectionLabel(
                  title: 'Key Metrics',
                  subtitle: 'Your most important performance numbers',
                  accent: Color(0xFF2563EB),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 126,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.kpis.length,
                    itemBuilder: (context, index) {
                      final kpi = data.kpis[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == data.kpis.length - 1 ? 0 : 10,
                        ),
                        child: _KpiCard(kpi: kpi, index: index),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionLabel(
                  title: 'Mock Test Performance',
                  subtitle: 'Score trend across your submitted tests',
                  accent: Color(0xFF6366F1),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Mock Test Score Timeline',
                  subtitle: 'Your score progression across all tests',
                  gradientColors: const [Color(0xFF6366F1), Color(0xFF7C3AED)],
                  child: _TimelineCard(points: data.charts.scoresOverTime),
                ),
                const SizedBox(height: 12),
                const _SectionLabel(
                  title: 'Answer Breakdown',
                  subtitle: 'Correct, incorrect and unattempted distribution',
                  accent: Color(0xFFEC4899),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Answer Breakdown',
                  subtitle: 'All mock test answers combined',
                  gradientColors: const [Color(0xFFEC4899), Color(0xFFE11D48)],
                  child: _AnswerBreakdownCard(
                    answer: data.charts.answerBreakdown,
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionLabel(
                  title: 'Subject Performance',
                  subtitle: 'Score and coverage by subject',
                  accent: Color(0xFF14B8A6),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Subject Performance Overview',
                  subtitle: 'Score and coverage % per subject',
                  gradientColors: const [Color(0xFF14B8A6), Color(0xFF0891B2)],
                  child: _SubjectOverviewCard(
                    scores: data.charts.subjectScores,
                    coverage: data.charts.subjectCoverage,
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionLabel(
                  title: 'Syllabus Deep Dive',
                  subtitle: 'Topic-level performance per subject',
                  accent: Color(0xFF0EA5E9),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Skill Tree / Topic Map',
                  subtitle: 'Open your course-wise syllabus progression map',
                  gradientColors: const [Color(0xFF0284C7), Color(0xFF0F766E)],
                  child: _TopicMapCta(
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SkillTreeVisualizationPage(
                            authController: widget.authController,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  title: 'Time Attack Mode',
                  subtitle: '1-minute sprint mode with leaderboard ranking',
                  gradientColors: const [Color(0xFF0F766E), Color(0xFF1D4ED8)],
                  child: _TimeAttackCta(
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TimeAttackPage(
                            authController: widget.authController,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                ...data.subjectData.map(
                  (subject) => _SubjectCard(subject: subject),
                ),
                const SizedBox(height: 12),
                const _SectionLabel(
                  title: 'Smart Recommendations',
                  subtitle: 'Prioritized actions from your recent trends',
                  accent: Color(0xFFE11D48),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Smart Recommendations',
                  subtitle: 'Study plan based on your performance data',
                  gradientColors: const [Color(0xFFE11D48), Color(0xFFDB2777)],
                  child: _RecommendationSection(
                    recommendations: data.recommendations,
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionLabel(
                  title: 'AI Weakness Solutions',
                  subtitle:
                      'Focused fixes for your weakest and least-practiced topics',
                  accent: Color(0xFF7C3AED),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Weakness Fix Plan',
                  subtitle: 'What to fix first and how to improve quickly',
                  gradientColors: const [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  child: _WeaknessSolutionsSection(
                    recommendations: data.recommendations,
                  ),
                ),
                if (data.strongTopics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionLabel(
                    title: 'Strong Topics',
                    subtitle: 'Areas where your mastery is consistently high',
                    accent: Color(0xFF10B981),
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: 'Your Strong Topics',
                    subtitle: "Topics where you're performing well",
                    gradientColors: const [
                      Color(0xFF10B981),
                      Color(0xFF16A34A),
                    ],
                    child: _StrongTopicsSection(topics: data.strongTopics),
                  ),
                ],
                if (data.mockBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionLabel(
                    title: 'Mock Test History',
                    subtitle: 'Detailed result history per attempt',
                    accent: Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    title: 'Mock Test History',
                    subtitle: 'Detailed breakdown of every test you took',
                    gradientColors: const [
                      Color(0xFF2563EB),
                      Color(0xFF0891B2),
                    ],
                    childPadding: EdgeInsets.zero,
                    child: _MockHistorySection(items: data.mockBreakdown),
                  ),
                ],
                const SizedBox(height: 12),
                const _SectionLabel(
                  title: 'Live Tests',
                  subtitle: 'Recent published live exams and their status',
                  accent: Color(0xFFF97316),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Live Tests',
                  subtitle: 'Recently published competitive live tests',
                  gradientColors: const [Color(0xFFF97316), Color(0xFFF59E0B)],
                  child: _LiveTestsSection(items: data.liveTests),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.data});

  final AnalyticsData data;

  @override
  Widget build(BuildContext context) {
    final score = data.grade.overallScore.clamp(0, 100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Analytics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Course: ${data.course.name}',
            style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  child: Icon(_gradeIcon(data.grade.icon), color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.grade.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: score / 100,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${score.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<List<Color>> _kpiGradients = [
  [Color(0xFF3B82F6), Color(0xFF2563EB)], // Mock Tests
  [Color(0xFF6366F1), Color(0xFF7C3AED)], // Avg Score
  [Color(0xFF10B981), Color(0xFF0D9488)], // Questions Done
  [Color(0xFF22C55E), Color(0xFF059669)], // Mastered
  [Color(0xFF06B6D4), Color(0xFF0284C7)], // Mock Correct
  [Color(0xFF94A3B8), Color(0xFF6B7280)], // Unattempted
  [Color(0xFFFB7185), Color(0xFFE11D48)], // Live Tests
  [Color(0xFFFBBF24), Color(0xFFF97316)], // Avg Time/Q
  [Color(0xFFF43F5E), Color(0xFFDC2626)], // Topics Not Done
];

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi, required this.index});

  final AnalyticsKpi kpi;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = index < _kpiGradients.length
        ? _kpiGradients[index]
        : _kpiGradients[0];
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFromText(kpi.icon), color: Colors.white, size: 22),
          const SizedBox(height: 8),
          Text(
            kpi.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kpi.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kpi.sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.points});

  final List<AnalyticsScorePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'No mock test data yet',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: points.length,
          separatorBuilder: (_, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final point = points[index];
            return Container(
              width: 138,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.date,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${point.score.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    point.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnswerBreakdownCard extends StatelessWidget {
  const _AnswerBreakdownCard({required this.answer});

  final AnalyticsAnswerBreakdown answer;

  @override
  Widget build(BuildContext context) {
    final total = answer.correct + answer.incorrect + answer.unattempted;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _metricBar('Correct', answer.correct, total, const Color(0xFF10B981)),
          const SizedBox(height: 10),
          _metricBar(
            'Incorrect',
            answer.incorrect,
            total,
            const Color(0xFFEF4444),
          ),
          const SizedBox(height: 10),
          _metricBar(
            'Unattempted',
            answer.unattempted,
            total,
            const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  Widget _metricBar(String label, int value, int total, Color color) {
    final pct = total > 0 ? (value / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              '$value (${(pct * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SubjectOverviewCard extends StatelessWidget {
  const _SubjectOverviewCard({required this.scores, required this.coverage});

  final List<AnalyticsSubjectScore> scores;
  final List<AnalyticsSubjectCoverage> coverage;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'No subject performance data yet',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: scores.map((score) {
          final cov = coverage.firstWhere(
            (item) => item.subjectName == score.subjectName,
            orElse: () =>
                const AnalyticsSubjectCoverage(subjectName: '', coveragePct: 0),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.subjectName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _bar(
                        'Score',
                        score.score,
                        const Color(0xFF0EA5E9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _bar(
                        'Coverage',
                        cov.coveragePct,
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bar(String label, double value, Color color) {
    final clamped = value.clamp(0, 100) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${value.toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 7,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final AnalyticsSubjectData subject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration(),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Text(
          subject.subjectName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Score ${subject.performanceScore.toStringAsFixed(1)}% • ${subject.marks} marks',
          style: const TextStyle(fontSize: 12),
        ),
        children: subject.topicGroups
            .map(
              (topic) => Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            topic.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: topic.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Marks ${topic.marks} • Q ${topic.totalQuestions} • Practiced ${topic.practicedCount} • Mastered ${topic.clearedCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _tinyBar(
                            'Coverage',
                            topic.coveragePct,
                            const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _tinyBar(
                            'Mastery',
                            topic.masteryPct,
                            const Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _tinyBar(
                            'Mock',
                            topic.mockAccuracy,
                            const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _tinyBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${value.toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (value.clamp(0, 100)) / 100,
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _TopicMapCta extends StatelessWidget {
  const _TopicMapCta({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visualize your topic unlock path and jump directly into the course syllabus map tailored to your selected course.',
          style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.account_tree_rounded),
            label: const Text('Open Skill Tree / Topic Map'),
          ),
        ),
      ],
    );
  }
}

class _TimeAttackCta extends StatelessWidget {
  const _TimeAttackCta({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start a 60-second speed run, attempt as many questions as possible, and improve your global rank.',
          style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.timer_rounded),
            label: const Text('Open Time Attack'),
          ),
        ),
      ],
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({required this.recommendations});

  final List<AnalyticsRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Great job! No weak areas detected yet.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Column(
      children: recommendations
          .map(
            (rec) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: rec.type == 'weak'
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: rec.type == 'weak'
                      ? const Color(0xFFFECACA)
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.topic,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rec.subject} • ${rec.marks} marks',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rec.reason,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Action: ${rec.action}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _WeaknessSolutionsSection extends StatelessWidget {
  const _WeaknessSolutionsSection({required this.recommendations});

  final List<AnalyticsRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    final prioritized = [...recommendations]
      ..sort(
        (a, b) => _priorityForType(a.type).compareTo(_priorityForType(b.type)),
      );
    final focused = prioritized.take(4).toList();

    if (focused.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No active weak areas yet. Keep attempting daily challenges to generate AI solutions.',
            style: TextStyle(color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: focused
          .map(
            (rec) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bgForType(rec.type),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderForType(rec.type)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _iconForType(rec.type),
                        size: 18,
                        color: _fgForType(rec.type),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec.topic,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${rec.subject} • ${rec.marks} marks • Score ${rec.score.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Problem: ${rec.reason}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI Solution: ${_solutionFor(rec)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _pill(
                    rec.action.isEmpty
                        ? _defaultNextStep(rec.type)
                        : 'Next Step: ${rec.action}',
                    const Color(0xFFE2E8F0),
                    const Color(0xFF334155),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  int _priorityForType(String type) {
    if (type == 'weak') {
      return 0;
    }
    if (type == 'unpracticed') {
      return 1;
    }
    return 2;
  }

  String _solutionFor(AnalyticsRecommendation rec) {
    if (rec.type == 'weak') {
      return 'Attempt 15-20 focused MCQs in this topic, then review every wrong answer and reattempt tomorrow.';
    }
    if (rec.type == 'unpracticed') {
      return 'Start with concept-level basics, then solve one short practice set to build initial confidence.';
    }
    return 'Maintain performance with one quick revision set and move to higher-weight weak areas.';
  }

  String _defaultNextStep(String type) {
    if (type == 'weak') {
      return 'Next Step: Open Practice by Topics and target this chapter now';
    }
    if (type == 'unpracticed') {
      return 'Next Step: Start first attempt in this chapter today';
    }
    return 'Next Step: Quick revision with 5 mixed questions';
  }

  IconData _iconForType(String type) {
    if (type == 'weak') {
      return Icons.priority_high_rounded;
    }
    if (type == 'unpracticed') {
      return Icons.play_circle_fill_rounded;
    }
    return Icons.trending_up_rounded;
  }

  Color _bgForType(String type) {
    if (type == 'weak') {
      return const Color(0xFFFEE2E2);
    }
    if (type == 'unpracticed') {
      return const Color(0xFFFFF7ED);
    }
    return const Color(0xFFEFF6FF);
  }

  Color _borderForType(String type) {
    if (type == 'weak') {
      return const Color(0xFFFCA5A5);
    }
    if (type == 'unpracticed') {
      return const Color(0xFFFCD34D);
    }
    return const Color(0xFF93C5FD);
  }

  Color _fgForType(String type) {
    if (type == 'weak') {
      return const Color(0xFFB91C1C);
    }
    if (type == 'unpracticed') {
      return const Color(0xFFB45309);
    }
    return const Color(0xFF1D4ED8);
  }
}

class _StrongTopicsSection extends StatelessWidget {
  const _StrongTopicsSection({required this.topics});

  final List<AnalyticsTopic> topics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: topics
          .map(
            (topic) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFBBF7D0),
                    child: Icon(
                      Icons.check_rounded,
                      color: Color(0xFF166534),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${topic.subjectName ?? '-'} · ${topic.marks} marks',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _pill(
                              'Score ${topic.performanceScore.toStringAsFixed(1)}%',
                              const Color(0xFFBBF7D0),
                              const Color(0xFF166534),
                            ),
                            const SizedBox(width: 4),
                            _pill(
                              '${topic.masteryPct.toStringAsFixed(0)}% mastered',
                              const Color(0xFFDBEAFE),
                              const Color(0xFF1E40AF),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MockHistorySection extends StatelessWidget {
  const _MockHistorySection({required this.items});

  final List<AnalyticsMockBreakdown> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final score = entry.value.score;
        final scoreColor = score >= 60
            ? const Color(0xFF166534)
            : score >= 40
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
        final scoreBg = score >= 60
            ? const Color(0xFFDCFCE7)
            : score >= 40
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFDBEAFE),
            child: Text(
              '${entry.key + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          title: Text(entry.value.name),
          subtitle: Text(
            '${entry.value.date} · ${entry.value.timeMin.toStringAsFixed(1)} min',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scoreBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${score.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: scoreColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LiveTestsSection extends StatelessWidget {
  const _LiveTestsSection({required this.items});

  final List<AnalyticsLiveTest> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No published live tests for your course yet.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Column(
      children: items
          .map(
            (item) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _LiveStatusBadge(status: item.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Starts: ${_fmtDateTime(item.startsAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    'Ends: ${_fmtDateTime(item.endsAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    'Duration: ${item.durationMinutes} min • Questions: ${item.requiredQuestions}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 34,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.child,
    this.childPadding = const EdgeInsets.all(14),
  });

  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Widget child;
  final EdgeInsets childPadding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Padding(padding: childPadding, child: child),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final data = switch (status) {
      'strong' => (const Color(0xFFDCFCE7), const Color(0xFF166534), 'Strong'),
      'average' => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        'Average',
      ),
      'weak' => (const Color(0xFFFEE2E2), const Color(0xFF991B1B), 'Weak'),
      _ => (const Color(0xFFE2E8F0), const Color(0xFF475569), 'Not Started'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: data.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        data.$3,
        style: TextStyle(
          fontSize: 11,
          color: data.$2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LiveStatusBadge extends StatelessWidget {
  const _LiveStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final data = switch (status) {
      'live' => (const Color(0xFFDCFCE7), const Color(0xFF166534), 'Live Now'),
      'upcoming' => (
        const Color(0xFFDBEAFE),
        const Color(0xFF1E40AF),
        'Upcoming',
      ),
      _ => (const Color(0xFFE2E8F0), const Color(0xFF475569), 'Ended'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: data.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        data.$3,
        style: TextStyle(
          fontSize: 11,
          color: data.$2,
          fontWeight: FontWeight.w700,
        ),
      ),
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

Widget _pill(String text, Color bg, Color fg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w700),
    ),
  );
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE2E8F0)),
  );
}

IconData _iconFromText(String value) {
  return switch (value) {
    'description' => Icons.description_rounded,
    'show_chart' => Icons.show_chart_rounded,
    'quiz' => Icons.quiz_rounded,
    'track_changes' => Icons.track_changes_rounded,
    'check_circle' => Icons.check_circle_rounded,
    'skip_next' => Icons.skip_next_rounded,
    'schedule' => Icons.schedule_rounded,
    'warning' => Icons.warning_rounded,
    _ => Icons.insights_rounded,
  };
}

IconData _gradeIcon(String value) {
  return switch (value) {
    'trophy' => Icons.emoji_events_rounded,
    'thumb_up' => Icons.thumb_up_alt_rounded,
    'trending_up' => Icons.trending_up_rounded,
    'fitness_center' => Icons.fitness_center_rounded,
    'rocket_launch' => Icons.rocket_launch_rounded,
    _ => Icons.star_rounded,
  };
}

String _fmtDateTime(DateTime? date) {
  if (date == null) {
    return '-';
  }

  final m = _monthShort(date.month);
  final d = date.day.toString().padLeft(2, '0');
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$m $d, ${date.year} $h:$min';
}

String _monthShort(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  if (month < 1 || month > 12) {
    return 'N/A';
  }

  return months[month - 1];
}
