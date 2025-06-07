import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryBlueLight = Color(0xFF64B5F6);
  static const Color primaryBlueDark = Color(0xFF1976D2);

  // Background Colors
  static const Color backgroundWhite = Colors.white;
  static const Color backgroundGrey = Color(0xFFF5F5F5);
  static const Color backgroundLightGrey = Color(0xFFFAFAFA);

  // Text Colors
  static const Color textDark = Color(0xFF333333);
  static const Color textGrey = Color(0xFF7F8C8D);
  static const Color textLightGrey = Color(0xFF95A5A6);

  // Status Colors
  static const Color successGreen = Color(0xFF43A047);
  static const Color errorRed = Color(0xFFE53935);
  static const Color warningOrange = Color(0xFFFFB74D);

  // Border Colors
  static const Color borderGrey = Color(0xFFE0E0E0);
  static const Color borderLightGrey = Color(0xFFEEEEEE);

  // Gradient Colors
  static const List<Color> primaryGradient = [
    primaryBlue,
    primaryBlueLight,
  ];

  // Font Family
  static const String _fontFamily = 'Noto Sans';

  // Theme Data
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: const ColorScheme.light(
          primary: primaryBlue,
          secondary: primaryBlueLight,
          surface: backgroundWhite,
          error: errorRed,
        ),
        scaffoldBackgroundColor: backgroundWhite,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: backgroundWhite,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: backgroundGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: errorRed, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: backgroundWhite,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: textDark,
            fontFamily: _fontFamily,
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textDark,
            fontFamily: _fontFamily,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: textDark,
            fontFamily: _fontFamily,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: textGrey,
            fontFamily: _fontFamily,
          ),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: backgroundWhite,
            fontFamily: _fontFamily,
          ),
        ),
      );

  // Common Decorations
  static BoxDecoration get inputDecoration => BoxDecoration(
        color: backgroundGrey,
        borderRadius: BorderRadius.circular(12),
      );

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration get headerDecoration => const BoxDecoration(
        gradient: LinearGradient(
          colors: primaryGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(100),
        ),
      );

  // Common Text Styles
  static const TextStyle headerStyle = TextStyle(
    fontSize: 30,
    color: backgroundWhite,
    fontWeight: FontWeight.bold,
    fontFamily: _fontFamily,
  );

  static const TextStyle subheaderStyle = TextStyle(
    fontSize: 18,
    color: textGrey,
    fontWeight: FontWeight.w500,
    fontFamily: _fontFamily,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: backgroundWhite,
    fontFamily: _fontFamily,
  );

  // Common Spacing
  static const double defaultPadding = 24.0;
  static const double defaultSpacing = 16.0;
  static const double smallSpacing = 8.0;
}
