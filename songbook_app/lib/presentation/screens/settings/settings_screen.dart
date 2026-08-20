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
      body: ListView(
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

          // Photo import. Its own section rather than a line under Appearance:
          // it is the only setting that points the app at something outside
          // itself, and it is the difference between the Photo button working
          // and explaining itself.
          _buildSectionHeader(context, l10n.settingsPhotoImport),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.settingsPhotoImport),
            subtitle: Text(
              ref.watch(settingsRepositoryProvider).getPhotoImportEndpoint()
                      ?.host ??
                  l10n.settingsPhotoImportNotSet,
            ),
            onTap: () => _showPhotoImportDialog(context, ref),
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

  /// Where photo import sends an image, and the token it presents.
  ///
  /// Two plain fields rather than a wizard: the value is a URL the user was
  /// given by whatever service they set up, and the only thing the app can
  /// usefully check is that it looks like one.
  void _showPhotoImportDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(settingsRepositoryProvider);
    final endpointController = TextEditingController(
      text: settings.getPhotoImportEndpoint()?.toString() ?? '',
    );
    final tokenController =
        TextEditingController(text: settings.getPhotoImportToken() ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final raw = endpointController.text.trim();
          // Empty is valid — it turns the feature off. Only a non-empty value
          // that cannot be a URL is worth complaining about.
          final invalid = raw.isNotEmpty && !_looksLikeUrl(raw);
          return AlertDialog(
            title: Text(l10n.settingsPhotoImport),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: endpointController,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.settingsPhotoImportEndpoint,
                    helperText: l10n.settingsPhotoImportEndpointHint,
                    helperMaxLines: 3,
                    errorText:
                        invalid ? l10n.settingsPhotoImportInvalid : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tokenController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsPhotoImportToken,
                    helperText: l10n.settingsPhotoImportTokenHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: invalid
                    ? null
                    : () async {
                        await settings
                            .setPhotoImportEndpoint(endpointController.text);
                        await settings
                            .setPhotoImportToken(tokenController.text);
                        // The provider reads storage, which is not reactive,
                        // so nothing would notice the change otherwise.
                        ref.invalidate(photoNotationImportServiceProvider);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: Text(l10n.commonSave),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Mirrors SettingsRepository's own check, so the dialog refuses exactly what
  /// storage would have discarded rather than accepting a value that silently
  /// reads back as "not configured".
  static bool _looksLikeUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
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
        // ListTile + a tick, matching the language dialog above. The Radio
        // API these dialogs used is deprecated, and the decision recorded
        // there was to stop adding to that debt — this is the same dialog
        // asking the same kind of question, so it gets the same treatment
        // rather than a second pattern living beside it.
        children: AppThemeMode.values.map((mode) {
          return ListTile(
            title: Text(_getThemeModeLabel(l10n, mode)),
            trailing: mode == current ? const Icon(Icons.check) : null,
            onTap: () {
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
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
        // Same ListTile + tick pattern as the theme and language dialogs.
        //
        // The three presets are described by data rather than three near
        // identical widgets: the previous shape repeated groupValue and the
        // Navigator.pop on every branch, which is how the middle one ended up
        // discarding its own `value` and relying on position instead.
        children: [
          for (final preset in const [
            (key: 'sheet', config: ViewConfig.sheetMusic()),
            (key: 'chords', config: ViewConfig.chords()),
            (key: 'lyrics', config: ViewConfig.lyricsOnly()),
          ])
            ListTile(
              title: Text(_getViewConfigLabel(l10n, preset.config)),
              subtitle: Text(_viewConfigHint(l10n, preset.key)),
              trailing: preset.key == _getPresetKey(current)
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(settingsProvider.notifier).setPreset(preset.config);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  /// The explanatory line under each default-view option.
  String _viewConfigHint(AppLocalizations l10n, String presetKey) {
    return switch (presetKey) {
      'chords' => l10n.settingsViewChordsHint,
      'lyrics' => l10n.settingsViewLyricsOnlyHint,
      _ => l10n.settingsViewSheetMusicHint,
    };
  }

  String _getPresetKey(ViewConfig config) {
    if (config.isSheetMusicPreset) return 'sheet';
    if (config.isChordsPreset) return 'chords';
    if (config.isLyricsOnlyPreset) return 'lyrics';
    return 'sheet';
  }
}
