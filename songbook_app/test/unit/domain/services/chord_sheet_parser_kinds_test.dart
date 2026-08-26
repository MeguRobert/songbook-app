import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/chord_sheet_parser.dart';

/// Overruling the parser about one line.
///
/// `isChordLine` is right about almost every row, and it is more forgiving than
/// it looks: `D 5US2 G` reads as chords already, because one odd-looking stray is
/// tolerated beside two recognised ones. What it cannot forgive is a row that
/// runs out of recognised chords to lean on — `Em 5US2` is one short — and that
/// is the residue [LineKinds] is for, a row a person holding the photograph can
/// see plainly and the rule cannot.
///
/// It is deliberately not the answer to a misread token. Overriding a row's kind
/// says nothing about what its tokens mean, so `5US2` is still stored as a chord
/// nothing can transpose; correcting the token is what fixes that, and the parser
/// then agrees about the row on its own.
///
/// The first test in this file is the one that matters most: with no overrides,
/// the parse must be what it always was. Everything else in the app parses
/// without them.
void main() {
  const parser = ChordSheetParser();

  /// A row the rule genuinely reads as lyrics.
  ///
  /// Measured rather than assumed: `D 5US2 G` does NOT need an override, because
  /// `chord_row_reason` tolerates one odd-looking stray beside two chords - it
  /// reads as chords already and stores `5US2` as one, which is the deliberate
  /// cost recorded in `9d471cc`. `Em 5US2` is one chord short of that tolerance,
  /// so it falls to lyrics, and this is the shape `125-nincs-mas-isten` gives up
  /// for its intro row.
  const misread = 'Em    5US2\n'
      'Az Úr irgalma végtelen';

  String render(ParsedChordSheet sheet) => sheet.verses
      .expand((v) => v.lines)
      .map((l) => '${l.chords.map((c) => '${c.position}:${c.chord}').join(',')}'
          '|${l.text}')
      .join('\n');

  group('no overrides changes nothing', () {
    test('a sheet parses identically with an empty LineKinds and with none', () {
      const sheet = '{title: Az Úr irgalma}\n'
          '\n'
          'G        D       em    G\n'
          'Szívemben öröm dalol,\n'
          'am     D7    G\n'
          'Jézust dícsérem.\n'
          '\n'
          'Refr: Boldog a szívem\n'
          '[C]Az [G]Úrra bízom';
      expect(render(parser.parse(sheet, kinds: const LineKinds.none())),
          render(parser.parse(sheet)));
      expect(parser.parse(sheet, kinds: const LineKinds.none()).warnings.length,
          parser.parse(sheet).warnings.length);
    });

    test('the misread row is lyrics when nobody says otherwise', () {
      final lines = parser.parse(misread).verses.single.lines;
      expect(lines, hasLength(2));
      expect(lines.first.text, 'Em    5US2');
      expect(lines.first.chords, isEmpty);
    });
  });

  group('an override makes a row chords', () {
    test('the row pairs with the line under it', () {
      final result = parser.parse(misread,
          kinds: const LineKinds({0: LineKind.chords}));
      final lines = result.verses.single.lines;
      expect(lines, hasLength(1), reason: 'the pair is one lyric line');
      expect(lines.single.text, 'Az Úr irgalma végtelen');
    });

    test('the chords land at the columns the row printed them in', () {
      final result = parser.parse(misread,
          kinds: const LineKinds({0: LineKind.chords}));
      final chords = result.verses.single.lines.single.chords;
      // `5US2` IS carried over, at the column the page printed it in, because
      // overriding the row's kind says nothing about what its tokens mean. It is
      // visibly wrong somewhere a person can fix it - and fixing it is what the
      // token edit is for. This is the same trade `9d471cc` recorded.
      expect(chords.map((c) => c.chord), ['Em', '5US2']);
      expect(chords.map((c) => c.position), [0, 6]);
    });
  });

  group('an override makes a row lyrics', () {
    test('a chord row marked lyric is not consumed as a pair', () {
      const sheet = 'D     G\nAz Úr irgalma';
      final result = parser.parse(sheet,
          kinds: const LineKinds({0: LineKind.lyric}));
      final lines = result.verses.single.lines;
      expect(lines, hasLength(2));
      expect(lines.first.text, 'D     G');
      expect(lines.first.chords, isEmpty);
    });

    test('the line under a chord row can be refused as its lyric', () {
      // Two chord rows in a row: the second is really chords, and marking it so
      // stops the first swallowing it.
      const sheet = 'D     G\nem    A';
      final result = parser.parse(sheet,
          kinds: const LineKinds({1: LineKind.chords}));
      final lines = result.verses.single.lines;
      expect(lines, hasLength(2), reason: 'two chord rows, two lines');
      // `em` is stored as `Em`: the app keeps one spelling per chord so
      // transposing stays exact, which `ChordTransposer` documents.
      expect(lines.map((l) => l.chords.map((c) => c.chord).join(' ')),
          ['D G', 'Em A']);
    });
  });

  group('a stale override cannot take the import down', () {
    test('an index past the end of the text is ignored', () {
      final result = parser.parse(misread,
          kinds: const LineKinds({99: LineKind.chords}));
      expect(render(result), render(parser.parse(misread)));
    });

    test('a negative index is ignored', () {
      final result = parser.parse(misread,
          kinds: const LineKinds({-1: LineKind.lyric}));
      expect(render(result), render(parser.parse(misread)));
    });

    test('an override on a blank line or a directive is ignored', () {
      const sheet = '{title: Az Úr}\n\nD  G\nirgalma';
      final result = parser.parse(sheet,
          kinds: const LineKinds({0: LineKind.chords, 1: LineKind.chords}));
      expect(result.title, 'Az Úr');
      expect(render(result), render(parser.parse(sheet)));
    });
  });

  group('LineKinds keeps itself sparse', () {
    test('it starts empty', () {
      expect(const LineKinds.none().isEmpty, isTrue);
      expect(const LineKinds.none().kindOf(0), isNull);
    });

    test('withLine records one line and withoutLine forgets it', () {
      const none = LineKinds.none();
      final marked = none.withLine(3, LineKind.chords);
      expect(marked.kindOf(3), LineKind.chords);
      expect(marked.kindOf(4), isNull);
      expect(marked.withoutLine(3).isEmpty, isTrue);
    });

    test('it does not mutate what it was built from', () {
      const none = LineKinds.none();
      none.withLine(1, LineKind.lyric);
      expect(none.isEmpty, isTrue);
    });

    test('isChords and isLyric are null where nobody said', () {
      const kinds = LineKinds({0: LineKind.chords});
      expect(kinds.isChords(0), isTrue);
      expect(kinds.isLyric(0), isFalse);
      expect(kinds.isChords(1), isNull);
      expect(kinds.isLyric(1), isNull);
    });
  });
}
