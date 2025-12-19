import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminPalette {
  const AdminPalette._();

  static const Color backgroundBase = Color(0xFF020617);
  static const Color backgroundMuted = Color(0xFF050816);
  static const Color surfaceCard = Color(0xC70F172A); // rgba(15, 23, 42, 0.78)
  static const Color surfaceElevated = Color(0xEB0F172A); // rgba(15, 23, 42, 0.92)
  static const Color surfaceHover = Color(0x1F94A3B8); // rgba(148, 163, 184, 0.12)
  static const Color border = Color(0x2E94A3B8); // rgba(148, 163, 184, 0.18)
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);

  static const Color accent = Color(0xFF3B82F6);
  static const Color accentHover = Color(0xFF2563EB);
  static const Color danger = Color(0xFFF87171);
  static const Color success = Color(0xFF10B981);

  static const Color inputBg = Color(0xBF0F172A); // rgba(15, 23, 42, 0.75)

  static const Color salesLine = Color(0xFFEA580C);

  static const List<Color> popularityPalette = <Color>[
    Color(0xFFEA580C),
    Color(0xFFF97316),
    Color(0xFFFB923C),
    Color(0xFFFACC15),
    Color(0xFF38D4C3),
    Color(0xFFC084FC),
    Color(0xFFF472B6),
    Color(0xFFFB7185),
  ];
}

ThemeData buildAdminThemeData(ThemeData base) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AdminPalette.accent,
    brightness: Brightness.dark,
    primary: AdminPalette.accent,
    secondary: const Color(0xFF14B8A6),
    error: AdminPalette.danger,
    surface: AdminPalette.surfaceElevated.withValues(alpha: 1.0),
  );

  final rounded = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: AdminPalette.border),
  );

  return base.copyWith(
    colorScheme: scheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: AdminPalette.textPrimary,
      displayColor: AdminPalette.textPrimary,
    ),
    iconTheme: base.iconTheme.copyWith(color: AdminPalette.textPrimary),
    dividerColor: AdminPalette.border,
    appBarTheme: const AppBarTheme(
      backgroundColor: AdminPalette.surfaceElevated,
      foregroundColor: AdminPalette.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminPalette.inputBg,
      border: rounded,
      enabledBorder: rounded,
      focusedBorder: rounded.copyWith(
        borderSide: const BorderSide(color: AdminPalette.accent, width: 1.2),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: AdminPalette.textSecondary.withValues(alpha: 0.75),
      ),
      labelStyle: GoogleFonts.plusJakartaSans(
        color: AdminPalette.textSecondary.withValues(alpha: 0.82),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AdminPalette.surfaceElevated.withValues(alpha: 0.98),
      contentTextStyle: GoogleFonts.plusJakartaSans(color: AdminPalette.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AdminPalette.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        color: AdminPalette.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
      contentTextStyle: GoogleFonts.plusJakartaSans(
        color: AdminPalette.textPrimary.withValues(alpha: 0.9),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: AdminPalette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AdminPalette.success
            : AdminPalette.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AdminPalette.success.withValues(alpha: 0.35)
            : AdminPalette.textSecondary.withValues(alpha: 0.25),
      ),
    ),
  );
}
