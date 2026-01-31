import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Appearance section
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            subtitle: Text(_getThemeModeLabel(themeMode)),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Font Size'),
            subtitle: Text('${settings.fontSize.round()}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: settings.fontSize > 12
                      ? () => ref.read(settingsProvider.notifier).decreaseFontSize()
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: settings.fontSize < 32
                      ? () => ref.read(settingsProvider.notifier).increaseFontSize()
                      : null,
                ),
              ],
            ),
          ),

          const Divider(),

          // Display section
          _buildSectionHeader(context, 'Display'),
          SwitchListTile(
            secondary: const Icon(Icons.music_note),
            title: const Text('Show Chords'),
            subtitle: const Text('Display chord symbols above lyrics'),
            value: settings.showChords,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setShowChords(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.view_agenda),
            title: const Text('Default View'),
            subtitle: Text(_getViewModeLabel(settings.viewMode)),
            onTap: () => _showViewModeDialog(context, ref, settings.viewMode),
          ),

          const Divider(),

          // About section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text('Songbook'),
            subtitle: const Text('Worship Songbook App'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  String _getThemeModeLabel(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => 'Light',
      AppThemeMode.dark => 'Dark',
      AppThemeMode.system => 'System default',
    };
  }

  String _getViewModeLabel(SongViewMode mode) {
    return switch (mode) {
      SongViewMode.chords => 'Lyrics with chords',
      SongViewMode.sheet => 'Sheet music',
    };
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, AppThemeMode current) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: AppThemeMode.values.map((mode) {
          return RadioListTile<AppThemeMode>(
            title: Text(_getThemeModeLabel(mode)),
            value: mode,
            groupValue: current,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showViewModeDialog(BuildContext context, WidgetRef ref, SongViewMode current) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Default View'),
        children: SongViewMode.values.map((mode) {
          return RadioListTile<SongViewMode>(
            title: Text(_getViewModeLabel(mode)),
            value: mode,
            groupValue: current,
            onChanged: (value) {
              if (value != null) {
                ref.read(settingsProvider.notifier).setViewMode(value);
              }
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }
}
