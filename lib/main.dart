import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/authentication/login_screen.dart';

const bool _showPerfOverlay =
    bool.fromEnvironment('ENABLE_PERF_OVERLAY', defaultValue: false);

bool _isRenderFlexOverflow(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  return message.contains('A RenderFlex overflowed');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final FlutterExceptionHandler? originalOnError = FlutterError.onError;
  final void Function(FlutterErrorDetails details) originalPresentError =
      FlutterError.presentError;
  FlutterError.presentError = (details) {
    if (_isRenderFlexOverflow(details)) return;
    originalPresentError(details);
  };
  FlutterError.onError = (details) {
    if (_isRenderFlexOverflow(details)) return;
    if (originalOnError != null) {
      originalOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF030816),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F55B5),
      secondary: const Color(0xFF68D4FF),
      surface: const Color(0xFFF5F9FF),
    );
    return MaterialApp(
      title: 'Auth Flutter',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: _showPerfOverlay,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: GoogleFonts.poppinsTextTheme(),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.85),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
