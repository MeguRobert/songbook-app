import 'package:flutter/material.dart';

/// App typography styles
class AppTypography {
  AppTypography._();

  // Font families
  static const String fontFamilyDisplay = 'Roboto';
  static const String fontFamilyBody = 'Roboto';
  static const String fontFamilyMonospace = 'RobotoMono';

  // Song display text styles
  static const TextStyle songTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle songNumber = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.25,
  );

  static const TextStyle verseText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0.15,
  );

  static const TextStyle chordText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle metadata = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    letterSpacing: 0.25,
  );

  // List item text styles
  static const TextStyle listTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  static const TextStyle listSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  // Settings text styles
  static const TextStyle settingsHeader = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
  );
}
