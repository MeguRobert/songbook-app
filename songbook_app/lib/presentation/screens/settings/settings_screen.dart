import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/view_config.dart';
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
          ListTile(
            leading: const Icon(Icons.view_agenda),
            title: const Text('Default View'),
            subtitle: Text(_getViewConfigLabel(settings.viewConfig)),
            onTap: () => _showViewConfigDialog(context, ref, settings.viewConfig),
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

  String _getViewConfigLabel(ViewConfig config) {
    if (config.isSheetMusicPreset) return 'Sheet Music';
    if (config.isChordsPreset) return 'Chords';
    if (config.isLyricsOnlyPreset) return 'Lyrics Only';
    if (config.isNotationWithoutChords) return 'Notation without chords';
    return 'Custom';
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

  void _showViewConfigDialog(BuildContext context, WidgetRef ref, ViewConfig current) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Default View'),
        children: [
          RadioListTile<String>(
            title: const Text('Sheet Music'),
            subtitle: const Text('Notation with chords and lyrics'),
            value: 'sheet',
            groupValue: _getPresetKey(current),
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setPreset(const ViewConfig.sheetMusic());
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            title: const Text('Chords'),
            subtitle: const Text('Chords and lyrics only'),
            value: 'chords',
            groupValue: _getPresetKey(current),
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setPreset(const ViewConfig.chords());
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            title: const Text('Lyrics Only'),
            subtitle: const Text('Clean text without notation or chords'),
            value: 'lyrics',
            groupValue: _getPresetKey(current),
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setPreset(const ViewConfig.lyricsOnly());
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  String _getPresetKey(ViewConfig config) {
    if (config.isSheetMusicPreset) return 'sheet';
    if (config.isChordsPreset) return 'chords';
    if (config.isLyricsOnlyPreset) return 'lyrics';
    return 'custom';
  }
}
