/// Turning what a browser says about itself into `chrome/131`.
///
/// **Pure, and in its own file, so it can be tested at all.** The reads that
/// have to happen in a browser — `navigator.userAgentData`, `navigator.userAgent`
/// — live in `browser_name_web.dart` and are three property lookups. Everything
/// that can be *wrong* is here: which brand of several to believe, which token
/// of a user-agent string to match first, how to shorten a name. None of that
/// needs a browser to check, and `flutter test` runs on the Dart VM where a
/// browser is exactly what there is not.
///
/// Nothing here ever returns a raw user-agent string, a device model or a minor
/// version. See [describeBrowser] in `browser_name_web.dart` for why that is a
/// rule and not a preference.
library;

/// `navigator.userAgentData.brands`, reduced to one token.
///
/// The list always holds one or more GREASE entries — `Not;A=Brand`,
/// `Not_A Brand`, `Not)A;Brand` — put there precisely so that code doing this
/// cannot come to depend on a fixed shape. They are dropped by comparing
/// letters only, which is the one thing the punctuation cannot vary.
///
/// Of the rest, the specific brand beats `Chromium`: Chrome, Edge, Opera and
/// Samsung Internet all list `Chromium` as well, and answering with that would
/// erase the only distinction this field exists to draw. Chromium is still
/// returned when it is all there is, which is what a plain Chromium build and
/// most embedded WebViews report.
String? browserFromBrands(List<(String brand, String version)> brands) {
  String? chromium;
  for (final (brand, version) in brands) {
    if (brand.isEmpty) continue;
    final letters = brand.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    if (letters == 'notabrand') continue;
    final named = '${browserSlug(brand)}/${browserMajor(version)}';
    if (letters == 'chromium') {
      chromium = named;
      continue;
    }
    return named;
  }
  return chromium;
}

/// The last resort: Firefox and Safari, which have no `userAgentData` at all,
/// and any Chromium too old or too insecure to offer one.
///
/// **Order is load-bearing, and is the reason UA sniffing has the reputation it
/// has.** Every Chromium user-agent contains both `Chrome` and `Safari`; Edge
/// appends `Edg` after both, Opera appends `OPR`, Samsung Internet appends
/// `SamsungBrowser`. So the most specific token has to be tried first and plain
/// `Chrome` last of the Chromium family, or every one of them reports as
/// Chrome. Firefox goes first because it shares nothing with the rest.
///
/// Only the name and one run of digits ever leaves this function. [agent] is
/// not stored, not logged and not returned.
String? browserFromUserAgent(String agent) {
  const patterns = <(String, String)>[
    ('firefox', r'(?:Firefox|FxiOS)/(\d+)'),
    ('samsung-internet', r'SamsungBrowser/(\d+)'),
    ('edge', r'Edge?(?:A|iOS)?/(\d+)'),
    ('opera', r'(?:OPR|OPiOS|Opera)/(\d+)'),
    ('chrome', r'(?:CriOS|Chrome)/(\d+)'),
    // Safari names its own release in `Version/`. The `Safari/` token carries a
    // WebKit build number — `605.1.15` for every Safari for years — which is
    // not a browser version and tells a reader nothing.
    ('safari', r'Version/(\d+)[.\d]*\s+(?:Mobile/\S+\s+)?Safari'),
  ];
  for (final (name, pattern) in patterns) {
    final match = RegExp(pattern).firstMatch(agent);
    if (match != null) return '$name/${match.group(1)}';
  }
  return null;
}

/// A brand as one lowercase token: `Google Chrome` becomes `google-chrome`.
///
/// Bounded, because the string this joins is capped at 200 characters by the
/// column that stores it, and a brand name is not the part worth spending them
/// on.
String browserSlug(String brand) {
  final slug = brand
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) return 'unknown';
  return slug.length <= 24 ? slug : slug.substring(0, 24);
}

/// `131` from `131`, and from `131.0.6778.85` if a browser ever sends one.
///
/// The major version and no more of it. A minor version identifies a patch
/// level, which nobody debugging this will ever act on, and narrows the set of
/// people a row could describe.
String browserMajor(String? version) =>
    RegExp(r'^\d+').firstMatch(version ?? '')?.group(0) ?? '?';
