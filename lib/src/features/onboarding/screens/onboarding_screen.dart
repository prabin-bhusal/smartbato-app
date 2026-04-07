import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  static const _pages = <_OnboardingData>[
    _OnboardingData(
      icon: Icons.track_changes_rounded,
      title: 'Prepare Smarter',
      description:
          'Practice by topics and track your progress with focused study sessions.',
      color: Color(0xFF0EA5E9),
    ),
    _OnboardingData(
      icon: Icons.insights_rounded,
      title: 'See Your Growth',
      description:
          'Measure your weak areas, improve daily, and build exam confidence.',
      color: Color(0xFF22C55E),
    ),
    _OnboardingData(
      icon: Icons.emoji_events_rounded,
      title: 'Crack MCQ Exams',
      description:
          'Stay consistent with SmartBato and get exam-ready with every attempt.',
      color: Color(0xFFF97316),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _pages.length - 1;
    final size = MediaQuery.of(context).size;
    final compact = size.width < 380;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F8FF), Color(0xFFF0FCFA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 20,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          await widget.onFinished();
                        },
                        child: const Text('Skip'),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _pages.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = _pages[index];

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: compact ? 220 : 260,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      item.color.withValues(alpha: 0.92),
                                      item.color.withValues(alpha: 0.62),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: [
                                    BoxShadow(
                                      color: item.color.withValues(alpha: 0.25),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  item.icon,
                                  size: compact ? 72 : 86,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 26),
                              Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: compact ? 26 : 30,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                item.description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: compact ? 15 : 16,
                                  color: const Color(0xFF334155),
                                  height: 1.55,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          duration: const Duration(milliseconds: 220),
                          width: _currentIndex == index ? 24 : 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFFBFCCDF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (isLastPage) {
                            await widget.onFinished();
                          } else {
                            await _controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        child: Text(isLastPage ? 'Get Started' : 'Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}
