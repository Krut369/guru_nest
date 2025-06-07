import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF2196F3); // Material Blue
  static const accentColor = Color(0xFF64B5F6); // Sky blue
  static const backgroundColor = Color(0xFFF5F5F5); // Off-white
  static const surfaceColor = Colors.white;
  static const errorColor = Color(0xFFE57373);
  static const textColor = Color(0xFF2C3E50);
  static const textLightColor = Color(0xFF7F8C8D);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: accentColor,
          surface: surfaceColor,
          error: errorColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          color: surfaceColor.withOpacity(0.9),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: errorColor, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: textColor,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: textLightColor,
          ),
        ),
      );
}
