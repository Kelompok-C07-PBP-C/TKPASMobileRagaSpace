import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api.dart';
import '../widgets/aurora_route.dart';
import '../widgets/gradient_button.dart';
import '../widgets/hero_slideshow.dart';
import 'register_screen.dart';
import 'loading_screen.dart';

const _loginBackground = LinearGradient(
  colors: [Color(0xFF050913), Color(0xFF0C1C33), Color(0xFF172654)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _remember = true;
  bool _obscure = true;
  String? _error;
  late final AnimationController _nebulaController;

  @override
  void initState() {
    super.initState();
    _nebulaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Api().login(_userCtrl.text.trim(), _passCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Signed in successfully')));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          AuroraWarpRoute(const LoadingScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nebulaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: _loginBackground),
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _nebulaController,
                  builder: (_, __) =>
                      _LoginAurora(phase: _nebulaController.value),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 64,
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 50, end: 0),
                          duration: const Duration(milliseconds: 850),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) =>
                              Transform.translate(
                                offset: Offset(0, value),
                                child: child,
                              ),
                          child: _buildCard(theme),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme) {
    final decorationTheme = theme.inputDecorationTheme.copyWith(
          fillColor: Colors.white.withValues(alpha: 0.12),
          labelStyle: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xF016264D),
              Color(0xE0123A63),
              Color(0xC0116B76),
            ],
            stops: [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(38),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1BD7A1).withValues(alpha: 0.45),
              blurRadius: 42,
              spreadRadius: 4,
              offset: const Offset(0, 28),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HeroSlideshow(),
            const SizedBox(height: 28),
            Text(
              'Login',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Welcome back! Please sign in to continue.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    controller: _userCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      filled: true,
                    ).applyDefaults(decorationTheme),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter username' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      filled: true,
                    ).applyDefaults(decorationTheme),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 10),
                  _buildRememberRow(theme),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: (_error == null)
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _error!,
                              key: const ValueKey('error'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  GradientButton(
                    label: 'Sign In',
                    onPressed: _loading ? null : _login,
                    loading: _loading,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                child: const Text(
                  "Don't have an account? Sign Up",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRememberRow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.alarm_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder me next time',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'We will keep you signed in securely.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _remember,
            onChanged: (value) => setState(() => _remember = value),
            activeTrackColor: Colors.white.withValues(alpha: 0.35),
            thumbColor: WidgetStateProperty.all(Colors.white),
          ),
        ],
      ),
    );
  }
}

class _LoginAurora extends StatelessWidget {
  const _LoginAurora({required this.phase});

  final double phase;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(phase * 2 * math.pi);
    final swell = math.cos(phase * 2 * math.pi);
    return IgnorePointer(
      child: Stack(
        children: [
          _halo(
            alignment: Alignment(-0.8 + wave * 0.08, -0.85 + swell * 0.05),
            radius: 420 + wave * 30,
            color: const Color(0x994E7BFF),
          ),
          _halo(
            alignment: Alignment(0.9 + swell * 0.1, -0.7 + wave * 0.04),
            radius: 360 + swell * 34,
            color: const Color(0x88FF8EC7),
          ),
          _halo(
            alignment: Alignment(0.0 + wave * 0.09, 0.7 + swell * 0.07),
            radius: 520 + wave * 40,
            color: const Color(0x6635F7FF),
          ),
          Positioned(
            top: 160 + swell * 20,
            left: -140 + wave * 24,
            child: _ribbon(
              width: 320,
              height: 260,
              colors: const [Color(0x22FFFFFF), Color(0x0051F6FF)],
            ),
          ),
          Positioned(
            right: -130 + wave * 26,
            bottom: 90 + swell * 18,
            child: _ribbon(
              width: 280,
              height: 280,
              colors: const [Color(0x10FFFFFF), Color(0x4045AFFF)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ribbon({
    required double width,
    required double height,
    required List<Color> colors,
  }) {
    return Transform.rotate(
      angle: -0.45,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  Widget _halo({
    required Alignment alignment,
    required double radius,
    required Color color,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 160,
              spreadRadius: 16,
            ),
          ],
        ),
      ),
    );
  }
}
