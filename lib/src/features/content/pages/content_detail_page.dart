import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../auth/auth_controller.dart';
import '../../../core/theme/app_page_shell.dart';
import '../models/content_models.dart';

enum ContentType { blog, news }

class ContentDetailPage extends StatefulWidget {
  const ContentDetailPage({
    super.key,
    required this.authController,
    required this.slug,
    required this.type,
  });

  final AuthController authController;
  final String slug;
  final ContentType type;

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  late Future<ContentDetailResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ContentDetailResponse> _load() {
    return widget.type == ContentType.blog
        ? widget.authController.loadBlogDetail(widget.slug)
        : widget.authController.loadNewsDetail(widget.slug);
  }

  String get _title =>
      widget.type == ContentType.blog ? 'Blog Detail' : 'News Detail';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<ContentDetailResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return AppPageShell(
              children: [
                AppHeroBanner(
                  title: _title,
                  subtitle: 'Loading content details.',
                  icon: widget.type == ContentType.blog
                      ? Icons.article_rounded
                      : Icons.newspaper_rounded,
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

          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorView(
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry: () {
                setState(() {
                  _future = _load();
                });
              },
            );
          }

          final data = snapshot.data!;
          final item = data.item;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppHeroBanner(
                title: item.title,
                subtitle: _dateLabel(item.publishedAt),
                icon: widget.type == ContentType.blog
                    ? Icons.article_rounded
                    : Icons.newspaper_rounded,
                colors: const [Color(0xFF1D4ED8), Color(0xFF0F766E)],
              ),
              const SizedBox(height: 12),
              if ((item.thumbnailUrl ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    item.thumbnailUrl!,
                    height: 190,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _imageFallback(),
                  ),
                )
              else
                _imageFallback(),
              const SizedBox(height: 14),
              AppSurfaceCard(
                child: Html(
                  data: item.contentHtml,
                  style: {
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      color: const Color(0xFF0F172A),
                      lineHeight: const LineHeight(1.45),
                      fontSize: FontSize(15),
                    ),
                    'h1': Style(
                      fontSize: FontSize(28),
                      fontWeight: FontWeight.w800,
                    ),
                    'h2': Style(
                      fontSize: FontSize(24),
                      fontWeight: FontWeight.w700,
                    ),
                    'h3': Style(
                      fontSize: FontSize(20),
                      fontWeight: FontWeight.w700,
                    ),
                    'p': Style(margin: Margins.only(bottom: 12)),
                    'li': Style(margin: Margins.only(bottom: 6)),
                    'a': Style(
                      color: const Color(0xFF1D4ED8),
                      textDecoration: TextDecoration.underline,
                    ),
                    'blockquote': Style(
                      padding: HtmlPaddings.all(10),
                      backgroundColor: const Color(0xFFF1F5F9),
                      border: Border(
                        left: BorderSide(
                          color: const Color(0xFF94A3B8),
                          width: 3,
                        ),
                      ),
                    ),
                  },
                ),
              ),
              const SizedBox(height: 20),
              if (data.related.isNotEmpty)
                const Text(
                  'Related',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              const SizedBox(height: 10),
              ...data.related.map(
                (related) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppSurfaceCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(related.title),
                      subtitle: Text(_dateLabel(related.publishedAt)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => ContentDetailPage(
                              authController: widget.authController,
                              slug: related.slug,
                              type: widget.type,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
        ),
      ),
      child: Icon(
        widget.type == ContentType.blog
            ? Icons.article_rounded
            : Icons.newspaper_rounded,
        size: 44,
        color: const Color(0xFF475569),
      ),
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      children: [
        AppSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Color(0xFFB91C1C),
              ),
              const SizedBox(height: 10),
              Text(
                message.isEmpty ? 'Unable to load.' : message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }
}
