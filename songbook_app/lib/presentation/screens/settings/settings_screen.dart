import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/view_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/app_info_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/content_pane.dart';
import '../auth/auth_screen.dart';
import '../moderation/moderation_queue_screen.dart';
import '../moderation/my_submissions_screen.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// The optional account.
  ///
  /// Renders nothing at all when there is no backend — an account row that
  /// cannot work is worse than no row, and a build with no Supabase configured
  /// should look exactly like the app did before accounts existed.
  Widget _buildAccountSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    if (!ref.watch(authAvailableProvider)) return const SizedBox.shrink();

    final user = ref.watch(currentUserProvider);
    final confirmed = ref.watch(isEmailConfirmedProvider);
    final email = user?.email ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(context, l10n.accountSection),
        if (user == null)
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.signIn),
            subtitle: Text(l10n.accountOptional),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            ),
          )
        else ...[
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(l10n.signedInAs(email)),
            subtitle: confirmed ? null : Text(l10n.verifyEmailTitle),
            trailing: TextButton(
              onPressed: () =>
                  ref.read(authRepositoryProvider)?.signOut(),
              child: Text(l10n.signOut),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.outbox_outlined),
            title: Text(l10n.mySubmissionsTitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
            ),
          ),
          // Moderation appears only for an admin. This hides the entry; it is
          // not what stops anyone else deciding anything — RLS and the status
          // trigger do that, server-side, on every write.
          ref.watch(isAdminProvider).maybeWhen(
                data: (isAdmin) => isAdmin
                    ? ListTile(
                        leading: const Icon(Icons.rule),
                        title: Text(l10n.moderationQueueTitle),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ModerationQueueScreen(),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
          // Holding a session is not the same as having confirmed the address,
          // and contributing a song requires the latter.
          if (!confirmed)
            ListTile(
              leading: const Icon(Icons.mark_email_unread_outlined),
              title: Text(l10n.verifyEmailBody(email)),
              trailing: TextButton(
                onPressed: () => ref
                    .read(authRepositoryProvider)
                    ?.resendConfirmation(email)
                    // Failure here is not worth interrupting Settings for; the
                    // user can simply tap again.
                    .catchError((_) {}),
                child: Text(l10n.resendConfirmation),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: ContentPane.list(
        child: ListView(
          children: [
            // Account, and deliberately not first. An optional feature placed at
            // the top of Settings reads as something you are expected to do; the
            // app works signed-out and nothing here gates on a session.
            _buildAccountSection(context, ref, l10n),

            // Language first among the real settings: it changes every other label
            // on this screen, so burying it under Appearance would mean hunting for
            // it in a language you cannot read.
            _buildSectionHeader(context, l10n.settingsLanguage),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.settingsLanguage),
              subtitle: Text(_languageLabel(l10n, locale)),
              onTap: () => _showLanguageDialog(context, ref, locale),
            ),

            // Appearance section
            _buildSectionHeader(context, l10n.settingsAppearance),
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: Text(l10n.settingsTheme),
              subtitle: Text(_getThemeModeLabel(l10n, themeMode)),
              onTap: () => _showThemeDialog(context, ref, themeMode),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text(l10n.settingsFontSize),
              subtitle: Text('${settings.fontSize.round()}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: l10n.fontSizeDecrease,
                    onPressed: settings.fontSize > 12
                        ? () => ref.read(settingsProvider.notifier).decreaseFontSize()
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: l10n.fontSizeIncrease,
                    onPressed: settings.fontSize < 32
                        ? () => ref.read(settingsProvider.notifier).increaseFontSize()
                        : null,
                  ),
                ],
              ),
            ),

            const Divider(),

            // Display section
            _buildSectionHeader(context, l10n.settingsDisplay),
            ListTile(
              leading: const Icon(Icons.view_agenda),
              title: Text(l10n.settingsDefaultView),
              subtitle: Text(_getViewConfigLabel(l10n, settings.viewConfig)),
              onTap: () => _showViewConfigDialog(context, ref, settings.viewConfig),
            ),

            const Divider(),

            // About section
            _buildSectionHeader(context, l10n.settingsAbout),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.settingsVersion),
              subtitle: ref.watch(appVersionProvider).when(
                    data: (version) => Text(version),
                    loading: () => const Text('…'),
                    error: (_, __) => Text(l10n.settingsVersionUnknown),
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.library_books),
              title: Text(l10n.appTitle),
              subtitle: Text(l10n.settingsTagline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }

  /// The chosen language, named in its own language so it stays recognisable
  /// even when the interface is currently in one the reader does not know.
  static String _languageLabel(AppLocalizations l10n, Locale? locale) {
    return switch (locale?.languageCode) {
      'hu' => l10n.languageHungarian,
      'ro' => l10n.languageRomanian,
      'en' => l10n.languageEnglish,
      _ => l10n.settingsLanguageSystem,
    };
  }

  void _showLanguageDialog(
      BuildContext context, WidgetRef ref, Locale? current) {
    final l10n = AppLocalizations.of(context);
    // null first: "follow the device" is the default, and the absence of a
    // choice rather than a fourth language.
    final options = <Locale?>[
      null,
      ...AppLocalizations.supportedLocales,
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.settingsLanguage),
        // ListTile rather than RadioListTile: the Radio API this file's other
        // dialogs use is deprecated, and new code should not add to that debt.
        // A tick on the current row says the same thing.
        children: [
          for (final option in options)
            ListTile(
              title: Text(_languageLabel(l10n, option)),
              trailing: option?.languageCode == current?.languageCode
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(option);
                Navigator.of(dialogContext).pop();
              },
            ),
        ],
      ),
    );
  }

  String _getThemeModeLabel(AppLocalizations l10n, AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => l10n.themeLight,
      AppThemeMode.dark => l10n.themeDark,
      AppThemeMode.system => l10n.themeSystem,
    };
  }

  String _getViewConfigLabel(AppLocalizations l10n, ViewConfig config) {
    if (config.isChordsPreset) return l10n.settingsViewChords;
    if (config.isLyricsOnlyPreset) return l10n.settingsViewLyricsOnly;
    // Sheet music is both the preset test and the fallback for a config that
    // matches none of the three.
    return l10n.settingsViewSheetMusic;
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, AppThemeMode current) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.settingsTheme),
        children: AppThemeMode.values.map((mode) {
          return RadioListTile<AppThemeMode>(
            title: Text(_getThemeModeLabel(l10n, mode)),
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.settingsDefaultView),
        children: [
          RadioListTile<String>(
            title: Text(l10n.settingsViewSheetMusic),
            subtitle: Text(l10n.settingsViewSheetMusicHint),
            value: 'sheet',
            groupValue: _getPresetKey(current),
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setPreset(const ViewConfig.sheetMusic());
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            title: Text(l10n.settingsViewChords),
            subtitle: Text(l10n.settingsViewChordsHint),
            value: 'chords',
            groupValue: _getPresetKey(current),
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setPreset(const ViewConfig.chords());
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            title: Text(l10n.settingsViewLyricsOnly),
            subtitle: Text(l10n.settingsViewLyricsOnlyHint),
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
    return 'sheet';
  }
}
