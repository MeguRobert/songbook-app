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

  @override
  String get actionRename => 'Rename';

  @override
  String get setlistSingular => 'Setlist';

  @override
  String get setlistNotFound => 'Setlist not found';

  @override
  String setlistSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get setlistOptions => 'Setlist options';

  @override
  String get setlistNew => 'New setlist';

  @override
  String get setlistRenameTitle => 'Rename setlist';

  @override
  String get setlistDeleteTitle => 'Delete setlist?';

  @override
  String setlistDeleteBody(String name) {
    return '\"$name\" will be permanently removed.';
  }

  @override
  String get setlistNameLabel => 'Name';

  @override
  String get setlistNameHint => 'Setlist name';

  @override
  String get setlistsEmpty => 'No setlists yet';

  @override
  String get setlistsEmptyHint => 'Create one for your next service';

  @override
  String get setlistPlay => 'Play setlist';

  @override
  String get setlistAddSongs => 'Add songs';

  @override
  String get setlistRemoveSong => 'Remove from setlist';

  @override
  String get setlistEmpty => 'No songs in this setlist';

  @override
  String errorLoadingSongsDetail(String detail) {
    return 'Error loading songs: $detail';
  }

  @override
  String get importSectionPaste => 'PASTE THE SONG';

  @override
  String get importSectionReplace => 'REPLACE THE WORDS AND CHORDS';

  @override
  String get importPasteHint =>
      'G       C\nAz Úrra bízom életem\n\nor [G]Az Úrra [C]bízom életem';

  @override
  String get importMusicXmlFile => 'MusicXML file';

  @override
  String get importParse => 'Parse';

  @override
  String get importSectionDetails => 'DETAILS';

  @override
  String importFromSource(String source) {
    return 'from $source';
  }

  @override
  String get importSourceSaved => 'the saved song';

  @override
  String get importSourcePasted => 'pasted text';

  @override
  String get importTitleField => 'Title';

  @override
  String get importNumberField => 'Number';

  @override
  String get importBookField => 'Songbook';

  @override
  String importKeyFromFile(String key) {
    return 'Key $key, from the file.';
  }

  @override
  String importKeyGuessed(String key) {
    return 'Key guessed as $key from the first chord.';
  }

  @override
  String get importSectionPreview => 'PREVIEW';

  @override
  String importVerseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verses',
      one: '1 verse',
    );
    return '$_temp0';
  }

  @override
  String importBarCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bars',
      one: '1 bar',
    );
    return '$_temp0';
  }

  @override
  String get importBlockerDeleted =>
      'That song is no longer stored on this device.';

  @override
  String get importBlockerNothing => 'Paste a song or open a MusicXML file.';

  @override
  String get importBlockerEmpty =>
      'No lyrics or notation found in that source.';

  @override
  String get importBlockerNoTitle => 'Give the song a title.';

  @override
  String get importBlockerNoNumber => 'Give the song a number.';

  @override
  String get importBlockerBadNumber =>
      'The number has to be a whole number above zero.';

  @override
  String importErrorNotMusicXml(String name) {
    return '$name is not a MusicXML file. Expected .xml, .musicxml or .mxl — a MuseScore .mscz has to be exported first.';
  }

  @override
  String importErrorUnreadable(String name) {
    return 'Could not read $name.';
  }

  @override
  String importErrorFailed(String detail) {
    return 'Could not import that file: $detail';
  }

  @override
  String importWarningsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Check these lines',
      one: 'Check this line',
    );
    return '$_temp0';
  }

  @override
  String get tagsNoneYetAddOne => 'No tags yet — add one below.';

  @override
  String get tagAddLabel => 'Add a tag';

  @override
  String get tagAddHint => 'e.g. Christmas, communion';

  @override
  String get tagAddTooltip => 'Add tag';

  @override
  String get tagSuggestions => 'Suggestions';

  @override
  String get tagResetToDefault => 'Reset to default';

  @override
  String get filterAllSongs => 'All Songs';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String errorLoadingBooks(String detail) {
    return 'Error loading books: $detail';
  }

  @override
  String get filterByTags => 'Filter by tags';

  @override
  String get filterTagsAnd => 'Songs must carry every selected tag';

  @override
  String get tagsEmpty => 'No tags yet';

  @override
  String errorLoadingTags(String detail) {
    return 'Error loading tags: $detail';
  }

  @override
  String get filterClearAllTags => 'Clear all tags';

  @override
  String get presentationExit => 'Exit (Esc)';

  @override
  String sheetSemanticsLabel(String title) {
    return 'Sheet music notation for $title';
  }

  @override
  String sheetKey(String key) {
    return 'Key: $key';
  }

  @override
  String sheetTransposed(String offset) {
    return 'Transposed $offset';
  }

  @override
  String sheetTime(String signature) {
    return 'Time: $signature';
  }

  @override
  String sheetTune(String tune) {
    return 'Tune: $tune';
  }

  @override
  String sheetOrigin(String origin) {
    return 'Origin: $origin';
  }

  @override
  String get sheetNotAvailable => 'Sheet music not available';

  @override
  String get sheetNotAvailableHint =>
      'Switch to chord view to see lyrics with chords';

  @override
  String sheetTransposedFrom(String key) {
    return 'Transposed from $key';
  }

  @override
  String sheetMissingForKey(String key, String original) {
    return 'Sheet music for $key not available. Showing original key ($original).';
  }

  @override
  String get sheetNoneForSong => 'No sheet music available for this song';

  @override
  String get routeNotFound => 'Page not found';

  @override
  String get routeGoHome => 'Go Home';

  @override
  String get sectionVoice => 'VOICE';

  @override
  String get voiceMelody => 'Melody';

  @override
  String get voiceAlto => 'Alto';

  @override
  String get voiceTenor => 'Tenor';

  @override
  String get voiceBass => 'Bass';

  @override
  String get importMoreWays => 'More ways to add';

  @override
  String get importMusicXmlHint =>
      'The only path that brings in engraved notation. Export from MuseScore first.';

  @override
  String get accountSection => 'ACCOUNT';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create account';

  @override
  String get signOut => 'Sign out';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get passwordResetSent =>
      'If that address has an account, a reset link is on its way.';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get accountOptional =>
      'You do not need an account. The songs on this device work offline either way.';

  @override
  String get accountsUnavailable => 'Accounts are unavailable right now.';

  @override
  String get verifyEmailTitle => 'Confirm your email';

  @override
  String verifyEmailBody(String email) {
    return 'We sent a link to $email. Confirm it before contributing songs.';
  }

  @override
  String get resendConfirmation => 'Send it again';

  @override
  String get confirmationResent => 'Sent.';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get needAccountPrompt => 'Need an account?';

  @override
  String get authErrorInvalidCredentials =>
      'That email and password do not match.';

  @override
  String get authErrorEmailNotConfirmed => 'Confirm your email address first.';

  @override
  String get authErrorEmailAlreadyRegistered =>
      'That address already has an account.';

  @override
  String get authErrorWeakPassword =>
      'Choose a longer password — at least 6 characters.';

  @override
  String get authErrorInvalidEmail =>
      'That does not look like an email address.';

  @override
  String get authErrorRateLimited =>
      'Too many attempts. Wait a minute and try again.';

  @override
  String get authErrorServerRejected =>
      'The server refused that. Try again later.';

  @override
  String get authErrorNetwork =>
      'Could not reach the server. Check your connection.';

  @override
  String get authErrorUnknown => 'Something went wrong. Try again.';

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get authOrDivider => 'or';

  @override
  String get moderationQueueTitle => 'Waiting for review';

  @override
  String get moderationQueueEmpty => 'Nothing is waiting.';

  @override
  String get mySubmissionsTitle => 'Songs I sent in';

  @override
  String get mySubmissionsEmpty => 'You have not sent in any songs yet.';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Turn down';

  @override
  String get rejectReasonLabel => 'Why? The contributor will see this.';

  @override
  String get rejectReasonRequired => 'Give a reason so they can fix it.';

  @override
  String get withdraw => 'Withdraw';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusPending => 'Waiting for review';

  @override
  String get statusApproved => 'In the shared songbook';

  @override
  String get statusRejected => 'Turned down';

  @override
  String get moderationDecided => 'Done.';

  @override
  String get importPhoto => 'Photo';

  @override
  String get importSourcePhoto => 'photo';

  @override
  String get importPhotoReading => 'Reading the photo…';

  @override
  String get importPhotoNotConfigured =>
      'This version of Songbook cannot read sheet music.';

  @override
  String get importPhotoHint =>
      'Reads the words and chords on the page, on your device.';

  @override
  String get importPhotoSheetMusic => 'This page has sheet music';

  @override
  String get importPhotoSheetMusicHint =>
      'Press the book flat and photograph it straight from above — the notes are lost off a curved page. Reading music needs a connection and can take a minute.';

  @override
  String get importPhotoSignIn =>
      'Sign in first: sheet music is read by a shared service, not on your device.';

  @override
  String get importPhotoNoReader =>
      'Photos can only be read in the browser version of Songbook.';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get voiceAll => 'All';
}
