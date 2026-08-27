import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/models/song.dart';
import '../../../data/models/submission.dart';
import '../../../data/models/submission_refusal.dart';
import '../../../domain/services/publish_gate.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/admin_provider.dart';
import '../../providers/providers.dart';
import '../auth/auth_screen.dart';

/// Offers a song to the shared catalogue, asking for whatever is missing first.
///
/// **One flow, reached from one place.** The song-view overflow menu is the only
/// entry point: a song has to exist before it can be shared, and importing
/// already lands on the song it created, so the menu item is one tap away from
/// the end of an import. A second Share button on the import screen would be two
/// ways to do the same thing, with two places for the rules to drift apart.
///
/// **Nothing here has to preserve a draft**, because the local copy is written
/// before this ever runs — sharing gives a song a second home rather than moving
/// it. That is what makes the sign-in stop safe: the AuthScreen is pushed on top
/// and popped, and the song is on the device either way.
///
/// The stop ordering lives in `domain/services/publish_gate.dart`, as a pure
/// function with its own tests. This class only puts a face on each answer.
class PublishFlow {
  final WidgetRef ref;
  final BuildContext context;

  const PublishFlow({required this.ref, required this.context});

  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Runs the gate and, if it clears, sends the song. Returns true if it went.
  Future<bool> run(Song song) async {
    // A loop, because clearing one stop reveals the next: a signed-in user's
    // profile is only readable after they have signed in, so the name and the
    // guidelines cannot even be checked on the first pass. Bounded, so a stop
    // that will not clear cannot spin.
    for (var attempt = 0; attempt < PublishStop.values.length + 1; attempt++) {
      final settings = await _settings();
      final profile = await ref.read(myProfileProvider.future);
      if (!context.mounted) return false;

      final stop = firstUnmetStop(PublishReadiness(
        isSignedIn: ref.read(isSignedInProvider),
        isEmailConfirmed: ref.read(isEmailConfirmedProvider),
        displayName: profile.displayName,
        hasAcceptedGuidelines: profile.guidelinesAcceptedAt != null,
        settings: settings,
      ));

      if (stop == null) return _confirmAndSubmit(song);

      final cleared = await _resolve(stop, settings);
      if (!cleared) return false;
    }
    return false;
  }

  Future<AppSettings> _settings() async {
    try {
      return await ref.read(appSettingsProvider.future);
    } catch (_) {
      // Unreachable settings must not block sharing: the database re-checks
      // every rule anyway, so the worst case is a refusal with a real message
      // instead of a prompt.
      return const AppSettings();
    }
  }

  Future<bool> _resolve(PublishStop stop, AppSettings settings) async {
    switch (stop) {
      case PublishStop.submissionsClosed:
        await _tell(_l10n.publishClosedTitle, _l10n.publishClosedBody);
        return false;

      case PublishStop.signIn:
        return _promptSignIn();

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
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(dialogContext).actionOk),
            ),
          ],
        ),
      );

  void _say(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// Explains why an account is needed before showing a login form.
  ///
  /// The explanation is not decoration. Throwing somebody straight at a sign-in
  /// screen for tapping "share" gives them no way to tell whether the app wants
  /// an account or has simply broken.
  Future<bool> _promptSignIn() async {
    final l10n = _l10n;
    final wantsToSignIn = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shareSongSignInTitle),
        content: Text(l10n.shareSongSignInBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.signIn),
          ),
        ],
      ),
    );
    if (wantsToSignIn != true || !context.mounted) return false;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AuthScreen()),
    );
    if (!context.mounted) return false;

    // The auth screen reports no verdict of its own and can be abandoned, so ask
    // the provider what actually happened rather than trusting the pop.
    ref.invalidate(myProfileProvider);
    return ref.read(isSignedInProvider);
  }

  Future<bool> _promptConfirmEmail() async {
    final l10n = _l10n;
    final email = ref.read(currentUserProvider)?.email ?? '';
    final auth = ref.read(authRepositoryProvider);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.verifyEmailTitle),
        content: Text(l10n.publishConfirmEmailBody(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () {
              auth?.resendConfirmation(email).catchError((_) {});
              Navigator.of(dialogContext).pop();
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
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _NameDialog(),
    );

    if (name == null) return false;

    final repository = ref.read(adminRepositoryProvider);
    if (repository == null) return false;
    try {
      await repository.setDisplayName(name);
      ref.invalidate(myProfileProvider);
      return true;
    } catch (_) {
      // Said out loud, like every other refusal in this flow. A silent `false`
      // here closed the dialog, cleared the stop, and left the gate asking for
      // a name that had in fact not been stored — with nothing on screen to
      // explain the second asking.
      _say(_l10n.publishProfileSaveFailed);
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              // Cannot be agreed to without ticking it. The tick is the whole
              // record that they were shown the rules.
              onPressed:
                  ticked ? () => Navigator.of(dialogContext).pop(true) : null,
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
      // The worst of the two silences: the contributor ticked the box, tapped
      // Accept, and watched the dialog close on a record that was never made.
      _say(_l10n.publishProfileSaveFailed);
      return false;
    }
  }

  /// Asks once more, then sends.
  Future<bool> _confirmAndSubmit(Song song) async {
    final l10n = _l10n;
    final repository = ref.read(submissionRepositoryProvider);
    if (repository == null) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shareSongTitle),
        content: Text(l10n.shareSongBody(song.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.shareSongConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    try {
      // Asked at the moment of sending rather than when the menu was built. The
      // queue is shared state: the same song sent from another device is not in
      // anything this screen holds, and a second pending row for one hymn is a
      // moderator's problem rather than this user's.
      final sent = await repository.mySubmissions();
      final already = sent.any((submission) =>
          submission.status != SubmissionStatus.rejected &&
          submission.song.number == song.number &&
          submission.song.title == song.title);
      if (!context.mounted) return false;
      if (already) {
        _say(l10n.shareSongAlreadySent);
        return false;
      }

      await repository.submit(song);
      // So "Songs I sent in" shows it without a manual refresh.
      ref.invalidate(mySubmissionsProvider);
      _say(l10n.shareSongSent);
      return true;
    } catch (error) {
      // Each refusal gets its own message where there is one to give. The
      // generic fallback stays for anything the server refuses that this build
      // has no vocabulary for.
      final refusal =
          SubmissionRefusalParsing.fromServerMessage(error.toString());
      _say(_messageFor(refusal));
      return false;
    }
  }

  String _messageFor(SubmissionRefusal refusal) => switch (refusal) {
        SubmissionRefusal.submissionsClosed => _l10n.publishClosedBody,
        SubmissionRefusal.emailNotConfirmed => _l10n
            .publishConfirmEmailBody(ref.read(currentUserProvider)?.email ?? ''),
        SubmissionRefusal.guidelinesNotAccepted => _l10n.publishGuidelinesTitle,
        SubmissionRefusal.displayNameRequired => _l10n.publishNameBody,
        // The one stop the client deliberately does not pre-check, so a refusal
        // is the only place it can ever be reported.
        SubmissionRefusal.dailyLimitReached => _l10n.publishDailyLimitBody,
        SubmissionRefusal.unknown => _l10n.shareSongFailed,
      };
}

/// Asking what to credit the song to.
///
/// Its own `StatefulWidget` because it owns a `TextEditingController`, and a
/// controller has to outlive the dialog's exit animation. Built inline first and
/// disposed the moment `showDialog` returned — while the popped route was still
/// transitioning out, so the next frame rebuilt the `TextFormField`,
/// `EditableText` re-subscribed, and the framework threw *A
/// TextEditingController was used after being disposed*. The same defect the
/// three admin dialogs carried; the pattern is `_TokenDialog` in
/// `import_song_screen.dart`.
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.publishNameTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.publishNameBody),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
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
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
