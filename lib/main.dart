import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'presentation/providers/providers.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Run the app with Riverpod
  runApp(
    ProviderScope(
      overrides: [
        // Override SharedPreferences provider with initialized instance
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SongbookApp(),
    ),
  );
}
