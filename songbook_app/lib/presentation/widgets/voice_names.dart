import '../../l10n/app_localizations.dart';

/// The four well-known voice names in the reader's language.
///
/// The stored names come from the importer, which writes English so the JSON
/// stays one thing whatever language the app is in. Anything the importer could
/// not identify — `P1 staff 2 voice 6` — passes through, because a label taken
/// from the file is not a word to translate.
///
/// Lives here rather than on the controls sheet because two unrelated places need
/// it: the voice picker's chips, and the labels the grand staff draws at the left
/// of each staff. The layout engine has no `BuildContext`, so it is given the
/// finished strings.
String localisedVoiceName(AppLocalizations l10n, String stored) =>
    switch (stored) {
      'Melody' => l10n.voiceMelody,
      'Alto' => l10n.voiceAlto,
      'Tenor' => l10n.voiceTenor,
      'Bass' => l10n.voiceBass,
      _ => stored,
    };
