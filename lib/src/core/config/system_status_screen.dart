import 'package:flutter/material.dart';

class SystemStatusScreen extends StatelessWidget {
  final String status;
  final String? finalDate;
  const SystemStatusScreen({super.key, required this.status, this.finalDate});

  @override
  Widget build(BuildContext context) {
    if (status == 'maintenance') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.build_rounded, size: 64, color: Colors.amber),
              SizedBox(height: 24),
              Text(
                'We\'ll be back soon!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Our system is currently under maintenance.\nPlease check back later.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (status == 'coming_soon') {
      return Scaffold(
        body: Center(child: _ComingSoonCountdown(finalDate: finalDate)),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ComingSoonCountdown extends StatefulWidget {
  final String? finalDate;
  const _ComingSoonCountdown({this.finalDate});
  @override
  State<_ComingSoonCountdown> createState() => _ComingSoonCountdownState();
}

class _ComingSoonCountdownState extends State<_ComingSoonCountdown> {
  late Duration _remaining;
  late DateTime? _target;
  late bool _ended;
  @override
  void initState() {
    super.initState();
    _target = widget.finalDate != null
        ? DateTime.tryParse(widget.finalDate!)
        : null;
    _ended = false;
    _remaining = _target != null
        ? _target!.difference(DateTime.now())
        : Duration.zero;
    if (_target != null) {
      _tick();
    }
  }

  void _tick() {
    if (!mounted || _target == null) return;
    setState(() {
      _remaining = _target!.difference(DateTime.now());
      _ended = _remaining.inSeconds <= 0;
    });
    if (!_ended) {
      Future.delayed(const Duration(seconds: 1), _tick);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ended) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.celebration_rounded, size: 64, color: Colors.green),
          SizedBox(height: 24),
          Text(
            'We are launching soon!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
    final d = _remaining.inDays;
    final h = _remaining.inHours % 24;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_rounded, size: 64, color: Colors.blue),
        const SizedBox(height: 24),
        const Text(
          'Coming Soon',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'We\'re preparing something amazing for you.\nStay tuned!',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          '$d days $h h $m m $s s',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text('until launch'),
      ],
    );
  }
}
