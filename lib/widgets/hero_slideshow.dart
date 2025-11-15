import 'dart:async';
import 'package:flutter/material.dart';

class HeroSlideshow extends StatefulWidget {
  const HeroSlideshow({super.key});

  @override
  State<HeroSlideshow> createState() => _HeroSlideshowState();
}

class _HeroSlideshowState extends State<HeroSlideshow> {
  final _controller = PageController();
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _index = (_index + 1) % _slides.length;
      if (mounted) {
        _controller.animateToPage(
          _index,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _HeroCard(data: _slides[i]),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 28 : 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                gradient: active
                    ? LinearGradient(colors: _slides[i].colors)
                    : null,
                color: active
                    ? null
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        ),
      ],
    );
  }
}

final List<_SlideData> _slides = [
  _SlideData(
    title: 'Book Turf Instantly',
    subtitle: 'Reserve premium football fields in seconds, no phone calls needed.',
    icon: Icons.sports_soccer_rounded,
    colors: [const Color(0xFF4AD1FF), const Color(0xFF2480FF)],
    accent: const Color(0xFF1B335F),
  ),
  _SlideData(
    title: 'Live Slot Tracking',
    subtitle: 'See live availability, so your squad never shows up to a busy pitch.',
    icon: Icons.schedule_rounded,
    colors: [const Color(0xFF5FFFBE), const Color(0xFF31C3FF)],
    accent: const Color(0xFF13413E),
  ),
  _SlideData(
    title: 'Club-Level Facilities',
    subtitle: 'Discover venues with pro lighting, lockers, and officiating services.',
    icon: Icons.emoji_events_rounded,
    colors: [const Color(0xFFFF769C), const Color(0xFF7C74FF)],
    accent: const Color(0xFF4A1C4D),
  ),
];

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.data});
  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: data.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -80,
              top: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 1.2,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(data.icon, size: 40, color: Colors.white.withValues(alpha: 0.9)),
                  const Spacer(),
                  Text(
                    data.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white.withValues(alpha: 0.88), height: 1.4),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 26,
              right: 26,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: data.accent.withValues(alpha: 0.4), blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('LIVE', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color accent;
}

