import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF09090C);
  static const surface = Color(0xFF15151B);
  static const coral = Color(0xFFFF5C67);
  static const magenta = Color(0xFFD62976);
  static const gold = Color(0xFFFFC857);
  static const muted = Color(0xFF9D9DA8);
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.coral,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xF20E0E12),
      indicatorColor: Color(0x33FF5C67),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
