part of 'package:tk2ragaspace/features/home/home_screen.dart';

mixin _HomeTestimonialsSection on _HomeScreenCore {
  Widget _buildTestimonialsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stacked = constraints.maxWidth < 560;
        final double cardHeight = _estimateTestimonialHeight(
          constraints.maxWidth,
          stacked,
        );
        return VisibilityDetector(
          key: _testimonialVisibilityKey,
          onVisibilityChanged: (info) {
            final shouldRun = info.visibleFraction > 0.3;
            if (shouldRun && !_testimonialAutoplayEnabled) {
              _startTestimonialAutoScroll();
            } else if (!shouldRun && _testimonialAutoplayEnabled) {
              _pauseTestimonialAutoScroll();
            }
          },
          child: Column(
            children: [
              SizedBox(
                height: cardHeight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: Padding(
                    key: ValueKey('${_testimonialPage}_$stacked'),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _TestimonialCard(
                      data: _testimonials[_testimonialPage],
                      stacked: stacked,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _buildTestimonialControls(),
            ],
          ),
        );
      },
    );
  }

  double _estimateTestimonialHeight(double width, bool stacked) {
    const double horizontalPadding = 56; // 28 * 2
    const double verticalPadding = 64; // 32 * 2
    const double avatarSize = 96;
    const double avatarGap = 24;
    final double textWidth = math.max(
      140,
      width - horizontalPadding - (stacked ? 0 : avatarSize + avatarGap),
    );
    final nameStyle = GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    final roleStyle = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      letterSpacing: 1.5,
      fontWeight: FontWeight.w600,
      color: Colors.white70,
    );
    final quoteStyle = GoogleFonts.plusJakartaSans(
      fontSize: 15,
      height: 1.6,
      color: Colors.white.withValues(alpha: 0.88),
    );
    double maxTextBlockHeight = 0;
    for (final testimonial in _testimonials) {
      final quoteHeight = _measureTextHeight(
        testimonial.quote,
        quoteStyle,
        textWidth,
      );
      final nameHeight = _measureTextHeight(
        testimonial.name,
        nameStyle,
        textWidth,
      );
      final roleHeight = _measureTextHeight(
        testimonial.role.toUpperCase(),
        roleStyle,
        textWidth,
      );
      final blockHeight = nameHeight + 4 + roleHeight + 12 + quoteHeight;
      maxTextBlockHeight = math.max(maxTextBlockHeight, blockHeight);
    }
    final double contentHeight = stacked
        ? avatarSize + 18 + maxTextBlockHeight
        : math.max(avatarSize, maxTextBlockHeight);
    final double safety = stacked ? 70 : 40;
    return contentHeight + verticalPadding + safety;
  }

  double _measureTextHeight(String text, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  Widget _buildTestimonialControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          children: List.generate(_testimonials.length, (index) {
            final bool isActive = index == _testimonialPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              height: 8,
              width: isActive ? 28 : 8,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
        Row(
          children: [
            _buildCircleButton(
              icon: Icons.chevron_left,
              onTap: _testimonials.length > 1 ? _previousTestimonial : null,
            ),
            const SizedBox(width: 12),
            _buildCircleButton(
              icon: Icons.chevron_right,
              onTap: _testimonials.length > 1 ? _nextTestimonial : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleButton({required IconData icon, VoidCallback? onTap}) {
    final button = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(icon, color: Colors.white),
    );
    if (onTap == null) {
      return Opacity(opacity: 0.35, child: button);
    }
    return GestureDetector(onTap: onTap, child: button);
  }

  void _nextTestimonial() {
    final next = (_testimonialPage + 1) % _testimonials.length;
    setState(() => _testimonialPage = next);
  }

  void _previousTestimonial() {
    final prev = _testimonialPage == 0
        ? _testimonials.length - 1
        : _testimonialPage - 1;
    setState(() => _testimonialPage = prev);
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.data, required this.stacked});

  final _TestimonialData data;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 100,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF43D6FF), Color(0xFF1E6EEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ClipOval(
          child: homeDisableNetworkImagesForTests
              ? const SizedBox.shrink()
              : Image.network(data.avatarUrl, fit: BoxFit.cover),
        ),
      ),
    );
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.role.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          data.quote,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.6,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
    final child = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: avatar),
              const SizedBox(height: 20),
              textBlock,
            ],
          )
        : Row(
            children: [
              avatar,
              const SizedBox(width: 24),
              Expanded(child: textBlock),
            ],
          );
    return _GlassPanel(
      radius: 40,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      overlayColor: const Color(0x330C1E33),
      child: child,
    );
  }
}
