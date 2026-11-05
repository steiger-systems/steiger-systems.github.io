import 'package:flutter/material.dart';

import 'data/models.dart';

class HuntColors {
  static const hunter = Color(0xFFE5484D);
  static const runner = Color(0xFF3E8EF7);
  static const zone = Color(0xFFF5C542);
  static const background = Color(0xFF0F1115);
  static const surface = Color(0xFF1A1D23);

  static Color team(Team t) => t == Team.hunter ? hunter : runner;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: HuntColors.runner,
    brightness: Brightness.dark,
    surface: HuntColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: HuntColors.background,
    // Big touch targets: the app is used while running.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
