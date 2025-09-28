import 'package:flutter/material.dart';

// AppTheme with a pink/purple primary palette on a black/dark background.
// Input fields use a translucent 'bubbly' style (rounded, soft borders).
class AppTheme {
  // Primary / secondary colors
  // Deeper pink for a darker, richer look
  static const Color lilacPink = Color(0xFFE2B5FF);
  static const Color babyBlue = Color(0xFFAED4FF);
  static const Color midnight = Color(0xFF05060B);
  static const Color surface = Color(0xFF10121A);
  static const Color glassHighlight = Color(0xFFFFFFFF);

  static ThemeData get themeData {
    final colorScheme = ColorScheme.dark(
      primary: lilacPink,
      secondary: babyBlue,
      background: midnight,
      surface: surface,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: Colors.white,
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: midnight,
      canvasColor: surface,
      primaryColor: lilacPink,
      hintColor: Colors.white70,
      useMaterial3: false,

      // AppBar theme will use a subtle pink->purple gradient
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 18, fontWeight: FontWeight.w700),
      ),

      // Inputs: bubbly, translucent, rounded, slightly elevated
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: lilacPink.withOpacity(0.9), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.9), width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),

      // Elevated buttons follow the primary gradient
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lilacPink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
    );
  }

  static LinearGradient get appBarGradient => const LinearGradient(
        colors: [Color(0xFF6E4CF5), Color(0xFF8EC5FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
