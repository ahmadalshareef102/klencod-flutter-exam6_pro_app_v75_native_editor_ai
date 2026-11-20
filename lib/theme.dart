import 'package:flutter/material.dart';

/// ألوان مأخوذة من لقطة التصميم المرجعية (الصورة الثانية).
class AppColors {
  static const cream = Color(0xFFFBF7EE);
  static const navBg = Color(0xFFFDFCF7);
  static const maroon = Color(0xFF8B4A5E);
  static const pink = Color(0xFFFED9E1);
  static const ink = Color(0xFF1B1B1D);
  static const muted = Color(0xFF74555D);
  static const border = Color(0xFFEFE6D6);
  static const chipTeal = Color(0xFFD2ECEB);
  static const chipBlue = Color(0xFFD7ECFD);
  static const chipPurple = Color(0xFFECD8F1);
  static const chipAmber = Color(0xFFFFECD1);
  static const iconTeal = Color(0xFF00897B);
  static const iconBlue = Color(0xFF1E88E5);
  static const iconPurple = Color(0xFF8E24AA);
  static const iconAmber = Color(0xFFF59E0B);
  static const iconOrange = Color(0xFFFB8C00);
  static const danger = Color(0xFFC62828);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.maroon,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.maroon,
    onPrimary: Colors.white,
    primaryContainer: AppColors.pink,
    onPrimaryContainer: AppColors.maroon,
    surface: AppColors.cream,
    onSurface: AppColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Mohammad',
    scaffoldBackgroundColor: AppColors.cream,
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.navBg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.pink,
      elevation: 0,
      height: 76,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? Colors.white : const Color(0xFFB9A9AE)),
      trackColor: WidgetStateProperty.resolveWith((st) =>
          st.contains(WidgetState.selected) ? AppColors.maroon : const Color(0xFFEFE6D6)),
      trackOutlineColor: WidgetStateProperty.resolveWith((st) =>
          st.contains(WidgetState.selected) ? AppColors.maroon : const Color(0xFFD9CDB8)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
