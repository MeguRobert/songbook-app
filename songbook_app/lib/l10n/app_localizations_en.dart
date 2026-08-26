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
  String get measureActions => 'Measure actions';

  @override
  String get measureProperties => 'Measure properties';

  @override
  String get measureEditTitle => 'MEASURE PROPERTIES';

  @override
  String get measureInsertBefore => 'Insert measure before';

  @override
  String get measureInsertAfter => 'Insert measure after';

  @override
  String get measureMerge => 'Merge into previous measure';

  @override
  String get measureDelete => 'Delete measure';

  @override
  String get measureSplitHere => 'Start a new measure here';

  @override
  String get measureRepeatStart => 'Repeat sign at the start';

  @override
  String get measureRepeatEnd => 'Repeat sign at the end';

  @override
  String get measureLineBreak => 'Break the staff after this measure';

  @override
  String get measurePickup => 'Pickup measure';

  @override
  String get measurePickupHint =>
      'Short on purpose: not numbered, and not checked against the time signature';

  @override
  String get measureVolta => 'Volta bracket';

  @override
  String get measureVoltaNone => 'None';

  @override
  String measureVoltaEnding(int number) {
    return 'Ending $number';
  }

  @override
  String get notationOtherVoices => 'OTHER VOICES';

  @override
  String get notationOtherVoicesHint =>
      'Kept with the song and not engraved here. Pick the line to read in the song controls.';

  @override
  String notationVoiceMeasures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count measures',
      one: '1 measure',
    );
    return '$_temp0';
  }

  @override
  String get voiceActions => 'Voice actions';

  @override
  String get voiceRenameTitle => 'Rename voice';

  @override
  String get voiceName => 'Voice name';

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
  String get importSectionLines => 'LINES';

  @override
  String get importLineKindChords => 'chords';

  @override
  String get importLineKindLyric => 'words';

  @override
  String get importLineOverridden => 'you set this';

  @override
  String get importTokenEditTitle => 'Correct this chord';

  @override
  String get importTokenEditHint =>
      'The reader misreads a glyph now and then — `Csus2` can come back as `5US2`. Correcting it here is usually all a row needs.';

  @override
  String get importLinesHint =>
      'Tap a chord to correct it. Use the buttons when a whole row was read as the wrong kind.';

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
  String get menuShareSong => 'Share with the congregation';

  @override
  String get shareSongTitle => 'Share this song?';

  @override
  String shareSongBody(String title) {
    return '“$title” goes to the moderators. It joins the shared songbook only after one of them approves it, and your copy stays on this device either way.';
  }

  @override
  String get shareSongConfirm => 'Send';

  @override
  String get shareSongSignInTitle => 'Sign in to share';

  @override
  String get shareSongSignInBody =>
      'Sharing needs an account, so the congregation can see who contributed the song. Your song is already saved on this device and stays there.';

  @override
  String get shareSongSent => 'Sent for review.';

  @override
  String get shareSongAlreadySent =>
      'You have already sent this song in. It is waiting for review.';

  @override
  String get shareSongFailed =>
      'The song could not be sent. Check your connection and try again.';

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
  String get importSectionPhoto => 'PHOTO';

  @override
  String get importPhotoZoomHint => 'Pinch or scroll to zoom.';

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

  @override
  String importNoticeUnknownDirective(int line, String text) {
    return 'Line $line: ignored the unknown directive \"$text\".';
  }

  @override
  String importNoticeAmbiguousBareRoot(int line, String text) {
    return 'Line $line: \"$text\" could be a one-chord line or a lyric; kept as a lyric.';
  }

  @override
  String importNoticeBracketNotAChord(int line, String text) {
    return 'Line $line: \"[$text]\" is not a chord; kept as lyric text.';
  }

  @override
  String get importNoticeTimewiseScore =>
      'This file is score-timewise, so its measures may be grouped incorrectly. Export it as score-partwise for a clean import.';

  @override
  String get importNoticeNoNotes => 'No notes were found in the file.';

  @override
  String importNoticeExtraVoicesKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count voices beyond the melody were kept — only the melody is engraved. Switch voices in the song controls.',
      one:
          '1 voice beyond the melody was kept — only the melody is engraved. Switch voices in the song controls.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeGraceNotesSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count grace notes were skipped: the notation has no grace-note beat.',
      one: '1 grace note was skipped: the notation has no grace-note beat.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeChordsReduced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count chords were reduced to their top notes; the lower notes were kept as extra voices.',
      one:
          '1 chord was reduced to its top note; the lower notes were kept as extra voices.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeDoubleAccidentals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count double accidentals were approximated to a single sharp or flat, which is all the notation stores.',
      one:
          '1 double accidental was approximated to a single sharp or flat, which is all the notation stores.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeDoubleDots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count double-dotted notes were imported as single-dotted.',
      one: '1 double-dotted note was imported as single-dotted.',
    );
    return '$_temp0';
  }

  @override
  String importNoticeUnsupportedNoteValues(int count, String text) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The note values $text cannot be drawn, so they were approximated to the nearest ones that can.',
      one:
          'The note value $text cannot be drawn, so it was approximated to the nearest one that can.',
    );
    return '$_temp0';
  }

  @override
  String get importNoticeEmptyXmlInput => 'The MusicXML input is empty.';

  @override
  String importNoticeInvalidXml(String text) {
    return 'This file is not valid XML: $text';
  }

  @override
  String get importNoticeContainerManifest =>
      'This is the container index from inside an .mxl file, not a score. Open the .mxl file itself.';

  @override
  String get importNoticeEmptyMxlInput => 'The .mxl input is empty.';

  @override
  String importNoticeUnreadableArchive(String text) {
    return 'This is not a readable .mxl archive: $text';
  }

  @override
  String get importNoticeNoScoreInArchive =>
      'The .mxl archive contains no MusicXML score.';

  @override
  String importNoticeContinuationWithoutChord(int line, String text) {
    return 'Line $line: “$text” has no chord before it to continue; dropped.';
  }

  @override
  String importNoticePhotoLowResolution(String text, int count) {
    return 'That photo arrived at $text in $count KB — too compressed to hold the fine strokes. Accents like ő and ű are the first thing to go, so expect a few wrong letters. A phone gallery hands over a shrunken copy; picking the same photo through Files usually gives the full-quality original.';
  }

  @override
  String get importNoticePhotoShowThroughRemoved =>
      'Part of the page read as faint second ink — the reverse side showing through, or uneven light — and it was cleaned away before reading. If a chord is missing, a photo in flatter light will read better than this one.';

  @override
  String importNoticePhotoTwoSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'That page holds $count songs side by side. All of them were read, in reading order — delete the one you did not want.',
    );
    return '$_temp0';
  }

  @override
  String get importNoticePhotoNoChords =>
      'No chords were recognised — the words were imported on their own.';

  @override
  String get importNoticePhotoNothingLegible =>
      'Nothing legible was found in that photo.';

  @override
  String importNoticePhotoGermanNoteNames(String text) {
    return '$text will be stored under the English name (H is B natural). The app keeps one spelling per pitch so transposing stays exact.';
  }

  @override
  String importNoticePhotoLowercaseCRaised(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count chords were read as a lowercase c and stored as C major. In print C and c are the same shape at two sizes, so a small one is almost always a capital the reader mis-sized — if your page really means the minor, write Cm.',
    );
    return '$_temp0';
  }

  @override
  String get roleMember => 'Member';

  @override
  String get roleModerator => 'Moderator';

  @override
  String get roleAdministrator => 'Administrator';

  @override
  String get roleMemberDescription =>
      'Can read the songbook and offer songs for review.';

  @override
  String get roleModeratorDescription =>
      'Can approve or turn down submissions, and correct any song.';

  @override
  String get roleAdministratorDescription =>
      'Everything a moderator can do, plus managing accounts and settings.';

  @override
  String get adminTitle => 'Administration';

  @override
  String get adminNotPermitted => 'This area is for administrators.';

  @override
  String get adminUsersTitle => 'Members';

  @override
  String get adminUserTitle => 'Member';

  @override
  String get adminUserGone => 'This account no longer exists.';

  @override
  String get adminSettingsTitle => 'Contribution settings';

  @override
  String get adminSettingsSubtitle =>
      'Who may submit, and the rules they accept';

  @override
  String adminWaitingCount(String count) {
    return '$count waiting for review';
  }

  @override
  String adminMemberCount(String count) {
    return '$count accounts';
  }

  @override
  String get adminSubmissionsClosedNotice =>
      'Submissions are closed. Nobody can offer a song.';

  @override
  String get adminReopen => 'Open';

  @override
  String get adminSearchUsers => 'Search by name or address';

  @override
  String get adminFilterAll => 'All';

  @override
  String get adminInvite => 'Invite someone';

  @override
  String get adminSendInvite => 'Send invitation';

  @override
  String get adminInviteSent => 'Invitation sent.';

  @override
  String get adminUsersUnavailable => 'The member list could not be loaded.';

  @override
  String get adminNoMatchingUsers => 'Nobody matches that.';

  @override
  String get adminActionDone => 'Done.';

  @override
  String get adminActionFailed => 'That did not work.';

  @override
  String get adminCannotActOnSelf =>
      'You cannot change your own role or delete your own account.';

  @override
  String get adminLastAdministrator =>
      'There has to be at least one administrator.';

  @override
  String get adminRole => 'Role';

  @override
  String get adminChange => 'Change';

  @override
  String get adminChangeRole => 'Change role';

  @override
  String get adminEmailStatus => 'Email address';

  @override
  String get adminEmailConfirmed => 'Confirmed';

  @override
  String get adminEmailUnconfirmed => 'Not confirmed';

  @override
  String get adminGuidelinesStatus => 'Contribution guidelines';

  @override
  String get adminGuidelinesAccepted => 'Accepted';

  @override
  String get adminGuidelinesNotAccepted => 'Not accepted yet';

  @override
  String get adminLastSignIn => 'Last signed in';

  @override
  String get adminNeverSignedIn => 'never signed in';

  @override
  String get adminSubmissions => 'Submitted songs';

  @override
  String adminTallyApproved(int count) {
    return '$count approved';
  }

  @override
  String adminTallyPending(int count) {
    return '$count waiting';
  }

  @override
  String adminTallyRejected(int count) {
    return '$count turned down';
  }

  @override
  String get adminDeleteAccount => 'Delete this account';

  @override
  String get adminDeleteWarning => 'This cannot be undone.';

  @override
  String get adminDeleteKeepsApproved =>
      'Songs already approved stay in the songbook, credited to the name recorded when they were submitted. Anything still waiting or turned down is removed.';

  @override
  String adminDeleteTypeToConfirm(String address) {
    return 'Type $address to confirm.';
  }

  @override
  String get adminDeletePermanently => 'Delete permanently';

  @override
  String get adminSubmissionsSection => 'Submissions';

  @override
  String get adminSubmissionsOpen => 'Accept new songs';

  @override
  String get adminSubmissionsOpenHelp =>
      'Turn this off to stop accepting anything new, without a redeploy.';

  @override
  String get adminRequireConfirmedEmail => 'Require a confirmed address';

  @override
  String get adminRequireConfirmedEmailHelp =>
      'Someone who has not confirmed their email cannot submit.';

  @override
  String get adminDailyCap => 'Songs per person per day';

  @override
  String get adminDailyCapHelp =>
      'A limit on how fast one account can fill the queue.';

  @override
  String get adminGuidelinesSection => 'Contribution guidelines';

  @override
  String get adminGuidelinesHelp =>
      'Everyone reads this and ticks it once, before their first submission.';

  @override
  String get actionOk => 'OK';

  @override
  String get publishClosedTitle => 'Submissions are closed';

  @override
  String get publishClosedBody =>
      'New songs are not being accepted at the moment. Your song is still saved on this device.';

  @override
  String publishConfirmEmailBody(String email) {
    return 'Confirm your email address first. We sent a link to $email.';
  }

  @override
  String get publishNameTitle => 'How should we credit you?';

  @override
  String get publishNameBody =>
      'Your name is shown next to the song, so the congregation can see who brought it.';

  @override
  String get publishNameLabel => 'Name';

  @override
  String get publishNameRequired => 'Please give a name.';

  @override
  String get publishGuidelinesTitle => 'Before you send it';

  @override
  String get publishGuidelinesAgree =>
      'I have read this and my song follows it.';

  @override
  String get publishGuidelinesAccept => 'Agree and send';

  @override
  String get publishRefusedTitle => 'Not sent';

  @override
  String get publishDailyLimitBody =>
      'You have already sent as many songs today as the limit allows. Please try again tomorrow.';

  @override
  String submittedBy(String name) {
    return 'Submitted by $name';
  }

  @override
  String submittedByFormerMember(String name) {
    return 'Submitted by $name, who has since left';
  }
}
