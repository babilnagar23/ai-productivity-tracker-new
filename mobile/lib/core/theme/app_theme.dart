import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const _dark = _AppPalette(
    bg: Color(0xFF050505),
    sidebar: Color(0xFF0A0A0D),
    card: Color(0xFF141418),
    cardElevated: Color(0xFF1A1A20),
    nav: Color(0xFF141418),
    border: Color(0xFF2A2A33),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB8B8C5),
    textMuted: Color(0xFF8A8A98),
    purple: Color(0xFFB18CFF),
    purpleDark: Color(0xFF8E5DFF),
    purpleLight: Color(0xFFC7B2FF),
    blue: Color(0xFF7DA6FF),
    cyan: Color(0xFF06B6D4),
    success: Color(0xFF2DD881),
    error: Color(0xFFFF5D73),
    warning: Color(0xFFFFC857),
    gradientStart: Color(0xFFC6A5FF),
    gradientEnd: Color(0xFF7DA6FF),
  );

  static const _light = _AppPalette(
    bg: Color(0xFFF8F8F6),
    sidebar: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardElevated: Color(0xFFF2F4F4),
    nav: Color(0xFFFFFFFF),
    border: Color(0xFFE6E8EC),
    textPrimary: Color(0xFF101114),
    textSecondary: Color(0xFF4E5563),
    textMuted: Color(0xFF8A909D),
    purple: Color(0xFF8E5DFF),
    purpleDark: Color(0xFF6E3FE8),
    purpleLight: Color(0xFFE6D9FF),
    blue: Color(0xFF7DA6FF),
    cyan: Color(0xFF06B6D4),
    success: Color(0xFF0E9F6E),
    error: Color(0xFFE5485D),
    warning: Color(0xFFE5A500),
    gradientStart: Color(0xFFC6A5FF),
    gradientEnd: Color(0xFF7DA6FF),
  );

  static _AppPalette _active = _dark;

  static void setThemeMode(ThemeMode mode) {
    _active = mode == ThemeMode.light ? _light : _dark;
  }

  static bool get isLight => identical(_active, _light);

  // Current active palette
  static Color get bg => _active.bg;
  static Color get sidebar => _active.sidebar;
  static Color get card => _active.card;
  static Color get cardElevated => _active.cardElevated;
  static Color get nav => _active.nav;
  static Color get border => _active.border;
  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textMuted => _active.textMuted;
  static Color get purple => _active.purple;
  static Color get purpleDark => _active.purpleDark;
  static Color get purpleLight => _active.purpleLight;
  static Color get blue => _active.blue;
  static Color get cyan => _active.cyan;
  static Color get success => _active.success;
  static Color get error => _active.error;
  static Color get warning => _active.warning;
  static Color get gradientStart => _active.gradientStart;
  static Color get gradientEnd => _active.gradientEnd;

  // Legacy aliases kept for existing UI code
  static Color get surface => card;
  static Color get surfaceLight => cardElevated;
  static Color get bgSecondary => sidebar;
  static Color get divider => border;
  static const Color borderPurple = Color(0x4DB18CFF);

  // Keep this const so existing `const [AppColors.cardShadow]` patterns still work.
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 24,
    spreadRadius: 0,
    offset: Offset(0, 8),
  );

  static BorderRadius get cardRadius => BorderRadius.circular(18);
  static BorderRadius get buttonRadius => BorderRadius.circular(16);
  static BorderRadius get inputRadius => BorderRadius.circular(16);
  static BorderRadius get badgeRadius => BorderRadius.circular(999);

  static Border get cardBorder => Border.all(color: border);

  static LinearGradient get primaryGradient => LinearGradient(
        colors: [gradientStart, gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

class _AppPalette {
  final Color bg;
  final Color sidebar;
  final Color card;
  final Color cardElevated;
  final Color nav;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color purple;
  final Color purpleDark;
  final Color purpleLight;
  final Color blue;
  final Color cyan;
  final Color success;
  final Color error;
  final Color warning;
  final Color gradientStart;
  final Color gradientEnd;

  Color get divider => border;

  const _AppPalette({
    required this.bg,
    required this.sidebar,
    required this.card,
    required this.cardElevated,
    required this.nav,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.purple,
    required this.purpleDark,
    required this.purpleLight,
    required this.blue,
    required this.cyan,
    required this.success,
    required this.error,
    required this.warning,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

class AppTheme {
  static ThemeData get darkTheme => _buildTheme(AppColors._dark, Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(AppColors._light, Brightness.light);

  static ThemeData _buildTheme(_AppPalette p, Brightness brightness) {
    final base = GoogleFonts.interTextTheme(
      TextTheme(
        displayLarge: TextStyle(
          color: p.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: TextStyle(
          color: p.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: p.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: p.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: p.textSecondary, fontSize: 15),
        bodyMedium: TextStyle(color: p.textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: p.textMuted, fontSize: 12),
      ),
    );

    final scheme = brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: p.purple,
            secondary: p.blue,
            surface: p.card,
            error: p.error,
            onPrimary: Colors.black,
            onSecondary: Colors.black,
            onSurface: p.textPrimary,
          )
        : ColorScheme.light(
            primary: p.purple,
            secondary: p.blue,
            surface: p.card,
            error: p.error,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: p.textPrimary,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      cardColor: p.card,
      colorScheme: scheme,
      textTheme: base,
      primaryTextTheme: base,

      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: p.purple),
        actionsIconTheme: IconThemeData(color: p.purple),
        titleTextStyle: GoogleFonts.inter(
          color: p.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.nav,
        selectedItemColor: p.purple,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
        elevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.nav,
        indicatorColor: p.purple.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.inter(
            color: states.contains(WidgetState.selected)
                ? p.purple
                : p.textMuted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.purple
                : p.textMuted,
          );
        }),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.cardElevated,
        border: OutlineInputBorder(
          borderRadius: AppColors.inputRadius,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppColors.inputRadius,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppColors.inputRadius,
          borderSide: BorderSide(color: p.purple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppColors.inputRadius,
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppColors.inputRadius,
          borderSide: BorderSide(color: p.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: p.textMuted),
        labelStyle: GoogleFonts.inter(color: p.textSecondary),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.purple,
        selectionColor: p.purple.withValues(alpha: 0.20),
        selectionHandleColor: p.purple,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.purple,
          foregroundColor: Colors.black,
          disabledBackgroundColor: p.cardElevated,
          disabledForegroundColor: p.textMuted,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: AppColors.buttonRadius,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: AppColors.buttonRadius,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.purple,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppColors.cardRadius,
          side: BorderSide(color: p.border),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: p.divider,
        thickness: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return p.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return p.purple.withValues(alpha: 0.30);
          }
          return p.border;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.purple;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: p.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.purple,
        linearTrackColor: p.border,
        circularTrackColor: p.border,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.cardElevated,
        contentTextStyle: GoogleFonts.inter(color: p.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.purple,
        unselectedLabelColor: p.textMuted,
        indicatorColor: p.purple,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 14),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.purple,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
        textStyle: GoogleFonts.inter(color: p.textPrimary),
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(p.cardElevated),
        dataRowColor: WidgetStatePropertyAll(p.card),
        dividerThickness: 1,
        headingTextStyle: GoogleFonts.inter(
          color: p.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: GoogleFonts.inter(color: p.textSecondary),
      ),
    );
  }
}
