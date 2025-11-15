import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';

const bool _showPerfOverlay =
    bool.fromEnvironment('ENABLE_PERF_OVERLAY', defaultValue: false);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
