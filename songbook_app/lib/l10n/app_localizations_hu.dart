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

  @override
  String get favoriteAdd => 'Kedvencekhez adás';

  @override
  String get favoriteRemove => 'Eltávolítás a kedvencekből';

  @override
  String get moreActions => 'További műveletek';

  @override
  String get songControls => 'Ének beállításai';

  @override
  String get menuPresentation => 'Kivetítés';

  @override
  String get menuEditTags => 'Címkék szerkesztése';

  @override
  String get menuCopyText => 'Ének szövegének másolása';

  @override
  String get menuEditSong => 'Ének szerkesztése';

  @override
  String get menuEditNotation => 'Kottajavítás';

  @override
  String get menuDeleteSong => 'Ének törlése';

  @override
  String get songTextCopied => 'Az ének szövegét kimásoltam.';

  @override
  String get deleteSongTitle => 'Törlöd az éneket?';

  @override
  String deleteSongBody(String title) {
    return '„$title” csak ezen a készüléken van meg. A törlés nem vonható vissza.';
  }

  @override
  String get noSheetMusicShowingChords =>
      'Ehhez az énekhez nincs kotta — az akkordokat mutatom.';

  @override
  String get errorGeneric => 'Hiba';

  @override
  String get sectionView => 'MEGJELENÍTÉS';

  @override
  String get sectionTextSize => 'SZÖVEGMÉRET';

  @override
  String get sectionTranspose => 'TRANSZPONÁLÁS';

  @override
  String get sectionCapo => 'KAPODASZTER';

  @override
  String get sectionAutoScroll => 'AUTOMATIKUS GÖRGETÉS';

  @override
  String get presetSheetMusic => 'Kotta';

  @override
  String get presetChords => 'Akkordok';

  @override
  String get presetLyrics => 'Szöveg';

  @override
  String get chordsAboveStaff => 'Akkordok a kotta felett';

  @override
  String get noSheetMusicOpensInChords =>
      'Ehhez az énekhez nincs kotta, ezért az Akkordok nézetben nyílik meg.';

  @override
  String get textSizeDecrease => 'Kisebb szöveg';

  @override
  String get textSizeIncrease => 'Nagyobb szöveg';

  @override
  String get transposeDown => 'Lejjebb transzponálás';

  @override
  String get transposeUp => 'Feljebb transzponálás';

  @override
  String transposeReset(String key) {
    return 'Vissza $key-re';
  }

  @override
  String get autoScrollStart => 'Görgetés indítása';

  @override
  String get autoScrollStop => 'Görgetés leállítása';

  @override
  String get autoScrollSpeedPerSong => 'A sebességet énekenként megjegyzem';

  @override
  String get autoScrollNotInSheetMusic => 'a kotta nézetben nem működik';

  @override
  String get speedSlowest => 'Leglassabb';

  @override
  String get speedSlow => 'Lassú';

  @override
  String get speedGentle => 'Kényelmes';

  @override
  String get speedSteady => 'Egyenletes';

  @override
  String get speedBrisk => 'Fürge';

  @override
  String get speedFast => 'Gyors';

  @override
  String get speedFastest => 'Leggyorsabb';

  @override
  String get capoNone => 'Nem kell kapodaszter';

  @override
  String capoAt(int fret) {
    return '$fret. fogás';
  }

  @override
  String capoOpenShape(String shape, String key) {
    return 'Játszd $shape fogásban (így $key szól)';
  }

  @override
  String capoClamp(int fret, String shape, String key) {
    return '$fret. fogásra tedd, $shape fogásokkal — így $key szól';
  }

  @override
  String get capoOther => 'Más pozíciók';

  @override
  String capoNoSuggestion(String key) {
    return '$key-hez nincs kapodaszter-javaslat';
  }

  @override
  String get favoritesEmpty => 'Még nincs kedvenc';

  @override
  String get favoritesEmptyHint =>
      'Koppints egy ének szív ikonjára, hogy ide kerülön';

  @override
  String get favoritesBrowse => 'Énekek böngészése';

  @override
  String get errorLoadingFavorites => 'Nem sikerült betölteni a kedvenceket';

  @override
  String get setlistPrevious => 'Előző ének';

  @override
  String get setlistNext => 'Következő ének';

  @override
  String get setlistStop => 'Énekrend leállítása';
}
