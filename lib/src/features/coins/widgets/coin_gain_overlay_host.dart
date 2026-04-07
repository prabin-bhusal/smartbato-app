import 'dart:collection';

import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../models/coin_gain_event.dart';

class CoinGainOverlayHost extends StatefulWidget {
  const CoinGainOverlayHost({
    super.key,
    required this.authController,
    required this.child,
  });

  final AuthController authController;
  final Widget child;

  @override
  State<CoinGainOverlayHost> createState() => _CoinGainOverlayHostState();
}

class _CoinGainOverlayHostState extends State<CoinGainOverlayHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  final Queue<CoinGainEvent> _queue = ListQueue<CoinGainEvent>();
  CoinGainEvent? _active;
  int? _lastSeenEventId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
      reverseDuration: const Duration(milliseconds: 360),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    widget.authController.addListener(_onAuthControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CoinGainOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authController != widget.authController) {
      oldWidget.authController.removeListener(_onAuthControllerChanged);
      widget.authController.addListener(_onAuthControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_active != null)
          IgnorePointer(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ScaleTransition(
                        scale: _scale,
                        child: _CoinGainBanner(
                          event: _active!,
                          pendingCount: _queue.length,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _onAuthControllerChanged() {
    final event = widget.authController.coinGainEvent;
    if (event != null && event.id != _lastSeenEventId) {
      _lastSeenEventId = event.id;
      _queue.add(event);
      widget.authController.dismissCoinGainEvent(event.id);
      if (_active == null) {
        _playNext();
      }
    }
  }

  Future<void> _playNext() async {
    if (!mounted || _queue.isEmpty) {
      return;
    }

    setState(() {
      _active = _queue.removeFirst();
    });

    await _controller.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) {
      return;
    }
    await _controller.reverse();

    if (!mounted) {
      return;
    }

    setState(() {
      _active = null;
    });

    if (_queue.isNotEmpty) {
      _playNext();
    }
  }
}

class _CoinGainBanner extends StatelessWidget {
  const _CoinGainBanner({required this.event, required this.pendingCount});

  final CoinGainEvent event;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final subtitle = (event.message ?? event.reason).trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD8E2F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.monetization_on_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+${event.amount} coins',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$pendingCount',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
          ],
        ),
      ),
    );
  }
}
