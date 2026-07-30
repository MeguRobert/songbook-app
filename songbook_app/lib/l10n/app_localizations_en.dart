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
}
