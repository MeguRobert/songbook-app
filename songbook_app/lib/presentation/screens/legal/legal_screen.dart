import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../widgets/content_pane.dart';

/// Where a reader is told to write.
///
/// A Dart constant rather than an ARB string on purpose: an address is not a
/// translation, so keeping it here means it is filled in once instead of three
/// times, and it cannot end up right in one language and stale in another.
///
/// This address is published on two pages of a public site, so it will be
/// scraped. That is the cost of being reachable, and being reachable is the
/// point of the section it appears in — a privacy notice that offers no way to
/// ask a question is not one.
const legalContactAddress = 'megurobi14@gmail.com';

/// What the app keeps, and what it never uploads.
///
/// Every claim on this page was written from the code rather than from a
/// template, and the two are meant to stay in step. If you change any of the
/// following, this page is wrong until it is updated too:
///
///   * the tables or columns in `supabase/migrations/`
///   * the row-level security policies that decide who can read what
///   * the Content-Security-Policy in `web/index.html`, which is the complete
///     list of origins the app is able to reach
///   * `page_text_recognizer_web.dart` (reads photographs on the device) or
///     `photo_import_service.dart` (uploads them), because the difference
///     between those two is the single most important sentence here
///   * what `deploy/omr/server.py` writes to its log
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _LegalPage(
      title: l10n.legalPrivacyTitle,
      intro: l10n.privacyIntro,
      sections: [
        (l10n.privacyNoAccountTitle, l10n.privacyNoAccountBody),
        (l10n.privacyOnDeviceTitle, l10n.privacyOnDeviceBody),
        (l10n.privacyServerTitle, l10n.privacyServerBody),
        (l10n.privacyWhoSeesTitle, l10n.privacyWhoSeesBody),
        // Three entries rather than one, because the honest answer has three
        // parts: which button you pressed, and then two genuinely different
        // fates for the photograph.
        (l10n.privacyPhotosTitle, l10n.privacyPhotosIntro),
        (l10n.privacyPhotosWordsTitle, l10n.privacyPhotosWordsBody),
        (l10n.privacyPhotosNotationTitle, l10n.privacyPhotosNotationBody),
        (l10n.privacyOthersTitle, l10n.privacyOthersBody),
        (l10n.privacyGoogleTitle, l10n.privacyGoogleBody),
        (l10n.privacyEmailsTitle, l10n.privacyEmailsBody),
        (l10n.privacyKeepingTitle, l10n.privacyKeepingBody),
        (l10n.privacyDeleteTitle, l10n.privacyDeleteBody),
        (l10n.privacyRightsTitle, l10n.privacyRightsBody),
        (l10n.privacyChangesTitle, l10n.privacyChangesBody),
      ],
      otherLabel: l10n.legalTermsTitle,
      otherPath: AppRoutes.terms,
    );
  }
}

/// What you may put in, and whose problem the copyright is.
///
/// A separate page from [PrivacyScreen], not a section of it, for three
/// reasons. They answer different questions — "what do you do with my data"
/// against "what may I put in here" — and a reader arrives wanting one of them,
/// not both. The copyright paragraph is the one somebody will need to send to
/// somebody else, and that wants its own address. And the sign-up footer wants
/// two short links rather than one long page whose second half is the half that
/// actually constrains the person signing up.
///
/// Distinct again from the contribution guidelines in `app_settings`: those are
/// the administrator's editable house rules, shown at the moment of submitting.
/// These are the fixed terms, and mixing the two would mean an administrator
/// could edit the copyright paragraph by accident.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _LegalPage(
      title: l10n.legalTermsTitle,
      intro: l10n.termsIntro,
      sections: [
        (l10n.termsWhatTitle, l10n.termsWhatBody),
        (l10n.termsAccountTitle, l10n.termsAccountBody),
        (l10n.termsContentTitle, l10n.termsContentBody),
        (l10n.termsCopyrightTitle, l10n.termsCopyrightBody),
        (l10n.termsSubmissionTitle, l10n.termsSubmissionBody),
        (l10n.termsModerationTitle, l10n.termsModerationBody),
      ],
      otherLabel: l10n.legalPrivacyTitle,
      otherPath: AppRoutes.privacy,
    );
  }
}

/// A document: a heading, prose, a contact and a way to the other one.
///
/// [ContentPane] sits inside the scroll view rather than around it, so the
/// desktop scrollbar stays at the window edge instead of floating against the
/// text — the placement its own documentation asks for.
class _LegalPage extends StatelessWidget {
  const _LegalPage({
    required this.title,
    required this.intro,
    required this.sections,
    required this.otherLabel,
    required this.otherPath,
  });

  final String title;
  final String intro;
  final List<(String, String)> sections;
  final String otherLabel;
  final String otherPath;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: ContentPane.list(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(intro, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text(
                  l10n.legalUpdated,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final (heading, body) in sections)
                  _LegalSection(heading: heading, body: body),
                _LegalSection(
                  heading: l10n.legalContactTitle,
                  body: l10n.legalContactBody(legalContactAddress),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton(
                    onPressed: () => context.push(otherPath),
                    child: Text(otherLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One heading and its paragraphs.
///
/// `Semantics(container: true)` because static text otherwise merges into the
/// parent node: without it a screen reader meets the entire notice as one
/// unbroken utterance with no way to skip a section it does not need.
class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.heading, required this.body});

  final String heading;

  /// Paragraphs separated by newlines. Blank lines are dropped, so the ARB
  /// strings can use either `\n` between bullets or `\n\n` between paragraphs
  /// and both come out spaced the same on screen.
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paragraphs =
        body.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                heading,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            for (final paragraph in paragraphs)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(paragraph, style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}
