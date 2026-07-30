import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/import_notice.dart';

/// [ImportNotice] is compared, deduplicated and asserted on, so its equality has
/// to cover every argument it carries — not just the code. Two notices that
/// differ only by line number are two different problems.

void main() {
  group('ImportNotice equality', () {
    test('the same code and arguments are equal and hash alike', () {
      const a = ImportNotice(ImportNoticeCode.unknownDirective,
          line: 3, text: '{define: G}');
      const b = ImportNotice(ImportNoticeCode.unknownDirective,
          line: 3, text: '{define: G}');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different code is a different notice', () {
      expect(
        const ImportNotice(ImportNoticeCode.noNotes),
        isNot(const ImportNotice(ImportNoticeCode.emptyXmlInput)),
      );
    });

    test('every argument participates', () {
      const base = ImportNotice(ImportNoticeCode.unknownDirective,
          line: 3, count: 1, text: 'x');

      expect(
        base,
        isNot(const ImportNotice(ImportNoticeCode.unknownDirective,
            line: 4, count: 1, text: 'x')),
        reason: 'line must count towards equality',
      );
      expect(
        base,
        isNot(const ImportNotice(ImportNoticeCode.unknownDirective,
            line: 3, count: 2, text: 'x')),
        reason: 'count must count towards equality',
      );
      expect(
        base,
        isNot(const ImportNotice(ImportNoticeCode.unknownDirective,
            line: 3, count: 1, text: 'y')),
        reason: 'text must count towards equality',
      );
    });

    test('arguments default to absent', () {
      const notice = ImportNotice(ImportNoticeCode.noNotes);
      expect(notice.line, isNull);
      expect(notice.count, isNull);
      expect(notice.text, isNull);
    });
  });

  group('ImportNotice.toString', () {
    // Debug output only. It must NEVER be shown to a user — that is what the
    // presentation-layer formatter is for — so it names the code rather than
    // reading as a sentence, which also makes an accidental leak obvious.
    test('names the code and the arguments that are present', () {
      const notice = ImportNotice(ImportNoticeCode.unknownDirective,
          line: 3, text: '{define: G}');
      final text = notice.toString();

      expect(text, contains('unknownDirective'));
      expect(text, contains('3'));
      expect(text, contains('{define: G}'));
    });

    test('omits the arguments a code does not carry', () {
      expect(const ImportNotice(ImportNoticeCode.noNotes).toString(),
          'ImportNotice(noNotes)');
    });
  });
}
