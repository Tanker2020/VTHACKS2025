import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF6A4CFF);
  static const Color secondary = Color(0xFF00D4FF);

  static ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark, primary: primary, secondary: secondary);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0B0B12),
      appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, foregroundColor: colorScheme.onPrimary),
      textTheme: Typography.blackMountainView.apply(bodyColor: Colors.white),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
  cardColor: const Color(0xFF0F1720),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: primary, elevation: 6),
    );
  }

  // Gradient helpers
  static LinearGradient get appBarGradient => const LinearGradient(colors: [primary, secondary], begin: Alignment.topLeft, end: Alignment.bottomRight);
}
