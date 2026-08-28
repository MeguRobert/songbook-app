/// There is no browser here, so there is nothing to name.
///
/// The half of the conditional import that keeps `crash_reporter.dart`
/// compiling — and `flutter test` running — on a platform with no `window`.
/// Returning null rather than a guess is the point: an empty field says "not
/// asked", and an invented one would be read as evidence.
String? describeBrowser() => null;
