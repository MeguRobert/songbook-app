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
  String get measureActions => 'Acțiuni pentru măsură';

  @override
  String get measureProperties => 'Proprietățile măsurii';

  @override
  String get measureEditTitle => 'PROPRIETĂȚILE MĂSURII';

  @override
  String get measureInsertBefore => 'Inserează măsură înainte';

  @override
  String get measureInsertAfter => 'Inserează măsură după';

  @override
  String get measureMerge => 'Unește cu măsura anterioară';

  @override
  String get measureDelete => 'Șterge măsura';

  @override
  String get measureSplitHere => 'Începe o măsură nouă aici';

  @override
  String get measureRepeatStart => 'Semn de repetiție la început';

  @override
  String get measureRepeatEnd => 'Semn de repetiție la sfârșit';

  @override
  String get measureLineBreak => 'Rând nou după această măsură';

  @override
  String get measurePickup => 'Măsură de anacruză';

  @override
  String get measurePickupHint =>
      'Scurtă intenționat: nu se numerotează și nu se verifică față de măsură';

  @override
  String get measureVolta => 'Paranteză de repetiție';

  @override
  String get measureVoltaNone => 'Niciuna';

  @override
  String measureVoltaEnding(int number) {
    return 'Finalul $number';
  }

  @override
  String get notationOtherVoices => 'ALTE VOCI';

  @override
  String get notationOtherVoicesHint =>
      'Se păstrează cu cântecul și nu sunt scrise pe portativ aici. Alege vocea de citit din setările cântecului.';

  @override
  String notationVoiceMeasures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count măsuri',
      one: '1 măsură',
    );
    return '$_temp0';
  }

  @override
  String get voiceActions => 'Acțiuni pentru voce';

  @override
  String get voiceRenameTitle => 'Redenumește vocea';

  @override
  String get voiceName => 'Numele vocii';

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
  String get importSectionLines => 'LINII';

  @override
  String get importLineKindChords => 'acorduri';

  @override
  String get importLineKindLyric => 'versuri';

  @override
  String get importLineOverridden => 'tu ai stabilit asta';

  @override
  String get importTokenEditTitle => 'Corectează acordul';

  @override
  String get importTokenEditHint =>
      'Cititorul citește greșit un caracter din când în când — `Csus2` poate reveni ca `5US2`. De obicei atât trebuie corectat.';

  @override
  String get importLinesHint =>
      'Atinge un acord pentru a-l corecta. Folosește butoanele când un rând întreg a fost citit ca tipul greșit.';

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
  String get importBlockerNoNumber => 'Dă un număr cântecului.';

  @override
  String get importBlockerBadNumber =>
      'Numărul trebuie să fie un întreg mai mare decât zero.';

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

  @override
  String get accountSection => 'CONT';

  @override
  String get signIn => 'Conectare';

  @override
  String get signUp => 'Creează cont';

  @override
  String get signOut => 'Deconectare';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Parolă';

  @override
  String get forgotPassword => 'Ai uitat parola?';

  @override
  String get passwordResetSent =>
      'Dacă există un cont pentru această adresă, am trimis linkul de resetare.';

  @override
  String signedInAs(String email) {
    return 'Conectat ca $email';
  }

  @override
  String get notSignedIn => 'Neconectat';

  @override
  String get accountOptional =>
      'Nu ai nevoie de cont. Cântecele de pe acest dispozitiv funcționează și offline.';

  @override
  String get accountsUnavailable => 'Conturile nu sunt disponibile momentan.';

  @override
  String get verifyEmailTitle => 'Confirmă adresa de e-mail';

  @override
  String verifyEmailBody(String email) {
    return 'Am trimis un link către $email. Confirmă-l înainte de a contribui cu cântece.';
  }

  @override
  String get resendConfirmation => 'Trimite din nou';

  @override
  String get confirmationResent => 'Trimis.';

  @override
  String get haveAccountPrompt => 'Ai deja un cont?';

  @override
  String get needAccountPrompt => 'Ai nevoie de un cont?';

  @override
  String get authErrorInvalidCredentials =>
      'Adresa de e-mail și parola nu corespund.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirmă mai întâi adresa de e-mail.';

  @override
  String get authErrorEmailAlreadyRegistered =>
      'Există deja un cont pentru această adresă.';

  @override
  String get authErrorWeakPassword =>
      'Alege o parolă mai lungă – cel puțin 6 caractere.';

  @override
  String get authErrorInvalidEmail => 'Aceasta nu pare o adresă de e-mail.';

  @override
  String get authErrorRateLimited =>
      'Prea multe încercări. Așteaptă un minut și încearcă din nou.';

  @override
  String get authErrorServerRejected =>
      'Serverul a refuzat. Încearcă mai târziu.';

  @override
  String get authErrorNetwork =>
      'Nu am putut contacta serverul. Verifică conexiunea.';

  @override
  String get authErrorUnknown => 'A apărut o eroare. Încearcă din nou.';

  @override
  String get signInWithGoogle => 'Continuă cu Google';

  @override
  String get authOrDivider => 'sau';

  @override
  String get moderationQueueTitle => 'În așteptare';

  @override
  String get moderationQueueEmpty => 'Nu așteaptă nimic.';

  @override
  String get mySubmissionsTitle => 'Cântecele trimise de mine';

  @override
  String get mySubmissionsEmpty => 'Nu ai trimis încă niciun cântec.';

  @override
  String get menuShareSong => 'Împarte cu adunarea';

  @override
  String get shareSongTitle => 'Trimiți acest cântec?';

  @override
  String shareSongBody(String title) {
    return '„$title” ajunge la moderatori. Intră în cartea de cântări comună doar după ce unul dintre ei îl aprobă, iar copia ta rămâne pe acest dispozitiv oricum.';
  }

  @override
  String get shareSongConfirm => 'Trimite';

  @override
  String shareSongPublishBody(String title) {
    return '„$title” intră direct în cartea de cântări comună. Tu ești moderator, așa că nu mai e nimeni de așteptat — iar copia ta rămâne pe acest dispozitiv oricum.';
  }

  @override
  String get shareSongPublish => 'Publică';

  @override
  String get shareSongSignInTitle => 'Autentifică-te pentru a trimite';

  @override
  String get shareSongSignInBody =>
      'Trimiterea are nevoie de un cont, ca adunarea să vadă cine a contribuit cântecul. Cântecul este deja salvat pe acest dispozitiv și rămâne acolo.';

  @override
  String get shareSongSent => 'Trimis spre aprobare.';

  @override
  String get shareSongPublished => 'Publicat în cartea de cântări.';

  @override
  String get shareSongAlreadySent =>
      'Ai trimis deja acest cântec. Așteaptă aprobarea.';

  @override
  String get shareSongAlreadyPublished =>
      'Acest cântec este deja în cartea de cântări comună.';

  @override
  String get shareSongNumberTaken =>
      'Există deja un cântec cu acest număr în această carte. Dă-i alt număr și încearcă din nou.';

  @override
  String get shareSongFailed =>
      'Cântecul nu a putut fi trimis. Verifică conexiunea și încearcă din nou.';

  @override
  String get approve => 'Aprobă';

  @override
  String get reject => 'Respinge';

  @override
  String get rejectReasonLabel =>
      'De ce? Cel care a trimis va vedea acest mesaj.';

  @override
  String get rejectReasonRequired => 'Dă un motiv, ca să poată corecta.';

  @override
  String get withdraw => 'Retrage';

  @override
  String get statusDraft => 'Ciornă';

  @override
  String get statusPending => 'În așteptare';

  @override
  String get statusApproved => 'În cartea de cântece comună';

  @override
  String get statusRejected => 'Respins';

  @override
  String get moderationDecided => 'Gata.';

  @override
  String get importPhoto => 'Fotografie';

  @override
  String get importSourcePhoto => 'fotografie';

  @override
  String get importPhotoReading => 'Se citește fotografia…';

  @override
  String get importPhotoNotConfigured =>
      'În această versiune Songbook partitura nu poate fi citită.';

  @override
  String get importPhotoHint =>
      'Citește versurile și acordurile de pe pagină, pe dispozitivul tău.';

  @override
  String get importSectionPhoto => 'FOTOGRAFIE';

  @override
  String get importPhotoZoomHint =>
      'Apropie degetele sau derulează pentru mărire.';

  @override
  String get importPhotoSheetMusic => 'Pagina aceasta are partitură';

  @override
  String get importPhotoSheetMusicHint =>
      'Apasă cartea ca să stea plată și fotografiaz-o de sus, drept deasupra paginii — pe o pagină curbată notele se pierd. Citirea partiturii are nevoie de internet și poate dura un minut.';

  @override
  String get importPhotoSignIn =>
      'Conectează-te mai întâi: partitura este citită de un serviciu comun, nu de dispozitivul tău.';

  @override
  String get importPhotoNoReader =>
      'Fotografiile pot fi citite doar în versiunea de browser a aplicației Songbook.';

  @override
  String get commonSave => 'Salvează';

  @override
  String get commonCancel => 'Anulează';

  @override
  String get voiceAll => 'Toate';

  @override
  String importNoticeUnknownDirective(int line, String text) {
    return 'Rândul $line: am ignorat directiva necunoscută „$text”.';
  }

  @override
  String importNoticeAmbiguousBareRoot(int line, String text) {
    return 'Rândul $line: „$text” poate fi un rând cu un singur acord sau un rând de text; l-am păstrat ca text.';
  }

  @override
  String importNoticeBracketNotAChord(int line, String text) {
    return 'Rândul $line: „[$text]” nu este un acord; l-am păstrat ca text.';
  }

  @override
  String get importNoticeTimewiseScore =>
      'Acest fișier este de tip score-timewise, așa că măsurile pot fi grupate greșit. Salvează-l ca score-partwise pentru un import curat.';

  @override
  String get importNoticeNoNotes => 'Nu am găsit nicio notă în fișier.';

  @override
  String importNoticeExtraVoicesKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Am păstrat $count voci în afară de melodie — doar melodia este scrisă pe portativ. Poți schimba vocea din setările cântecului.',
      one:
          'Am păstrat 1 voce în afară de melodie — doar melodia este scrisă pe portativ. Poți schimba vocea din setările cântecului.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeGraceNotesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Am omis $count note de podoabă: notația nu are timp pentru note de podoabă.',
      one:
          'Am omis 1 notă de podoabă: notația nu are timp pentru note de podoabă.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeChordsReduced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Am redus $count acorduri la nota lor de sus; notele de jos au fost păstrate ca voci suplimentare.',
      one:
          'Am redus 1 acord la nota lui de sus; notele de jos au fost păstrate ca voci suplimentare.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeDoubleAccidentals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Am aproximat $count alterații duble la un singur diez sau bemol — notația păstrează doar una.',
      one:
          'Am aproximat 1 alterație dublă la un singur diez sau bemol — notația păstrează doar una.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeDoubleDots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Am importat $count note cu două puncte ca note cu un punct.',
      one: 'Am importat 1 notă cu două puncte ca notă cu un punct.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeUnsupportedNoteValues(int count, String text) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Duratele $text nu pot fi desenate, așa că le-am aproximat la cele mai apropiate durate care pot fi desenate.',
      one:
          'Durata $text nu poate fi desenată, așa că am aproximat-o la cea mai apropiată durată care poate fi desenată.',
    );
    return '$_temp0';
  }

  @override
  String get importNoticeEmptyXmlInput => 'Fișierul MusicXML este gol.';

  @override
  String importNoticeInvalidXml(String text) {
    return 'Acest fișier nu este XML valid: $text';
  }

  @override
  String get importNoticeContainerManifest =>
      'Acesta este cuprinsul din interiorul unui fișier .mxl, nu o partitură. Deschide fișierul .mxl în sine.';

  @override
  String get importNoticeEmptyMxlInput => 'Fișierul .mxl este gol.';

  @override
  String importNoticeUnreadableArchive(String text) {
    return 'Aceasta nu este o arhivă .mxl care poate fi citită: $text';
  }

  @override
  String get importNoticeNoScoreInArchive =>
      'Arhiva .mxl nu conține nicio partitură MusicXML.';

  @override
  String importNoticeContinuationWithoutChord(int line, String text) {
    return 'Rândul $line: „$text” nu are un acord înainte pe care să îl continue; a fost omis.';
  }

  @override
  String importNoticePhotoLowResolution(String text, int count) {
    return 'Fotografia a sosit la $text, în $count KB — prea comprimată ca să păstreze liniile fine. Accentele ő și ű dispar primele, așa că sunt de așteptat câteva litere greșite. Galeria telefonului predă o copie micșorată; dacă alegi aceeași fotografie prin Fișiere, primești de obicei originalul la calitate completă.';
  }

  @override
  String get importNoticePhotoShowThroughRemoved =>
      'O parte a paginii s-a citit ca o a doua cerneală, palidă — versoul care se vede prin hârtie, sau lumină neuniformă — și a fost curățată înainte de citire. Dacă lipsește un acord, o fotografie la lumină mai uniformă se va citi mai bine.';

  @override
  String importNoticePhotoTwoSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Pagina are $count cântece unul lângă altul. Le-am citit pe toate, în ordinea de citire — șterge-l pe cel de care nu aveai nevoie.',
    );
    return '$_temp0';
  }

  @override
  String get importNoticePhotoNoChords =>
      'Nu am recunoscut niciun acord — au fost importate doar versurile.';

  @override
  String get importNoticePhotoNothingLegible =>
      'Nu am găsit nimic lizibil în fotografia aceasta.';

  @override
  String get importNoticePhotoCouldNotDecode =>
      'Acest fișier nu este o imagine pe care browserul o poate deschide. O captură de ecran foarte lungă poate fi prea mare ca să fie deschisă, iar un videoclip sau un fișier deteriorat nu se deschide deloc. Salvează-l din nou ca JPEG sau PNG ori fă captura în bucăți mai scurte.';

  @override
  String importNoticePhotoGermanNoteNames(String text) {
    return '$text va fi stocat sub denumirea engleză (H este si natural). Aplicația păstrează o singură scriere pentru fiecare notă, ca transpunerea să rămână exactă.';
  }

  @override
  String importNoticePhotoLowercaseCRaised(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count acorduri au fost citite ca un c mic și stocate ca do major (C). În tipar, C și c au aceeași formă la două dimensiuni, așa că unul mic este aproape întotdeauna o majusculă căreia cititorul i-a greșit dimensiunea — dacă pagina înseamnă într-adevăr minorul, scrie Cm.',
    );
    return '$_temp0';
  }

  @override
  String get roleMember => 'Membru';

  @override
  String get roleModerator => 'Moderator';

  @override
  String get roleAdministrator => 'Administrator';

  @override
  String get roleMemberDescription =>
      'Poate citi cartea de cântări și poate propune cântări spre aprobare.';

  @override
  String get roleModeratorDescription =>
      'Poate aproba sau respinge propunerile și poate corecta orice cântare.';

  @override
  String get roleAdministratorDescription =>
      'Tot ce poate face un moderator, plus gestionarea conturilor și a setărilor.';

  @override
  String get adminTitle => 'Administrare';

  @override
  String get adminNotPermitted =>
      'Această secțiune este pentru administratori.';

  @override
  String get adminUsersTitle => 'Membri';

  @override
  String get adminUserTitle => 'Membru';

  @override
  String get adminUserGone => 'Acest cont nu mai există.';

  @override
  String get adminSettingsTitle => 'Setări pentru contribuții';

  @override
  String get adminSettingsSubtitle =>
      'Cine poate trimite cântări și regulile pe care le acceptă';

  @override
  String adminWaitingCount(String count) {
    return '$count în așteptare';
  }

  @override
  String adminMemberCount(String count) {
    return '$count conturi';
  }

  @override
  String get adminSubmissionsClosedNotice =>
      'Trimiterile sunt închise. Nimeni nu poate propune o cântare.';

  @override
  String get adminReopen => 'Deschide';

  @override
  String get adminSearchUsers => 'Caută după nume sau adresă';

  @override
  String get adminFilterAll => 'Toți';

  @override
  String get adminInvite => 'Invită';

  @override
  String get adminSendInvite => 'Trimite invitația';

  @override
  String get adminInviteSent => 'Invitația a fost trimisă.';

  @override
  String get adminUsersUnavailable =>
      'Lista de membri nu a putut fi încărcată.';

  @override
  String get adminNoMatchingUsers => 'Nu există rezultate.';

  @override
  String get adminActionDone => 'Gata.';

  @override
  String get adminActionFailed => 'Nu a funcționat.';

  @override
  String get adminCannotActOnSelf =>
      'Nu îți poți schimba propriul rol și nu îți poți șterge propriul cont.';

  @override
  String get adminLastAdministrator =>
      'Trebuie să existe cel puțin un administrator.';

  @override
  String get adminRole => 'Rol';

  @override
  String get adminChange => 'Modifică';

  @override
  String get adminChangeRole => 'Modifică rolul';

  @override
  String get adminEmailStatus => 'Adresă de e-mail';

  @override
  String get adminEmailConfirmed => 'Confirmată';

  @override
  String get adminEmailUnconfirmed => 'Neconfirmată';

  @override
  String get adminGuidelinesStatus => 'Regulile de contribuție';

  @override
  String get adminGuidelinesAccepted => 'Acceptate';

  @override
  String get adminGuidelinesNotAccepted => 'Încă neacceptate';

  @override
  String get adminLastSignIn => 'Ultima conectare';

  @override
  String get adminNeverSignedIn => 'nu s-a conectat niciodată';

  @override
  String get adminSubmissions => 'Cântări trimise';

  @override
  String adminTallyApproved(int count) {
    return '$count aprobate';
  }

  @override
  String adminTallyPending(int count) {
    return '$count în așteptare';
  }

  @override
  String adminTallyRejected(int count) {
    return '$count respinse';
  }

  @override
  String get adminDeleteAccount => 'Șterge acest cont';

  @override
  String get adminDeleteWarning => 'Această acțiune nu poate fi anulată.';

  @override
  String get adminDeleteKeepsApproved =>
      'Cântările deja aprobate rămân în cartea de cântări, cu numele înregistrat la trimitere. Cele aflate încă în așteptare sau respinse se șterg.';

  @override
  String adminDeleteTypeToConfirm(String address) {
    return 'Scrie $address pentru confirmare.';
  }

  @override
  String get adminDeletePermanently => 'Șterge definitiv';

  @override
  String get adminSubmissionsSection => 'Trimiteri';

  @override
  String get adminSubmissionsOpen => 'Acceptă cântări noi';

  @override
  String get adminSubmissionsOpenHelp =>
      'Dezactivează pentru a nu mai accepta cântări noi.';

  @override
  String get adminRequireConfirmedEmail => 'Cere o adresă confirmată';

  @override
  String get adminRequireConfirmedEmailHelp =>
      'Cine nu și-a confirmat adresa nu poate trimite cântări.';

  @override
  String get adminDailyCap => 'Cântări pe persoană pe zi';

  @override
  String get adminDailyCapHelp =>
      'Limitează cât de repede un cont poate umple lista.';

  @override
  String get adminGuidelinesSection => 'Regulile de contribuție';

  @override
  String get adminGuidelinesHelp =>
      'Toți citesc acest text și îl acceptă o dată, înainte de prima trimitere.';

  @override
  String get actionOk => 'OK';

  @override
  String get publishClosedTitle => 'Trimiterile sunt închise';

  @override
  String get publishClosedBody =>
      'Momentan nu se acceptă cântări noi. Cântarea ta rămâne salvată pe acest dispozitiv.';

  @override
  String publishConfirmEmailBody(String email) {
    return 'Confirmă mai întâi adresa de e-mail. Am trimis un link la $email.';
  }

  @override
  String get publishNameTitle => 'Ce nume să afișăm?';

  @override
  String get publishNameBody =>
      'Numele tău apare lângă cântare, ca adunarea să vadă cine a adus-o.';

  @override
  String get publishNameLabel => 'Nume';

  @override
  String get publishNameRequired => 'Te rugăm să introduci un nume.';

  @override
  String get publishGuidelinesTitle => 'Înainte de a trimite';

  @override
  String get publishGuidelinesAgree =>
      'Am citit regulile și cântarea mea le respectă.';

  @override
  String get publishGuidelinesAccept => 'Accept și trimit';

  @override
  String get publishRefusedTitle => 'Nu a fost trimisă';

  @override
  String get publishDailyLimitBody =>
      'Ai trimis deja astăzi atâtea cântări câte permite limita. Te rugăm să încerci mâine.';

  @override
  String get publishProfileSaveFailed =>
      'Nu s-a putut salva. Verifică conexiunea și încearcă din nou.';

  @override
  String submittedBy(String name) {
    return 'Trimisă de $name';
  }

  @override
  String submittedByFormerMember(String name) {
    return 'Trimisă de $name, care a plecat de atunci';
  }

  @override
  String get legalPrivacyTitle => 'Confidențialitate';

  @override
  String get legalTermsTitle => 'Condiții de utilizare';

  @override
  String get legalUpdated => 'Ultima actualizare: 27 august 2026';

  @override
  String get legalContactTitle => 'Cui îi scrii';

  @override
  String legalContactBody(String address) {
    return 'Scrie la $address pentru orice ține de pagina aceasta — o întrebare, o corectură sau o cerere de ștergere a contului.';
  }

  @override
  String get settingsPrivacy => 'Confidențialitate și condiții';

  @override
  String get settingsPrivacySubtitle =>
      'Ce se păstrează și ce nu pleacă niciodată de pe dispozitiv';

  @override
  String get authLegalNotice =>
      'Dacă îți faci cont, accepți condițiile de utilizare. Ambele pagini sunt scurte.';

  @override
  String get privacyIntro =>
      'Songbook este ținut de o singură adunare, pentru uzul ei. Nu are reclame, nu urmărește pe nimeni și nimic nu se vinde nimănui. Pagina aceasta spune ce se păstrează, unde, cine poate vedea și cum scapi de ele.';

  @override
  String get privacyNoAccountTitle => 'Nu ai nevoie de cont';

  @override
  String get privacyNoAccountBody =>
      'Căutarea, citirea unei cântări, schimbarea tonalității și proiectarea funcționează fără autentificare. Tot ce urmează te privește doar dacă alegi să te autentifici sau să adaugi cântări proprii.';

  @override
  String get privacyOnDeviceTitle => 'Ce rămâne pe dispozitivul tău';

  @override
  String get privacyOnDeviceBody =>
      'Favoritele, listele tale de cântece, ultimele câteva căutări, cântările pe care le-ai adăugat dar nu le-ai trimis și toate setările de afișare — tema, mărimea textului, acordurile pornite sau oprite, viteza de derulare, limba — se păstrează în acest browser, pe acest dispozitiv. Nu se încarcă nicăieri, nimeni altcineva nu le vede, iar dacă ștergi datele site-ului din browser dispar definitiv.';

  @override
  String get privacyServerTitle => 'Ce se păstrează pe server';

  @override
  String get privacyServerBody =>
      '• Dacă îți faci cont: adresa de e-mail, parola într-o formă criptată pe care nimeni nu o poate citi înapoi, când a fost creat contul, când te-ai autentificat ultima dată și dacă ți-ai confirmat adresa.\n• Numele afișat pe care îl alegi. Acesta este public: apare lângă orice cântare trimisă de tine.\n• Dacă ai acceptat regulile de contribuție și când.\n• Rolul tău: membru, moderator sau administrator.\n• Fiecare cântare trimisă: titlul, numărul, etichetele, versurile, acordurile și notația, împreună cu momentul trimiterii, al evaluării și cine a evaluat-o.';

  @override
  String get privacyWhoSeesTitle => 'Cine poate vedea';

  @override
  String get privacyWhoSeesBody =>
      '• O cântare aprobată, și numele de lângă ea, se văd de către oricine — inclusiv de cei care nu se autentifică niciodată.\n• O cântare încă în așteptare sau respinsă se vede doar de tine și de moderatori.\n• Adresa ta de e-mail se vede doar de un administrator, și numai în ecranul de conturi. Moderatorul care îți evaluează cântarea vede un nume, niciodată o adresă.\n• Lista cu cine ce rol are se vede doar de un administrator, în același ecran.\n• Când un administrator invită, promovează sau șterge un cont, faptul se scrie într-un jurnal pe care doar administratorii îl pot citi.';

  @override
  String get privacyPhotosTitle => 'Fotografii';

  @override
  String get privacyPhotosIntro =>
      'Sunt două cititoare de fotografii și nu se poartă la fel. Aplicația te întreabă întâi ce fel de pagină ai fotografiat.';

  @override
  String get privacyPhotosWordsTitle => 'Versuri și acorduri';

  @override
  String get privacyPhotosWordsBody =>
      'Se citesc chiar pe dispozitivul tău, de un program care rulează în browser. Fotografia nu pleacă nicăieri. Prima dată browserul descarcă programul de citire și dicționarul lui maghiar din trei arhive publice de cod — unpkg.com, cdn.jsdelivr.net și tessdata.projectnaptha.com. Ele află doar că un browser a cerut acele fișiere și îi văd adresa de rețea. Fotografia nu o văd niciodată.';

  @override
  String get privacyPhotosNotationTitle => 'Note muzicale';

  @override
  String get privacyPhotosNotationBody =>
      'Aceasta chiar încarcă. Fotografia se trimite pe o conexiune criptată către cititorul nostru, care rulează în Google Cloud la Varșovia, și trebuie să fii autentificat ca să îl folosești. Acolo imaginea se scrie într-un dosar temporar, se citește și se șterge imediat ce pleacă răspunsul înapoi. Nu se stochează niciodată și nu ajunge în jurnal. În jurnal ajunge o singură linie: numele fișierului, mărimea lui, identificatorul contului tău, cât a durat citirea și cât s-a găsit. Google păstrează acele linii aproximativ o lună.';

  @override
  String get privacyOthersTitle => 'Cu cine mai vorbește aplicația';

  @override
  String get privacyOthersBody =>
      '• Supabase — baza de date care ține conturile, cântările trimise și catalogul comun.\n• GitHub Pages — de aici îți încarcă browserul aplicația însăși.\n• Google Cloud, Varșovia — cititorul de note, și doar când îl folosești.\n• unpkg.com, cdn.jsdelivr.net și tessdata.projectnaptha.com — programul de citire a fotografiilor, de obicei doar prima dată.\n• fonts.gstatic.com — serverul de fonturi al Google, pentru litera cu care desenează aplicația.\n• Google — doar dacă alegi să te autentifici cu Google.\n\nFiecare dintre ele vede adresa de rețea a dispozitivului tău, ca orice site pe care îl deschizi. În aplicație nu există analiză de trafic, urmărire sau reclame și nu se pune niciun cookie — autentificarea ta rămâne în stocarea proprie a browserului.';

  @override
  String get privacyGoogleTitle => 'Autentificarea cu Google';

  @override
  String get privacyGoogleBody =>
      'Dacă o folosești, Google îi spune cărții de cântări adresa ta de e-mail și datele de bază pe care le dă oricărui site unde te autentifici. Aplicația nu cere nimic altceva — nici contactele, nici calendarul, nici fișierele tale — și folosește doar adresa. Numele afișat lângă cântările tale este cel pe care îl scrii aici, nu cel ținut de Google.';

  @override
  String get privacyEmailsTitle => 'Ce e-mailuri primești';

  @override
  String get privacyEmailsBody =>
      'Trei feluri și nimic altceva: un link ca să îți confirmi adresa, un link ca să îți resetezi parola dacă ceri asta, și o invitație dacă te invită un administrator. Nu există buletin informativ și nici listă de corespondență.';

  @override
  String get privacyKeepingTitle => 'Cât timp se păstrează';

  @override
  String get privacyKeepingBody =>
      'Contul și cântările tale rămân până când le șterge cineva. Nimic nu expiră de la sine.';

  @override
  String get privacyDeleteTitle => 'Ștergerea contului';

  @override
  String get privacyDeleteBody =>
      'Cere-i unui administrator și contul dispare: adresa, parola, numele afișat și rolul. Două lucruri rămân, și e drept să știi asta dinainte.\n\nO cântare de-a ta care a fost aprobată rămâne în cartea de cântări. Până atunci adunarea cântă din ea, iar scoaterea ei ar lăsa un gol. Păstrează numele pe care îl aveai când ai trimis-o, cu mențiunea că persoana a plecat între timp.\n\nCântările încă în așteptare sau respinse rămân și ele, dar le văd doar moderatorii.\n\nNumele trecut lângă o cântare se fixează în clipa trimiterii, așa că schimbarea numelui afișat mai târziu nu îl schimbă, și nici un moderator nu îl poate rescrie din aplicație. Dacă vrei să fii trecut altfel, spune înainte de a trimite.';

  @override
  String get privacyRightsTitle => 'Ce poți cere';

  @override
  String get privacyRightsBody =>
      'O copie a ce se păstrează despre tine, o corectură la oricare dintre ele sau ștergerea. Cere, și se face.';

  @override
  String get privacyChangesTitle => 'Dacă se schimbă pagina aceasta';

  @override
  String get privacyChangesBody =>
      'Se schimbă și data din capul ei. Dacă va fi vorba să se păstreze ceva nou, aici se va spune întâi.';

  @override
  String get termsIntro =>
      'Songbook este ținut de o singură adunare, pentru uzul ei. Nu costă nimic și nu este o afacere. Acestea sunt puținele reguli care îl țin folositor.';

  @override
  String get termsWhatTitle => 'Ce primești';

  @override
  String get termsWhatBody =>
      'Aplicația așa cum este, fără promisiunea că va fi mereu disponibilă sau mereu corectă. Cântările sunt scrise și fotografiate de oameni, iar oamenii greșesc. Ce contează, verifică din cartea tipărită.';

  @override
  String get termsAccountTitle => 'Contul tău';

  @override
  String get termsAccountBody =>
      'Un cont, cu adresa ta de e-mail și parola ta. Nu te autentifica în numele altcuiva și nu lăsa pe altcineva să folosească contul tău. Dacă bănuiești că cineva a intrat în contul tău, spune-i imediat unui administrator.';

  @override
  String get termsContentTitle => 'Ce poți trimite';

  @override
  String get termsContentBody =>
      'Cântări care se cântă cu adevărat la închinare, scrise cu atenție, pentru că cineva va cânta din ele. Nu glume, nu teste, nu reclame, nimic jignitor și nimic din viața privată a altcuiva.';

  @override
  String get termsCopyrightTitle =>
      'Drepturi de autor — citește partea aceasta';

  @override
  String get termsCopyrightBody =>
      'Cele mai multe cărți de cântări sunt încă protejate prin drepturi de autor, iar fotografierea unei pagini nu schimbă asta. Înainte de a trimite o cântare, este responsabilitatea ta să te asiguri că o poți împărtăși: pentru că este destul de veche ca să nu mai fie protejată, pentru că deținătorul drepturilor permite, sau pentru că adunarea are deja o licență care o acoperă. Dacă nu ești sigur, întreabă înainte de a trimite, nu după.\n\nDacă un deținător de drepturi cere scoaterea unei cântări, ea va fi scoasă fără discuție. Adresa este pe pagina de confidențialitate.';

  @override
  String get termsSubmissionTitle => 'Ce se întâmplă cu o cântare trimisă';

  @override
  String get termsSubmissionBody =>
      'Un moderator o citește înainte să o vadă altcineva și fie o aprobă, fie o respinge cu un motiv, fie îți cere să o corectezi. Odată aprobată, devine parte din cartea de cântări comună: rămâne acolo chiar dacă îți ștergi contul mai târziu, iar numele tău rămâne lângă ea.\n\nPăstrezi orice drept ai asupra lucrării tale. Ceea ce dai este permisiunea ca această adunare să țină cântarea în cartea ei și să cânte din ea.';

  @override
  String get termsModerationTitle => 'Moderarea';

  @override
  String get termsModerationBody =>
      'Moderatorii pot corecta, renumerota, respinge sau scoate orice din catalog. Un administrator poate scoate un cont folosit ca să abuzeze de asta. Dacă ți se pare că o hotărâre a fost greșită, spune — aceasta este o adunare, nu o instanță.';
}
