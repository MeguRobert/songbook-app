// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Carte de cântece';

  @override
  String get navSongs => 'Cântece';

  @override
  String get navSetlists => 'Liste de cântece';

  @override
  String get navFavorites => 'Favorite';

  @override
  String get navSettings => 'Setări';

  @override
  String get actionCancel => 'Anulează';

  @override
  String get actionDelete => 'Șterge';

  @override
  String get actionSave => 'Salvează';

  @override
  String get actionClear => 'Golește';

  @override
  String get actionRetry => 'Reîncearcă';

  @override
  String get searchHint => 'Caută după titlu, număr, referință sau versuri…';

  @override
  String get searchTooltip => 'Căutare';

  @override
  String get searchClose => 'Închide căutarea';

  @override
  String get searchRecent => 'Căutări recente';

  @override
  String get searchNoResults => 'Niciun cântec găsit';

  @override
  String get searchScope =>
      'Am căutat în titluri, numere, referințe și versuri';

  @override
  String searchLyricsFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Niciun titlu potrivit — găsit în versurile a $count de cântece',
      few: 'Niciun titlu potrivit — găsit în versurile a $count cântece',
      one: 'Niciun titlu potrivit — găsit în versurile unui cântec',
    );
    return '$_temp0';
  }

  @override
  String get searchNoTagMatch =>
      'Niciun cântec nu corespunde etichetelor selectate și căutării';

  @override
  String get booksTooltip => 'Cărți de cântece';

  @override
  String get tagsTooltip => 'Etichete';

  @override
  String get addSong => 'Adaugă un cântec';

  @override
  String get backToAllSongs => 'Înapoi la toate cântecele';

  @override
  String get clearTags => 'Șterge etichetele';

  @override
  String get settingsTitle => 'Setări';

  @override
  String get settingsLanguage => 'Limbă';

  @override
  String get settingsLanguageSystem => 'Limba dispozitivului';

  @override
  String get languageHungarian => 'Magyar';

  @override
  String get languageRomanian => 'Română';

  @override
  String get languageEnglish => 'English';

  @override
  String get songNotFound => 'Cântecul nu a fost găsit';

  @override
  String get loading => 'Se încarcă…';

  @override
  String get errorLoadingSongs => 'Nu am putut încărca cântecele';

  @override
  String get favoriteAdd => 'Adaugă la favorite';

  @override
  String get favoriteRemove => 'Elimină de la favorite';

  @override
  String get moreActions => 'Mai multe acțiuni';

  @override
  String get songControls => 'Setările cântecului';

  @override
  String get menuPresentation => 'Mod de prezentare';

  @override
  String get menuEditTags => 'Editează etichetele';

  @override
  String get menuCopyText => 'Copiază textul cântecului';

  @override
  String get menuEditSong => 'Editează cântecul';

  @override
  String get menuEditNotation => 'Corectează notele';

  @override
  String get menuDeleteSong => 'Șterge cântecul';

  @override
  String get songTextCopied => 'Am copiat textul cântecului.';

  @override
  String get deleteSongTitle => 'Ștergi cântecul?';

  @override
  String deleteSongBody(String title) {
    return '„$title” este salvat doar pe acest dispozitiv. Ștergerea nu poate fi anulată.';
  }

  @override
  String get noSheetMusicShowingChords =>
      'Acest cântec nu are partitură — arăt acordurile.';

  @override
  String get errorGeneric => 'Eroare';

  @override
  String get sectionView => 'AFIȘARE';

  @override
  String get sectionTextSize => 'MĂRIMEA TEXTULUI';

  @override
  String get sectionTranspose => 'TRANSPUNERE';

  @override
  String get sectionCapo => 'CAPODASTRU';

  @override
  String get sectionAutoScroll => 'DERULARE AUTOMATĂ';

  @override
  String get presetSheetMusic => 'Partitură';

  @override
  String get presetChords => 'Acorduri';

  @override
  String get presetLyrics => 'Versuri';

  @override
  String get chordsAboveStaff => 'Acorduri deasupra portativului';

  @override
  String get noSheetMusicOpensInChords =>
      'Acest cântec nu are partitură, așa că se deschide în Acorduri.';

  @override
  String get textSizeDecrease => 'Text mai mic';

  @override
  String get textSizeIncrease => 'Text mai mare';

  @override
  String get transposeDown => 'Transpune mai jos';

  @override
  String get transposeUp => 'Transpune mai sus';

  @override
  String transposeReset(String key) {
    return 'Revino la $key';
  }

  @override
  String get autoScrollStart => 'Pornește derularea';

  @override
  String get autoScrollStop => 'Oprește derularea';

  @override
  String get autoScrollSpeedPerSong => 'Rețin viteza pentru fiecare cântec';

  @override
  String get autoScrollNotInSheetMusic => 'nu în vizualizarea partiturii';

  @override
  String get speedSlowest => 'Cea mai lentă';

  @override
  String get speedSlow => 'Lentă';

  @override
  String get speedGentle => 'Moderată';

  @override
  String get speedSteady => 'Constantă';

  @override
  String get speedBrisk => 'Vioaie';

  @override
  String get speedFast => 'Rapidă';

  @override
  String get speedFastest => 'Cea mai rapidă';

  @override
  String get capoNone => 'Nu ai nevoie de capodastru';

  @override
  String capoAt(int fret) {
    return 'Capodastru $fret';
  }

  @override
  String capoOpenShape(String shape, String key) {
    return 'Cântă deschis în $shape (sună $key)';
  }

  @override
  String capoClamp(int fret, String shape, String key) {
    return 'Prinde la $fret, cu acorduri $shape — sună $key';
  }

  @override
  String get capoOther => 'Alte poziții';

  @override
  String capoNoSuggestion(String key) {
    return 'Nicio sugestie de capodastru pentru $key';
  }

  @override
  String get favoritesEmpty => 'Încă nu ai favorite';

  @override
  String get favoritesEmptyHint =>
      'Apasă pe inima unui cântec pentru a-l adăuga aici';

  @override
  String get favoritesBrowse => 'Răsfoiește cântecele';

  @override
  String get errorLoadingFavorites => 'Nu am putut încărca favoritele';

  @override
  String get setlistPrevious => 'Cântecul anterior';

  @override
  String get setlistNext => 'Cântecul următor';

  @override
  String get setlistStop => 'Oprește lista de cântece';
}
