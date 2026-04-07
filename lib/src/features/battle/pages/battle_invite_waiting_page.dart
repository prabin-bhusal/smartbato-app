import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';
import 'battle_intro_page.dart';

class BattleInviteWaitingPage extends StatefulWidget {
  const BattleInviteWaitingPage({
    super.key,
    required this.authController,
    required this.invite,
  });

  final AuthController authController;
  final Map<String, dynamic> invite;

  @override
  State<BattleInviteWaitingPage> createState() =>
      _BattleInviteWaitingPageState();
}

class _BattleInviteWaitingPageState extends State<BattleInviteWaitingPage> {
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _matched = false;
  bool _cancelled = false;
  bool _cancelling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.authController.ensureRealtimeConnected();
    widget.authController.realtimeSocket.off('battle:matched', _handleMatched);
    widget.authController.realtimeSocket.on('battle:matched', _handleMatched);
    _syncRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      _syncRemainingTime();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    widget.authController.realtimeSocket.off('battle:matched', _handleMatched);
    super.dispose();
  }

  void _handleMatched(dynamic payload) {
    if (!mounted || _matched || payload is! Map) {
      return;
    }

    final data = Map<String, dynamic>.from(
      payload.map<String, dynamic>((k, v) => MapEntry(k.toString(), v)),
    );
    final battle = data['battle'];
    if (battle is! Map<String, dynamic>) {
      return;
    }

    _matched = true;
    _countdownTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BattleIntroPage(
          authController: widget.authController,
          battle: Map<String, dynamic>.from(battle),
        ),
      ),
    );
  }

  Future<void> _cancelInvite() async {
    if (_cancelled || _cancelling || _matched) {
      return;
    }

    setState(() => _cancelling = true);
    _countdownTimer?.cancel();

    try {
      await widget.authController.cancelBattleInvite();
      if (!mounted) {
        return;
      }

      setState(() {
        _cancelled = true;
      });
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _cancelling = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        _syncRemainingTime();
      });
    }
  }

  void _syncRemainingTime() {
    final expiresAt = DateTime.tryParse(
      (widget.invite['expires_at'] ?? '').toString(),
    );
    if (expiresAt == null) {
      setState(() => _remainingSeconds = 0);
      return;
    }

    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    setState(() {
      _remainingSeconds = remaining > 0 ? remaining : 0;
    });
  }

  Future<void> _shareInvite() async {
    final code = (widget.invite['code'] ?? '').toString();
    final shareLink = (widget.invite['share_link'] ?? '').toString();
    final host = widget.invite['host'] as Map<String, dynamic>?;
    final hostCode = (host?['username'] ?? '').toString();
    final message =
        'Join my SmartBato battle challenge!\nInvite code: $code\nFriend code: $hostCode\nLink: $shareLink';
    await Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final code = (widget.invite['code'] ?? '').toString();
    final shareLink = (widget.invite['share_link'] ?? '').toString();
    final host = widget.invite['host'] as Map<String, dynamic>?;
    final hostName = (host?['name'] ?? 'Friend').toString();
    final hostCode = (host?['username'] ?? '').toString();
    final isExpired = _remainingSeconds <= 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_cancelled && !_matched) {
          _cancelInvite();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1120),
        body: SafeArea(
          child: AppPageShell(
            maxWidth: 760,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Waiting for another user',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your invite is live. Keep this screen open while the other user joins, or cancel it if you want to stop the challenge.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              AppSurfaceCard(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hourglass_top_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Invite status',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isExpired
                                      ? 'Invite expired'
                                      : 'Waiting for $hostName to join',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isExpired ? 'Expired' : '$_remainingSeconds s',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _WaitingStatRow(label: 'Invite code', value: code),
                      const SizedBox(height: 10),
                      _WaitingStatRow(label: 'Friend code', value: hostCode),
                      const SizedBox(height: 10),
                      _WaitingStatRow(label: 'Share link', value: shareLink),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_error != null) ...[
                AppSurfaceCard(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What happens next',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The invited user will see an invitation alert. Once they accept, both of you will move into the battle intro automatically.',
                      style: TextStyle(color: Color(0xFF475569), height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_cancelled || _cancelling)
                          ? null
                          : _cancelInvite,
                      icon: const Icon(Icons.close_rounded),
                      label: Text(
                        _cancelling ? 'Cancelling...' : 'Cancel invite',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isExpired
                          ? null
                          : () async {
                              final codeText = code;
                              await Clipboard.setData(
                                ClipboardData(text: codeText),
                              );
                              if (!mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invite code copied.'),
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy code'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: isExpired ? null : _shareInvite,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share invite again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingStatRow extends StatelessWidget {
  const _WaitingStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
