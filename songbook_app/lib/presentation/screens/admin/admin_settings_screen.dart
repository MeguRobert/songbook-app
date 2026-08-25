import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/content_pane.dart';

/// The settings that govern contribution.
///
/// Deliberately not in the ordinary Settings screen. Those are one person's
/// preferences on one device; these are the project's rules for everybody, and
/// mixing them would make "Settings" mean two different things.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  AppSettings? _draft;
  bool _saving = false;

  final _guidelines = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _guidelines.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Seeds the editable copy once, from the loaded settings.
  ///
  /// Held locally rather than written on every keystroke: the guidelines are
  /// three paragraphs of prose, and a round trip per character would be both slow
  /// and a good way to leave half a sentence as the published rule.
  void _seed(AppSettings settings) {
    if (_draft != null) return;
    _draft = settings;
    for (final code in const ['en', 'hu', 'ro']) {
      _guidelines[code] =
          TextEditingController(text: settings.guidelines[code] ?? '');
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    final repository = ref.read(adminRepositoryProvider);
    if (draft == null || repository == null) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await repository.saveSettings(draft.copyWith(
        guidelines: {
          for (final entry in _guidelines.entries) entry.key: entry.value.text,
        },
      ));
      ref.invalidate(appSettingsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionDone)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminSettingsTitle),
        actions: [
          TextButton(
            onPressed: _draft == null || _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.actionSave),
          ),
        ],
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.authErrorNetwork)),
        data: (loaded) {
          _seed(loaded);
          final draft = _draft!;

          return ContentPane.form(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.adminSubmissionsSection,
                    style: Theme.of(context).textTheme.titleSmall),
                SwitchListTile(
                  title: Text(l10n.adminSubmissionsOpen),
                  subtitle: Text(l10n.adminSubmissionsOpenHelp),
                  value: draft.submissionsOpen,
                  onChanged: (value) => setState(
                    () => _draft = draft.copyWith(submissionsOpen: value),
                  ),
                ),
                SwitchListTile(
                  title: Text(l10n.adminRequireConfirmedEmail),
                  subtitle: Text(l10n.adminRequireConfirmedEmailHelp),
                  value: draft.requireConfirmedEmail,
                  onChanged: (value) => setState(
                    () => _draft = draft.copyWith(requireConfirmedEmail: value),
                  ),
                ),
                ListTile(
                  title: Text(l10n.adminDailyCap),
                  subtitle: Text(l10n.adminDailyCapHelp),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: draft.dailySubmissionCap <= 0
                            ? null
                            : () => setState(() => _draft = draft.copyWith(
                                dailySubmissionCap:
                                    draft.dailySubmissionCap - 1)),
                      ),
                      Text('${draft.dailySubmissionCap}'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setState(() => _draft = draft.copyWith(
                            dailySubmissionCap: draft.dailySubmissionCap + 1)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(l10n.adminGuidelinesSection,
                    style: Theme.of(context).textTheme.titleSmall),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.adminGuidelinesHelp,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                for (final entry in const [
                  ('hu', 'Magyar'),
                  ('ro', 'Română'),
                  ('en', 'English'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextField(
                      controller: _guidelines[entry.$1],
                      maxLines: 5,
                      minLines: 3,
                      decoration: InputDecoration(
                        labelText: entry.$2,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
