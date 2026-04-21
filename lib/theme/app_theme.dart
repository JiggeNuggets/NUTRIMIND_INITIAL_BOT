import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Modern Light Mode Colors - Davao City, Philippines Theme
  static const Color primaryGreen = Color(0xFF4CAF50);    // Soft Green
  static const Color secondaryOrange = Color(0xFFFF9800); // Soft Orange
  static const Color accentGreen = Color(0xFF81C784);     // Light Green
  static const Color softGreen = Color(0xFFE8F5E8);       // Very Light Green
  static const Color bgGreen = Color(0xFFF1F8E9);         // Background Green

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFAFAFA);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textDark = Color(0xFF212121);
  static const Color textMid = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);
  static const Color textHint = Color(0xFF9E9E9E);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  // Additional colors used throughout the app
  static const Color errorRed = Color(0xFFF44336);
  static const Color darkGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF81C784);
  static const Color orangeAccent = Color(0xFFFF9800);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color infoBlue = Color(0xFF2196F3);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Border and Dividers
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFE8E8E8);

  // Spacing Constants (16-20px safe margins)
  static const double spacingXs = 8.0;
  static const double spacingSm = 12.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 20.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;

  // Theme Data
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: secondaryOrange,
      surface: surface,
      background: white,
      onPrimary: white,
      onSecondary: textDark,
      onSurface: textDark,
      onBackground: textDark,
    ),
    scaffoldBackgroundColor: bgGreen,
    cardColor: cardBackground,
    dividerColor: divider,

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
    ),

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: primaryGreen),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
      labelStyle: const TextStyle(color: textMid),
      hintStyle: const TextStyle(color: textHint),
    ),

    // Card Theme
    cardTheme: const CardThemeData(
      color: cardBackground,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
      ),
      margin: EdgeInsets.all(spacingMd),
    ),
  );

  // Currency and Location
  static const String currency = '?';
  static const String location = 'Davao City, Philippines';
}
