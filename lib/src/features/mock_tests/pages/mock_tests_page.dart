import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../../core/theme/app_page_shell.dart';
import '../models/mock_test_models.dart';
import 'mock_test_exam_page.dart';
import 'mock_test_result_page.dart';

class MockTestsPage extends StatefulWidget {
  const MockTestsPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<MockTestsPage> createState() => _MockTestsPageState();
}

class _MockTestsPageState extends State<MockTestsPage> {
  late Future<MockTestListResponse> _future;
  int _tabIndex = 0;
  final Set<int> _reportLoadingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _future = widget.authController.loadMockTests();
  }

  Future<void> _refresh() async {
    final next = widget.authController.loadMockTests();
    setState(() {
      _future = next;
    });
    await next;

    try {
      await widget.authController.refreshCurrentUser();
    } catch (_) {
      // Preserve refreshed test list even if user profile refresh fails.
    }
  }

  Future<void> _openMock(MockTestItem item) async {
    final loadingReport = item.alreadyAttempted;

    if (loadingReport && _reportLoadingIds.contains(item.id)) {
      return;
    }

    if (loadingReport) {
      setState(() {
        _reportLoadingIds.add(item.id);
      });
    }

    try {
      final begin = await widget.authController.beginMockTest(item.id);

      if (!mounted) {
        return;
      }

      if (begin.alreadyAttempted) {
        final report = begin.report;
        if (report != null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MockTestResultPage(
                authController: widget.authController,
                report: report,
              ),
            ),
          );
          return;
        }

        final loaded = await widget.authController.loadMockReport(item.id);
        if (!mounted) {
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MockTestResultPage(
              authController: widget.authController,
              report: loaded.report,
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
            content: Text('Mock test is not ready. Please try again.'),
          ),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MockTestExamPage(
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
    } finally {
      if (loadingReport && mounted) {
        setState(() {
          _reportLoadingIds.remove(item.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MockTestListResponse>(
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
            message: 'No mock tests found.',
            onRetry: _refresh,
          );
        }

        final upcoming = data.modelSets
            .where((item) => !item.alreadyAttempted)
            .toList();
        final taken = data.modelSets
            .where((item) => item.alreadyAttempted)
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: AppHeroBanner(
                title: 'Mock Tests',
                subtitle: 'Take timed tests and compare your performance',
                icon: Icons.fact_check_rounded,
                colors: const [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
                trailing: Chip(
                  label: Text(
                    'Coins ${data.userCoins}',
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      return const Color(0xFF1D4ED8);
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
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Column(
                          children: [
                            ...(_tabIndex == 0 ? upcoming : taken).map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AppSurfaceCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${item.questionsCount} questions',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: const Color(
                                                      0xFF64748B,
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Builder(
                                        builder: (context) {
                                          final isLoadingReport =
                                              _reportLoadingIds.contains(
                                                item.id,
                                              );

                                          return FilledButton(
                                            onPressed:
                                                (item.canAttempt &&
                                                    !isLoadingReport)
                                                ? () => _openMock(item)
                                                : null,
                                            style: FilledButton.styleFrom(
                                              disabledBackgroundColor:
                                                  const Color(0xFF1D4ED8),
                                              disabledForegroundColor:
                                                  Colors.white,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (item.alreadyAttempted)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                    child: isLoadingReport
                                                        ? const SizedBox(
                                                            width: 16,
                                                            height: 16,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          )
                                                        : const Icon(
                                                            Icons
                                                                .assessment_rounded,
                                                            size: 16,
                                                          ),
                                                  ),
                                                Text(
                                                  item.alreadyAttempted
                                                      ? (isLoadingReport
                                                            ? 'Fetching report...'
                                                            : 'View Report')
                                                      : 'Start (${item.attemptCost} coins)',
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if ((_tabIndex == 0 ? upcoming : taken).isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 48),
                                child: Center(
                                  child: Text(
                                    _tabIndex == 0
                                        ? 'No unattempted mock tests.'
                                        : 'No attempted mock tests yet.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF64748B),
                                        ),
                                  ),
                                ),
                              ),
                          ],
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
