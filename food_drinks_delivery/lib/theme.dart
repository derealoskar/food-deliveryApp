import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// User-selectable theme (System / Light / Dark). Persist with shared_preferences if desired.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

class AppTheme {
  static const brand = Color(0xFFC62828); // deep red
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    // Neutral warm greys for surfaces/containers (no pink tints); red is used only as the accent.
    final cs = ColorScheme.fromSeed(seedColor: brand, brightness: b).copyWith(
      primary: dark ? const Color(0xFFE53935) : brand,
      onPrimary: Colors.white,
      primaryContainer: dark ? const Color(0xFF2E2A28) : const Color(0xFFECE8E5),
      onPrimaryContainer: dark ? Colors.white : const Color(0xFF1C1B1A),
      secondaryContainer: dark ? const Color(0xFF2E2A28) : const Color(0xFFECE8E5),
      surface: dark ? const Color(0xFF161413) : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF1F1D1C) : const Color(0xFFF7F5F3),
      surfaceContainerHigh: dark ? const Color(0xFF2A2725) : const Color(0xFFEFEBE8),
      surfaceContainerHighest: dark ? const Color(0xFF353230) : const Color(0xFFE6E2DF),
    );
    OutlineInputBorder border([Color? c]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: c == null ? BorderSide.none : BorderSide(color: c, width: 1.5));
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: dark ? const Color(0xFF121110) : const Color(0xFFF6F4F2),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: dark ? const Color(0xFF121110) : const Color(0xFFF6F4F2),
        foregroundColor: dark ? Colors.white : const Color(0xFF1C1B1A),
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        border: border(),
        focusedBorder: border(cs.primary),
        errorBorder: border(cs.error),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      snackBarTheme: SnackBarThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}
