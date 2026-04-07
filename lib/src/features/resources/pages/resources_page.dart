import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';

class ResourcesPage extends StatelessWidget {
  const ResourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      maxWidth: 760,
      children: [
        const AppHeroBanner(
          title: 'Resources',
          subtitle: 'Premium study materials and references are coming soon.',
          icon: Icons.library_books_rounded,
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planned Resource Modules',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Study notes, chapter-wise PDFs, curated references, and quick revision cards will appear here in a structured library.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '• Structured Notes\n• Topic-wise PDFs\n• Exam Cheatsheets\n• External References',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF334155),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
