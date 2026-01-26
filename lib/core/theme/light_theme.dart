import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Light theme configuration
ThemeData createLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      brightness: Brightness.light,
      surface: AppColors.surfaceLight,
    ),
    scaffoldBackgroundColor: AppColors.backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.textPrimaryLight,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surfaceLight,
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerLight,
      thickness: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      indicatorColor: AppColors.primaryLight.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.textSecondaryLight,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: AppColors.textPrimaryLight),
      headlineMedium: TextStyle(color: AppColors.textPrimaryLight),
      headlineSmall: TextStyle(color: AppColors.textPrimaryLight),
      titleLarge: TextStyle(color: AppColors.textPrimaryLight),
      titleMedium: TextStyle(color: AppColors.textPrimaryLight),
      titleSmall: TextStyle(color: AppColors.textPrimaryLight),
      bodyLarge: TextStyle(color: AppColors.textPrimaryLight),
      bodyMedium: TextStyle(color: AppColors.textPrimaryLight),
      bodySmall: TextStyle(color: AppColors.textSecondaryLight),
      labelLarge: TextStyle(color: AppColors.textPrimaryLight),
      labelMedium: TextStyle(color: AppColors.textSecondaryLight),
      labelSmall: TextStyle(color: AppColors.textSecondaryLight),
    ),
  );
}
