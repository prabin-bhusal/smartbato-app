import 'package:flutter/material.dart';
import '../../auth/auth_controller.dart';
import '../../dashboard/student_dashboard_screen.dart';
import '../../../core/theme/app_page_shell.dart';
import 'dart:async';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  void _goToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            StudentDashboardScreen(authController: widget.authController),
      ),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _goToDashboard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _goToDashboard,
          ),
          title: const Text('Leaderboard'),
          elevation: 0,
        ),
        body: SafeArea(
          top: false,
          maintainBottomViewPadding: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero Banner ─────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: AppHeroBanner(
                  title: 'Leaderboard',
                  subtitle: 'Top performers based on weekly XP.',
                  icon: Icons.emoji_events_rounded,
                  colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                ),
              ),

              // ── Pill Tab Bar ───────────────────────────────────────────────────
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
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: const Color(0xFF1D4ED8),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(9),
                    tabs: const [
                      Tab(text: '👤 People'),
                      Tab(text: '🏫 College'),
                      Tab(text: '📍 District'),
                    ],
                  ),
                ),
              ),

              // ── Tab Views ──────────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _LeaderboardTabView(
                      tab: 'user',
                      authController: widget.authController,
                    ),
                    _LeaderboardTabView(
                      tab: 'college',
                      authController: widget.authController,
                    ),
                    _LeaderboardTabView(
                      tab: 'district',
                      authController: widget.authController,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTabState {
  bool loading = false;
  String? error;
  List<dynamic> items = [];
  Map<String, dynamic>? me;
  int page = 1;
  int perPage = 20;
  int total = 0;
  int lastPage = 1;
  bool get hasMore => page < lastPage;
}

class _LeaderboardTabView extends StatefulWidget {
  final String tab;
  final AuthController authController;
  const _LeaderboardTabView({required this.tab, required this.authController});

  @override
  State<_LeaderboardTabView> createState() => _LeaderboardTabViewState();
}

class _LeaderboardTabViewState extends State<_LeaderboardTabView> {
  final _state = _LeaderboardTabState();
  final _scrollController = ScrollController();
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || _state.loading) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200 && _state.hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetchLeaderboard({bool refresh = false}) async {
    setState(() {
      _state.loading = true;
      _state.error = null;
      if (refresh) {
        _state.page = 1;
        _state.items.clear();
      }
    });
    try {
      final data = await widget.authController.fetchLeaderboard(
        tab: widget.tab,
        page: _state.page,
        perPage: _state.perPage,
      );
      if (!mounted) return;

      setState(() {
        final incomingItems = data['data'] as List? ?? [];
        if (refresh) {
          _state.items = incomingItems;
        } else {
          _state.items.addAll(incomingItems);
        }
        _state.total = data['total'] ?? _state.items.length;
        _state.lastPage = data['last_page'] ?? 1;
        _state.page = data['current_page'] ?? 1;
        _state.me = data['me'] as Map<String, dynamic>?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state.error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _state.loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_state.hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _state.page + 1;
      final data = await widget.authController.fetchLeaderboard(
        tab: widget.tab,
        page: nextPage,
        perPage: _state.perPage,
      );
      if (!mounted) return;
      setState(() {
        _state.items.addAll(data['data'] as List? ?? []);
        _state.page = data['current_page'] ?? nextPage;
        _state.lastPage = data['last_page'] ?? _state.lastPage;
        _state.me = data['me'] as Map<String, dynamic>?;
      });
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _state.me;
    final isMeVisible = _isMeVisible(me);
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    if (_state.loading && _state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_state.error != null && _state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _state.error!,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _fetchLeaderboard(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFF94A3B8),
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No data found',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetchLeaderboard(refresh: true),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppSurfaceCard(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF0F172A), const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tabTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Weekly XP ranking with your position highlighted.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _LeaderboardStatChip(
                          label: 'Entries',
                          value: '${_state.total}',
                        ),
                        _LeaderboardStatChip(
                          label: 'Page',
                          value: '${_state.page}/${_state.lastPage}',
                        ),
                        if (me != null)
                          _LeaderboardStatChip(
                            label: 'My rank',
                            value: '#${me['rank']}',
                            emphasized: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          ..._state.items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildLeaderboardCard(item, i),
            );
          }),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (me != null && !isMeVisible)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _buildMyRankCard(me),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  bool _isMeVisible(Map<String, dynamic>? me) {
    if (me == null) {
      return false;
    }

    final meRank = (me['rank'] ?? '').toString();
    final meTitle = _normalizeText((me['title'] ?? '').toString());
    final meUserId = (me['user_id'] ?? '').toString();

    return _state.items.any((item) {
      if ((item['is_me'] ?? false) == true) {
        return true;
      }

      if (widget.tab == 'user') {
        return (item['user_id'] ?? '').toString() == meUserId;
      }

      return (item['rank'] ?? '').toString() == meRank ||
          _normalizeText(_itemTitle(item)) == meTitle;
    });
  }

  String _itemTitle(Map<String, dynamic> item) {
    if (widget.tab == 'user') {
      return (item['user']?['name'] ?? '-').toString();
    }

    if (widget.tab == 'college') {
      return (item['last_degree_college'] ?? '-').toString();
    }

    return (item['district'] ?? '-').toString();
  }

  String _itemSubtitle(Map<String, dynamic> item) {
    if (widget.tab == 'user') {
      final district = item['user']?['district'];
      if (district != null && district.toString().trim().isNotEmpty) {
        return district.toString();
      }

      final college = item['user']?['last_degree_college'];
      if (college != null && college.toString().trim().isNotEmpty) {
        return college.toString();
      }
    }

    return widget.tab == 'college'
        ? 'College leaderboard'
        : 'District leaderboard';
  }

  Widget _buildLeaderboardCard(Map<String, dynamic> item, int index) {
    final rank =
        int.tryParse((item['rank'] ?? (index + 1)).toString()) ?? (index + 1);
    final title = _itemTitle(item);
    final subtitleText = _itemSubtitle(item);
    final xpVal = item['xp']?.toString() ?? '0';
    final isMe = (item['is_me'] ?? false) == true;

    final rankColor = rank == 1
        ? const Color(0xFFF59E0B)
        : rank == 2
        ? const Color(0xFF94A3B8)
        : rank == 3
        ? const Color(0xFFB45309)
        : const Color(0xFF334155);

    final backgroundColor = isMe ? const Color(0xFFEFF6FF) : Colors.white;

    final borderColor = isMe
        ? const Color(0xFF2563EB)
        : const Color(0xFFE2E8F0);

    return AppSurfaceCard(
      child: Container(
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFFF8FBFF), Color(0xFFE8F1FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isMe ? 1.4 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? rankColor.withValues(alpha: 0.18)
                    : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: rank <= 3
                    ? Border.all(
                        color: rankColor.withValues(alpha: 0.35),
                        width: 2,
                      )
                    : Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: rank <= 3 ? rankColor : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isMe
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF1E293B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMe)
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
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$xpVal XP',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRankCard(Map<String, dynamic> me) {
    final rank = (me['rank'] ?? '-').toString();
    final title = (me['title'] ?? 'Me').toString();
    final xpVal = me['xp']?.toString() ?? '0';
    final subtitle = (me['subtitle'] ?? '').toString();

    return AppSurfaceCard(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your rank',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$xpVal XP',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String get _tabTitle {
    switch (widget.tab) {
      case 'college':
        return 'College leaderboard';
      case 'district':
        return 'District leaderboard';
      default:
        return 'People leaderboard';
    }
  }
}

class _LeaderboardStatChip extends StatelessWidget {
  const _LeaderboardStatChip({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: emphasized ? 0.3 : 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
