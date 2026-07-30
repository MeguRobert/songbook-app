// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Songbook';

  @override
  String get navSongs => 'Songs';

  @override
  String get navSetlists => 'Setlists';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionSave => 'Save';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionRetry => 'Retry';

  @override
  String get searchHint => 'Search title, number, reference or lyrics…';

  @override
  String get searchTooltip => 'Search';

  @override
  String get searchClose => 'Close search';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchNoResults => 'No songs found';

  @override
  String get searchScope => 'Searched titles, numbers, references and lyrics';

  @override
  String searchLyricsFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No title match — found in the lyrics of $count songs',
      one: 'No title match — found in the lyrics of 1 song',
    );
    return '$_temp0';
  }

  @override
  String get searchNoTagMatch => 'No songs match the selected tags and query';

  @override
  String get booksTooltip => 'Books';

  @override
  String get tagsTooltip => 'Tags';

  @override
  String get addSong => 'Add a song';

  @override
  String get backToAllSongs => 'Back to all songs';

  @override
  String get clearTags => 'Clear tags';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Match my device';

  @override
  String get languageHungarian => 'Magyar';

  @override
  String get languageRomanian => 'Română';

  @override
  String get languageEnglish => 'English';

  @override
  String get songNotFound => 'Song not found';

  @override
  String get loading => 'Loading…';

  @override
  String get errorLoadingSongs => 'Error loading songs';

  @override
  String get favoriteAdd => 'Add to favorites';

  @override
  String get favoriteRemove => 'Remove from favorites';

  @override
  String get moreActions => 'More actions';

  @override
  String get songControls => 'Song controls';

  @override
  String get menuPresentation => 'Presentation mode';

  @override
  String get menuEditTags => 'Edit tags';

  @override
  String get menuCopyText => 'Copy song text';

  @override
  String get menuEditSong => 'Edit song';

  @override
  String get menuEditNotation => 'Correct the notation';

  @override
  String get menuDeleteSong => 'Delete song';

  @override
  String get songTextCopied => 'Song text copied.';

  @override
  String get deleteSongTitle => 'Delete song?';

  @override
  String deleteSongBody(String title) {
    return '\"$title\" is stored only on this device. Deleting it cannot be undone.';
  }

  @override
  String get noSheetMusicShowingChords =>
      'No sheet music for this song — showing chords.';

  @override
  String get errorGeneric => 'Error';

  @override
  String get sectionView => 'VIEW';

  @override
  String get sectionTextSize => 'TEXT SIZE';

  @override
  String get sectionTranspose => 'TRANSPOSE';

  @override
  String get sectionCapo => 'CAPO';

  @override
  String get sectionAutoScroll => 'AUTO-SCROLL';

  @override
  String get presetSheetMusic => 'Sheet';

  @override
  String get presetChords => 'Chords';

  @override
  String get presetLyrics => 'Lyrics';

  @override
  String get chordsAboveStaff => 'Chords above staff';

  @override
  String get noSheetMusicOpensInChords =>
      'There is no sheet music for this song, so it opens in Chords.';

  @override
  String get textSizeDecrease => 'Decrease text size';

  @override
  String get textSizeIncrease => 'Increase text size';

  @override
  String get transposeDown => 'Transpose down';

  @override
  String get transposeUp => 'Transpose up';

  @override
  String transposeReset(String key) {
    return 'Reset to $key';
  }

  @override
  String get autoScrollStart => 'Start auto-scroll';

  @override
  String get autoScrollStop => 'Stop auto-scroll';

  @override
  String get autoScrollSpeedPerSong => 'Speed remembered per song';

  @override
  String get autoScrollNotInSheetMusic => 'not in sheet music view';

  @override
  String get speedSlowest => 'Slowest';

  @override
  String get speedSlow => 'Slow';

  @override
  String get speedGentle => 'Gentle';

  @override
  String get speedSteady => 'Steady';

  @override
  String get speedBrisk => 'Brisk';

  @override
  String get speedFast => 'Fast';

  @override
  String get speedFastest => 'Fastest';

  @override
  String get capoNone => 'No capo needed';

  @override
  String capoAt(int fret) {
    return 'Capo $fret';
  }

  @override
  String capoOpenShape(String shape, String key) {
    return 'Play open in $shape (sounds $key)';
  }

  @override
  String capoClamp(int fret, String shape, String key) {
    return 'Clamp fret $fret, finger $shape shapes — sounds $key';
  }

  @override
  String get capoOther => 'Other positions';

  @override
  String capoNoSuggestion(String key) {
    return 'No capo suggestion for $key';
  }

  @override
  String get favoritesEmpty => 'No favorites yet';

  @override
  String get favoritesEmptyHint =>
      'Tap the heart icon on a song to add it here';

  @override
  String get favoritesBrowse => 'Browse Songs';

  @override
  String get errorLoadingFavorites => 'Error loading favorites';

  @override
  String get setlistPrevious => 'Previous song';

  @override
  String get setlistNext => 'Next song';

  @override
  String get setlistStop => 'Stop playing setlist';

  @override
  String get showAllSongs => 'Show all songs';

  @override
  String errorDetail(String detail) {
    return 'Error: $detail';
  }

  @override
  String noSongsInBook(String book) {
    return 'No songs in \"$book\"';
  }

  @override
  String get noSongsAvailable => 'No songs available';

  @override
  String get noSongsHint => 'The songbook that ships with the app is empty.';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionDiscard => 'Discard';

  @override
  String get discardTitle => 'Discard corrections?';

  @override
  String get discardBody =>
      'The changes on this screen have not been saved to the song.';

  @override
  String get discardKeepEditing => 'Keep editing';

  @override
  String get notationNoneStored =>
      'This song has no engraved notation stored, or is no longer on this device.';

  @override
  String notationVerse(int number) {
    return 'Verse $number';
  }

  @override
  String notationMeasure(int number) {
    return 'Measure $number';
  }

  @override
  String get notationPickup => 'Pickup';

  @override
  String notationPickupBeats(int count, String beats) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$beats beats before bar 1',
      one: '$beats beat before bar 1',
    );
    return '$_temp0';
  }

  @override
  String notationMeasureBeats(String total, int expected) {
    return '$total / $expected beats';
  }

  @override
  String get notationNoBeats => 'No beats in this measure.';

  @override
  String notationStalePickupNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count beats sit in this song’s old separate pickup list, which nothing reads, so they are not shown above or below. An upbeat belongs in a leading measure instead.',
      one:
          '1 beat sits in this song’s old separate pickup list, which nothing reads, so it is not shown above or below. An upbeat belongs in a leading measure instead.',
    );
    return '$_temp0';
  }

  @override
  String get beatRestShort => 'rest';

  @override
  String get beatActions => 'Beat actions';

  @override
  String get beatInsertAfter => 'Insert after';

  @override
  String get beatEditTitle => 'EDIT BEAT';

  @override
  String get beatRest => 'Rest';

  @override
  String get beatNote => 'Note';

  @override
  String get beatAccidental => 'Accidental';

  @override
  String get accidentalNatural => 'natural';

  @override
  String get accidentalSharp => 'sharp';

  @override
  String get accidentalFlat => 'flat';

  @override
  String get beatOctave => 'Octave';

  @override
  String get octaveLower => 'Lower octave';

  @override
  String get octaveHigher => 'Higher octave';

  @override
  String get beatDuration => 'Duration';

  @override
  String get beatDotted => 'Dotted';

  @override
  String get beatDottedHint => 'One and a half times the duration';

  @override
  String get beatTieEnd => 'Ties from the previous note';

  @override
  String get beatTieStart => 'Ties to the next note';

  @override
  String get beatSyllable => 'Syllable';

  @override
  String get beatChord => 'Chord above the staff';

  @override
  String beatExtraLyricLines(int count, String lines) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count further lyric lines on this note ($lines) are kept as they are.',
      one: '1 further lyric line on this note ($lines) is kept as it is.',
    );
    return '$_temp0';
  }

  @override
  String get durationWhole => 'whole';

  @override
  String get durationHalf => 'half';

  @override
  String get durationQuarter => 'quarter';

  @override
  String get durationEighth => 'eighth';

  @override
  String get durationSixteenth => 'sixteenth';

  @override
  String durationDotted(String duration) {
    return '$duration, dotted';
  }

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsFontSize => 'Font Size';

  @override
  String get fontSizeDecrease => 'Decrease font size';

  @override
  String get fontSizeIncrease => 'Increase font size';

  @override
  String get settingsDisplay => 'Display';

  @override
  String get settingsDefaultView => 'Default View';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsVersionUnknown => 'unknown';

  @override
  String get settingsTagline => 'Worship Songbook App';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System default';

  @override
  String get settingsViewSheetMusic => 'Sheet Music';

  @override
  String get settingsViewSheetMusicHint => 'Notation with chords and lyrics';

  @override
  String get settingsViewChords => 'Chords';

  @override
  String get settingsViewChordsHint => 'Chords and lyrics only';

  @override
  String get settingsViewLyricsOnly => 'Lyrics Only';

  @override
  String get settingsViewLyricsOnlyHint =>
      'Clean text without notation or chords';
}
