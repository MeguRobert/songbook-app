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

  /// Tooltip on a measure header's overflow menu
  ///
  /// In en, this message translates to:
  /// **'Measure actions'**
  String get measureActions;

  /// Measure menu: open the repeat, volta and pickup controls
  ///
  /// In en, this message translates to:
  /// **'Measure properties'**
  String get measureProperties;

  /// Heading of the measure-properties bottom sheet
  ///
  /// In en, this message translates to:
  /// **'MEASURE PROPERTIES'**
  String get measureEditTitle;

  /// Measure menu: add a bar in front of this one
  ///
  /// In en, this message translates to:
  /// **'Insert measure before'**
  String get measureInsertBefore;

  /// Measure menu: add a bar behind this one
  ///
  /// In en, this message translates to:
  /// **'Insert measure after'**
  String get measureInsertAfter;

  /// Measure menu: move this bar's beats onto the end of the bar before it
  ///
  /// In en, this message translates to:
  /// **'Merge into previous measure'**
  String get measureMerge;

  /// Measure menu: remove the whole bar and its beats
  ///
  /// In en, this message translates to:
  /// **'Delete measure'**
  String get measureDelete;

  /// Beat menu: put a bar line in front of this beat, so it begins the next measure
  ///
  /// In en, this message translates to:
  /// **'Start a new measure here'**
  String get measureSplitHere;

  /// Switch for NotatedMeasure.repeatStart
  ///
  /// In en, this message translates to:
  /// **'Repeat sign at the start'**
  String get measureRepeatStart;

  /// Switch for NotatedMeasure.repeatEnd
  ///
  /// In en, this message translates to:
  /// **'Repeat sign at the end'**
  String get measureRepeatEnd;

  /// Switch for NotatedMeasure.lineBreakAfter
  ///
  /// In en, this message translates to:
  /// **'Break the staff after this measure'**
  String get measureLineBreak;

  /// Switch for NotatedMeasure.isPickup
  ///
  /// In en, this message translates to:
  /// **'Pickup measure'**
  String get measurePickup;

  /// Explains what declaring a bar a pickup changes, since a short bar is otherwise flagged as damaged
  ///
  /// In en, this message translates to:
  /// **'Short on purpose: not numbered, and not checked against the time signature'**
  String get measurePickupHint;

  /// Dropdown label for NotatedMeasure.volta — the second-time bar bracket
  ///
  /// In en, this message translates to:
  /// **'Volta bracket'**
  String get measureVolta;

  /// Volta dropdown: this bar is under no bracket
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get measureVoltaNone;

  /// Volta dropdown: bars sharing a number form one bracket
  ///
  /// In en, this message translates to:
  /// **'Ending {number}'**
  String measureVoltaEnding(int number);

  /// Section heading above the score's non-engraved voices in the editor
  ///
  /// In en, this message translates to:
  /// **'OTHER VOICES'**
  String get notationOtherVoices;

  /// Explains why the other voices are listed but show no beats
  ///
  /// In en, this message translates to:
  /// **'Kept with the song and not engraved here. Pick the line to read in the song controls.'**
  String get notationOtherVoicesHint;

  /// How many bars a voice holds, which should match the melody
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 measure} other{{count} measures}}'**
  String notationVoiceMeasures(int count);

  /// Tooltip on a voice row's overflow menu
  ///
  /// In en, this message translates to:
  /// **'Voice actions'**
  String get voiceActions;

  /// Title of the dialog that relabels one voice
  ///
  /// In en, this message translates to:
  /// **'Rename voice'**
  String get voiceRenameTitle;

  /// Field label for a voice's label, which the voice picker shows
  ///
  /// In en, this message translates to:
  /// **'Voice name'**
  String get voiceName;

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

  /// Change the name of something
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// One order of service. The app-bar title while a setlist is being resolved.
  ///
  /// In en, this message translates to:
  /// **'Setlist'**
  String get setlistSingular;

  /// Shown when a setlist id does not resolve
  ///
  /// In en, this message translates to:
  /// **'Setlist not found'**
  String get setlistNotFound;

  /// How many songs a setlist holds, under its name in the list
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String setlistSongCount(int count);

  /// Tooltip on a setlist row's overflow menu
  ///
  /// In en, this message translates to:
  /// **'Setlist options'**
  String get setlistOptions;

  /// Creates a setlist. Used as the button, its tooltip and the dialog title.
  ///
  /// In en, this message translates to:
  /// **'New setlist'**
  String get setlistNew;

  /// Title of the rename dialog
  ///
  /// In en, this message translates to:
  /// **'Rename setlist'**
  String get setlistRenameTitle;

  /// Title of the delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete setlist?'**
  String get setlistDeleteTitle;

  /// Warns that deleting a setlist cannot be undone
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be permanently removed.'**
  String setlistDeleteBody(String name);

  /// Field label in the create/rename dialog
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get setlistNameLabel;

  /// Placeholder in the create/rename dialog
  ///
  /// In en, this message translates to:
  /// **'Setlist name'**
  String get setlistNameHint;

  /// Empty state heading on the setlists screen
  ///
  /// In en, this message translates to:
  /// **'No setlists yet'**
  String get setlistsEmpty;

  /// Empty state hint on the setlists screen
  ///
  /// In en, this message translates to:
  /// **'Create one for your next service'**
  String get setlistsEmptyHint;

  /// Tooltip that starts working through a setlist in order
  ///
  /// In en, this message translates to:
  /// **'Play setlist'**
  String get setlistPlay;

  /// Opens the picker that toggles songs in and out of a setlist
  ///
  /// In en, this message translates to:
  /// **'Add songs'**
  String get setlistAddSongs;

  /// Tooltip on a song row's remove button
  ///
  /// In en, this message translates to:
  /// **'Remove from setlist'**
  String get setlistRemoveSong;

  /// Empty state heading inside one setlist
  ///
  /// In en, this message translates to:
  /// **'No songs in this setlist'**
  String get setlistEmpty;

  /// Catalogue load failure with the underlying message appended
  ///
  /// In en, this message translates to:
  /// **'Error loading songs: {detail}'**
  String errorLoadingSongsDetail(String detail);

  /// Section heading above the chord-sheet box when adding a song
  ///
  /// In en, this message translates to:
  /// **'PASTE THE SONG'**
  String get importSectionPaste;

  /// The same box's heading when correcting a song that is already saved
  ///
  /// In en, this message translates to:
  /// **'REPLACE THE WORDS AND CHORDS'**
  String get importSectionReplace;

  /// Placeholder showing both accepted shapes — chords on their own line above the words, or inline in brackets. The example line stays Hungarian in every language because the songs are Hungarian; only the connective changes.
  ///
  /// In en, this message translates to:
  /// **'G       C\nAz Úrra bízom életem\n\nor [G]Az Úrra [C]bízom életem'**
  String get importPasteHint;

  /// Button that reads the pasted text into a song
  ///
  /// In en, this message translates to:
  /// **'Parse'**
  String get importParse;

  /// Section heading above title, number and songbook
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get importSectionDetails;

  /// Names which importer produced what is on screen
  ///
  /// In en, this message translates to:
  /// **'from {source}'**
  String importFromSource(String source);

  /// Source label when the preview is the song as already stored
  ///
  /// In en, this message translates to:
  /// **'the saved song'**
  String get importSourceSaved;

  /// Source label when the preview came from the paste box
  ///
  /// In en, this message translates to:
  /// **'pasted text'**
  String get importSourcePasted;

  /// Field label for the song title
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get importTitleField;

  /// Field label for the hymn number
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get importNumberField;

  /// Field label for which book the song belongs to
  ///
  /// In en, this message translates to:
  /// **'Songbook'**
  String get importBookField;

  /// Says the key was declared by the source rather than guessed
  ///
  /// In en, this message translates to:
  /// **'Key {key}, from the file.'**
  String importKeyFromFile(String key);

  /// Says the key was inferred, so it is worth checking
  ///
  /// In en, this message translates to:
  /// **'Key guessed as {key} from the first chord.'**
  String importKeyGuessed(String key);

  /// Section heading above the rendered song
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get importSectionPreview;

  /// Import screen: heading over the editable list of parsed lines, where a row can be made chords or lyrics and a token corrected.
  ///
  /// In en, this message translates to:
  /// **'LINES'**
  String get importSectionLines;

  /// Import screen, line list: the button and badge for a row read as chords. Lower case: it is a label on a small chip, not a sentence.
  ///
  /// In en, this message translates to:
  /// **'chords'**
  String get importLineKindChords;

  /// Import screen, line list: the button and badge for a row read as lyrics.
  ///
  /// In en, this message translates to:
  /// **'words'**
  String get importLineKindLyric;

  /// Import screen, line list: marks a row whose kind a person chose rather than the parser deciding. Shown as a tooltip on the badge.
  ///
  /// In en, this message translates to:
  /// **'you set this'**
  String get importLineOverridden;

  /// Import screen: title of the dialog that opens when a chord token in the line list is tapped.
  ///
  /// In en, this message translates to:
  /// **'Correct this chord'**
  String get importTokenEditTitle;

  /// Import screen: why the token-edit dialog exists. The example is real, from 125-nincs-mas-isten.
  ///
  /// In en, this message translates to:
  /// **'The reader misreads a glyph now and then — `Csus2` can come back as `5US2`. Correcting it here is usually all a row needs.'**
  String get importTokenEditHint;

  /// Import screen: how to use the line list.
  ///
  /// In en, this message translates to:
  /// **'Tap a chord to correct it. Use the buttons when a whole row was read as the wrong kind.'**
  String get importLinesHint;

  /// How many verses the importer recovered
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 verse} other{{count} verses}}'**
  String importVerseCount(int count);

  /// How many measures of notation the importer recovered
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bar} other{{count} bars}}'**
  String importBarCount(int count);

  /// Why Save is disabled: the song being corrected was deleted elsewhere
  ///
  /// In en, this message translates to:
  /// **'That song is no longer stored on this device.'**
  String get importBlockerDeleted;

  /// Why Save is disabled: nothing has been imported yet
  ///
  /// In en, this message translates to:
  /// **'Paste a song or open a MusicXML file.'**
  String get importBlockerNothing;

  /// Why Save is disabled: the importer recovered nothing
  ///
  /// In en, this message translates to:
  /// **'No lyrics or notation found in that source.'**
  String get importBlockerEmpty;

  /// Why Save is disabled: the title box is empty
  ///
  /// In en, this message translates to:
  /// **'Give the song a title.'**
  String get importBlockerNoTitle;

  /// Why Save is disabled: the number box is empty. Saving without one used to store the song as number 0, which then reads as a real number everywhere else.
  ///
  /// In en, this message translates to:
  /// **'Give the song a number.'**
  String get importBlockerNoNumber;

  /// Why Save is disabled: the number box holds something that is not a positive whole number
  ///
  /// In en, this message translates to:
  /// **'The number has to be a whole number above zero.'**
  String get importBlockerBadNumber;

  /// Rejects a picked file by extension, and says what to do about the commonest wrong one
  ///
  /// In en, this message translates to:
  /// **'{name} is not a MusicXML file. Expected .xml, .musicxml or .mxl — a MuseScore .mscz has to be exported first.'**
  String importErrorNotMusicXml(String name);

  /// The picker returned a file with no bytes
  ///
  /// In en, this message translates to:
  /// **'Could not read {name}.'**
  String importErrorUnreadable(String name);

  /// An unexpected failure while importing, with the underlying message
  ///
  /// In en, this message translates to:
  /// **'Could not import that file: {detail}'**
  String importErrorFailed(String detail);

  /// Heading above the importer's warnings
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Check this line} other{Check these lines}}'**
  String importWarningsTitle(int count);

  /// Empty state inside the tag editor, where adding one is the next step
  ///
  /// In en, this message translates to:
  /// **'No tags yet — add one below.'**
  String get tagsNoneYetAddOne;

  /// Field label in the tag editor
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get tagAddLabel;

  /// Example tags. Translate to occasions a reader of this language would recognise.
  ///
  /// In en, this message translates to:
  /// **'e.g. Christmas, communion'**
  String get tagAddHint;

  /// Tooltip on the + inside the tag field
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get tagAddTooltip;

  /// Heading above tags already used elsewhere in the library
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get tagSuggestions;

  /// Drops the per-song tag override and goes back to the bundled tags
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get tagResetToDefault;

  /// The book filter's no-filter row
  ///
  /// In en, this message translates to:
  /// **'All Songs'**
  String get filterAllSongs;

  /// How many songs a book holds, and the total across all books
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String songCount(int count);

  /// The book list failed to load
  ///
  /// In en, this message translates to:
  /// **'Error loading books: {detail}'**
  String errorLoadingBooks(String detail);

  /// Title of the tag filter sheet
  ///
  /// In en, this message translates to:
  /// **'Filter by tags'**
  String get filterByTags;

  /// Says the filter is AND, not OR — several tags narrow rather than widen
  ///
  /// In en, this message translates to:
  /// **'Songs must carry every selected tag'**
  String get filterTagsAnd;

  /// Empty state in the tag filter, where there is nothing to act on
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get tagsEmpty;

  /// The tag list failed to load
  ///
  /// In en, this message translates to:
  /// **'Error loading tags: {detail}'**
  String errorLoadingTags(String detail);

  /// Removes every tag filter from inside the filter sheet
  ///
  /// In en, this message translates to:
  /// **'Clear all tags'**
  String get filterClearAllTags;

  /// Leaves full-screen presentation mode. The key name stays literal.
  ///
  /// In en, this message translates to:
  /// **'Exit (Esc)'**
  String get presentationExit;

  /// Screen-reader description of the engraved staff, which is a canvas and otherwise invisible to the accessibility tree
  ///
  /// In en, this message translates to:
  /// **'Sheet music notation for {title}'**
  String sheetSemanticsLabel(String title);

  /// The key the staff is currently written in, above the notation
  ///
  /// In en, this message translates to:
  /// **'Key: {key}'**
  String sheetKey(String key);

  /// Badge shown when the staff is not in the song's own key. `offset` arrives with its sign already attached ("+2", "-3").
  ///
  /// In en, this message translates to:
  /// **'Transposed {offset}'**
  String sheetTransposed(String offset);

  /// The time signature, above the notation
  ///
  /// In en, this message translates to:
  /// **'Time: {signature}'**
  String sheetTime(String signature);

  /// The melody's name, in the footer under the score
  ///
  /// In en, this message translates to:
  /// **'Tune: {tune}'**
  String sheetTune(String tune);

  /// Where the song came from, in the footer under the score
  ///
  /// In en, this message translates to:
  /// **'Origin: {origin}'**
  String sheetOrigin(String origin);

  /// Placeholder shown in place of a score the song has no notation for
  ///
  /// In en, this message translates to:
  /// **'Sheet music not available'**
  String get sheetNotAvailable;

  /// What to do instead when there is no score
  ///
  /// In en, this message translates to:
  /// **'Switch to chord view to see lyrics with chords'**
  String get sheetNotAvailableHint;

  /// Badge on the legacy SVG view, naming the key the song is written in
  ///
  /// In en, this message translates to:
  /// **'Transposed from {key}'**
  String sheetTransposedFrom(String key);

  /// The legacy SVG view has one image per key, and the transposed key has no image. Distinct from having no sheet music at all — this song has some, just not in this key.
  ///
  /// In en, this message translates to:
  /// **'Sheet music for {key} not available. Showing original key ({original}).'**
  String sheetMissingForKey(String key, String original);

  /// The legacy SVG view's empty state. Says "this song" where sheetNotAvailable says only "not available".
  ///
  /// In en, this message translates to:
  /// **'No sheet music available for this song'**
  String get sheetNoneForSong;

  /// Router error page heading for a URL that matches no route
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routeNotFound;

  /// Button on the router error page, back to the song list
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get routeGoHome;

  /// Controls-sheet section heading: which line of a four-part score is engraved
  ///
  /// In en, this message translates to:
  /// **'VOICE'**
  String get sectionVoice;

  /// The line the importer engraved — the top of the score. It has no name of its own.
  ///
  /// In en, this message translates to:
  /// **'Melody'**
  String get voiceMelody;

  /// Second voice of a four-part score
  ///
  /// In en, this message translates to:
  /// **'Alto'**
  String get voiceAlto;

  /// Third voice of a four-part score
  ///
  /// In en, this message translates to:
  /// **'Tenor'**
  String get voiceTenor;

  /// Lowest voice of a four-part score
  ///
  /// In en, this message translates to:
  /// **'Bass'**
  String get voiceBass;

  /// Settings section header for the optional account
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get accountSection;

  /// Button and screen title for signing in to an existing account
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// Button for registering a new account
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUp;

  /// Button that ends the session
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Label for the email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Label for the password field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Starts the password reset flow
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPassword;

  /// Confirmation after requesting a reset. Deliberately does not say whether the account exists, because that would let anyone test which addresses are registered.
  ///
  /// In en, this message translates to:
  /// **'If that address has an account, a reset link is on its way.'**
  String get passwordResetSent;

  /// Shown in settings when a session exists
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String signedInAs(String email);

  /// Shown in settings when there is no session
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// Says plainly that accounts are additive. Songbook works fully signed-out and that must never look like a degraded mode.
  ///
  /// In en, this message translates to:
  /// **'You do not need an account. The songs on this device work offline either way.'**
  String get accountOptional;

  /// Shown when there is no backend reachable, so the account section cannot do anything
  ///
  /// In en, this message translates to:
  /// **'Accounts are unavailable right now.'**
  String get accountsUnavailable;

  /// Title of the notice shown to a signed-in but unverified account
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get verifyEmailTitle;

  /// Explains why verification matters: reading needs no account, contributing needs a confirmed one
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}. Confirm it before contributing songs.'**
  String verifyEmailBody(String email);

  /// Re-sends the confirmation email
  ///
  /// In en, this message translates to:
  /// **'Send it again'**
  String get resendConfirmation;

  /// Brief acknowledgement after re-sending the confirmation email
  ///
  /// In en, this message translates to:
  /// **'Sent.'**
  String get confirmationResent;

  /// Switches the auth screen from register to sign in
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountPrompt;

  /// Switches the auth screen from sign in to register
  ///
  /// In en, this message translates to:
  /// **'Need an account?'**
  String get needAccountPrompt;

  /// Wrong password or unknown address. Deliberately does not say which, so it cannot be used to discover registered addresses.
  ///
  /// In en, this message translates to:
  /// **'That email and password do not match.'**
  String get authErrorInvalidCredentials;

  /// Sign-in blocked pending email confirmation
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address first.'**
  String get authErrorEmailNotConfirmed;

  /// Registration failed because the address is taken
  ///
  /// In en, this message translates to:
  /// **'That address already has an account.'**
  String get authErrorEmailAlreadyRegistered;

  /// Registration failed on password strength
  ///
  /// In en, this message translates to:
  /// **'Choose a longer password — at least 6 characters.'**
  String get authErrorWeakPassword;

  /// The address failed server-side validation
  ///
  /// In en, this message translates to:
  /// **'That does not look like an email address.'**
  String get authErrorInvalidEmail;

  /// The server is rate limiting this address or device
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get authErrorRateLimited;

  /// Reached the server and it declined, for a reason not worth its own message
  ///
  /// In en, this message translates to:
  /// **'The server refused that. Try again later.'**
  String get authErrorServerRejected;

  /// Never reached the server. Distinct from a refusal because the advice differs: check the connection rather than what you typed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection.'**
  String get authErrorNetwork;

  /// Last-resort auth failure message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get authErrorUnknown;

  /// Google OAuth button
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogle;

  /// Separates the Google button from the email form
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOrDivider;

  /// Admin-only screen listing submissions awaiting a decision
  ///
  /// In en, this message translates to:
  /// **'Waiting for review'**
  String get moderationQueueTitle;

  /// Empty moderation queue
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting.'**
  String get moderationQueueEmpty;

  /// Screen listing the user's own submissions and their state
  ///
  /// In en, this message translates to:
  /// **'Songs I sent in'**
  String get mySubmissionsTitle;

  /// Empty own-submissions list
  ///
  /// In en, this message translates to:
  /// **'You have not sent in any songs yet.'**
  String get mySubmissionsEmpty;

  /// Overflow-menu action that sends a user's own song to the moderators
  ///
  /// In en, this message translates to:
  /// **'Share with the congregation'**
  String get menuShareSong;

  /// Title of the confirmation before submitting
  ///
  /// In en, this message translates to:
  /// **'Share this song?'**
  String get shareSongTitle;

  /// Explains submit-then-review before the user commits
  ///
  /// In en, this message translates to:
  /// **'“{title}” goes to the moderators. It joins the shared songbook only after one of them approves it, and your copy stays on this device either way.'**
  String shareSongBody(String title);

  /// Confirms the submission
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get shareSongConfirm;

  /// Title shown when a signed-out user tries to share
  ///
  /// In en, this message translates to:
  /// **'Sign in to share'**
  String get shareSongSignInTitle;

  /// Why an account is required to submit
  ///
  /// In en, this message translates to:
  /// **'Sharing needs an account, so the congregation can see who contributed the song. Your song is already saved on this device and stays there.'**
  String get shareSongSignInBody;

  /// Confirmation after a successful submission
  ///
  /// In en, this message translates to:
  /// **'Sent for review.'**
  String get shareSongSent;

  /// Shown when the same song is already in the queue
  ///
  /// In en, this message translates to:
  /// **'You have already sent this song in. It is waiting for review.'**
  String get shareSongAlreadySent;

  /// Shown when the submission call fails
  ///
  /// In en, this message translates to:
  /// **'The song could not be sent. Check your connection and try again.'**
  String get shareSongFailed;

  /// Accepts a submission into the shared catalogue
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// Declines a submission. Softer than 'Reject' because a person wrote the thing.
  ///
  /// In en, this message translates to:
  /// **'Turn down'**
  String get reject;

  /// Label on the rejection reason field. Says who reads it, because a reason nobody sees is pointless.
  ///
  /// In en, this message translates to:
  /// **'Why? The contributor will see this.'**
  String get rejectReasonLabel;

  /// Validation when a rejection has no reason
  ///
  /// In en, this message translates to:
  /// **'Give a reason so they can fix it.'**
  String get rejectReasonRequired;

  /// Takes back a submission that has not been decided yet
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// Submission state: saved but not sent
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// Submission state: sent, no decision yet
  ///
  /// In en, this message translates to:
  /// **'Waiting for review'**
  String get statusPending;

  /// Submission state: accepted. Phrased as the outcome rather than 'Approved', which says nothing to a contributor.
  ///
  /// In en, this message translates to:
  /// **'In the shared songbook'**
  String get statusApproved;

  /// Submission state: declined, with a reason shown alongside
  ///
  /// In en, this message translates to:
  /// **'Turned down'**
  String get statusRejected;

  /// Brief acknowledgement after approving or turning down a submission
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get moderationDecided;

  /// Button that picks a photo of a song to extract lyrics and chords from
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get importPhoto;

  /// Source label when the preview came from a photo
  ///
  /// In en, this message translates to:
  /// **'photo'**
  String get importSourcePhoto;

  /// Progress text while the photo is being sent and read
  ///
  /// In en, this message translates to:
  /// **'Reading the photo…'**
  String get importPhotoReading;

  /// Shown when this build carries no sheet-music reader, so the toggle cannot work
  ///
  /// In en, this message translates to:
  /// **'This version of Songbook cannot read sheet music.'**
  String get importPhotoNotConfigured;

  /// Explanation under the Photo button for the ordinary chord-sheet path
  ///
  /// In en, this message translates to:
  /// **'Reads the words and chords on the page, on your device.'**
  String get importPhotoHint;

  /// Import screen: heading over the photograph shown beside the preview, so a reading can be compared against the page it came from.
  ///
  /// In en, this message translates to:
  /// **'PHOTO'**
  String get importSectionPhoto;

  /// Import screen: how to magnify the photograph shown beside the preview.
  ///
  /// In en, this message translates to:
  /// **'Pinch or scroll to zoom.'**
  String get importPhotoZoomHint;

  /// Toggle asking whether the photographed page carries engraved notation
  ///
  /// In en, this message translates to:
  /// **'This page has sheet music'**
  String get importPhotoSheetMusic;

  /// The instruction that matters most: a curled page drops most of the notes
  ///
  /// In en, this message translates to:
  /// **'Press the book flat and photograph it straight from above — the notes are lost off a curved page. Reading music needs a connection and can take a minute.'**
  String get importPhotoSheetMusicHint;

  /// Shown when the sheet-music service refused the upload for want of a sign-in
  ///
  /// In en, this message translates to:
  /// **'Sign in first: sheet music is read by a shared service, not on your device.'**
  String get importPhotoSignIn;

  /// Shown on a platform with no engine to read a photo with
  ///
  /// In en, this message translates to:
  /// **'Photos can only be read in the browser version of Songbook.'**
  String get importPhotoNoReader;

  /// Generic confirm button in a settings dialog
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Generic dismiss button in a settings dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Voice picker option: engrave every voice at once, one staff each, rather than choosing one line to read. Must stay short — the chip row has to fit one line at 360px.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get voiceAll;

  /// Chord-sheet parser: a {directive} it does not implement. The importNotice* keys are the messages of ChordSheetParser and MusicXmlImporter, which name a code rather than building prose — this is the only place that prose exists.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: ignored the unknown directive \"{text}\".'**
  String importNoticeUnknownDirective(int line, String text);

  /// Chord-sheet parser: a lone note letter, which in Hungarian is also the definite article. Losing a chord is recoverable, losing a line of words is not, so it stays a lyric.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: \"{text}\" could be a one-chord line or a lyric; kept as a lyric.'**
  String importNoticeAmbiguousBareRoot(int line, String text);

  /// Chord-sheet parser: a [...] marker holding something else — a section name, a repeat count. `text` arrives without its brackets, so each language can punctuate it its own way.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: \"[{text}]\" is not a chord; kept as lyric text.'**
  String importNoticeBracketNotAChord(int line, String text);

  /// MusicXML importer: the rarer of the two MusicXML layouts. The two format names are literal and stay untranslated.
  ///
  /// In en, this message translates to:
  /// **'This file is score-timewise, so its measures may be grouped incorrectly. Export it as score-partwise for a clean import.'**
  String get importNoticeTimewiseScore;

  /// MusicXML importer: valid XML, but nothing to engrave
  ///
  /// In en, this message translates to:
  /// **'No notes were found in the file.'**
  String get importNoticeNoNotes;

  /// MusicXML importer: a four-part score reduces to its melody for engraving, and the other lines are stored on the song rather than discarded. "the song controls" is the sheet reached from the song view, whose VOICE section picks one.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 voice beyond the melody was kept — only the melody is engraved. Switch voices in the song controls.} other{{count} voices beyond the melody were kept — only the melody is engraved. Switch voices in the song controls.}}'**
  String importNoticeExtraVoicesKept(int count);

  /// MusicXML importer: a grace note would be engraved as a full beat and break the bar's arithmetic, so it is dropped
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 grace note was skipped: the notation has no grace-note beat.} other{{count} grace notes were skipped: the notation has no grace-note beat.}}'**
  String importNoticeGraceNotesSkipped(int count);

  /// MusicXML importer: the melody reduction applied vertically to a <chord> stack
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chord was reduced to its top note; the lower notes were kept as extra voices.} other{{count} chords were reduced to their top notes; the lower notes were kept as extra voices.}}'**
  String importNoticeChordsReduced(int count);

  /// MusicXML importer: a double sharp or double flat cannot round-trip through a model that stores one accidental character
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 double accidental was approximated to a single sharp or flat, which is all the notation stores.} other{{count} double accidentals were approximated to a single sharp or flat, which is all the notation stores.}}'**
  String importNoticeDoubleAccidentals(int count);

  /// MusicXML importer: the model has one dot, not two
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 double-dotted note was imported as single-dotted.} other{{count} double-dotted notes were imported as single-dotted.}}'**
  String importNoticeDoubleDots(int count);

  /// MusicXML importer: values shorter than a sixteenth or longer than a whole. `text` is the MusicXML type names, already sorted and comma-joined, and stays literal; `count` only selects singular or plural.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The note value {text} cannot be drawn, so it was approximated to the nearest one that can.} other{The note values {text} cannot be drawn, so they were approximated to the nearest ones that can.}}'**
  String importNoticeUnsupportedNoteValues(int count, String text);

  /// MusicXML importer, fatal: nothing but whitespace was handed over
  ///
  /// In en, this message translates to:
  /// **'The MusicXML input is empty.'**
  String get importNoticeEmptyXmlInput;

  /// MusicXML importer, fatal: the document is not well-formed. `text` is the XML parser's own reason and stays in English — it names elements and offsets.
  ///
  /// In en, this message translates to:
  /// **'This file is not valid XML: {text}'**
  String importNoticeInvalidXml(String text);

  /// MusicXML importer, fatal: META-INF/container.xml was passed on its own. It says which entry of the archive is the score, so it looks like MusicXML and holds no music.
  ///
  /// In en, this message translates to:
  /// **'This is the container index from inside an .mxl file, not a score. Open the .mxl file itself.'**
  String get importNoticeContainerManifest;

  /// MusicXML importer, fatal: no bytes at all
  ///
  /// In en, this message translates to:
  /// **'The .mxl input is empty.'**
  String get importNoticeEmptyMxlInput;

  /// MusicXML importer, fatal: .mxl is a zip, and these bytes are not one. `text` is the decoder's own reason.
  ///
  /// In en, this message translates to:
  /// **'This is not a readable .mxl archive: {text}'**
  String importNoticeUnreadableArchive(String text);

  /// MusicXML importer, fatal: a readable zip with nothing to read in it
  ///
  /// In en, this message translates to:
  /// **'The .mxl archive contains no MusicXML score.'**
  String get importNoticeNoScoreInArchive;

  /// Chord-sheet parser: a -7 style continuation token with nothing in front of it to extend.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: “{text}” has no chord before it to continue; dropped.'**
  String importNoticeContinuationWithoutChord(int line, String text);

  /// Photo reader: the upload is too compressed to hold Hungarian long umlauts. `text` is the pixel size, `count` the file size in kilobytes.
  ///
  /// In en, this message translates to:
  /// **'That photo arrived at {text} in {count} KB — too compressed to hold the fine strokes. Accents like ő and ű are the first thing to go, so expect a few wrong letters. A phone gallery hands over a shrunken copy; picking the same photo through Files usually gives the full-quality original.'**
  String importNoticePhotoLowResolution(String text, int count);

  /// Photo reader: a second, paler population of ink was detected and suppressed. Deliberately says what was done rather than what caused it: measured on the corpus, uneven light across a photographed page trips the same gate as a legible reverse side, and suppression costs stroke sharpness either way.
  ///
  /// In en, this message translates to:
  /// **'Part of the page read as faint second ink — the reverse side showing through, or uneven light — and it was cleaned away before reading. If a chord is missing, a photo in flatter light will read better than this one.'**
  String get importNoticePhotoShowThroughRemoved;

  /// Photo reader: a hymnal page set with more than one song across it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{That page holds {count} songs side by side. All of them were read, in reading order — delete the one you did not want.}}'**
  String importNoticePhotoTwoSongs(int count);

  /// Photo reader: words were read but no row of them classified as chords.
  ///
  /// In en, this message translates to:
  /// **'No chords were recognised — the words were imported on their own.'**
  String get importNoticePhotoNoChords;

  /// Photo reader: the page could not be read at all.
  ///
  /// In en, this message translates to:
  /// **'Nothing legible was found in that photo.'**
  String get importNoticePhotoNothingLegible;

  /// Photo reader: German/Hungarian note names were read and are renamed on the way into storage. `text` is the names, sorted and joined.
  ///
  /// In en, this message translates to:
  /// **'{text} will be stored under the English name (H is B natural). The app keeps one spelling per pitch so transposing stays exact.'**
  String importNoticePhotoGermanNoteNames(String text);

  /// Photo reader: a bare lowercase c on a chord row, stored as C major rather than C minor. `count` is how many. C and c are the same shape at two sizes and no other note letter is, so a small one is almost always a mis-sized capital - measured on 084-van-egy-ut (6 of its 12 chords) and 125-nincs-mas-isten (3).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} chords were read as a lowercase c and stored as C major. In print C and c are the same shape at two sizes, so a small one is almost always a capital the reader mis-sized — if your page really means the minor, write Cm.}}'**
  String importNoticePhotoLowercaseCRaised(int count);

  /// Role name shown to users. One of three; see the roles table.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @roleModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get roleModerator;

  /// No description provided for @roleAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdministrator;

  /// No description provided for @roleMemberDescription.
  ///
  /// In en, this message translates to:
  /// **'Can read the songbook and offer songs for review.'**
  String get roleMemberDescription;

  /// No description provided for @roleModeratorDescription.
  ///
  /// In en, this message translates to:
  /// **'Can approve or turn down submissions, and correct any song.'**
  String get roleModeratorDescription;

  /// No description provided for @roleAdministratorDescription.
  ///
  /// In en, this message translates to:
  /// **'Everything a moderator can do, plus managing accounts and settings.'**
  String get roleAdministratorDescription;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get adminTitle;

  /// Shown when a non-administrator opens an /admin URL
  ///
  /// In en, this message translates to:
  /// **'This area is for administrators.'**
  String get adminNotPermitted;

  /// No description provided for @adminUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get adminUsersTitle;

  /// No description provided for @adminUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get adminUserTitle;

  /// No description provided for @adminUserGone.
  ///
  /// In en, this message translates to:
  /// **'This account no longer exists.'**
  String get adminUserGone;

  /// No description provided for @adminSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contribution settings'**
  String get adminSettingsTitle;

  /// No description provided for @adminSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Who may submit, and the rules they accept'**
  String get adminSettingsSubtitle;

  /// Number waiting, or an em dash while loading
  ///
  /// In en, this message translates to:
  /// **'{count} waiting for review'**
  String adminWaitingCount(String count);

  /// Number of accounts, or an em dash while loading
  ///
  /// In en, this message translates to:
  /// **'{count} accounts'**
  String adminMemberCount(String count);

  /// No description provided for @adminSubmissionsClosedNotice.
  ///
  /// In en, this message translates to:
  /// **'Submissions are closed. Nobody can offer a song.'**
  String get adminSubmissionsClosedNotice;

  /// No description provided for @adminReopen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get adminReopen;

  /// No description provided for @adminSearchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search by name or address'**
  String get adminSearchUsers;

  /// No description provided for @adminFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminFilterAll;

  /// No description provided for @adminInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get adminInvite;

  /// No description provided for @adminSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get adminSendInvite;

  /// No description provided for @adminInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent.'**
  String get adminInviteSent;

  /// No description provided for @adminUsersUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The member list could not be loaded.'**
  String get adminUsersUnavailable;

  /// No description provided for @adminNoMatchingUsers.
  ///
  /// In en, this message translates to:
  /// **'Nobody matches that.'**
  String get adminNoMatchingUsers;

  /// No description provided for @adminActionDone.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get adminActionDone;

  /// No description provided for @adminActionFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work.'**
  String get adminActionFailed;

  /// No description provided for @adminCannotActOnSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot change your own role or delete your own account.'**
  String get adminCannotActOnSelf;

  /// No description provided for @adminLastAdministrator.
  ///
  /// In en, this message translates to:
  /// **'There has to be at least one administrator.'**
  String get adminLastAdministrator;

  /// No description provided for @adminRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get adminRole;

  /// No description provided for @adminChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get adminChange;

  /// No description provided for @adminChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get adminChangeRole;

  /// No description provided for @adminEmailStatus.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get adminEmailStatus;

  /// No description provided for @adminEmailConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get adminEmailConfirmed;

  /// No description provided for @adminEmailUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get adminEmailUnconfirmed;

  /// No description provided for @adminGuidelinesStatus.
  ///
  /// In en, this message translates to:
  /// **'Contribution guidelines'**
  String get adminGuidelinesStatus;

  /// No description provided for @adminGuidelinesAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get adminGuidelinesAccepted;

  /// No description provided for @adminGuidelinesNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'Not accepted yet'**
  String get adminGuidelinesNotAccepted;

  /// No description provided for @adminLastSignIn.
  ///
  /// In en, this message translates to:
  /// **'Last signed in'**
  String get adminLastSignIn;

  /// No description provided for @adminNeverSignedIn.
  ///
  /// In en, this message translates to:
  /// **'never signed in'**
  String get adminNeverSignedIn;

  /// No description provided for @adminSubmissions.
  ///
  /// In en, this message translates to:
  /// **'Submitted songs'**
  String get adminSubmissions;

  /// How many of this member's songs were approved
  ///
  /// In en, this message translates to:
  /// **'{count} approved'**
  String adminTallyApproved(int count);

  /// How many are still waiting
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String adminTallyPending(int count);

  /// How many were turned down
  ///
  /// In en, this message translates to:
  /// **'{count} turned down'**
  String adminTallyRejected(int count);

  /// No description provided for @adminDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete this account'**
  String get adminDeleteAccount;

  /// No description provided for @adminDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get adminDeleteWarning;

  /// Explains what survives deleting an account
  ///
  /// In en, this message translates to:
  /// **'Songs already approved stay in the songbook, credited to the name recorded when they were submitted. Anything still waiting or turned down is removed.'**
  String get adminDeleteKeepsApproved;

  /// The address the administrator must retype
  ///
  /// In en, this message translates to:
  /// **'Type {address} to confirm.'**
  String adminDeleteTypeToConfirm(String address);

  /// No description provided for @adminDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get adminDeletePermanently;

  /// No description provided for @adminSubmissionsSection.
  ///
  /// In en, this message translates to:
  /// **'Submissions'**
  String get adminSubmissionsSection;

  /// No description provided for @adminSubmissionsOpen.
  ///
  /// In en, this message translates to:
  /// **'Accept new songs'**
  String get adminSubmissionsOpen;

  /// No description provided for @adminSubmissionsOpenHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn this off to stop accepting anything new, without a redeploy.'**
  String get adminSubmissionsOpenHelp;

  /// No description provided for @adminRequireConfirmedEmail.
  ///
  /// In en, this message translates to:
  /// **'Require a confirmed address'**
  String get adminRequireConfirmedEmail;

  /// No description provided for @adminRequireConfirmedEmailHelp.
  ///
  /// In en, this message translates to:
  /// **'Someone who has not confirmed their email cannot submit.'**
  String get adminRequireConfirmedEmailHelp;

  /// No description provided for @adminDailyCap.
  ///
  /// In en, this message translates to:
  /// **'Songs per person per day'**
  String get adminDailyCap;

  /// No description provided for @adminDailyCapHelp.
  ///
  /// In en, this message translates to:
  /// **'A limit on how fast one account can fill the queue.'**
  String get adminDailyCapHelp;

  /// No description provided for @adminGuidelinesSection.
  ///
  /// In en, this message translates to:
  /// **'Contribution guidelines'**
  String get adminGuidelinesSection;

  /// No description provided for @adminGuidelinesHelp.
  ///
  /// In en, this message translates to:
  /// **'Everyone reads this and ticks it once, before their first submission.'**
  String get adminGuidelinesHelp;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @publishClosedTitle.
  ///
  /// In en, this message translates to:
  /// **'Submissions are closed'**
  String get publishClosedTitle;

  /// Reassures the contributor their work is not lost
  ///
  /// In en, this message translates to:
  /// **'New songs are not being accepted at the moment. Your song is still saved on this device.'**
  String get publishClosedBody;

  /// The address the confirmation link went to
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address first. We sent a link to {email}.'**
  String publishConfirmEmailBody(String email);

  /// No description provided for @publishNameTitle.
  ///
  /// In en, this message translates to:
  /// **'How should we credit you?'**
  String get publishNameTitle;

  /// No description provided for @publishNameBody.
  ///
  /// In en, this message translates to:
  /// **'Your name is shown next to the song, so the congregation can see who brought it.'**
  String get publishNameBody;

  /// No description provided for @publishNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get publishNameLabel;

  /// No description provided for @publishNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please give a name.'**
  String get publishNameRequired;

  /// No description provided for @publishGuidelinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you send it'**
  String get publishGuidelinesTitle;

  /// No description provided for @publishGuidelinesAgree.
  ///
  /// In en, this message translates to:
  /// **'I have read this and my song follows it.'**
  String get publishGuidelinesAgree;

  /// No description provided for @publishGuidelinesAccept.
  ///
  /// In en, this message translates to:
  /// **'Agree and send'**
  String get publishGuidelinesAccept;

  /// No description provided for @publishRefusedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get publishRefusedTitle;

  /// No description provided for @publishDailyLimitBody.
  ///
  /// In en, this message translates to:
  /// **'You have already sent as many songs today as the limit allows. Please try again tomorrow.'**
  String get publishDailyLimitBody;

  /// The frozen name recorded when the song was submitted
  ///
  /// In en, this message translates to:
  /// **'Submitted by {name}'**
  String submittedBy(String name);

  /// The frozen name of a deleted account
  ///
  /// In en, this message translates to:
  /// **'Submitted by {name}, who has since left'**
  String submittedByFormerMember(String name);
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
