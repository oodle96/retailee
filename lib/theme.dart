import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF5948C8);
  static const canvas = Color(0xFF7466E5);
  static const primaryDark = Color(0xFF352676);
  static const primarySoft = Color(0xFFEEEAFE);
  static const accent = Color(0xFFFFE66D);
  static const accentSoft = Color(0xFFFFF8D6);
  static const bg = Color(0xFFE7E0FC);
  static const surface = Color(0xFFF3EFFF);
  static const ink = Color(0xFF171829);
  static const muted = ink;
  static const line = Color(0xFFE8E8F2);
  static const danger = Color(0xFFB53E52);
  static const dangerSoft = Color(0xFFFDECEC);
  static const warn = Color(0xFF925010);
  static const warnSoft = Color(0xFFFFF6E0);
  static const info = Color(0xFF245F87);
  static const infoSoft = Color(0xFFEAF7FF);
  static const ai = Color(0xFF5949C5);
  static const aiSoft = Color(0xFFEEEAFE);
  static const positive = Color(0xFF147D63);
  static const sky = Color(0xFFB8E8FF);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.danger,
  ).copyWith(onSurface: AppColors.ink, onSurfaceVariant: AppColors.ink);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.ink,
      iconColor: AppColors.primaryDark,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .merge(
          const TextTheme(
            bodyLarge: TextStyle(fontSize: 18, height: 1.4),
            bodyMedium: TextStyle(
              fontSize: 18,
              height: 1.4,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            bodySmall: TextStyle(fontSize: 16, height: 1.4),
            labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            labelMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            labelSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            titleSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(56, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
    ),
    badgeTheme: const BadgeThemeData(
      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      largeSize: 28,
      padding: EdgeInsets.symmetric(horizontal: 6),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primaryDark,
      unselectedLabelColor: Colors.white,
      indicator: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      unselectedLabelStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line, width: 1.5),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      floatingLabelStyle: const TextStyle(fontSize: 22, color: AppColors.ink),
      labelStyle: const TextStyle(fontSize: 18, color: AppColors.ink),
      hintStyle: const TextStyle(fontSize: 18, color: AppColors.muted),
      errorStyle: const TextStyle(fontSize: 16),
      helperStyle: const TextStyle(fontSize: 16),
      filled: true,
      fillColor: const Color(0xFFD9D0F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: const TextStyle(fontSize: 16, color: AppColors.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: AppColors.line),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
