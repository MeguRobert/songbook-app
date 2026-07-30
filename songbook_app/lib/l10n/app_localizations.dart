import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hu'),
    Locale('ro'),
  ];

  /// Application name, shown in the browser tab and the song list app bar
  ///
  /// In en, this message translates to:
  /// **'Songbook'**
  String get appTitle;

  /// Bottom navigation: the song list
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get navSongs;

  /// Bottom navigation: saved orders of service
  ///
  /// In en, this message translates to:
  /// **'Setlists'**
  String get navSetlists;

  /// Bottom navigation: favourited songs
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// Bottom navigation: app settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Dismiss a dialog without doing anything
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Confirm a destructive action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Commit an edit
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Empty a list or a field
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// Try a failed load again
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Placeholder in the song-list search field
  ///
  /// In en, this message translates to:
  /// **'Search title, number, reference or lyrics…'**
  String get searchHint;

  /// Tooltip on the search icon
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTooltip;

  /// Tooltip on the button that collapses the search field
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get searchClose;

  /// Heading above previously used search queries
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// Shown when a query matches nothing
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get searchNoResults;

  /// Explains what a fruitless search covered
  ///
  /// In en, this message translates to:
  /// **'Searched titles, numbers, references and lyrics'**
  String get searchScope;

  /// Says why results appeared when no title matched
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{No title match — found in the lyrics of 1 song} other{No title match — found in the lyrics of {count} songs}}'**
  String searchLyricsFallback(int count);

  /// Empty search results while tags are also filtering
  ///
  /// In en, this message translates to:
  /// **'No songs match the selected tags and query'**
  String get searchNoTagMatch;

  /// Tooltip on the songbook filter icon
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get booksTooltip;

  /// Tooltip on the tag filter icon
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTooltip;

  /// Tooltip on the button that opens the import screen
  ///
  /// In en, this message translates to:
  /// **'Add a song'**
  String get addSong;

  /// Tooltip on the button that clears the songbook filter
  ///
  /// In en, this message translates to:
  /// **'Back to all songs'**
  String get backToAllSongs;

  /// Removes every active tag filter
  ///
  /// In en, this message translates to:
  /// **'Clear tags'**
  String get clearTags;

  /// Settings screen app-bar title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Section heading for the interface language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Language option that follows the phone's own language
  ///
  /// In en, this message translates to:
  /// **'Match my device'**
  String get settingsLanguageSystem;

  /// Hungarian, named in Hungarian so it is recognisable whatever the current language
  ///
  /// In en, this message translates to:
  /// **'Magyar'**
  String get languageHungarian;

  /// Romanian, named in Romanian
  ///
  /// In en, this message translates to:
  /// **'Română'**
  String get languageRomanian;

  /// English, named in English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Shown when a song id does not resolve
  ///
  /// In en, this message translates to:
  /// **'Song not found'**
  String get songNotFound;

  /// Placeholder title while a song loads
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// Shown when the catalogue fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading songs'**
  String get errorLoadingSongs;

  /// Tooltip on the empty heart
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get favoriteAdd;

  /// Tooltip on the filled heart
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get favoriteRemove;

  /// Tooltip on the overflow menu
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// Tooltip on the controls button
  ///
  /// In en, this message translates to:
  /// **'Song controls'**
  String get songControls;

  /// Overflow menu: full-screen lyrics for a congregation
  ///
  /// In en, this message translates to:
  /// **'Presentation mode'**
  String get menuPresentation;

  /// Overflow menu: tag editor
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get menuEditTags;

  /// Overflow menu: put the song on the clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy song text'**
  String get menuCopyText;

  /// Overflow menu: correct a user song
  ///
  /// In en, this message translates to:
  /// **'Edit song'**
  String get menuEditSong;

  /// Overflow menu: beat-level score correction
  ///
  /// In en, this message translates to:
  /// **'Correct the notation'**
  String get menuEditNotation;

  /// Overflow menu: remove a user song
  ///
  /// In en, this message translates to:
  /// **'Delete song'**
  String get menuDeleteSong;

  /// Confirmation after copying
  ///
  /// In en, this message translates to:
  /// **'Song text copied.'**
  String get songTextCopied;

  /// Confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete song?'**
  String get deleteSongTitle;

  /// Warns that a user song has no copy anywhere else
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" is stored only on this device. Deleting it cannot be undone.'**
  String deleteSongBody(String title);

  /// Snackbar when the sheet-music view falls through to chords
  ///
  /// In en, this message translates to:
  /// **'No sheet music for this song — showing chords.'**
  String get noSheetMusicShowingChords;

  /// App-bar title when a song fails to load
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorGeneric;

  /// Controls-sheet section heading
  ///
  /// In en, this message translates to:
  /// **'VIEW'**
  String get sectionView;

  /// Controls-sheet section heading
  ///
  /// In en, this message translates to:
  /// **'TEXT SIZE'**
  String get sectionTextSize;

  /// Controls-sheet section heading
  ///
  /// In en, this message translates to:
  /// **'TRANSPOSE'**
  String get sectionTranspose;

  /// Controls-sheet section heading
  ///
  /// In en, this message translates to:
  /// **'CAPO'**
  String get sectionCapo;

  /// Controls-sheet section heading
  ///
  /// In en, this message translates to:
  /// **'AUTO-SCROLL'**
  String get sectionAutoScroll;

  /// View preset: engraved notation
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get presetSheetMusic;

  /// View preset: chord symbols over lyrics
  ///
  /// In en, this message translates to:
  /// **'Chords'**
  String get presetChords;

  /// View preset: words only
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get presetLyrics;

  /// Toggle for chord symbols in the notation view
  ///
  /// In en, this message translates to:
  /// **'Chords above staff'**
  String get chordsAboveStaff;

  /// Explains why the sheet-music preset is disabled
  ///
  /// In en, this message translates to:
  /// **'There is no sheet music for this song, so it opens in Chords.'**
  String get noSheetMusicOpensInChords;

  /// Accessibility label on A-
  ///
  /// In en, this message translates to:
  /// **'Decrease text size'**
  String get textSizeDecrease;

  /// Accessibility label on A+
  ///
  /// In en, this message translates to:
  /// **'Increase text size'**
  String get textSizeIncrease;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Transpose down'**
  String get transposeDown;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Transpose up'**
  String get transposeUp;

  /// Clears transposition back to the song key
  ///
  /// In en, this message translates to:
  /// **'Reset to {key}'**
  String transposeReset(String key);

  /// Tooltip on play
  ///
  /// In en, this message translates to:
  /// **'Start auto-scroll'**
  String get autoScrollStart;

  /// Tooltip on pause
  ///
  /// In en, this message translates to:
  /// **'Stop auto-scroll'**
  String get autoScrollStop;

  /// Explains that speed is stored per song
  ///
  /// In en, this message translates to:
  /// **'Speed remembered per song'**
  String get autoScrollSpeedPerSong;

  /// Why auto-scroll is disabled
  ///
  /// In en, this message translates to:
  /// **'not in sheet music view'**
  String get autoScrollNotInSheetMusic;

  /// Auto-scroll speed name
  ///
  /// In en, this message translates to:
  /// **'Slowest'**
  String get speedSlowest;

  /// Auto-scroll speed name
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get speedSlow;

  /// Auto-scroll speed name
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get speedGentle;

  /// Auto-scroll speed name
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get speedSteady;

  /// Auto-scroll speed name
  ///
  /// In en, this message translates to:
  /// **'Brisk'**
  String get speedBrisk;

  /// Auto-scroll speed name
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get speedFast;

  /// Auto-scroll speed name
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get speedFastest;

  /// Shown when the key needs no capo
  ///
  /// In en, this message translates to:
  /// **'No capo needed'**
  String get capoNone;

  /// Recommended capo fret
  ///
  /// In en, this message translates to:
  /// **'Capo {fret}'**
  String capoAt(int fret);

  /// Capo advice with no capo fitted
  ///
  /// In en, this message translates to:
  /// **'Play open in {shape} (sounds {key})'**
  String capoOpenShape(String shape, String key);

  /// Capo advice
  ///
  /// In en, this message translates to:
  /// **'Clamp fret {fret}, finger {shape} shapes — sounds {key}'**
  String capoClamp(int fret, String shape, String key);

  /// Heading above alternative capo frets
  ///
  /// In en, this message translates to:
  /// **'Other positions'**
  String get capoOther;

  /// Shown for a key with no useful capo
  ///
  /// In en, this message translates to:
  /// **'No capo suggestion for {key}'**
  String capoNoSuggestion(String key);

  /// Empty state heading
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmpty;

  /// Empty state hint
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on a song to add it here'**
  String get favoritesEmptyHint;

  /// Button from the empty favourites screen
  ///
  /// In en, this message translates to:
  /// **'Browse Songs'**
  String get favoritesBrowse;

  /// Favourites load failure
  ///
  /// In en, this message translates to:
  /// **'Error loading favorites'**
  String get errorLoadingFavorites;

  /// Tooltip during setlist playback
  ///
  /// In en, this message translates to:
  /// **'Previous song'**
  String get setlistPrevious;

  /// Tooltip during setlist playback
  ///
  /// In en, this message translates to:
  /// **'Next song'**
  String get setlistNext;

  /// Tooltip during setlist playback
  ///
  /// In en, this message translates to:
  /// **'Stop playing setlist'**
  String get setlistStop;

  /// Button that clears the songbook filter from an empty list
  ///
  /// In en, this message translates to:
  /// **'Show all songs'**
  String get showAllSongs;

  /// A failure with the underlying message appended
  ///
  /// In en, this message translates to:
  /// **'Error: {detail}'**
  String errorDetail(String detail);

  /// Empty state when a songbook filter matches nothing
  ///
  /// In en, this message translates to:
  /// **'No songs in \"{book}\"'**
  String noSongsInBook(String book);

  /// Empty state when the whole catalogue is empty
  ///
  /// In en, this message translates to:
  /// **'No songs available'**
  String get noSongsAvailable;

  /// Explains an empty catalogue. Replaces a developer hint naming an asset path, which is not something a singer can act on.
  ///
  /// In en, this message translates to:
  /// **'The songbook that ships with the app is empty.'**
  String get noSongsHint;

  /// Open something for correction
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// Commit the fields of a bottom sheet back to the caller
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// Leave a screen and lose the unsaved changes on it
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get actionDiscard;

  /// Title of the prompt shown when leaving the notation editor dirty
  ///
  /// In en, this message translates to:
  /// **'Discard corrections?'**
  String get discardTitle;

  /// Says what is about to be lost
  ///
  /// In en, this message translates to:
  /// **'The changes on this screen have not been saved to the song.'**
  String get discardBody;

  /// Dismiss the discard prompt and stay on the screen
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get discardKeepEditing;

  /// Shown when the notation editor is opened for a song it cannot edit
  ///
  /// In en, this message translates to:
  /// **'This song has no engraved notation stored, or is no longer on this device.'**
  String get notationNoneStored;

  /// Header above a notated verse in the beat list
  ///
  /// In en, this message translates to:
  /// **'Verse {number}'**
  String notationVerse(int number);

  /// Header above one measure's beats
  ///
  /// In en, this message translates to:
  /// **'Measure {number}'**
  String notationMeasure(int number);

  /// Header for an anacrusis — the short opening bar before bar 1. A score does not number it.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get notationPickup;

  /// How long the anacrusis is. `beats` is already formatted for display ("3", "3.5"); `count` only selects singular or plural.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{beats} beat before bar 1} other{{beats} beats before bar 1}}'**
  String notationPickupBeats(int count, String beats);

  /// What a measure's beats add up to against the time signature. Turns red when the two disagree.
  ///
  /// In en, this message translates to:
  /// **'{total} / {expected} beats'**
  String notationMeasureBeats(String total, int expected);

  /// Shown for a measure whose last beat was deleted
  ///
  /// In en, this message translates to:
  /// **'No beats in this measure.'**
  String get notationNoBeats;

  /// Warns that beats in the superseded SongNotation.pickup field are invisible everywhere
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 beat sits in this song’s old separate pickup list, which nothing reads, so it is not shown above or below. An upbeat belongs in a leading measure instead.} other{{count} beats sit in this song’s old separate pickup list, which nothing reads, so they are not shown above or below. An upbeat belongs in a leading measure instead.}}'**
  String notationStalePickupNotice(int count);

  /// Stands in for the pitch of a rest in the beat list. Lower case: it sits where a pitch like "F4" would.
  ///
  /// In en, this message translates to:
  /// **'rest'**
  String get beatRestShort;

  /// Tooltip on a beat row's overflow menu
  ///
  /// In en, this message translates to:
  /// **'Beat actions'**
  String get beatActions;

  /// Beat menu: add a new beat behind this one
  ///
  /// In en, this message translates to:
  /// **'Insert after'**
  String get beatInsertAfter;

  /// Heading of the beat-fields bottom sheet
  ///
  /// In en, this message translates to:
  /// **'EDIT BEAT'**
  String get beatEditTitle;

  /// Switch that turns a note into a rest
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get beatRest;

  /// Field label for the note letter (C–B)
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get beatNote;

  /// Field label for sharp/flat/natural
  ///
  /// In en, this message translates to:
  /// **'Accidental'**
  String get beatAccidental;

  /// Accidental option: no sharp or flat. Named rather than shown as ♮, which rendered unreadably in a browser.
  ///
  /// In en, this message translates to:
  /// **'natural'**
  String get accidentalNatural;

  /// Accidental option: raised a semitone (♯)
  ///
  /// In en, this message translates to:
  /// **'sharp'**
  String get accidentalSharp;

  /// Accidental option: lowered a semitone (♭)
  ///
  /// In en, this message translates to:
  /// **'flat'**
  String get accidentalFlat;

  /// Field label above the octave stepper
  ///
  /// In en, this message translates to:
  /// **'Octave'**
  String get beatOctave;

  /// Tooltip on the octave stepper's minus
  ///
  /// In en, this message translates to:
  /// **'Lower octave'**
  String get octaveLower;

  /// Tooltip on the octave stepper's plus
  ///
  /// In en, this message translates to:
  /// **'Higher octave'**
  String get octaveHigher;

  /// Field label for the note value
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get beatDuration;

  /// Switch that adds a dot to the note
  ///
  /// In en, this message translates to:
  /// **'Dotted'**
  String get beatDotted;

  /// Explains what a dot does
  ///
  /// In en, this message translates to:
  /// **'One and a half times the duration'**
  String get beatDottedHint;

  /// Switch for a tie arriving at this note
  ///
  /// In en, this message translates to:
  /// **'Ties from the previous note'**
  String get beatTieEnd;

  /// Switch for a tie leaving this note
  ///
  /// In en, this message translates to:
  /// **'Ties to the next note'**
  String get beatTieStart;

  /// Field label for the lyric syllable under the note
  ///
  /// In en, this message translates to:
  /// **'Syllable'**
  String get beatSyllable;

  /// Field label for the chord symbol printed over the note
  ///
  /// In en, this message translates to:
  /// **'Chord above the staff'**
  String get beatChord;

  /// Says that verses after the first are preserved untouched by this sheet
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 further lyric line on this note ({lines}) is kept as it is.} other{{count} further lyric lines on this note ({lines}) are kept as they are.}}'**
  String beatExtraLyricLines(int count, String lines);

  /// Note value: four quarter beats
  ///
  /// In en, this message translates to:
  /// **'whole'**
  String get durationWhole;

  /// Note value: two quarter beats
  ///
  /// In en, this message translates to:
  /// **'half'**
  String get durationHalf;

  /// Note value: one beat in 4/4
  ///
  /// In en, this message translates to:
  /// **'quarter'**
  String get durationQuarter;

  /// Note value: half a beat
  ///
  /// In en, this message translates to:
  /// **'eighth'**
  String get durationEighth;

  /// Note value: a quarter of a beat
  ///
  /// In en, this message translates to:
  /// **'sixteenth'**
  String get durationSixteenth;

  /// A note value with a dot, as shown in the beat list
  ///
  /// In en, this message translates to:
  /// **'{duration}, dotted'**
  String durationDotted(String duration);

  /// Settings section heading: theme and font size
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Light, dark or follow the device
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// The app-wide base text size
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get settingsFontSize;

  /// Tooltip on the minus button next to the font size
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get fontSizeDecrease;

  /// Tooltip on the plus button next to the font size
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get fontSizeIncrease;

  /// Settings section heading: how a song opens
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplay;

  /// Which of the three view presets a song opens in
  ///
  /// In en, this message translates to:
  /// **'Default View'**
  String get settingsDefaultView;

  /// Settings section heading: version and app name
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Row showing the installed build
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// Shown when the version cannot be read. Lower case: it stands in for a version string.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get settingsVersionUnknown;

  /// One-line description under the app name in About
  ///
  /// In en, this message translates to:
  /// **'Worship Songbook App'**
  String get settingsTagline;

  /// Theme option: always light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme option: always dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Theme option: follow the device
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// Default-view option. Spelled out in full here; the controls sheet's chip is the short `presetSheetMusic`, which has to stay narrow enough for three chips on one line at 360 px.
  ///
  /// In en, this message translates to:
  /// **'Sheet Music'**
  String get settingsViewSheetMusic;

  /// What the sheet-music default shows
  ///
  /// In en, this message translates to:
  /// **'Notation with chords and lyrics'**
  String get settingsViewSheetMusicHint;

  /// Default-view option: chord symbols over the words
  ///
  /// In en, this message translates to:
  /// **'Chords'**
  String get settingsViewChords;

  /// What the chords default shows
  ///
  /// In en, this message translates to:
  /// **'Chords and lyrics only'**
  String get settingsViewChordsHint;

  /// Default-view option: words with nothing above them
  ///
  /// In en, this message translates to:
  /// **'Lyrics Only'**
  String get settingsViewLyricsOnly;

  /// What the lyrics-only default shows
  ///
  /// In en, this message translates to:
  /// **'Clean text without notation or chords'**
  String get settingsViewLyricsOnlyHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hu', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hu':
      return AppLocalizationsHu();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
