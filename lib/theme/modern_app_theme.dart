import 'package:flutter/material.dart';

/// NutriMind Modern Design System v2.0
/// Premium, AI-powered nutrition & meal planning app
/// 
/// Design Philosophy:
/// - Clean, minimal layouts
/// - Soft pastel gradients
/// - Rounded cards & panels (16–28px)
/// - Subtle glassmorphism effects
/// - Airy spacing & breathing room
/// - Elegant typography
/// - Premium mobile feel

class ModernAppTheme {
  ModernAppTheme._();

  // ============================================================================
  // PRIMARY COLORS - Wellness Focus
  // ============================================================================
  
  /// Sage green - nature, health, growth
  static const Color primaryGreen = Color(0xFF2D6D4F);
  
  /// Bright green - positive, logged actions
  static const Color successGreen = Color(0xFF4CAF50);
  
  /// Light green - accents, highlights
  static const Color accentGreen = Color(0xFF81C784);
  
  /// Ultra light - backgrounds, soft containers
  static const Color softGreen = Color(0xFFE8F5E8);

  // ============================================================================
  // SECONDARY ACCENT COLORS - Wellness Accents
  // ============================================================================
  
  /// Fresh, clean, calming
  static const Color mint = Color(0xFFA8D8D8);
  
  /// Trust, calm, AI-related
  static const Color pastelBlue = Color(0xFFB3D9FF);
  
  /// Creative, wellness, balance
  static const Color pastelPurple = Color(0xFFE1BEE7);
  
  /// Warm, friendly, approachable
  static const Color pastelPink = Color(0xFFF8BBD0);
  
  /// Soft, welcoming, warm
  static const Color warmBlush = Color(0xFFFFE0E0);

  // ============================================================================
  // STATUS & FEEDBACK COLORS
  // ============================================================================
  
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // ============================================================================
  // NEUTRAL PALETTE
  // ============================================================================
  
  /// Pure white - cards, panels
  static const Color white = Color(0xFFFFFFFF);
  
  /// App background - light, airy
  static const Color backgroundNeutral = Color(0xFFFAFAFA);
  
  /// Section backgrounds
  static const Color lightGray = Color(0xFFF5F5F5);
  
  /// Dividers, borders
  static const Color mediumGray = Color(0xFFE8E8E8);
  
  /// Primary text
  static const Color textDark = Color(0xFF212121);
  
  /// Secondary text
  static const Color textMid = Color(0xFF757575);
  
  /// Tertiary text
  static const Color textLight = Color(0xFFBDBDBD);
  
  /// Placeholder, hint text
  static const Color textHint = Color(0xFF9E9E9E);

  // ============================================================================
  // SPACING SYSTEM (Base: 8px)
  // ============================================================================
  
  static const double spacingXs = 4.0;    // Minimal spacing
  static const double spacingSm = 8.0;    // Small padding
  static const double spacingMd = 12.0;   // Standard padding
  static const double spacingLg = 16.0;   // Card padding, section margins
  static const double spacingXl = 20.0;   // Large margins
  static const double spacingXxl = 24.0;  // Extra large spacing
  static const double spacingXxxl = 32.0; // Screen margins

  // ============================================================================
  // BORDER RADIUS (Rounded corners for premium feel)
  // ============================================================================
  
  static const double radiusSm = 8.0;     // Small components (chips, buttons)
  static const double radiusMd = 12.0;    // Medium components (inputs, cards)
  static const double radiusLg = 16.0;    // Large components (cards, dialogs)
  static const double radiusXl = 20.0;    // Extra large (premium cards)
  static const double radiusXxl = 28.0;   // Rounded buttons, large cards

  // ============================================================================
  // SHADOW SYSTEM (Soft, subtle shadows)
  // ============================================================================
  
  static const List<BoxShadow> shadowNone = [];
  
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];
  
  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> shadowXl = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  // ============================================================================
  // GRADIENT SYSTEM (Soft, premium gradients)
  // ============================================================================
  
  /// Primary green gradient (for buttons, CTAs)
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [primaryGreen, successGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Mint gradient (for accents)
  static const LinearGradient gradientMint = LinearGradient(
    colors: [mint, pastelBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Warm gradient (for wellness features)
  static const LinearGradient gradientWarm = LinearGradient(
    colors: [pastelPink, warmBlush],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================================
  // TYPOGRAPHY SCALE
  // ============================================================================
  
  static const TextStyle heroTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: textDark,
    height: 1.2,
  );
  
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textDark,
    height: 1.2,
  );
  
  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textDark,
    height: 1.2,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textDark,
    height: 1.6,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textDark,
    height: 1.6,
  );
  
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textDark,
    height: 1.4,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMid,
    height: 1.4,
  );
  
  static const TextStyle captionSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textLight,
    height: 1.4,
  );

  // ============================================================================
  // FLUTTER THEME
  // ============================================================================
  
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    
    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: mint,
      tertiary: pastelPurple,
      surface: white,
      background: backgroundNeutral,
      error: error,
      onPrimary: white,
      onSecondary: textDark,
      onSurface: textDark,
      onBackground: textDark,
      onError: white,
    ),
    
    // Global background
    scaffoldBackgroundColor: backgroundNeutral,
    
    // ========================================================================
    // APP BAR
    // ========================================================================
    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 2,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textDark,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: textDark, size: 24),
    ),
    
    // ========================================================================
    // BUTTONS
    // ========================================================================
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: primaryGreen, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // ========================================================================
    // INPUTS & FORMS
    // ========================================================================
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: mediumGray, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: mediumGray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      labelStyle: const TextStyle(
        color: textMid,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        color: textHint,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      errorStyle: const TextStyle(
        color: error,
        fontSize: 12,
      ),
      prefixIconColor: textMid,
      suffixIconColor: textMid,
    ),
    
    // ========================================================================
    // CARDS
    // ========================================================================
    cardTheme: const CardThemeData(
      color: white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
        side: BorderSide(color: mediumGray, width: 0.5),
      ),
      margin: EdgeInsets.all(spacingMd),
    ),
    
    // ========================================================================
    // DIALOGS & MODALS
    // ========================================================================
    dialogTheme: const DialogTheme(
      backgroundColor: white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusXl)),
      ),
    ),
    
    // ========================================================================
    // CHIPS
    // ========================================================================
    chipTheme: const ChipThemeData(
      backgroundColor: softGreen,
      selectedColor: primaryGreen,
      disabledColor: mediumGray,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
      ),
      labelStyle: TextStyle(
        color: primaryGreen,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    
    // ========================================================================
    // BOTTOM SHEET
    // ========================================================================
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radiusXl),
          topRight: Radius.circular(radiusXl),
        ),
      ),
    ),
    
    // ========================================================================
    // FLOATING ACTION BUTTON
    // ========================================================================
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryGreen,
      foregroundColor: white,
      elevation: 8,
      shape: CircleBorder(),
    ),
    
    // ========================================================================
    // SNACKBAR
    // ========================================================================
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: textDark,
      contentTextStyle: TextStyle(
        color: white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
      ),
      elevation: 6,
      behavior: SnackBarBehavior.floating,
    ),
    
    // ========================================================================
    // DIVIDER
    // ========================================================================
    dividerTheme: const DividerThemeData(
      color: mediumGray,
      thickness: 0.5,
      space: 16,
    ),
  );

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================
  
  /// Get gradient for BMI category
  static LinearGradient getBmiGradient(String category) {
    switch (category.toLowerCase()) {
      case 'underweight':
        return const LinearGradient(
          colors: [pastelBlue, Color(0xFF81D4FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'normal':
        return const LinearGradient(
          colors: [primaryGreen, successGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'overweight':
        return const LinearGradient(
          colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'obese':
        return const LinearGradient(
          colors: [error, Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return gradientPrimary;
    }
  }
  
  /// Get color for macro label
  static Color getMacroColor(String macroType) {
    switch (macroType.toLowerCase()) {
      case 'protein':
        return info;
      case 'carbs':
        return warning;
      case 'fat':
        return error;
      default:
        return primaryGreen;
    }
  }

  // ============================================================================
  // CONSTANTS
  // ============================================================================
  
  static const String currency = '₱';
  static const String location = 'Davao City, Philippines';
  static const String appName = 'NutriMind';
  static const String tagline = 'Your AI Nutrition Assistant';
}
