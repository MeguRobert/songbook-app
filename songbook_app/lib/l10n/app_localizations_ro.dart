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
  String get sectionAutoScroll => 'DERULARE';

  @override
  String get presetSheetMusic => 'Partitură';

  @override
  String get presetChords => 'Acord';

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
  String get autoScrollNotInSheetMusic => 'doar cu acorduri';

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

  @override
  String get showAllSongs => 'Arată toate cântecele';

  @override
  String errorDetail(String detail) {
    return 'Eroare: $detail';
  }

  @override
  String noSongsInBook(String book) {
    return 'Nu există cântece în „$book”';
  }

  @override
  String get noSongsAvailable => 'Niciun cântec disponibil';

  @override
  String get noSongsHint =>
      'Cartea de cântece livrată cu aplicația este goală.';

  @override
  String get actionEdit => 'Editează';

  @override
  String get actionApply => 'Aplică';

  @override
  String get actionDiscard => 'Renunță';

  @override
  String get discardTitle => 'Renunți la corecturi?';

  @override
  String get discardBody =>
      'Modificările de pe acest ecran nu au fost salvate în cântec.';

  @override
  String get discardKeepEditing => 'Continuă editarea';

  @override
  String get notationNoneStored =>
      'Acest cântec nu are partitură salvată sau nu se mai află pe acest dispozitiv.';

  @override
  String notationVerse(int number) {
    return 'Strofa $number';
  }

  @override
  String notationMeasure(int number) {
    return 'Măsura $number';
  }

  @override
  String get notationPickup => 'Anacruză';

  @override
  String notationPickupBeats(int count, String beats) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$beats timpi înainte de măsura 1',
      one: '$beats timp înainte de măsura 1',
    );
    return '$_temp0';
  }

  @override
  String notationMeasureBeats(String total, int expected) {
    return '$total / $expected timpi';
  }

  @override
  String get notationNoBeats => 'Nicio notă în această măsură.';

  @override
  String notationStalePickupNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count timpi se află în vechea listă separată de anacruză a acestui cântec, pe care nimic nu o citește, așa că nu apar nici deasupra, nici dedesubt. Anacruza își are locul într-o măsură introductivă.',
      one:
          '1 timp se află în vechea listă separată de anacruză a acestui cântec, pe care nimic nu o citește, așa că nu apare nici deasupra, nici dedesubt. Anacruza își are locul într-o măsură introductivă.',
    );
    return '$_temp0';
  }

  @override
  String get beatRestShort => 'pauză';

  @override
  String get beatActions => 'Acțiuni pentru notă';

  @override
  String get beatInsertAfter => 'Inserează după';

  @override
  String get beatEditTitle => 'EDITARE NOTĂ';

  @override
  String get beatRest => 'Pauză';

  @override
  String get beatNote => 'Notă';

  @override
  String get beatAccidental => 'Alterație';

  @override
  String get accidentalNatural => 'becar';

  @override
  String get accidentalSharp => 'diez';

  @override
  String get accidentalFlat => 'bemol';

  @override
  String get beatOctave => 'Octavă';

  @override
  String get octaveLower => 'Octavă mai joasă';

  @override
  String get octaveHigher => 'Octavă mai înaltă';

  @override
  String get beatDuration => 'Durată';

  @override
  String get beatDotted => 'Cu punct';

  @override
  String get beatDottedHint => 'De o dată și jumătate durata';

  @override
  String get beatTieEnd => 'Legată de nota anterioară';

  @override
  String get beatTieStart => 'Legată de nota următoare';

  @override
  String get beatSyllable => 'Silabă';

  @override
  String get beatChord => 'Acord deasupra portativului';

  @override
  String beatExtraLyricLines(int count, String lines) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Încă $count rânduri de text pe această notă ($lines) rămân neschimbate.',
      one: 'Încă 1 rând de text pe această notă ($lines) rămâne neschimbat.',
    );
    return '$_temp0';
  }

  @override
  String get durationWhole => 'întreagă';

  @override
  String get durationHalf => 'doime';

  @override
  String get durationQuarter => 'pătrime';

  @override
  String get durationEighth => 'optime';

  @override
  String get durationSixteenth => 'șaisprezecime';

  @override
  String durationDotted(String duration) {
    return '$duration, cu punct';
  }

  @override
  String get settingsAppearance => 'Aspect';

  @override
  String get settingsTheme => 'Temă';

  @override
  String get settingsFontSize => 'Dimensiunea textului';

  @override
  String get fontSizeDecrease => 'Micșorează textul';

  @override
  String get fontSizeIncrease => 'Mărește textul';

  @override
  String get settingsDisplay => 'Afișarea cântecului';

  @override
  String get settingsDefaultView => 'Vizualizarea implicită';

  @override
  String get settingsAbout => 'Despre';

  @override
  String get settingsVersion => 'Versiune';

  @override
  String get settingsVersionUnknown => 'necunoscută';

  @override
  String get settingsTagline => 'Carte de cântece pentru închinare';

  @override
  String get themeLight => 'Luminoasă';

  @override
  String get themeDark => 'Întunecată';

  @override
  String get themeSystem => 'Ca sistemul';

  @override
  String get settingsViewSheetMusic => 'Partitură';

  @override
  String get settingsViewSheetMusicHint => 'Partitură cu acorduri și text';

  @override
  String get settingsViewChords => 'Acorduri';

  @override
  String get settingsViewChordsHint => 'Doar acorduri și text';

  @override
  String get settingsViewLyricsOnly => 'Doar text';

  @override
  String get settingsViewLyricsOnlyHint =>
      'Text curat, fără partitură sau acorduri';

  @override
  String get actionRename => 'Redenumește';

  @override
  String get setlistSingular => 'Listă de cântece';

  @override
  String get setlistNotFound => 'Lista nu a fost găsită';

  @override
  String setlistSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cântece',
      one: '1 cântec',
    );
    return '$_temp0';
  }

  @override
  String get setlistOptions => 'Opțiuni pentru listă';

  @override
  String get setlistNew => 'Listă nouă';

  @override
  String get setlistRenameTitle => 'Redenumește lista';

  @override
  String get setlistDeleteTitle => 'Ștergi lista?';

  @override
  String setlistDeleteBody(String name) {
    return '„$name” va fi eliminată definitiv.';
  }

  @override
  String get setlistNameLabel => 'Nume';

  @override
  String get setlistNameHint => 'Numele listei';

  @override
  String get setlistsEmpty => 'Încă nicio listă';

  @override
  String get setlistsEmptyHint => 'Creează una pentru următorul serviciu divin';

  @override
  String get setlistPlay => 'Pornește lista';

  @override
  String get setlistAddSongs => 'Adaugă cântece';

  @override
  String get setlistRemoveSong => 'Elimină din listă';

  @override
  String get setlistEmpty => 'Niciun cântec în această listă';

  @override
  String errorLoadingSongsDetail(String detail) {
    return 'Eroare la încărcarea cântecelor: $detail';
  }

  @override
  String get importSectionPaste => 'LIPEȘTE CÂNTECUL';

  @override
  String get importSectionReplace => 'ÎNLOCUIEȘTE TEXTUL ȘI ACORDURILE';

  @override
  String get importPasteHint =>
      'G       C\nAz Úrra bízom életem\n\nsau [G]Az Úrra [C]bízom életem';

  @override
  String get importMusicXmlFile => 'Fișier MusicXML';

  @override
  String get importParse => 'Procesează';

  @override
  String get importSectionDetails => 'DETALII';

  @override
  String importFromSource(String source) {
    return 'din $source';
  }

  @override
  String get importSourceSaved => 'cântecul salvat';

  @override
  String get importSourcePasted => 'text lipit';

  @override
  String get importTitleField => 'Titlu';

  @override
  String get importNumberField => 'Număr';

  @override
  String get importBookField => 'Carte de cântece';

  @override
  String importKeyFromFile(String key) {
    return 'Tonalitatea $key, din fișier.';
  }

  @override
  String importKeyGuessed(String key) {
    return 'Tonalitatea a fost dedusă ca $key din primul acord.';
  }

  @override
  String get importSectionPreview => 'PREVIZUALIZARE';

  @override
  String importVerseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count strofe',
      one: '1 strofă',
    );
    return '$_temp0';
  }

  @override
  String importBarCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count măsuri',
      one: '1 măsură',
    );
    return '$_temp0';
  }

  @override
  String get importBlockerDeleted =>
      'Acest cântec nu mai este salvat pe acest dispozitiv.';

  @override
  String get importBlockerNothing =>
      'Lipește un cântec sau deschide un fișier MusicXML.';

  @override
  String get importBlockerEmpty =>
      'Nu s-a găsit text sau partitură în această sursă.';

  @override
  String get importBlockerNoTitle => 'Dă un titlu cântecului.';

  @override
  String importErrorNotMusicXml(String name) {
    return '$name nu este un fișier MusicXML. Se acceptă .xml, .musicxml sau .mxl — un fișier MuseScore .mscz trebuie exportat mai întâi.';
  }

  @override
  String importErrorUnreadable(String name) {
    return '$name nu poate fi citit.';
  }

  @override
  String importErrorFailed(String detail) {
    return 'Fișierul nu poate fi importat: $detail';
  }

  @override
  String importWarningsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verifică aceste rânduri',
      one: 'Verifică acest rând',
    );
    return '$_temp0';
  }

  @override
  String get tagsNoneYetAddOne => 'Încă nicio etichetă — adaugă una mai jos.';

  @override
  String get tagAddLabel => 'Adaugă o etichetă';

  @override
  String get tagAddHint => 'ex. Crăciun, cina Domnului';

  @override
  String get tagAddTooltip => 'Adaugă eticheta';

  @override
  String get tagSuggestions => 'Sugestii';

  @override
  String get tagResetToDefault => 'Revino la valorile implicite';

  @override
  String get filterAllSongs => 'Toate cântecele';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cântece',
      one: '1 cântec',
    );
    return '$_temp0';
  }

  @override
  String errorLoadingBooks(String detail) {
    return 'Eroare la încărcarea cărților: $detail';
  }

  @override
  String get filterByTags => 'Filtrează după etichete';

  @override
  String get filterTagsAnd =>
      'Cântecele trebuie să aibă toate etichetele selectate';

  @override
  String get tagsEmpty => 'Încă nicio etichetă';

  @override
  String errorLoadingTags(String detail) {
    return 'Eroare la încărcarea etichetelor: $detail';
  }

  @override
  String get filterClearAllTags => 'Șterge toate etichetele';

  @override
  String get presentationExit => 'Ieșire (Esc)';

  @override
  String sheetSemanticsLabel(String title) {
    return 'Partitura pentru $title';
  }

  @override
  String sheetKey(String key) {
    return 'Tonalitate: $key';
  }

  @override
  String sheetTransposed(String offset) {
    return 'Transpus: $offset';
  }

  @override
  String sheetTime(String signature) {
    return 'Măsură: $signature';
  }

  @override
  String sheetTune(String tune) {
    return 'Melodie: $tune';
  }

  @override
  String sheetOrigin(String origin) {
    return 'Origine: $origin';
  }

  @override
  String get sheetNotAvailable => 'Partitura nu este disponibilă';

  @override
  String get sheetNotAvailableHint =>
      'Comută la vizualizarea cu acorduri pentru a vedea textul cu acorduri';

  @override
  String sheetTransposedFrom(String key) {
    return 'Tonalitatea originală: $key';
  }

  @override
  String sheetMissingForKey(String key, String original) {
    return 'Nu există partitură în $key. Se afișează tonalitatea originală ($original).';
  }

  @override
  String get sheetNoneForSong => 'Acest cântec nu are partitură';

  @override
  String get routeNotFound => 'Pagina nu a fost găsită';

  @override
  String get routeGoHome => 'Înapoi la început';

  @override
  String get sectionVoice => 'VOCE';

  @override
  String get voiceMelody => 'Melodie';

  @override
  String get voiceAlto => 'Alto';

  @override
  String get voiceTenor => 'Tenor';

  @override
  String get voiceBass => 'Bas';
}
