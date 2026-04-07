import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/auth_controller.dart';
import '../../../core/theme/app_page_shell.dart';
import '../models/mock_test_models.dart';

class MockTestResultPage extends StatefulWidget {
  const MockTestResultPage({
    super.key,
    required this.authController,
    required this.report,
    this.resultTypeLabel = 'Mock Test',
    this.allowPdfDownload = true,
  });

  final AuthController authController;
  final MockTestReport report;
  final String resultTypeLabel;
  final bool allowPdfDownload;

  @override
  State<MockTestResultPage> createState() => _MockTestResultPageState();
}

class _MockTestResultPageState extends State<MockTestResultPage> {
  bool _downloading = false;
  bool _sharing = false;
  final GlobalKey _shareCardKey = GlobalKey();

  Future<void> _downloadReport() async {
    if (_downloading) return;

    setState(() {
      _downloading = true;
    });

    try {
      final bytes = await widget.authController.downloadMockReportPdf(
        widget.report.modelSet.id,
      );
      final dir = await _resolveReportDirectory();
      final safeName = widget.report.modelSet.name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      );
      final file = File('${dir.path}/${safeName}_report.pdf');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report Saved',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  file.path,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _openFile(file);
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _shareFile(file);
                        },
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<Directory> _resolveReportDirectory() async {
    const reportsFolderName = 'SmartBatoReports';

    if (Platform.isAndroid) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final target = Directory('${downloads.path}/$reportsFolderName');
        if (!target.existsSync()) {
          target.createSync(recursive: true);
        }
        return target;
      }

      final fallback = Directory(
        '/storage/emulated/0/Download/$reportsFolderName',
      );
      try {
        if (!fallback.existsSync()) {
          fallback.createSync(recursive: true);
        }
        return fallback;
      } catch (_) {
        // Continue to app documents fallback.
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final target = Directory('${docs.path}/$reportsFolderName');
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }
    return target;
  }

  Future<void> _openFile(File file) async {
    final result = await OpenFilex.open(file.path);
    if (!mounted) return;

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty ? result.message : 'Unable to open file.',
          ),
        ),
      );
    }
  }

  Future<void> _shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '${widget.resultTypeLabel} report',
      subject: 'SmartBato ${widget.resultTypeLabel} Report',
    );
  }

  Future<void> _shareChallengeCard() async {
    if (_sharing) return;

    setState(() {
      _sharing = true;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Unable to prepare result card for sharing.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Unable to export result card.');
      }

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final safeName = widget.report.modelSet.name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      );
      final file = File(
        '${tempDir.path}/${safeName}_${widget.resultTypeLabel.toLowerCase().replaceAll(' ', '_')}_challenge.png',
      );
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _challengeText(),
        subject: 'SmartBato ${widget.resultTypeLabel} Challenge',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  String _challengeText() {
    final summary = widget.report.summary;
    final rank = widget.report.userRank == null
        ? ''
        : ' and ranked #${widget.report.userRank}';
    return 'I scored ${summary.percentage.toStringAsFixed(1)}% in ${_formatDuration(summary.timeTakenSeconds)}$rank on SmartBato ${widget.resultTypeLabel.toLowerCase()}. Challenge me.';
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final summary = report.summary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${report.modelSet.name} ${widget.resultTypeLabel} Report',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (summary.suspended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Text(
                  'SUSPENDED',
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _sharing ? null : _shareChallengeCard,
            icon: _sharing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: const Text('Share'),
          ),
          if (!summary.suspended && widget.allowPdfDownload)
            TextButton.icon(
              onPressed: _downloading ? null : _downloadReport,
              icon: _downloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: const Text('PDF'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RepaintBoundary(
            key: _shareCardKey,
            child: _ShareChallengeCard(
              report: report,
              resultTypeLabel: widget.resultTypeLabel,
              challengeText: _challengeText(),
              formattedTime: _formatDuration(summary.timeTakenSeconds),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric(
                'Score',
                '${summary.score.toStringAsFixed(2)} / ${summary.total}',
                const Color(0xFF0F172A),
              ),
              _metric('Correct', '${summary.correct}', const Color(0xFF166534)),
              _metric(
                'Incorrect',
                '${summary.incorrect}',
                const Color(0xFF991B1B),
              ),
              _metric(
                'Unattempted',
                '${summary.unattempted}',
                const Color(0xFF92400E),
              ),
              _metric(
                'Accuracy',
                '${summary.accuracy.toStringAsFixed(1)}%',
                const Color(0xFF0369A1),
              ),
              _metric(
                'Time',
                _formatDuration(summary.timeTakenSeconds),
                const Color(0xFF1E3A8A),
              ),
            ],
          ),
          if ((summary.remarks ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            AppSurfaceCard(
              child: Text(
                summary.remarks!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (report.leaderboard.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Leaderboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...report.leaderboard.take(10).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: item.isMe
                        ? const Color(0xFFE0F2FE)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AppSurfaceCard(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '#${item.rank}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: item.isMe
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.score.toStringAsFixed(2)} (${item.correctAnswers})',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(item.timeTakenSeconds),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 14),
          const Text(
            'Answer Review',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...report.review.map((item) {
            final statusColor = item.status == 'correct'
                ? const Color(0xFF166534)
                : item.status == 'incorrect'
                ? const Color(0xFF991B1B)
                : const Color(0xFF92400E);
            final statusBg = item.status == 'correct'
                ? const Color(0xFFDCFCE7)
                : item.status == 'incorrect'
                ? const Color(0xFFFEE2E2)
                : const Color(0xFFFEF3C7);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Q${item.index}. ${item.question}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.status.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your answer: ${item.selectedOption ?? 'Not answered'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: item.status == 'correct'
                            ? const Color(0xFF166534)
                            : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Correct answer: ${item.correctOption ?? '-'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((item.solution ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.solution!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return SizedBox(
      width: 154,
      child: AppSurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: const Color(0xFF64748B)),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareChallengeCard extends StatelessWidget {
  const _ShareChallengeCard({
    required this.report,
    required this.resultTypeLabel,
    required this.challengeText,
    required this.formattedTime,
  });

  final MockTestReport report;
  final String resultTypeLabel;
  final String challengeText;
  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331E3A8A),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1AF8FAFC),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x33F8FAFC)),
                ),
                child: Text(
                  'SMARTBATO ${resultTypeLabel.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFDE68A),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            report.modelSet.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            challengeText,
            style: const TextStyle(
              color: Color(0xFFE0F2FE),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0x29FFFFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Score',
                        style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${summary.percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${summary.correct}/${summary.total} correct',
                        style: const TextStyle(color: Color(0xFFE2E8F0)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    if (report.userRank != null) ...[
                      _ShareCardStat(
                        label: 'Rank',
                        value: '#${report.userRank}',
                      ),
                      const SizedBox(height: 10),
                    ],
                    _ShareCardStat(label: 'Time', value: formattedTime),
                    const SizedBox(height: 10),
                    _ShareCardStat(
                      label: 'Accuracy',
                      value: '${summary.accuracy.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Post this card to your story or feed and throw a challenge back to your friends.',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareCardStat extends StatelessWidget {
  const _ShareCardStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x29FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFBFDBFE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
