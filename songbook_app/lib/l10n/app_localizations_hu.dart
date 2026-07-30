// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Énekeskönyv';

  @override
  String get navSongs => 'Énekek';

  @override
  String get navSetlists => 'Énekrendek';

  @override
  String get navFavorites => 'Kedvencek';

  @override
  String get navSettings => 'Beállítások';

  @override
  String get actionCancel => 'Mégsem';

  @override
  String get actionDelete => 'Törlés';

  @override
  String get actionSave => 'Mentés';

  @override
  String get actionClear => 'Törlés';

  @override
  String get actionRetry => 'Újra';

  @override
  String get searchHint => 'Keresés cím, szám, hivatkozás vagy szöveg szerint…';

  @override
  String get searchTooltip => 'Keresés';

  @override
  String get searchClose => 'Keresés bezárása';

  @override
  String get searchRecent => 'Korábbi keresések';

  @override
  String get searchNoResults => 'Nincs találat';

  @override
  String get searchScope =>
      'A keresés a címekre, számokra, hivatkozásokra és a szövegre is kiterjedt';

  @override
  String searchLyricsFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A címek között nincs találat — $count ének szövegében megtaláltam',
      one: 'A címek között nincs találat — 1 ének szövegében megtaláltam',
    );
    return '$_temp0';
  }

  @override
  String get searchNoTagMatch =>
      'Egy ének sem felel meg a kiválasztott címkéknek és a keresésnek';

  @override
  String get booksTooltip => 'Énekeskönyvek';

  @override
  String get tagsTooltip => 'Címkék';

  @override
  String get addSong => 'Ének hozzáadása';

  @override
  String get backToAllSongs => 'Vissza az összes énekhez';

  @override
  String get clearTags => 'Címkék törlése';

  @override
  String get settingsTitle => 'Beállítások';

  @override
  String get settingsLanguage => 'Nyelv';

  @override
  String get settingsLanguageSystem => 'A készülék nyelve';

  @override
  String get languageHungarian => 'Magyar';

  @override
  String get languageRomanian => 'Română';

  @override
  String get languageEnglish => 'English';

  @override
  String get songNotFound => 'Az ének nem található';

  @override
  String get loading => 'Betöltés…';

  @override
  String get errorLoadingSongs => 'Nem sikerült betölteni az énekeket';
}
