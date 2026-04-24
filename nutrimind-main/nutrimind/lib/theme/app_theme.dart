import 'package:flutter/material.dart';
import 'modern_app_theme.dart';

class AppTheme {
  AppTheme._();

  // Compatibility layer for older screens. New UI should use ModernAppTheme
  // directly, while existing feature code can keep compiling safely.
  static const Color primaryGreen = ModernAppTheme.primaryGreen;
  static const Color secondaryOrange = ModernAppTheme.warning;
  static const Color accentGreen = ModernAppTheme.accentGreen;
  static const Color softGreen = ModernAppTheme.softGreen;
  static const Color bgGreen = ModernAppTheme.bgGreen;

  // Neutral Colors
  static const Color white = ModernAppTheme.white;
  static const Color surface = ModernAppTheme.surface;
  static const Color cardBackground = ModernAppTheme.cardBackground;

  // Text Colors
  static const Color textDark = ModernAppTheme.textDark;
  static const Color textMid = ModernAppTheme.textMid;
  static const Color textLight = ModernAppTheme.textLight;
  static const Color textHint = ModernAppTheme.textHint;

  // Status Colors
  static const Color success = ModernAppTheme.success;
  // Additional colors used throughout the app
  static const Color errorRed = ModernAppTheme.errorRed;
  static const Color darkGreen = ModernAppTheme.darkGreen;
  static const Color lightGreen = ModernAppTheme.lightGreen;
  static const Color orangeAccent = ModernAppTheme.orangeAccent;
  static const Color successGreen = ModernAppTheme.successGreen;
  static const Color warningOrange = ModernAppTheme.warningOrange;
  static const Color infoBlue = ModernAppTheme.infoBlue;
  static const Color warning = ModernAppTheme.warning;
  static const Color error = ModernAppTheme.error;
  static const Color info = ModernAppTheme.info;

  // Border and Dividers
  static const Color divider = ModernAppTheme.divider;
  static const Color border = ModernAppTheme.border;

  // Spacing Constants (16-20px safe margins)
  static const double spacingXs = ModernAppTheme.spacingXs;
  static const double spacingSm = ModernAppTheme.spacingSm;
  static const double spacingMd = ModernAppTheme.spacingMd;
  static const double spacingLg = ModernAppTheme.spacingLg;
  static const double spacingXl = ModernAppTheme.spacingXl;
  static const double spacingXxl = ModernAppTheme.spacingXxl;

  // Border Radius
  static const double radiusSm = ModernAppTheme.radiusSm;
  static const double radiusMd = ModernAppTheme.radiusMd;
  static const double radiusLg = ModernAppTheme.radiusLg;
  static const double radiusXl = ModernAppTheme.radiusXl;

  // Theme Data
  static ThemeData get lightTheme => ModernAppTheme.lightTheme;

  // Currency and Location
  static const String currency = ModernAppTheme.currency;
  static const String location = ModernAppTheme.location;
}
