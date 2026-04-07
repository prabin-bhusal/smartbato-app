import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../../core/theme/app_page_shell.dart';
import '../models/content_models.dart';
import 'content_detail_page.dart';

enum ContentListType { blogs, news }

class ContentListPage extends StatefulWidget {
  const ContentListPage({
    super.key,
    required this.authController,
    required this.type,
  });

  final AuthController authController;
  final ContentListType type;

  @override
  State<ContentListPage> createState() => _ContentListPageState();
}

class _ContentListPageState extends State<ContentListPage> {
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  final List<ContentListItem> _items = <ContentListItem>[];
  PagedMeta? _meta;

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

  @override
  void didUpdateWidget(ContentListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data if the content type changed
    if (oldWidget.type != widget.type) {
      _loadInitial();
    }
  }

  Future<ContentListResponse> _load(int page) {
    return widget.type == ContentListType.blogs
        ? widget.authController.loadBlogs(page: page)
        : widget.authController.loadNews(page: page);
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
      // Keep existing list.
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  String get _title => widget.type == ContentListType.blogs ? 'Blogs' : 'News';
  IconData get _icon => widget.type == ContentListType.blogs
      ? Icons.article_rounded
      : Icons.newspaper_rounded;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: Builder(
        builder: (context) {
          if (_loading) {
            return AppPageShell(
              children: [
                AppHeroBanner(
                  title: _title,
                  subtitle:
                      'Loading the latest updates for your learning journey.',
                  icon: _icon,
                ),
                const SizedBox(height: 12),
                const AppSurfaceCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            );
          }

          if (_error != null) {
            return _ErrorState(message: _error!, onRetry: _loadInitial);
          }

          final meta = _meta;
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              AppHeroBanner(
                title: _title,
                subtitle: 'Latest updates curated for your learning journey',
                icon: _icon,
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
                    '${meta?.total ?? _items.length} items',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                const _EmptyState(message: 'No items available right now.')
              else
                ..._items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppSurfaceCard(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ContentDetailPage(
                                authController: widget.authController,
                                slug: item.slug,
                                type: widget.type == ContentListType.blogs
                                    ? ContentType.blog
                                    : ContentType.news,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child:
                                    item.thumbnailUrl != null &&
                                        item.thumbnailUrl!.isNotEmpty
                                    ? Image.network(
                                        item.thumbnailUrl!,
                                        width: 84,
                                        height: 70,
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
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.excerpt,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _dateLabel(item.publishedAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
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
                  label: Text(_loadingMore ? 'Loading...' : 'Load more'),
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
      width: 84,
      height: 70,
      color: const Color(0xFFE2E8F0),
      child: Icon(_icon, color: const Color(0xFF64748B)),
    );
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      children: [
        const AppSurfaceCard(
          child: Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB91C1C),
            size: 42,
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: Column(
            children: [
              Text(
                message.isEmpty ? 'Unable to load.' : message,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }
}
