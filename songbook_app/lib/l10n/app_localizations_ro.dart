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
  String get importMoreWays => 'Alte moduri de adăugare';

  @override
  String get importMusicXmlHint =>
      'Singura cale care aduce și partitura. Exportă mai întâi din MuseScore.';

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
  String importNoticePhotoGermanNoteNames(String text) {
    return '$text va fi stocat sub denumirea engleză (H este si natural). Aplicația păstrează o singură scriere pentru fiecare notă, ca transpunerea să rămână exactă.';
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
  String get adminChangeRole => 'Schimbă rolul';

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
      'Cântările deja aprobate rămân în cartea de cântări, cu numele înregistrat la trimitere. Ce este încă în așteptare sau respins se șterge.';

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
      'Oprește pentru a nu mai accepta nimic nou.';

  @override
  String get adminRequireConfirmedEmail => 'Cere o adresă confirmată';

  @override
  String get adminRequireConfirmedEmailHelp =>
      'Cine nu și-a confirmat adresa nu poate trimite cântări.';

  @override
  String get adminDailyCap => 'Cântări pe zi per persoană';

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
  String get publishShare => 'Partajează cu adunarea';

  @override
  String get publishSubmitted =>
      'Trimis spre aprobare. Un moderator îl va verifica.';

  @override
  String get publishSaveLocally => 'Salvează pe acest dispozitiv';

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
  String get publishNameTitle => 'Cum să te creditam?';

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
      'Am citit și cântarea mea respectă acest lucru.';

  @override
  String get publishGuidelinesAccept => 'Accept și trimit';

  @override
  String get publishRefusedTitle => 'Nu a fost trimis';

  @override
  String get publishDailyLimitBody =>
      'Ai trimis deja atâtea cântări astăzi cât permite limita. Te rugăm să încerci mâine.';

  @override
  String submittedBy(String name) {
    return 'Trimis de $name';
  }

  @override
  String submittedByFormerMember(String name) {
    return 'Trimis de $name, care a plecat de atunci';
  }
}
