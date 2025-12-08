part of 'package:marco/features/home/home_screen.dart';

const _backgroundGradient = AuroraPalette.sky;
const _ctaBlue = Color(0xFF1FA2FF);
const _ctaTeal = Color(0xFF2CD5FF);
const _imageFallbackGradient = LinearGradient(
  colors: [Color(0xFF132548), Color(0xFF1E3C6B)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

@visibleForTesting
bool disableFadeSlideInAnimationsForTests = false;

Widget _buildNetworkImage(String url, {BoxFit fit = BoxFit.cover}) {
  final placeholder = DecoratedBox(
    decoration: const BoxDecoration(gradient: _imageFallbackGradient),
    child: const Center(
      child: Icon(Icons.image_outlined, color: Colors.white70),
    ),
  );
  if (url.isEmpty) return placeholder;
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return placeholder;
    },
    errorBuilder: (_, __, ___) => placeholder,
  );
}

class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.12),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> {
  bool _visible = false;
  late final Key _visibilityKey;

  @override
  void initState() {
    super.initState();
    _visibilityKey = UniqueKey();
  }

  Future<void> _trigger() async {
    if (_visible) return;
    if (disableFadeSlideInAnimationsForTests) {
      if (mounted) {
        setState(() => _visible = true);
      }
      return;
    }
    await Future.delayed(widget.delay);
    if (mounted) {
      setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 650);
    if (disableFadeSlideInAnimationsForTests) {
      return widget.child;
    }
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (!_visible && info.visibleFraction > 0.25) {
          _trigger();
        }
      },
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : widget.offset,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: duration,
          child: widget.child,
        ),
      ),
    );
  }
}
