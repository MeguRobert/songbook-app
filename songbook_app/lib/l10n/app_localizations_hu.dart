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
  String get sectionCapo => 'CAPO';

  @override
  String get sectionAutoScroll => 'GÖRGETÉS';

  @override
  String get presetSheetMusic => 'Kotta';

  @override
  String get presetChords => 'Akkord';

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
  String get autoScrollNotInSheetMusic => 'csak akkord nézetben';

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
  String get capoNone => 'Nem kell capo';

  @override
  String capoAt(int fret) {
    return '$fret. bund';
  }

  @override
  String capoOpenShape(String shape, String key) {
    return 'Játszd $shape fogásban (így $key szól)';
  }

  @override
  String capoClamp(int fret, String shape, String key) {
    return '$fret. bundra tedd, $shape fogásokkal — így $key szól';
  }

  @override
  String get capoOther => 'Más pozíciók';

  @override
  String capoNoSuggestion(String key) {
    return '$key-hez nincs capo-javaslat';
  }

  @override
  String get favoritesEmpty => 'Még nincs kedvenc';

  @override
  String get favoritesEmptyHint =>
      'Koppints egy ének szív ikonjára, hogy ide kerüljön';

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

  @override
  String get showAllSongs => 'Összes ének';

  @override
  String errorDetail(String detail) {
    return 'Hiba: $detail';
  }

  @override
  String noSongsInBook(String book) {
    return '„$book” nem tartalmaz éneket';
  }

  @override
  String get noSongsAvailable => 'Nincs elérhető ének';

  @override
  String get noSongsHint => 'Az alkalmazással szállított énekeskönyv üres.';

  @override
  String get actionEdit => 'Szerkesztés';

  @override
  String get actionApply => 'Alkalmaz';

  @override
  String get actionDiscard => 'Elvetés';

  @override
  String get discardTitle => 'Elveti a javításokat?';

  @override
  String get discardBody =>
      'Az ezen a képernyőn végzett módosítások nincsenek elmentve az énekhez.';

  @override
  String get discardKeepEditing => 'Tovább szerkesztem';

  @override
  String get notationNoneStored =>
      'Ehhez az énekhez nincs kotta tárolva, vagy már nincs meg ezen a készüléken.';

  @override
  String notationVerse(int number) {
    return '$number. versszak';
  }

  @override
  String notationMeasure(int number) {
    return '$number. ütem';
  }

  @override
  String get notationPickup => 'Felütés';

  @override
  String notationPickupBeats(int count, String beats) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$beats ütés az 1. ütem előtt',
      one: '$beats ütés az 1. ütem előtt',
    );
    return '$_temp0';
  }

  @override
  String notationMeasureBeats(String total, int expected) {
    return '$total / $expected ütés';
  }

  @override
  String get notationNoBeats => 'Ebben az ütemben nincs hang.';

  @override
  String notationStalePickupNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count ütés az ének régi, külön felütéslistájában van, amelyet semmi nem olvas, ezért sem fent, sem lent nem látszanak. A felütés helye egy bevezető ütem.',
      one:
          '1 ütés az ének régi, külön felütéslistájában van, amelyet semmi nem olvas, ezért sem fent, sem lent nem látszik. A felütés helye egy bevezető ütem.',
    );
    return '$_temp0';
  }

  @override
  String get beatRestShort => 'szünet';

  @override
  String get beatActions => 'Ütés műveletei';

  @override
  String get beatInsertAfter => 'Beszúrás utána';

  @override
  String get beatEditTitle => 'ÜTÉS SZERKESZTÉSE';

  @override
  String get beatRest => 'Szünet';

  @override
  String get beatNote => 'Hang';

  @override
  String get beatAccidental => 'Módosítójel';

  @override
  String get accidentalNatural => 'feloldójel';

  @override
  String get accidentalSharp => 'kereszt';

  @override
  String get accidentalFlat => 'bé';

  @override
  String get beatOctave => 'Oktáv';

  @override
  String get octaveLower => 'Alacsonyabb oktáv';

  @override
  String get octaveHigher => 'Magasabb oktáv';

  @override
  String get beatDuration => 'Hangérték';

  @override
  String get beatDotted => 'Pontozott';

  @override
  String get beatDottedHint => 'A hangérték másfélszerese';

  @override
  String get beatTieEnd => 'Kötés az előző hangtól';

  @override
  String get beatTieStart => 'Kötés a következő hangig';

  @override
  String get beatSyllable => 'Szótag';

  @override
  String get beatChord => 'Akkord a kotta felett';

  @override
  String beatExtraLyricLines(int count, String lines) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ezen a hangon még $count szövegsor ($lines) változatlan marad.',
      one: 'Ezen a hangon még 1 szövegsor ($lines) változatlan marad.',
    );
    return '$_temp0';
  }

  @override
  String get durationWhole => 'egész';

  @override
  String get durationHalf => 'fél';

  @override
  String get durationQuarter => 'negyed';

  @override
  String get durationEighth => 'nyolcad';

  @override
  String get durationSixteenth => 'tizenhatod';

  @override
  String durationDotted(String duration) {
    return '$duration, pontozott';
  }

  @override
  String get settingsAppearance => 'Megjelenés';

  @override
  String get settingsTheme => 'Téma';

  @override
  String get settingsFontSize => 'Betűméret';

  @override
  String get fontSizeDecrease => 'Betűméret csökkentése';

  @override
  String get fontSizeIncrease => 'Betűméret növelése';

  @override
  String get settingsDisplay => 'Ének megjelenítése';

  @override
  String get settingsDefaultView => 'Alapértelmezett nézet';

  @override
  String get settingsAbout => 'Névjegy';

  @override
  String get settingsVersion => 'Verzió';

  @override
  String get settingsVersionUnknown => 'ismeretlen';

  @override
  String get settingsTagline => 'Istentiszteleti énekeskönyv';

  @override
  String get themeLight => 'Világos';

  @override
  String get themeDark => 'Sötét';

  @override
  String get themeSystem => 'Rendszer szerinti';

  @override
  String get settingsViewSheetMusic => 'Kotta';

  @override
  String get settingsViewSheetMusicHint => 'Kotta akkordokkal és szöveggel';

  @override
  String get settingsViewChords => 'Akkordok';

  @override
  String get settingsViewChordsHint => 'Csak akkordok és szöveg';

  @override
  String get settingsViewLyricsOnly => 'Csak szöveg';

  @override
  String get settingsViewLyricsOnlyHint =>
      'Tiszta szöveg kotta és akkordok nélkül';

  @override
  String get actionRename => 'Átnevezés';

  @override
  String get setlistSingular => 'Énekrend';

  @override
  String get setlistNotFound => 'Az énekrend nem található';

  @override
  String setlistSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ének',
      one: '$count ének',
    );
    return '$_temp0';
  }

  @override
  String get setlistOptions => 'Énekrend műveletei';

  @override
  String get setlistNew => 'Új énekrend';

  @override
  String get setlistRenameTitle => 'Énekrend átnevezése';

  @override
  String get setlistDeleteTitle => 'Törli az énekrendet?';

  @override
  String setlistDeleteBody(String name) {
    return 'A(z) „$name” véglegesen törlődik.';
  }

  @override
  String get setlistNameLabel => 'Név';

  @override
  String get setlistNameHint => 'Az énekrend neve';

  @override
  String get setlistsEmpty => 'Még nincs énekrend';

  @override
  String get setlistsEmptyHint => 'Készíts egyet a következő istentiszteletre';

  @override
  String get setlistPlay => 'Énekrend indítása';

  @override
  String get setlistAddSongs => 'Énekek hozzáadása';

  @override
  String get setlistRemoveSong => 'Eltávolítás az énekrendből';

  @override
  String get setlistEmpty => 'Ebben az énekrendben nincs ének';

  @override
  String errorLoadingSongsDetail(String detail) {
    return 'Hiba az énekek betöltésekor: $detail';
  }

  @override
  String get importSectionPaste => 'ILLESZD BE AZ ÉNEKET';

  @override
  String get importSectionReplace => 'SZÖVEG ÉS AKKORDOK CSERÉJE';

  @override
  String get importPasteHint =>
      'G       C\nAz Úrra bízom életem\n\nvagy [G]Az Úrra [C]bízom életem';

  @override
  String get importMusicXmlFile => 'MusicXML fájl';

  @override
  String get importParse => 'Feldolgozás';

  @override
  String get importSectionDetails => 'ADATOK';

  @override
  String importFromSource(String source) {
    return 'innen: $source';
  }

  @override
  String get importSourceSaved => 'a mentett ének';

  @override
  String get importSourcePasted => 'beillesztett szöveg';

  @override
  String get importTitleField => 'Cím';

  @override
  String get importNumberField => 'Szám';

  @override
  String get importBookField => 'Énekeskönyv';

  @override
  String importKeyFromFile(String key) {
    return '$key hangnem, a fájlból.';
  }

  @override
  String importKeyGuessed(String key) {
    return 'A hangnem $key, az első akkordból következtetve.';
  }

  @override
  String get importSectionPreview => 'ELŐNÉZET';

  @override
  String importVerseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count versszak',
      one: '$count versszak',
    );
    return '$_temp0';
  }

  @override
  String importBarCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ütem',
      one: '$count ütem',
    );
    return '$_temp0';
  }

  @override
  String get importBlockerDeleted =>
      'Ez az ének már nincs eltárolva ezen a készüléken.';

  @override
  String get importBlockerNothing =>
      'Illessz be egy éneket, vagy nyiss meg egy MusicXML fájlt.';

  @override
  String get importBlockerEmpty =>
      'Nem található szöveg vagy kotta ebben a forrásban.';

  @override
  String get importBlockerNoTitle => 'Adj címet az éneknek.';

  @override
  String get importBlockerNoNumber => 'Adj sorszámot az éneknek.';

  @override
  String get importBlockerBadNumber =>
      'A sorszám csak nullánál nagyobb egész szám lehet.';

  @override
  String importErrorNotMusicXml(String name) {
    return 'A(z) $name nem MusicXML fájl. Elfogadott: .xml, .musicxml vagy .mxl — a MuseScore .mscz fájlt előbb exportálni kell.';
  }

  @override
  String importErrorUnreadable(String name) {
    return 'A(z) $name nem olvasható.';
  }

  @override
  String importErrorFailed(String detail) {
    return 'A fájl nem importálható: $detail';
  }

  @override
  String importWarningsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ellenőrizd ezeket a sorokat',
      one: 'Ellenőrizd ezt a sort',
    );
    return '$_temp0';
  }

  @override
  String get tagsNoneYetAddOne => 'Még nincs címke — adj hozzá egyet alább.';

  @override
  String get tagAddLabel => 'Címke hozzáadása';

  @override
  String get tagAddHint => 'pl. Karácsony, úrvacsora';

  @override
  String get tagAddTooltip => 'Címke felvétele';

  @override
  String get tagSuggestions => 'Javaslatok';

  @override
  String get tagResetToDefault => 'Visszaállítás alapértelmezettre';

  @override
  String get filterAllSongs => 'Minden ének';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ének',
      one: '$count ének',
    );
    return '$_temp0';
  }

  @override
  String errorLoadingBooks(String detail) {
    return 'Hiba az énekeskönyvek betöltésekor: $detail';
  }

  @override
  String get filterByTags => 'Szűrés címkék szerint';

  @override
  String get filterTagsAnd =>
      'Az énekeknek minden kijelölt címkét tartalmazniuk kell';

  @override
  String get tagsEmpty => 'Még nincs címke';

  @override
  String errorLoadingTags(String detail) {
    return 'Hiba a címkék betöltésekor: $detail';
  }

  @override
  String get filterClearAllTags => 'Minden címke törlése';

  @override
  String get presentationExit => 'Kilépés (Esc)';

  @override
  String sheetSemanticsLabel(String title) {
    return '$title kottája';
  }

  @override
  String sheetKey(String key) {
    return 'Hangnem: $key';
  }

  @override
  String sheetTransposed(String offset) {
    return 'Transzponálva: $offset';
  }

  @override
  String sheetTime(String signature) {
    return 'Ütemmutató: $signature';
  }

  @override
  String sheetTune(String tune) {
    return 'Dallam: $tune';
  }

  @override
  String sheetOrigin(String origin) {
    return 'Eredet: $origin';
  }

  @override
  String get sheetNotAvailable => 'Nincs elérhető kotta';

  @override
  String get sheetNotAvailableHint =>
      'Válts akkord nézetre, hogy lásd a szöveget az akkordokkal';

  @override
  String sheetTransposedFrom(String key) {
    return 'Eredeti hangnem: $key';
  }

  @override
  String sheetMissingForKey(String key, String original) {
    return 'Nincs kotta $key hangnemben. Az eredeti hangnem látszik ($original).';
  }

  @override
  String get sheetNoneForSong => 'Ehhez az énekhez nincs kotta';

  @override
  String get routeNotFound => 'Az oldal nem található';

  @override
  String get routeGoHome => 'Vissza a kezdőlapra';

  @override
  String get sectionVoice => 'SZÓLAM';

  @override
  String get voiceMelody => 'Dallam';

  @override
  String get voiceAlto => 'Alt';

  @override
  String get voiceTenor => 'Tenor';

  @override
  String get voiceBass => 'Basszus';

  @override
  String get importMoreWays => 'További lehetőségek';

  @override
  String get importMusicXmlHint =>
      'Csak ez a mód hoz be kottát is. Előbb exportáld a MuseScore-ból.';

  @override
  String get accountSection => 'FIÓK';

  @override
  String get signIn => 'Bejelentkezés';

  @override
  String get signUp => 'Fiók létrehozása';

  @override
  String get signOut => 'Kijelentkezés';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Jelszó';

  @override
  String get forgotPassword => 'Elfelejtetted a jelszavad?';

  @override
  String get passwordResetSent =>
      'Ha ehhez a címhez tartozik fiók, elküldtük a jelszó-visszaállító linket.';

  @override
  String signedInAs(String email) {
    return 'Bejelentkezve: $email';
  }

  @override
  String get notSignedIn => 'Nincs bejelentkezve';

  @override
  String get accountOptional =>
      'Fiók nem szükséges. Az ezen az eszközön lévő énekek offline is működnek.';

  @override
  String get accountsUnavailable => 'A fiókok most nem érhetők el.';

  @override
  String get verifyEmailTitle => 'Igazold vissza az e-mail címed';

  @override
  String verifyEmailBody(String email) {
    return 'Küldtünk egy linket erre a címre: $email. Igazold vissza, mielőtt éneket töltesz fel.';
  }

  @override
  String get resendConfirmation => 'Küldd újra';

  @override
  String get confirmationResent => 'Elküldve.';

  @override
  String get haveAccountPrompt => 'Van már fiókod?';

  @override
  String get needAccountPrompt => 'Nincs még fiókod?';

  @override
  String get authErrorInvalidCredentials =>
      'Az e-mail cím és a jelszó nem egyezik.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Először igazold vissza az e-mail címed.';

  @override
  String get authErrorEmailAlreadyRegistered =>
      'Ehhez a címhez már tartozik fiók.';

  @override
  String get authErrorWeakPassword =>
      'Válassz hosszabb jelszót – legalább 6 karakter.';

  @override
  String get authErrorInvalidEmail => 'Ez nem tűnik e-mail címnek.';

  @override
  String get authErrorRateLimited =>
      'Túl sok kísérlet. Várj egy percet, majd próbáld újra.';

  @override
  String get authErrorServerRejected =>
      'A kiszolgáló elutasította. Próbáld később.';

  @override
  String get authErrorNetwork =>
      'Nem sikerült elérni a kiszolgálót. Ellenőrizd a kapcsolatot.';

  @override
  String get authErrorUnknown => 'Valami hiba történt. Próbáld újra.';

  @override
  String get signInWithGoogle => 'Folytatás Google-fiókkal';

  @override
  String get authOrDivider => 'vagy';

  @override
  String get moderationQueueTitle => 'Jóváhagyásra vár';

  @override
  String get moderationQueueEmpty => 'Nincs jóváhagyásra váró ének.';

  @override
  String get mySubmissionsTitle => 'Beküldött énekeim';

  @override
  String get mySubmissionsEmpty => 'Még nem küldtél be éneket.';

  @override
  String get approve => 'Jóváhagyás';

  @override
  String get reject => 'Elutasítás';

  @override
  String get rejectReasonLabel => 'Miért? A beküldő látni fogja.';

  @override
  String get rejectReasonRequired => 'Adj meg okot, hogy javíthassa.';

  @override
  String get withdraw => 'Visszavonás';

  @override
  String get statusDraft => 'Piszkozat';

  @override
  String get statusPending => 'Jóváhagyásra vár';

  @override
  String get statusApproved => 'Bekerült a közös énekeskönyvbe';

  @override
  String get statusRejected => 'Elutasítva';

  @override
  String get moderationDecided => 'Kész.';

  @override
  String get importPhoto => 'Fénykép';

  @override
  String get importSourcePhoto => 'fénykép';

  @override
  String get importPhotoReading => 'Fénykép beolvasása…';

  @override
  String get importPhotoNotConfigured =>
      'Előbb állítsd be a fényképes beolvasást a Beállításokban.';

  @override
  String get settingsPhotoImport => 'Fényképes beolvasás';

  @override
  String get settingsPhotoImportEndpoint => 'Szolgáltatás címe';

  @override
  String get settingsPhotoImportEndpointHint =>
      'Az a cím, amely beolvassa a fényképeidet. Hagyd üresen a kikapcsoláshoz.';

  @override
  String get settingsPhotoImportToken => 'Hozzáférési kulcs';

  @override
  String get settingsPhotoImportTokenHint => 'Nem kötelező.';

  @override
  String get settingsPhotoImportNotSet => 'Nincs beállítva';

  @override
  String get settingsPhotoImportInvalid => 'Ez nem tűnik érvényes webcímnek.';

  @override
  String get commonSave => 'Mentés';

  @override
  String get commonCancel => 'Mégse';
}
