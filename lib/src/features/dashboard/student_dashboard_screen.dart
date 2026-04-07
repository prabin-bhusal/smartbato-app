import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_controller.dart';
import '../auto_practice/pages/auto_practice_page.dart';
import '../battle/pages/battle_page.dart';
import '../battle/pages/battle_questions_page.dart';
import '../content/pages/content_list_page.dart';
import '../content/pages/notices_page.dart';
import '../daily_challenge/pages/daily_challenge_page.dart';
import '../discussion/pages/discussion_page.dart';
import '../help_support/pages/help_and_support_page.dart';
import '../live_tests/pages/live_tests_page.dart';
import '../mock_tests/pages/mock_tests_page.dart';
import '../practice_by_topics/pages/practice_by_topics_page.dart';
import '../profile/pages/profile_page.dart';
import '../resources/pages/resources_page.dart';
import '../settings/pages/settings_page.dart';
import '../time_attack/pages/time_attack_page.dart';
import '../wallet/pages/wallet_page.dart';
import 'models/analytics_data.dart';
import 'pages/analytics_page.dart';
import 'pages/home_dashboard_page.dart';

enum DashboardTab {
  dashboard,
  analytics,
  practiceByTopics,
  mockTests,
  liveTest,
  autoPractice,
  dailyChallenge,
  timeAttack,
  battle,
  blogs,
  news,
  notice,
  resources,
  helpAndSupport,
  discussion,
  wallet,
  setting,
  profile,
}

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key, required this.authController});

  final AuthController authController;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DashboardTab _activeTab = DashboardTab.dashboard;
  bool _checkingLiveGate = false;
  int? _activeGateTestId;
  bool _checkingActiveBattle = false;
  int? _redirectingBattleId;
  bool _checkingDailyChallengePrompt = false;
  bool _dailyChallengePromptShown = false;
  bool _handlingBackPress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.authController.ensureRealtimeConnected();
    _checkAndOpenLiveGate();
    _checkAndResumeBattle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptDailyChallengeIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndOpenLiveGate();
      _checkAndResumeBattle();
      _promptDailyChallengeIfNeeded();
    }
  }

  Future<void> _promptDailyChallengeIfNeeded() async {
    if (!mounted ||
        _checkingDailyChallengePrompt ||
        _dailyChallengePromptShown ||
        _activeTab == DashboardTab.dailyChallenge) {
      return;
    }

    _checkingDailyChallengePrompt = true;
    try {
      final status = await widget.authController.loadDailyChallengeStatus();
      if (!mounted) {
        return;
      }

      final attempt = status.attempt;
      final alreadyCompleted = attempt?.status == 'submitted';

      if (alreadyCompleted) {
        return;
      }

      _dailyChallengePromptShown = true;

      final actionLabel = attempt?.status == 'active'
          ? 'Resume Challenge'
          : 'Start Challenge';
      final isNewToSelectedCourse = _isNewToSelectedCourse();
      final challengeMessage = isNewToSelectedCourse
          ? 'You are new to this course. Start with today\'s 10 targeted questions to build confidence and earn coins.'
          : 'Your recent performance shows weak areas. Practice today\'s 10 targeted questions to improve quickly and earn coins.';

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Daily Challenge For You'),
            content: Text(challengeMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Not Now'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _onTabSelected(DashboardTab.dailyChallenge);
                },
                child: Text(actionLabel),
              ),
            ],
          );
        },
      );
    } catch (_) {
      // Keep dashboard resilient to transient API failures.
    } finally {
      _checkingDailyChallengePrompt = false;
    }
  }

  bool _isNewToSelectedCourse() {
    final user = widget.authController.user;
    final selectedAt = user?.currentCourseSelectedAt ?? user?.createdAt;
    if (selectedAt == null) {
      return (user?.xp ?? 0) <= 0;
    }

    final ageInDays = DateTime.now().difference(selectedAt).inDays;
    return ageInDays >= 0 && ageInDays < 7;
  }

  Future<void> _checkAndResumeBattle() async {
    if (_checkingActiveBattle || !mounted) {
      return;
    }

    _checkingActiveBattle = true;
    try {
      final battle = await widget.authController.loadActiveBattle();
      if (!mounted || battle == null) {
        return;
      }

      final battleId = (battle['id'] as num?)?.toInt() ?? 0;
      if (battleId <= 0 || _redirectingBattleId == battleId) {
        return;
      }

      _redirectingBattleId = battleId;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BattleQuestionsPage(
            authController: widget.authController,
            battle: battle,
          ),
        ),
      );
    } catch (_) {
      // Ignore transient network issues; next resume will retry.
    } finally {
      _checkingActiveBattle = false;
      _redirectingBattleId = null;
    }
  }

  Future<void> _checkAndOpenLiveGate() async {
    if (_checkingLiveGate || !mounted) {
      return;
    }

    _checkingLiveGate = true;
    try {
      final serverEnrolledIds = await widget.authController
          .loadEnrolledLiveTestIds();
      if (serverEnrolledIds.isEmpty) {
        return;
      }

      final analytics = await widget.authController.loadAnalyticsData();
      if (!mounted) {
        return;
      }

      final now = DateTime.now();
      final next = analytics.liveTests.firstWhere(
        (item) {
          final starts = item.startsAt;
          final enrolled = item.id > 0 && serverEnrolledIds.contains(item.id);

          if (starts == null || !enrolled) {
            return false;
          }

          final seconds = starts.difference(now).inSeconds;
          return seconds >= 0 && seconds <= 60;
        },
        orElse: () => const AnalyticsLiveTest(
          id: 0,
          name: '',
          startsAt: null,
          endsAt: null,
          durationMinutes: 0,
          requiredQuestions: 0,
          status: 'ended',
        ),
      );

      if (next.stableId <= 0 || _activeGateTestId == next.stableId) {
        return;
      }

      _activeGateTestId = next.stableId;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LiveTestCountdownGatePage(test: next),
        ),
      );
    } catch (_) {
      // Skip gate for transient API issues.
    } finally {
      _checkingLiveGate = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final user = widget.authController.user;
        final screenWidth = MediaQuery.of(context).size.width;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) {
              _handleBackPressed();
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            drawer: _SidebarDrawer(
              activeTab: _activeTab,
              onSelect: _onTabSelected,
            ),
            appBar: AppBar(
              titleSpacing: 0,
              actions: [
                _TopInfoChip(
                  icon: Icons.monetization_on_rounded,
                  label: '${user?.coins ?? 0} coins',
                ),
                const SizedBox(width: 8),
                _TopInfoChip(
                  icon: Icons.star_rounded,
                  label: '${user?.xp ?? 0} XP',
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Profile menu',
                  onPressed: _openProfileSheet,
                  icon: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF0F766E)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Row(
              children: [
                if (screenWidth >= 920)
                  SizedBox(
                    width: 290,
                    child: _SidebarDrawer(
                      activeTab: _activeTab,
                      onSelect: _onTabSelected,
                      embedded: true,
                    ),
                  ),
                Expanded(
                  child: _activeTab == DashboardTab.dashboard
                      ? HomeDashboardPage(
                          authController: widget.authController,
                          onOpenTab: _onTabSelected,
                        )
                      : _activeTab == DashboardTab.analytics
                      ? AnalyticsPage(authController: widget.authController)
                      : _activeTab == DashboardTab.practiceByTopics
                      ? PracticeByTopicsPage(
                          authController: widget.authController,
                        )
                      : _activeTab == DashboardTab.mockTests
                      ? MockTestsPage(authController: widget.authController)
                      : _activeTab == DashboardTab.liveTest
                      ? LiveTestsPage(authController: widget.authController)
                      : _activeTab == DashboardTab.autoPractice
                      ? AutoPracticePage(
                          authController: widget.authController,
                          onBackToDashboard: _switchToDashboardTab,
                        )
                      : _activeTab == DashboardTab.dailyChallenge
                      ? DailyChallengePage(
                          authController: widget.authController,
                        )
                      : _activeTab == DashboardTab.timeAttack
                      ? TimeAttackPage(authController: widget.authController)
                      : _activeTab == DashboardTab.battle
                      ? BattlePage(authController: widget.authController)
                      : _activeTab == DashboardTab.blogs
                      ? ContentListPage(
                          authController: widget.authController,
                          type: ContentListType.blogs,
                        )
                      : _activeTab == DashboardTab.news
                      ? ContentListPage(
                          authController: widget.authController,
                          type: ContentListType.news,
                        )
                      : _activeTab == DashboardTab.notice
                      ? NoticesPage(authController: widget.authController)
                      : _activeTab == DashboardTab.resources
                      ? const ResourcesPage()
                      : _activeTab == DashboardTab.helpAndSupport
                      ? HelpAndSupportPage(
                          authController: widget.authController,
                        )
                      : _activeTab == DashboardTab.discussion
                      ? DiscussionPage(authController: widget.authController)
                      : _activeTab == DashboardTab.wallet
                      ? WalletPage(authController: widget.authController)
                      : _activeTab == DashboardTab.setting
                      ? SettingsPage(authController: widget.authController)
                      : _activeTab == DashboardTab.profile
                      ? ProfilePage(authController: widget.authController)
                      : _ModulePlaceholderPage(
                          title: _labelFor(_activeTab),
                          subtitle: _descriptionFor(_activeTab),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onTabSelected(DashboardTab tab) {
    setState(() {
      _activeTab = tab;
    });

    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState?.isDrawerOpen ?? false) {
      scaffoldState?.closeDrawer();
    }
  }

  void _switchToDashboardTab() {
    if (_activeTab == DashboardTab.dashboard) {
      return;
    }

    setState(() {
      _activeTab = DashboardTab.dashboard;
    });
  }

  Future<void> _handleBackPressed() async {
    if (!mounted || _handlingBackPress) {
      return;
    }

    if (_activeTab != DashboardTab.dashboard) {
      _switchToDashboardTab();
      return;
    }

    _handlingBackPress = true;
    try {
      final shouldExit =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Keep Practicing?'),
                content: const Text(
                  'You are behind others. Practice more before leaving. Are you sure you want to exit the app?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Stay'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Exit App'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (shouldExit) {
        SystemNavigator.pop();
      }
    } finally {
      _handlingBackPress = false;
    }
  }

  Future<void> _openProfileSheet() async {
    final user = widget.authController.user;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Student',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFDCEAFE),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ProfileActionTile(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  onTap: () {
                    Navigator.of(context).pop();
                    _onTabSelected(DashboardTab.dashboard);
                  },
                ),
                _ProfileActionTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  onTap: () {
                    Navigator.of(context).pop();
                    _onTabSelected(DashboardTab.profile);
                  },
                ),
                _ProfileActionTile(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () {
                    Navigator.of(context).pop();
                    _onTabSelected(DashboardTab.setting);
                  },
                ),
                const SizedBox(height: 4),
                _ProfileActionTile(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  danger: true,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await widget.authController.logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _labelFor(DashboardTab tab) {
    switch (tab) {
      case DashboardTab.dashboard:
        return 'Dashboard';
      case DashboardTab.analytics:
        return 'Analytics';
      case DashboardTab.practiceByTopics:
        return 'Practice By Topics';
      case DashboardTab.mockTests:
        return 'Mock Tests';
      case DashboardTab.liveTest:
        return 'Live Test';
      case DashboardTab.autoPractice:
        return 'Auto Practice';
      case DashboardTab.dailyChallenge:
        return 'Daily Challenge';
      case DashboardTab.timeAttack:
        return 'Time Attack';
      case DashboardTab.battle:
        return 'Battle Arena';
      case DashboardTab.blogs:
        return 'Blogs';
      case DashboardTab.news:
        return 'News';
      case DashboardTab.notice:
        return 'Notice';
      case DashboardTab.resources:
        return 'Resources';
      case DashboardTab.helpAndSupport:
        return 'Help And Support';
      case DashboardTab.discussion:
        return 'Discussion';
      case DashboardTab.wallet:
        return 'Wallet';
      case DashboardTab.setting:
        return 'Setting';
      case DashboardTab.profile:
        return 'Profile';
    }
  }

  String _descriptionFor(DashboardTab tab) {
    return 'This module is ready as a placeholder. API and full UI will be connected next.';
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? const Color(0xFFB91C1C) : const Color(0xFF0F172A);
    final bg = danger ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarDrawer extends StatelessWidget {
  const _SidebarDrawer({
    required this.activeTab,
    required this.onSelect,
    this.embedded = false,
  });

  final DashboardTab activeTab;
  final ValueChanged<DashboardTab> onSelect;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: const Color(0xFF0F172A),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
          children: [
            const _SidebarBrand(),
            const SizedBox(height: 16),
            const _SectionTitle('Overview'),
            _NavTile(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              selected: activeTab == DashboardTab.dashboard,
              onTap: () => onSelect(DashboardTab.dashboard),
            ),
            _NavTile(
              icon: Icons.analytics_rounded,
              label: 'Analytics',
              selected: activeTab == DashboardTab.analytics,
              onTap: () => onSelect(DashboardTab.analytics),
            ),
            _NavTile(
              icon: Icons.leaderboard_rounded,
              label: 'Leaderboard',
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).pushNamed('/leaderboard');
                });
              },
            ),
            const SizedBox(height: 10),
            const _SectionTitle('Practice'),
            _NavTile(
              icon: Icons.topic_rounded,
              label: 'Practice By Topics',
              selected: activeTab == DashboardTab.practiceByTopics,
              onTap: () => onSelect(DashboardTab.practiceByTopics),
            ),
            _NavTile(
              icon: Icons.assignment_rounded,
              label: 'Mock Tests',
              selected: activeTab == DashboardTab.mockTests,
              onTap: () => onSelect(DashboardTab.mockTests),
            ),
            _NavTile(
              icon: Icons.live_tv_rounded,
              label: 'Live Test',
              selected: activeTab == DashboardTab.liveTest,
              onTap: () => onSelect(DashboardTab.liveTest),
            ),
            _NavTile(
              icon: Icons.auto_awesome_rounded,
              label: 'Auto Practice',
              selected: activeTab == DashboardTab.autoPractice,
              onTap: () => onSelect(DashboardTab.autoPractice),
            ),
            _NavTile(
              icon: Icons.emoji_events_rounded,
              label: 'Daily Challenge',
              selected: activeTab == DashboardTab.dailyChallenge,
              onTap: () => onSelect(DashboardTab.dailyChallenge),
            ),
            _NavTile(
              icon: Icons.timer_rounded,
              label: 'Time Attack',
              selected: activeTab == DashboardTab.timeAttack,
              onTap: () => onSelect(DashboardTab.timeAttack),
            ),
            _NavTile(
              icon: Icons.sports_martial_arts_rounded,
              label: 'Battle Arena',
              selected: activeTab == DashboardTab.battle,
              onTap: () => onSelect(DashboardTab.battle),
            ),
            const SizedBox(height: 10),
            const _SectionTitle('Resources'),
            _NavTile(
              icon: Icons.article_rounded,
              label: 'Blogs',
              selected: activeTab == DashboardTab.blogs,
              onTap: () => onSelect(DashboardTab.blogs),
            ),
            _NavTile(
              icon: Icons.newspaper_rounded,
              label: 'News',
              selected: activeTab == DashboardTab.news,
              onTap: () => onSelect(DashboardTab.news),
            ),
            _NavTile(
              icon: Icons.notifications_rounded,
              label: 'Notice',
              selected: activeTab == DashboardTab.notice,
              onTap: () => onSelect(DashboardTab.notice),
            ),
            _NavTile(
              icon: Icons.folder_special_rounded,
              label: 'Resources',
              selected: activeTab == DashboardTab.resources,
              onTap: () => onSelect(DashboardTab.resources),
            ),
            const SizedBox(height: 10),
            const _SectionTitle('Support'),
            _NavTile(
              icon: Icons.support_agent_rounded,
              label: 'Help And Support',
              selected: activeTab == DashboardTab.helpAndSupport,
              onTap: () => onSelect(DashboardTab.helpAndSupport),
            ),
            _NavTile(
              icon: Icons.forum_rounded,
              label: 'Discussion',
              selected: activeTab == DashboardTab.discussion,
              onTap: () => onSelect(DashboardTab.discussion),
            ),
            _NavTile(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Wallet',
              selected: activeTab == DashboardTab.wallet,
              onTap: () => onSelect(DashboardTab.wallet),
            ),
            _NavTile(
              icon: Icons.settings_rounded,
              label: 'Setting',
              selected: activeTab == DashboardTab.setting,
              onTap: () => onSelect(DashboardTab.setting),
            ),
          ],
        ),
      ),
    );

    if (embedded) {
      return content;
    }

    return Drawer(child: content);
  }
}

class _TopInfoChip extends StatelessWidget {
  const _TopInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width < 430 ? 120.0 : 170.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0F172A)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFF1D4ED8),
            child: Icon(Icons.school_rounded, color: Colors.white, size: 20),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SmartBato',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Student Dashboard',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1E3A8A) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: Colors.white, size: 20),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
}

class _ModulePlaceholderPage extends StatelessWidget {
  const _ModulePlaceholderPage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 640,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  size: 52,
                  color: Color(0xFF1E3A8A),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
