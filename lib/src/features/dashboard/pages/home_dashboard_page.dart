import 'package:flutter/material.dart';
import 'dart:async';

import '../../auth/auth_controller.dart';
import '../../content/models/content_models.dart';
import '../../live_tests/pages/live_test_exam_page.dart';
import '../../mock_tests/pages/mock_test_exam_page.dart';
import '../../mock_tests/pages/mock_test_result_page.dart';
import '../../practice_by_topics/models/practice_topics_models.dart';
import '../../practice_by_topics/pages/practice_topic_session_page.dart';
import '../../../core/navigation/app_route_observer.dart';
import '../models/dashboard_home_data.dart';
import '../student_dashboard_screen.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({
    super.key,
    required this.authController,
    required this.onOpenTab,
  });

  final AuthController authController;
  final ValueChanged<DashboardTab> onOpenTab;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> with RouteAware {
  late Future<_HomeBundle> _future;
  Timer? _liveCountdownTicker;
  bool _isRouteSubscribed = false;

  @override
  void initState() {
    super.initState();
    _future = _loadBundle();
    _liveCountdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        // Trigger rebuild for live countdown timer text.
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_isRouteSubscribed && route is PageRoute) {
      appRouteObserver.subscribe(this, route);
      _isRouteSubscribed = true;
    }
  }

  @override
  void dispose() {
    if (_isRouteSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    _liveCountdownTicker?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    _refreshDashboard();
  }

  Future<_HomeBundle> _loadBundle() async {
    Future<void> safeRefreshCurrentUser() async {
      try {
        await widget.authController.refreshCurrentUser();
      } catch (_) {
        // Keep dashboard usable if the user refresh endpoint fails.
      }
    }

    Future<List<ContentListItem>> safeLoad(
      Future<ContentListResponse> Function() loader,
    ) async {
      try {
        final response = await loader();
        return response.items.take(3).toList();
      } catch (_) {
        return const <ContentListItem>[];
      }
    }

    Future<List<ContentListItem>> safeLoadNotices() async {
      try {
        final response = await widget.authController.loadNotices(page: 1);
        return response.items
            .take(3)
            .map(
              (item) => ContentListItem(
                title: item.title,
                slug: item.slug,
                excerpt: item.contentPreview,
                thumbnailUrl: item.thumbnailUrl,
                publishedAt: item.publishedAt,
              ),
            )
            .toList();
      } catch (_) {
        return const <ContentListItem>[];
      }
    }

    final dashboardFuture = widget.authController.loadDashboardHomeData();
    final blogsFuture = safeLoad(
      () => widget.authController.loadBlogs(page: 1),
    );
    final newsFuture = safeLoad(() => widget.authController.loadNews(page: 1));
    final noticesFuture = safeLoadNotices();
    final refreshFuture = safeRefreshCurrentUser();

    final dashboard = await dashboardFuture;
    final blogs = await blogsFuture;
    final news = await newsFuture;
    final notices = await noticesFuture;
    await refreshFuture;

    return _HomeBundle(
      dashboard: dashboard,
      practiceTopicStats: _PracticeTopicStats.fromDashboard(dashboard),
      latestBlogs: blogs,
      latestNews: news,
      latestNotices: notices,
    );
  }

  Future<void> _refreshDashboard() async {
    final next = _loadBundle();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _continueTopicPractice(DashboardContinuePractice item) async {
    try {
      final map = await widget.authController.loadPracticeTopicsMap();
      final topic = _findTopicById(map, item.topicId);

      if (!mounted) return;

      if (topic == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Topic is not available in your current course. Opening topic practice list.',
            ),
          ),
        );
        widget.onOpenTab(DashboardTab.practiceByTopics);
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

      await _refreshDashboard();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _continueMockTest(DashboardContinueMockTest item) async {
    try {
      final begin = await widget.authController.beginMockTest(item.modelSetId);
      if (!mounted) return;

      if (begin.alreadyAttempted) {
        final loaded = await widget.authController.loadMockReport(
          item.modelSetId,
        );
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MockTestResultPage(
              authController: widget.authController,
              report: loaded.report,
            ),
          ),
        );
        await _refreshDashboard();
        return;
      }

      if (begin.session == null ||
          begin.modelSet == null ||
          begin.subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to resume this mock test.')),
        );
        widget.onOpenTab(DashboardTab.mockTests);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MockTestExamPage(
            authController: widget.authController,
            beginData: begin,
          ),
        ),
      );

      await _refreshDashboard();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _continueLiveTest(DashboardContinueLiveTest item) async {
    final now = DateTime.now();
    if (item.endsAt != null && now.isAfter(item.endsAt!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This live test has already ended.')),
      );
      await _refreshDashboard();
      return;
    }

    try {
      final begin = await widget.authController.beginLiveTest(item.liveTestId);
      if (!mounted) return;

      if (begin.alreadyAttempted) {
        final loaded = await widget.authController.loadLiveReport(
          item.liveTestId,
        );
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MockTestResultPage(
              authController: widget.authController,
              report: loaded.report,
              resultTypeLabel: 'Live Test',
              allowPdfDownload: false,
            ),
          ),
        );
        await _refreshDashboard();
        return;
      }

      if (begin.session == null ||
          begin.modelSet == null ||
          begin.subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to resume this live test.')),
        );
        widget.onOpenTab(DashboardTab.liveTest);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LiveTestExamPage(
            authController: widget.authController,
            beginData: begin,
          ),
        ),
      );

      await _refreshDashboard();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  PracticeTopicNode? _findTopicById(PracticeTopicsMap map, int topicId) {
    for (final subject in map.subjects) {
      for (final group in subject.topicGroups) {
        for (final topic in group.topics) {
          if (topic.id == topicId) {
            return topic;
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _DashboardErrorView(
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
            onRetry: _refreshDashboard,
          );
        }

        final bundle = snapshot.data;
        if (bundle == null) {
          return _DashboardErrorView(
            message: 'No dashboard data found.',
            onRetry: _refreshDashboard,
          );
        }

        final data = bundle.dashboard;
        final topicStats =
            bundle.practiceTopicStats ??
            _PracticeTopicStats.fromDashboard(data);

        final user = widget.authController.user;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final sectionCardColumns = width >= 1100
                ? 2
                : width >= 760
                ? 2
                : 1;
            final sectionCardWidth = _itemWidth(width, sectionCardColumns, 10);
            final supportColumns = width >= 1100
                ? 4
                : width >= 780
                ? 2
                : 1;
            final supportCardWidth = _itemWidth(width, supportColumns, 10);

            return RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeHero(studentName: user?.name ?? 'Student'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Topic Boost',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _CourseBadge(label: data.stats.courseName),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 116,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _StatChip(
                            title: 'Topics Practiced',
                            value: '${topicStats.topicsPracticed}',
                            sub: '${topicStats.totalTopics} total topics',
                            icon: Icons.layers_rounded,
                            color: const Color(0xFF0D9488),
                          ),
                          _StatChip(
                            title: 'Questions Attempted',
                            value: '${topicStats.attemptedQuestions}',
                            sub: '${topicStats.totalQuestions} available',
                            icon: Icons.quiz_rounded,
                            color: const Color(0xFF7C3AED),
                          ),
                          _StatChip(
                            title: 'Questions Mastered',
                            value: '${topicStats.masteredQuestions}',
                            sub:
                                '${topicStats.completedTopics} completed topics',
                            icon: Icons.track_changes_rounded,
                            color: const Color(0xFF059669),
                          ),
                          _StatChip(
                            title: 'Avg Progress',
                            value: _fmtPercent(topicStats.averageProgress),
                            sub: '${topicStats.bestStreak} best streak',
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFFD97706),
                          ),
                        ],
                      ),
                    ),
                    if (data.continuePractice != null ||
                        data.continueMockTest != null ||
                        data.continueLiveTest != null) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel(
                        title: 'Continue Learning',
                        subtitle: 'Resume where you left off',
                        accent: Color(0xFF0F766E),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (data.continuePractice != null)
                            SizedBox(
                              width: sectionCardWidth,
                              child: _resumeCard(
                                title: 'Continue Topic Practice',
                                subtitle: data.continuePractice!.topicName,
                                meta:
                                    data.continuePractice!.lastActivityAt ==
                                        null
                                    ? 'Recent activity'
                                    : 'Last active ${_fmtDate(data.continuePractice!.lastActivityAt)}',
                                icon: Icons.play_lesson_rounded,
                                color: const Color(0xFF2563EB),
                                cta: 'Resume Topic',
                                onTap: () => _continueTopicPractice(
                                  data.continuePractice!,
                                ),
                              ),
                            ),
                          if (data.continueMockTest != null)
                            SizedBox(
                              width: sectionCardWidth,
                              child: _resumeCard(
                                title: 'Continue Mock Test',
                                subtitle: data.continueMockTest!.modelSetName,
                                meta: data.continueMockTest!.expiresAt == null
                                    ? 'Session in progress'
                                    : 'Ends ${_fmtDate(data.continueMockTest!.expiresAt)}',
                                icon: Icons.fact_check_rounded,
                                color: const Color(0xFF7C3AED),
                                cta: 'Resume Mock',
                                onTap: () =>
                                    _continueMockTest(data.continueMockTest!),
                              ),
                            ),
                          if (data.continueLiveTest != null)
                            SizedBox(
                              width: sectionCardWidth,
                              child: _resumeCard(
                                title: 'Continue Live Test',
                                subtitle: data.continueLiveTest!.liveTestName,
                                meta: _liveCountdownMeta(
                                  data.continueLiveTest!,
                                ),
                                icon: Icons.live_tv_rounded,
                                color: const Color(0xFFDC2626),
                                cta: 'Resume Live Test',
                                onTap: () =>
                                    _continueLiveTest(data.continueLiveTest!),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _SectionLabel(
                      title: 'Start Learning',
                      subtitle: 'Choose your learning style',
                      accent: Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: sectionCardWidth,
                          child: _learningCard(
                            title: 'Daily Challenge',
                            description:
                                '10 weakness-based questions every day. Earn 1 coin for every 2 correct answers and build streak consistency.',
                            cta: 'Start Challenge',
                            level: 'Daily',
                            icon: Icons.emoji_events_rounded,
                            color: const Color(0xFFD97706),
                            onTap: () =>
                                widget.onOpenTab(DashboardTab.dailyChallenge),
                          ),
                        ),
                        SizedBox(
                          width: sectionCardWidth,
                          child: _learningCard(
                            title: 'Time Attack',
                            description:
                                '1-minute speed mode. Attempt as many questions as possible and compete on the leaderboard.',
                            cta: 'Start Sprint',
                            level: 'Speed',
                            icon: Icons.timer_rounded,
                            color: const Color(0xFF0F766E),
                            onTap: () =>
                                widget.onOpenTab(DashboardTab.timeAttack),
                          ),
                        ),
                        SizedBox(
                          width: sectionCardWidth,
                          child: _learningCard(
                            title: 'Practice by Topics',
                            description:
                                'Master concepts by practicing individual topics at your own pace. Perfect for building fundamentals.',
                            cta: 'Start Practice',
                            level: 'Beginner',
                            icon: Icons.folder_open_rounded,
                            color: const Color(0xFF2563EB),
                            onTap: () =>
                                widget.onOpenTab(DashboardTab.practiceByTopics),
                          ),
                        ),
                        SizedBox(
                          width: sectionCardWidth,
                          child: _learningCard(
                            title: 'Battle Arena',
                            description:
                                'Enter a 3-minute MCQ battle with performance-based matching and AI fallback when no opponent is found.',
                            cta: 'Start Battle',
                            level: 'Competitive',
                            icon: Icons.sports_martial_arts_rounded,
                            color: const Color(0xFF059669),
                            onTap: () => widget.onOpenTab(DashboardTab.battle),
                          ),
                        ),
                        SizedBox(
                          width: sectionCardWidth,
                          child: _learningCard(
                            title: 'Mock Tests',
                            description:
                                'Take full-length model tests that simulate real exam conditions. Track your progress and identify weak areas.',
                            cta: 'Take Test',
                            level: 'Advanced',
                            icon: Icons.fact_check_rounded,
                            color: const Color(0xFF7C3AED),
                            onTap: () =>
                                widget.onOpenTab(DashboardTab.mockTests),
                          ),
                        ),
                        SizedBox(
                          width: sectionCardWidth,
                          child: _learningCard(
                            title: 'Live Tests',
                            description:
                                'Compete with other students in real-time tests. See live rankings and compare your performance instantly.',
                            cta: 'Join Now',
                            level: 'Live',
                            icon: Icons.live_tv_rounded,
                            color: const Color(0xFFDC2626),
                            onTap: () =>
                                widget.onOpenTab(DashboardTab.liveTest),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _AutoPracticeBanner(
                      onTap: () => widget.onOpenTab(DashboardTab.autoPractice),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(
                      title: 'Your Progress',
                      subtitle: 'Track your learning journey and achievements',
                      accent: Color(0xFF0D9488),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: sectionCardWidth,
                          child: _progressCard(
                            title: 'Performance Analytics',
                            description:
                                'View detailed graphs, charts, and insights about your test performance over time',
                            color: const Color(0xFF0891B2),
                            icon: Icons.bar_chart_rounded,
                            onTap: () =>
                                widget.onOpenTab(DashboardTab.analytics),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(
                      title: 'Resources & Support',
                      subtitle: 'Everything you need to succeed',
                      accent: Color(0xFF7C3AED),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: supportCardWidth,
                          child: _smallSupportCard(
                            'Settings',
                            'Update profile & preferences',
                            Icons.settings_rounded,
                            const Color(0xFF2563EB),
                            () => widget.onOpenTab(DashboardTab.setting),
                          ),
                        ),
                        SizedBox(
                          width: supportCardWidth,
                          child: _smallSupportCard(
                            'Help & Support',
                            'Get help with questions',
                            Icons.support_agent_rounded,
                            const Color(0xFF16A34A),
                            () => widget.onOpenTab(DashboardTab.helpAndSupport),
                          ),
                        ),
                        SizedBox(
                          width: supportCardWidth,
                          child: _smallSupportCard(
                            'Discussion',
                            'Course chat, replies and polls',
                            Icons.forum_rounded,
                            const Color(0xFF9333EA),
                            () => widget.onOpenTab(DashboardTab.discussion),
                          ),
                        ),
                        SizedBox(
                          width: supportCardWidth,
                          child: _smallSupportCard(
                            'Resources',
                            'Study materials',
                            Icons.menu_book_rounded,
                            const Color(0xFFEA580C),
                            () => widget.onOpenTab(DashboardTab.resources),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(
                      title: 'Latest Updates',
                      subtitle: 'Fresh blogs, news and notices for you',
                      accent: Color(0xFFD97706),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: sectionCardWidth,
                          child: _contentPreviewCard(
                            title: 'Blogs',
                            icon: Icons.article_rounded,
                            color: const Color(0xFF2563EB),
                            items: bundle.latestBlogs,
                            onOpenAll: () =>
                                widget.onOpenTab(DashboardTab.blogs),
                          ),
                        ),
                        SizedBox(
                          width: sectionCardWidth,
                          child: _contentPreviewCard(
                            title: 'News',
                            icon: Icons.newspaper_rounded,
                            color: const Color(0xFF0EA5E9),
                            items: bundle.latestNews,
                            onOpenAll: () =>
                                widget.onOpenTab(DashboardTab.news),
                          ),
                        ),
                        SizedBox(
                          width: sectionCardWidth,
                          child: _contentPreviewCard(
                            title: 'Notices',
                            icon: Icons.notifications_rounded,
                            color: const Color(0xFFF59E0B),
                            items: bundle.latestNotices,
                            onOpenAll: () =>
                                widget.onOpenTab(DashboardTab.notice),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel(
                      title: 'Your Recent Tests',
                      subtitle: 'Latest attempts and score snapshots',
                      accent: Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 10),
                    if (data.recentTests.isEmpty)
                      _NoRecentTestsCard()
                    else
                      Column(
                        children: data.recentTests
                            .map(
                              (test) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _recentTestTile(test),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _recentTestTile(DashboardRecentTest test) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFDBEAFE),
            child: Icon(Icons.fact_check_rounded, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  test.modelSetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtDate(test.createdAt)} • ${_toMinutes(test.timeTakenSeconds)}m',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtPercent(test.percentage),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${test.correctAnswers}/${test.totalQuestions} correct',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _learningCard({
    required String title,
    required String description,
    required String cta,
    required String level,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      level,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        cta,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: color),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard({
    required String title,
    required String description,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resumeCard({
    required String title,
    required String subtitle,
    required String meta,
    required IconData icon,
    required Color color,
    required String cta,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  cta,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 18, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _liveCountdownMeta(DashboardContinueLiveTest item) {
    DateTime? target;
    if (item.endsAt != null && item.expiresAt != null) {
      target = item.endsAt!.isBefore(item.expiresAt!)
          ? item.endsAt
          : item.expiresAt;
    } else {
      target = item.endsAt ?? item.expiresAt;
    }

    if (target == null) {
      return 'Live exam in progress';
    }

    final now = DateTime.now();
    final diff = target.difference(now);

    if (diff.inSeconds <= 0) {
      return 'Time is over';
    }

    final hh = diff.inHours;
    final mm = diff.inMinutes.remainder(60);
    final ss = diff.inSeconds.remainder(60);

    final clock =
        '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    return 'Ends in $clock';
  }

  Widget _smallSupportCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentPreviewCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<ContentListItem> items,
    required VoidCallback onOpenAll,
  }) {
    return InkWell(
      onTap: onOpenAll,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(onPressed: onOpenAll, child: const Text('Open')),
              ],
            ),
            const SizedBox(height: 6),
            if (items.isEmpty)
              const Text(
                'No updates yet.',
                style: TextStyle(color: Color(0xFF64748B)),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.excerpt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _fmtPercent(double value) => '${value.toStringAsFixed(1)}%';

  static String _fmtDate(DateTime? dt) {
    if (dt == null) {
      return '-';
    }

    final month = <int, String>{
      1: 'Jan',
      2: 'Feb',
      3: 'Mar',
      4: 'Apr',
      5: 'May',
      6: 'Jun',
      7: 'Jul',
      8: 'Aug',
      9: 'Sep',
      10: 'Oct',
      11: 'Nov',
      12: 'Dec',
    }[dt.month]!;

    return '$month ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
  }

  static int _toMinutes(int seconds) => (seconds / 60).floor();

  static double _itemWidth(double maxWidth, int columns, double spacing) {
    final totalSpacing = spacing * (columns - 1);
    return (maxWidth - totalSpacing).clamp(120, double.infinity) / columns;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _HomeBundle {
  const _HomeBundle({
    required this.dashboard,
    required this.practiceTopicStats,
    required this.latestBlogs,
    required this.latestNews,
    required this.latestNotices,
  });

  final DashboardHomeData dashboard;
  final _PracticeTopicStats? practiceTopicStats;
  final List<ContentListItem> latestBlogs;
  final List<ContentListItem> latestNews;
  final List<ContentListItem> latestNotices;
}

class _PracticeTopicStats {
  const _PracticeTopicStats({
    required this.totalTopics,
    required this.topicsPracticed,
    required this.completedTopics,
    required this.attemptedQuestions,
    required this.masteredQuestions,
    required this.totalQuestions,
    required this.averageProgress,
    required this.bestStreak,
  });

  final int totalTopics;
  final int topicsPracticed;
  final int completedTopics;
  final int attemptedQuestions;
  final int masteredQuestions;
  final int totalQuestions;
  final double averageProgress;
  final int bestStreak;

  factory _PracticeTopicStats.fromDashboard(DashboardHomeData data) {
    return _PracticeTopicStats(
      totalTopics: data.stats.topicsPracticed.count,
      topicsPracticed: data.stats.topicsPracticed.count,
      completedTopics: data.stats.questionsPracticed.clearedCount,
      attemptedQuestions: data.stats.questionsPracticed.count,
      masteredQuestions: data.stats.questionsPracticed.clearedCount,
      totalQuestions: data.stats.questionsPracticed.totalCourseQuestions,
      averageProgress: data.stats.questionsPracticed.coveragePercent.toDouble(),
      bestStreak: 0,
    );
  }
}

class _DashboardErrorView extends StatelessWidget {
  const _DashboardErrorView({required this.message, required this.onRetry});

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
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFB91C1C)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _NoRecentTestsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 38, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text(
            'No Tests Attempted Yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Start taking tests to track your progress and improvement',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CourseBadge extends StatelessWidget {
  const _CourseBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_rounded, color: Color(0xFF1D4ED8), size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.studentName});

  final String studentName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF3730A3)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $studentName! 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Continue your learning journey and ace your exams',
                  style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text('📚', style: TextStyle(fontSize: 44)),
        ],
      ),
    );
  }
}

class _AutoPracticeBanner extends StatelessWidget {
  const _AutoPracticeBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEF4444)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI-Powered Auto Practice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Let our intelligent system adapt to your learning pace. Get personalized questions focused on your weak areas.',
                  style: TextStyle(color: Color(0xFFFFEDD5), fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Start Auto Practice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFEA580C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFFFEDD5),
            size: 42,
          ),
        ],
      ),
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
          height: 36,
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
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
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
