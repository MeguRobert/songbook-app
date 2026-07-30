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
}
