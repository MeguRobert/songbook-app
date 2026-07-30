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
}
