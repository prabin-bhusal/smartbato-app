import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_controller.dart';
import '../../../core/theme/app_page_shell.dart';
import '../models/content_models.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  final List<NoticeItem> _items = <NoticeItem>[];
  PagedMeta? _meta;
  NoticeFilters? _filters;
  int? _selectedCategoryId;
  int? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 240;
    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  Future<NoticeListResponse> _load(int page) {
    return widget.authController.loadNotices(
      page: page,
      categoryId: _selectedCategoryId,
      courseId: _selectedCourseId,
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _load(1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(response.items);
        _meta = response.meta;
        _filters = response.filters;
        _selectedCategoryId ??= response.filters.selectedCategoryId;
        _selectedCourseId ??= response.filters.selectedCourseId;
      });
    } catch (error) {
      if (!mounted) return;
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

  Future<void> _loadMore() async {
    final meta = _meta;
    if (_loadingMore || meta == null || !meta.hasMorePages) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final response = await _load(meta.currentPage + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(response.items);
        _meta = response.meta;
      });
    } catch (_) {
      // Keep current list; user can retry load more.
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _applyFilter({int? categoryId, int? courseId}) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedCourseId = courseId;
    });
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: Builder(
        builder: (context) {
          if (_loading) {
            return const AppPageShell(
              children: [
                AppHeroBanner(
                  title: 'Notices',
                  subtitle: 'Loading official announcements and updates.',
                  icon: Icons.notifications_active_rounded,
                  colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
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

          if (_error != null) {
            return _NoticesErrorState(message: _error!, onRetry: _loadInitial);
          }

          final filters = _filters;
          if (filters == null) {
            return const AppPageShell(
              children: [
                AppSurfaceCard(
                  child: Text(
                    'Notice filters are unavailable right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ],
            );
          }

          final meta = _meta;
          final visibleCourses = _selectedCategoryId == null
              ? filters.courses
              : filters.courses
                    .where((c) => c.categoryId == _selectedCategoryId)
                    .toList();

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              AppHeroBanner(
                title: 'Notices',
                subtitle: 'Official announcements and updates',
                icon: Icons.notifications_active_rounded,
                colors: const [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${meta?.total ?? _items.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedCategoryId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Categories'),
                              ),
                              ...filters.categories.map(
                                (cat) => DropdownMenuItem<int?>(
                                  value: cat.id,
                                  child: Text(cat.name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              _applyFilter(categoryId: value, courseId: null);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedCourseId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Course',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Courses'),
                              ),
                              ...visibleCourses.map(
                                (course) => DropdownMenuItem<int?>(
                                  value: course.id,
                                  child: Text(course.name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              _applyFilter(
                                categoryId: _selectedCategoryId,
                                courseId: value,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                const AppSurfaceCard(
                  child: Text(
                    'No notices found for selected filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              else
                ..._items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child:
                                    item.thumbnailUrl != null &&
                                        item.thumbnailUrl!.isNotEmpty
                                    ? Image.network(
                                        item.thumbnailUrl!,
                                        width: 80,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _thumbFallback(),
                                      )
                                    : _thumbFallback(),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _dateLabel(item.publishedAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if ((item.categoryName ?? '')
                                            .isNotEmpty)
                                          _chip(
                                            item.categoryName!,
                                            const Color(0xFFE0E7FF),
                                            const Color(0xFF3730A3),
                                          ),
                                        if ((item.courseName ?? '').isNotEmpty)
                                          _chip(
                                            item.courseName!,
                                            const Color(0xFFDCFCE7),
                                            const Color(0xFF166534),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.contentPreview,
                            style: const TextStyle(color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () => _showContent(item),
                                icon: const Icon(Icons.visibility_rounded),
                                label: const Text('Read'),
                              ),
                              if ((item.attachmentUrl ?? '').isNotEmpty)
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _openAttachment(item.attachmentUrl!),
                                    icon: const Icon(Icons.attach_file_rounded),
                                    label: Text(
                                      item.attachmentName?.isNotEmpty == true
                                          ? item.attachmentName!
                                          : 'Attachment',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if ((meta?.hasMorePages ?? false)) ...[
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(
                    _loadingMore ? 'Loading...' : 'Load more notices',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 80,
      height: 64,
      color: const Color(0xFFFDE68A),
      child: const Icon(Icons.notifications_rounded, color: Color(0xFF92400E)),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _showContent(NoticeItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _dateLabel(item.publishedAt),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Html(
                    data: item.contentHtml,
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(14),
                        lineHeight: const LineHeight(1.4),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open attachment.')),
      );
    }
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    return '${_month(local.month)} ${local.day}, ${local.year}';
  }

  String _month(int month) {
    const names = <String>[
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
    return names[(month - 1).clamp(0, 11)];
  }
}

class _NoticesErrorState extends StatelessWidget {
  const _NoticesErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      children: [
        AppSurfaceCard(
          child: Column(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFB91C1C),
                size: 42,
              ),
              const SizedBox(height: 8),
              Text(
                message.isEmpty ? 'Unable to load notices.' : message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }
}
