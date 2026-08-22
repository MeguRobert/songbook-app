import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/models/song.dart';
import '../../../data/models/submission_refusal.dart';
import '../../../domain/services/publish_gate.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/admin_provider.dart';
import '../../providers/providers.dart';
import '../auth/auth_screen.dart';

/// Offers a song to the shared catalogue, asking for whatever is missing first.
///
/// **Every stop preserves the draft.** Nothing here replaces the screen the user
/// is on: the sign-in step is pushed on top and popped, and the rest are dialogs.
/// A gate that discards a hymn somebody has just typed in is how you teach them
/// never to contribute again — and it would be an easy mistake to make here,
/// because navigating to a sign-in *route* would tear down the import screen and
/// its unsaved state with it.
///
/// Returns true only if the song actually reached the queue.
class PublishFlow {
  final WidgetRef ref;
  final BuildContext context;

  const PublishFlow({required this.ref, required this.context});

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<bool> run(Song song) async {
    // Loop rather than a straight line: clearing one stop can reveal the next,
    // and a signed-in user's profile is only readable after they have signed in.
    // Bounded, so a stop that cannot be cleared cannot spin forever.
    for (var attempt = 0; attempt < PublishStop.values.length + 1; attempt++) {
      final settings = await _settings();
      final profile = await ref.read(myProfileProvider.future);

      final stop = firstUnmetStop(PublishReadiness(
        isSignedIn: ref.read(isSignedInProvider),
        isEmailConfirmed: ref.read(isEmailConfirmedProvider),
        displayName: profile.displayName,
        hasAcceptedGuidelines: profile.guidelinesAcceptedAt != null,
        settings: settings,
      ));

      if (stop == null) return _submit(song);

      final cleared = await _resolve(stop, settings);
      if (!cleared) return false;
    }
    return false;
  }

  Future<AppSettings> _settings() async {
    try {
      return await ref.read(appSettingsProvider.future);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// Shows the step for [stop]. Returns true if the user did the thing.
  Future<bool> _resolve(PublishStop stop, AppSettings settings) async {
    switch (stop) {
      case PublishStop.submissionsClosed:
        await _tell(_l10n.publishClosedTitle, _l10n.publishClosedBody);
        return false;

      case PublishStop.signIn:
        // Pushed, not navigated to by route: the import screen and its draft
        // stay alive underneath.
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
        if (!context.mounted) return false;
        // The profile is a different account's now, or newly readable.
        ref.invalidate(myProfileProvider);
        return ref.read(isSignedInProvider);

      case PublishStop.confirmEmail:
        return _promptConfirmEmail();

      case PublishStop.displayName:
        return _promptDisplayName();

      case PublishStop.guidelines:
        return _promptGuidelines(settings);
    }
  }

  Future<void> _tell(String title, String body) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).actionOk),
            ),
          ],
        ),
      );

  Future<bool> _promptConfirmEmail() async {
    final l10n = _l10n;
    final email = ref.read(currentUserProvider)?.email ?? '';
    final auth = ref.read(authRepositoryProvider);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.verifyEmailTitle),
        content: Text(l10n.publishConfirmEmailBody(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () {
              auth?.resendConfirmation(email).catchError((_) {});
              Navigator.of(context).pop();
            },
            child: Text(l10n.resendConfirmation),
          ),
        ],
      ),
    );
    // Always false: confirming happens in an email client, so this attempt is
    // over either way. Returning true would loop on a stop that cannot clear
    // without the user leaving the app.
    return false;
  }

  Future<bool> _promptDisplayName() async {
    final l10n = _l10n;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.publishNameTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.publishNameBody),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.publishNameLabel),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.publishNameRequired
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null) return false;

    final repository = ref.read(adminRepositoryProvider);
    if (repository == null) return false;
    try {
      await repository.setDisplayName(name);
      ref.invalidate(myProfileProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _promptGuidelines(AppSettings settings) async {
    final l10n = _l10n;
    final languageCode = Localizations.localeOf(context).languageCode;
    final text = settings.guidelinesFor(languageCode);
    var ticked = false;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.publishGuidelinesTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: ticked,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(l10n.publishGuidelinesAgree),
                  onChanged: (value) =>
                      setDialogState(() => ticked = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              // Cannot be agreed to without ticking it. The tick is the whole
              // record that they were shown the rules.
              onPressed: ticked ? () => Navigator.of(context).pop(true) : null,
              child: Text(l10n.publishGuidelinesAccept),
            ),
          ],
        ),
      ),
    );

    if (accepted != true) return false;

    final repository = ref.read(adminRepositoryProvider);
    if (repository == null) return false;
    try {
      await repository.acceptGuidelines();
      ref.invalidate(myProfileProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The actual submission. Anything the database refuses is translated here.
  Future<bool> _submit(Song song) async {
    final repository = ref.read(submissionRepositoryProvider);
    if (repository == null) return false;

    try {
      await repository.submit(song);
      ref.invalidate(mySubmissionsProvider);
      return true;
    } catch (error) {
      final refusal =
          SubmissionRefusalParsing.fromServerMessage(error.toString());
      if (!context.mounted) return false;
      await _tell(_l10n.publishRefusedTitle, _messageFor(refusal));
      return false;
    }
  }

  String _messageFor(SubmissionRefusal refusal) => switch (refusal) {
        SubmissionRefusal.submissionsClosed => _l10n.publishClosedBody,
        SubmissionRefusal.emailNotConfirmed =>
          _l10n.publishConfirmEmailBody(ref.read(currentUserProvider)?.email ?? ''),
        SubmissionRefusal.guidelinesNotAccepted => _l10n.publishGuidelinesTitle,
        SubmissionRefusal.displayNameRequired => _l10n.publishNameBody,
        // The one stop the client deliberately does not pre-check, so this is
        // the only place it can ever be reported.
        SubmissionRefusal.dailyLimitReached => _l10n.publishDailyLimitBody,
        SubmissionRefusal.unknown => _l10n.authErrorNetwork,
      };
}
