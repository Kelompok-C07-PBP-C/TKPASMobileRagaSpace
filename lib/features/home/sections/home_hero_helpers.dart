part of 'package:marco/features/home/home_screen.dart';

class _HighlightInfoCard extends StatelessWidget {
  const _HighlightInfoCard({required this.data});

  final _HighlightCardData data;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(20),
      overlayColor: data.gradient.first.withValues(alpha: 0.18),
      borderColor: data.gradient.last.withValues(alpha: 0.4),
      boxShadow: [
        BoxShadow(
          color: data.gradient.last.withValues(alpha: 0.28),
          blurRadius: 35,
          offset: const Offset(0, 20),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: Colors.white, size: 28),
          const Spacer(),
          Text(
            data.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(24),
    this.overlayColor = const Color(0x3310213A),
    this.borderColor,
    this.boxShadow,
    this.useGradient = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color overlayColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: useGradient ? AuroraPalette.glassGradient(overlayColor) : null,
      color: useGradient ? null : overlayColor,
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.12),
      ),
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 20),
            ),
          ],
    );
    return Container(padding: padding, decoration: decoration, child: child);
  }
}

class _ExploreVenuesCard extends StatelessWidget {
  const _ExploreVenuesCard();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 28,
      padding: const EdgeInsets.all(24),
      overlayColor: const Color(0x3314294D),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF46E4C1), Color(0xFF23A8E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.explore_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Explore curated venues',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tim kami memilih venue dengan rating terbaik, fasilitas terawat, dan pengalaman booking paling mulus.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              textStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Flexible(
                  child: Text(
                    'Lihat panduan lengkap',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.data, this.width});

  final _CategoryChipData data;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0x3328C4FF), Color(0x12258DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              data.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: _categoryChipTextStyle(),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _categoryChipTextStyle() => GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

double _calculateChipWidth(String label) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: _categoryChipTextStyle()),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  const double horizontalPadding = 18 * 2;
  const double iconWidth = 18;
  const double iconGap = 8;
  return painter.width + horizontalPadding + iconWidth + iconGap;
}

enum _AuroraBackdropStyle { standard, detail }

class _StaticAuroraBackdrop extends StatelessWidget {
  const _StaticAuroraBackdrop({this.style = _AuroraBackdropStyle.standard});

  final _AuroraBackdropStyle style;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _StaticAuroraPainter(style)),
      ),
    );
  }
}

class _StaticAuroraPainter extends CustomPainter {
  const _StaticAuroraPainter(this.style);

  final _AuroraBackdropStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final ribbons = _buildRibbons(style);
    for (final ribbon in ribbons) {
      _paintRibbon(canvas, size, ribbon);
    }
    _paintStarfield(canvas, size);
    _paintHorizonGlow(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _StaticAuroraPainter oldDelegate) {
    return oldDelegate.style != style;
  }
}

class _AuroraRibbon {
  const _AuroraRibbon({
    required this.start,
    required this.end,
    required this.control1,
    required this.control2,
    required this.thickness,
    required this.colors,
    this.blur = 90,
  });

  final Offset start;
  final Offset end;
  final Offset control1;
  final Offset control2;
  final double thickness;
  final List<Color> colors;
  final double blur;
}

  List<_AuroraRibbon> _buildRibbons(_AuroraBackdropStyle style) {
  final bright = style == _AuroraBackdropStyle.detail
      ? const [Color(0xFF5EECFF), Color(0x8826FFC8)]
      : const [Color(0xFF60F3FF), Color(0x6624FFD5)];
  final mid = style == _AuroraBackdropStyle.detail
      ? const [Color(0xFF3BC3FF), Color(0x5523A8FF)]
      : const [Color(0xFF40C5FF), Color(0x553497FF)];
  final soft = style == _AuroraBackdropStyle.detail
      ? const [Color(0xFF2DF1C1), Color(0x3324A0FF)]
      : const [Color(0xFF2DF1C1), Color(0x332486FF)];
  return [
    _AuroraRibbon(
      start: const Offset(-0.1, 0.2),
      end: const Offset(0.35, 0.95),
      control1: const Offset(0.1, 0.1),
      control2: const Offset(0.15, 0.65),
      thickness: 0.09,
      colors: bright,
    ),
    _AuroraRibbon(
      start: const Offset(0.1, 0.05),
      end: const Offset(0.7, 0.9),
      control1: const Offset(0.25, 0.0),
      control2: const Offset(0.5, 0.7),
      thickness: 0.08,
      colors: mid,
      blur: 110,
    ),
    _AuroraRibbon(
      start: const Offset(0.6, 0.08),
      end: const Offset(1.05, 0.85),
      control1: const Offset(0.75, 0.12),
      control2: const Offset(0.9, 0.65),
      thickness: 0.07,
      colors: soft,
    ),
  ];
}

void _paintRibbon(Canvas canvas, Size size, _AuroraRibbon ribbon) {
  final start = Offset(
    ribbon.start.dx * size.width,
    ribbon.start.dy.clamp(0.0, 1.0) * size.height,
  );
  final end = Offset(
    ribbon.end.dx * size.width,
    ribbon.end.dy.clamp(0.0, 1.0) * size.height,
  );
  final c1 = Offset(
    ribbon.control1.dx * size.width,
    ribbon.control1.dy.clamp(0.0, 1.0) * size.height,
  );
  final c2 = Offset(
    ribbon.control2.dx * size.width,
    ribbon.control2.dy.clamp(0.0, 1.0) * size.height,
  );
  final thickness = ribbon.thickness * size.width;
  final path = Path()
    ..moveTo(start.dx - thickness, start.dy)
    ..cubicTo(
      c1.dx - thickness * 0.6,
      c1.dy,
      c2.dx - thickness * 0.4,
      c2.dy,
      end.dx - thickness * 0.2,
      end.dy,
    )
    ..lineTo(end.dx + thickness, end.dy)
    ..cubicTo(
      c2.dx + thickness * 0.4,
      c2.dy,
      c1.dx + thickness * 0.6,
      c1.dy,
      start.dx + thickness,
      start.dy,
    )
    ..close();

  final shader = LinearGradient(
    colors: ribbon.colors,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromPoints(start, end));

  final paint = Paint()
    ..shader = shader
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, ribbon.blur);
  canvas.drawPath(path, paint);
}

void _paintStarfield(Canvas canvas, Size size) {
  final starPaint = Paint()..style = PaintingStyle.fill;
  final stars = <Offset>[
    const Offset(0.1, 0.12),
    const Offset(0.18, 0.28),
    const Offset(0.32, 0.08),
    const Offset(0.48, 0.2),
    const Offset(0.58, 0.05),
    const Offset(0.7, 0.18),
    const Offset(0.82, 0.12),
    const Offset(0.9, 0.3),
  ];
  for (var i = 0; i < stars.length; i++) {
    final star = stars[i];
    final radius = size.shortestSide * (0.002 + (i % 3) * 0.001);
    starPaint.color = Colors.white.withValues(alpha: 0.15 + (i % 3) * 0.1);
    canvas.drawCircle(
      Offset(star.dx * size.width, star.dy * size.height),
      radius,
      starPaint,
    );
  }
}

  void _paintHorizonGlow(Canvas canvas, Size size) {
  final rect = Rect.fromLTWH(0, size.height * 0.4, size.width, size.height);
  final gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: const [
      Color(0x002AF0FF),
      Color(0x1429E7FF),
      Color(0x2625B4FF),
      Color(0x0F0B1C30),
      Color(0x00010208),
    ],
    stops: const [0.0, 0.35, 0.65, 0.85, 1.0],
  );
  final paint = Paint()..shader = gradient.createShader(rect);
  canvas.drawRect(rect, paint);
}

class _CategoryMarqueeRow extends StatelessWidget {
  const _CategoryMarqueeRow({
    required this.data,
    required this.animation,
    this.phase = 0,
    this.reverse = false,
  });

  final List<_CategoryChipData> data;
  final Animation<double> animation;
  final double phase;
  final bool reverse;

  static const double _spacing = 10;

  @override
  Widget build(BuildContext context) {
    final widths = data
        .map((category) => _calculateChipWidth(category.label))
        .toList();
    if (data.length <= 2) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < data.length; i++) ...[
            _CategoryChip(data: data[i], width: widths[i]),
            if (i != data.length - 1) const SizedBox(width: _spacing),
          ],
        ],
      );
    }
    // coverage:ignore-start
    final baseWidth =
        widths.fold<double>(0, (sum, width) => sum + width) +
        (data.length - 1) * _spacing;
    if (baseWidth <= 0) return const SizedBox();

    final sequence = _buildSequence(widths);
    final travel = baseWidth + _spacing;
    final tape = SizedBox(
      width: travel * 2,
      child: Row(
        children: [
          ...sequence,
          const SizedBox(width: _spacing),
          ...sequence,
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : baseWidth;
        return SizedBox(
          width: viewportWidth,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final progress = ((animation.value + phase) % 1.0);
                final shift = progress * travel;
                final dx = reverse ? shift - travel : -shift;
                return Transform.translate(offset: Offset(dx, 0), child: tape);
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSequence(List<double> widths) {
    final children = <Widget>[];
    for (var i = 0; i < data.length; i++) {
      children.add(_CategoryChip(data: data[i], width: widths[i]));
      if (i != data.length - 1) {
        children.add(const SizedBox(width: _spacing));
      }
    }
    return children;
  }
}

// -- Test helpers -------------------------------------------------------------

@visibleForTesting
Widget buildHighlightInfoCardForTests() {
  const data = _HighlightCardData(
    title: 'Highlight title',
    subtitle: 'Highlight subtitle',
    gradient: [Color(0xFF3EC9FF), Color(0xFF5B7CFF)],
    icon: Icons.star_rounded,
  );
  return const _HighlightInfoCard(data: data);
}

@visibleForTesting
Widget buildGlassPanelForTests({bool useGradient = true}) {
  return _GlassPanel(
    useGradient: useGradient,
    overlayColor: const Color(0x5510213A),
    child: const Text('Glass panel'),
  );
}

@visibleForTesting
Widget buildExploreVenuesCardForTests() => const _ExploreVenuesCard();

@visibleForTesting
Widget buildStaticAuroraBackdropForTests({bool detail = false}) {
  return _StaticAuroraBackdrop(
    style:
        detail ? _AuroraBackdropStyle.detail : _AuroraBackdropStyle.standard,
  );
}

@visibleForTesting
Widget buildCategoryMarqueeRowShortForTests(Animation<double> animation) {
  const data = [
    _CategoryChipData(label: 'Tennis', icon: Icons.sports_tennis),
    _CategoryChipData(label: 'Badminton', icon: Icons.sports),
  ];
  return _CategoryMarqueeRow(data: data, animation: animation);
}

@visibleForTesting
bool debugStaticAuroraShouldRepaintForTests() {
  const a = _StaticAuroraPainter(_AuroraBackdropStyle.standard);
  const b = _StaticAuroraPainter(_AuroraBackdropStyle.detail);
  final repaintDifferent = a.shouldRepaint(b);
  final repaintSame = a.shouldRepaint(a);
  return repaintDifferent && !repaintSame;
}
// coverage:ignore-end
