import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Dark theme configuration
ThemeData createDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      brightness: Brightness.dark,
      surface: AppColors.surfaceDark,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: AppColors.textPrimaryDark,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerDark,
      thickness: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      indicatorColor: AppColors.primaryDark.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.black,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.textSecondaryDark,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: AppColors.textPrimaryDark),
      headlineMedium: TextStyle(color: AppColors.textPrimaryDark),
      headlineSmall: TextStyle(color: AppColors.textPrimaryDark),
      titleLarge: TextStyle(color: AppColors.textPrimaryDark),
      titleMedium: TextStyle(color: AppColors.textPrimaryDark),
      titleSmall: TextStyle(color: AppColors.textPrimaryDark),
      bodyLarge: TextStyle(color: AppColors.textPrimaryDark),
      bodyMedium: TextStyle(color: AppColors.textPrimaryDark),
      bodySmall: TextStyle(color: AppColors.textSecondaryDark),
      labelLarge: TextStyle(color: AppColors.textPrimaryDark),
      labelMedium: TextStyle(color: AppColors.textSecondaryDark),
      labelSmall: TextStyle(color: AppColors.textSecondaryDark),
    ),
  );
}
