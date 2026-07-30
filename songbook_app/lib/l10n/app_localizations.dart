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
