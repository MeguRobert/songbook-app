import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/browser_name.dart';
import 'package:songbook_app/domain/services/browser_name_stub.dart';
import 'package:songbook_app/domain/services/crash_reporter.dart';

void main() {
  group('browserFromBrands', () {
    // Real `navigator.userAgentData.brands` payloads. The GREASE entry is
    // spelled differently in each one on purpose — that is the whole point of
    // it, and a filter written against one spelling passes a test and fails in
    // the field.
    test('Chrome answers with itself, not with Chromium', () {
      expect(
        browserFromBrands(const [
          ('Not_A Brand', '24'),
          ('Chromium', '131'),
          ('Google Chrome', '131'),
        ]),
        'google-chrome/131',
      );
    });

    test('Edge answers with Edge', () {
      expect(
        browserFromBrands(const [
          ('Not/A)Brand', '8'),
          ('Chromium', '131'),
          ('Microsoft Edge', '131'),
        ]),
        'microsoft-edge/131',
      );
    });

    test('a plain Chromium build is reported as Chromium', () {
      // Not a fallback: an Android WebView and a self-built Chromium really do
      // list nothing else, and answering null would lose a real distinction.
      expect(
        browserFromBrands(const [('Not;A=Brand', '99'), ('Chromium', '131')]),
        'chromium/131',
      );
    });

    test('nothing but GREASE answers nothing', () {
      expect(browserFromBrands(const [('Not A;Brand', '99')]), isNull);
    });

    test('an empty list answers nothing rather than an empty token', () {
      expect(browserFromBrands(const []), isNull);
    });

    test('only the major version is kept', () {
      // The hints API sends "131" today. If it ever sends a full version, a
      // patch level must still not reach the table: it narrows the set of
      // people a row could describe and nobody debugging will act on it.
      expect(
        browserFromBrands(const [('Google Chrome', '131.0.6778.85')]),
        'google-chrome/131',
      );
    });
  });

  group('browserFromUserAgent', () {
    // Verbatim user-agent strings, because the order these are matched in is
    // the only thing this function gets wrong, and it can only be wrong against
    // the real ones: every Chromium UA below contains both `Chrome` and
    // `Safari`, and three of them are not Chrome.
    const agents = <String, String>{
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like '
              'Gecko) Chrome/131.0.0.0 Mobile Safari/537.36':
          'chrome/131',
      'Mozilla/5.0 (Android 14; Mobile; rv:131.0) Gecko/131.0 Firefox/131.0':
          'firefox/131',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
              'Mobile/15E148 Safari/604.1':
          'safari/17',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
              '(KHTML, like Gecko) Version/17.5 Safari/605.1.15':
          'safari/17',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, '
              'like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.2903.86':
          'edge/131',
      'Mozilla/5.0 (Linux; Android 13; SAMSUNG SM-S918B) AppleWebKit/537.36 '
              '(KHTML, like Gecko) SamsungBrowser/23.0 Chrome/115.0.0.0 '
              'Mobile Safari/537.36':
          'samsung-internet/23',
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like '
              'Gecko) Chrome/131.0.0.0 Mobile Safari/537.36 '
              'OPR/76.2.4027.73374':
          'opera/76',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/131.0.6778.73 '
              'Mobile/15E148 Safari/604.1':
          'chrome/131',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/131.0 '
              'Mobile/15E148 Safari/605.1.15':
          'firefox/131',
    };

    agents.forEach((agent, expected) {
      test(expected, () => expect(browserFromUserAgent(agent), expected));
    });

    test('something unrecognisable answers nothing', () {
      expect(browserFromUserAgent('curl/8.4.0'), isNull);
      expect(browserFromUserAgent(''), isNull);
    });

    test('no part of the agent string is ever returned', () {
      // The rule this whole file exists to keep: a name and a run of digits,
      // never the device model or the build. `SM-S918B` is a phone model and
      // must not survive.
      const samsung = 'Mozilla/5.0 (Linux; Android 13; SAMSUNG SM-S918B) '
          'AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/23.0 '
          'Chrome/115.0.0.0 Mobile Safari/537.36';
      final named = browserFromUserAgent(samsung)!;
      expect(named, isNot(contains('SM-S918B')));
      expect(named, isNot(contains('Android')));
      expect(named, matches(RegExp(r'^[a-z0-9-]+/\d+$')));
    });
  });

  group('browserSlug', () {
    test('a two-word brand becomes one token', () {
      expect(browserSlug('Google Chrome'), 'google-chrome');
      expect(browserSlug('Microsoft Edge'), 'microsoft-edge');
    });

    test('punctuation does not survive', () {
      expect(browserSlug('Not;A=Brand'), 'not-a-brand');
    });

    test('a long brand is bounded', () {
      // The column holds 200 characters and a brand is not the part worth
      // spending them on.
      expect(browserSlug('A' * 100).length, 24);
    });

    test('a brand with no letters at all still answers something', () {
      expect(browserSlug('---'), 'unknown');
    });
  });

  group('browserMajor', () {
    test('a bare major version is itself', () => expect(browserMajor('131'), '131'));
    test('a full version keeps only the major',
        () => expect(browserMajor('131.0.6778.85'), '131'));
    test('nothing answers a question mark rather than an empty string', () {
      expect(browserMajor(null), '?');
      expect(browserMajor(''), '?');
    });
  });

  group('describeBrowser off the web', () {
    test('answers null rather than a guess', () {
      // The stub half of the conditional import. Null reads as "not asked" in
      // the table; an invented value would be read as evidence.
      expect(describeBrowser(), isNull);
    });
  });

  group('describePlatform', () {
    test('stays inside the column it is stored in', () {
      // Postgres truncates past 200 with `left(new.platform, 200)`, silently.
      // A field cut off mid-token is worse than one that decided for itself.
      expect(describePlatform().length, lessThanOrEqualTo(maxPlatformLength));
    });

    test('says nothing about a browser when there is none to ask', () {
      // On the VM there is no navigator, so the browser token is absent rather
      // than blank — no trailing separator, nothing to misread as a name.
      expect(describePlatform().trim(), describePlatform());
      expect(describePlatform(), isNot(contains('/?')));
    });
  });
}
