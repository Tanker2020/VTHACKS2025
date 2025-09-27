import 'package:flutter/material.dart';

// AppTheme with a pink/purple primary palette on a black/dark background.
// Input fields use a translucent 'bubbly' style (rounded, soft borders).
class AppTheme {
  // Primary / secondary colors
  static const Color primaryPink = Color(0xFFFF4DA6); // vivid pink
  static const Color purpleAccent = Color(0xFF9B59FF); // purple
  static const Color deepBlack = Color(0xFF050507);
  static const Color surfaceDark = Color(0xFF0B0B0D);
  static const Color mutedWhite = Color(0xFFFAFAFA);

  static ThemeData get themeData {
    final colorScheme = ColorScheme.dark(
      primary: primaryPink,
      secondary: purpleAccent,
      background: deepBlack,
      surface: surfaceDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: mutedWhite,
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deepBlack,
      canvasColor: surfaceDark,
      primaryColor: primaryPink,
      hintColor: Colors.white70,
      useMaterial3: false,

      // AppBar theme will use a subtle pink->purple gradient
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      ),

      // Inputs: bubbly, translucent, rounded, slightly elevated
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryPink.withOpacity(0.9), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.9), width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.03)),
        ),
      ),

      // Elevated buttons follow the primary gradient
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
    );
  }

  static LinearGradient get appBarGradient => const LinearGradient(
        colors: [Color(0xFF2A0A1F), Color(0xFF5B2EFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
