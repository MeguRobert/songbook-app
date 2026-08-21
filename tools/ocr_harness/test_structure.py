"""The editor's two-way conversion.

The editor never shows a character column, so this module is the only thing that
knows about them. If it loses a chord or moves one to another word, a gold file
silently starts asserting something nobody typed.
"""
import unittest

from . import gold, reading, structure


def placements(chordpro):
    """Every (chord, which word) in [chordpro], order-insensitive."""
    return sorted((p.chord, p.word_index)
                  for p in reading.parse(chordpro).placements)


class ToLines(unittest.TestCase):

    def test_a_chord_row_folds_into_the_lyric_beneath_it(self):
        lines = structure.to_lines("G       D\nAmazing grace")
        self.assertEqual(1, len(lines))
        self.assertEqual(structure.LYRIC, lines[0]["kind"])
        self.assertEqual("Amazing grace", lines[0]["text"])
        self.assertEqual([("G", 0), ("D", 1)],
                         [(c["chord"], c["word"]) for c in lines[0]["chords"]])

    def test_a_chord_past_the_end_lands_in_after(self):
        lines = structure.to_lines("G                D\nAmazing grace")
        self.assertEqual([("G", 0)],
                         [(c["chord"], c["word"]) for c in lines[0]["chords"]])
        self.assertEqual(["D"], [c["chord"] for c in lines[0]["after"]])

    def test_a_chord_row_with_nothing_under_it_stays_its_own_line(self):
        lines = structure.to_lines("Em7 Cadd9 G5\n\nG    D\nAmazing grace")
        self.assertEqual(structure.CHORDS, lines[0]["kind"])
        self.assertEqual(["Em7", "Cadd9", "G5"], lines[0]["chords"])

    def test_two_chord_rows_in_a_row_do_not_swallow_each_other(self):
        lines = structure.to_lines("G  D\nC  G\nAmazing grace")
        self.assertEqual([structure.CHORDS, structure.LYRIC],
                         [line["kind"] for line in lines])

    def test_a_blank_line_becomes_one_break(self):
        lines = structure.to_lines("one\n\n\n\ntwo")
        self.assertEqual([structure.LYRIC, structure.BLANK, structure.LYRIC],
                         [line["kind"] for line in lines])

    def test_leading_and_trailing_blanks_are_dropped(self):
        lines = structure.to_lines("\n\none\n\n\n")
        self.assertEqual([structure.LYRIC], [line["kind"] for line in lines])

    def test_a_title_directive_is_not_a_line(self):
        lines = structure.to_lines("{title: 84. Van egy ut}\n\nAmazing grace")
        self.assertEqual([structure.LYRIC], [line["kind"] for line in lines])

    def test_punctuation_is_kept_but_marked_as_such(self):
        # Kept so a save puts the page's own marks back where it printed them;
        # marked so the editor can dim them. Nothing that scores counts them -
        # `placements` below is what the metrics read.
        lines = structure.to_lines("G7 - Am\nAmazing grace how")
        self.assertEqual([("G7", False), ("-", True), ("Am", False)],
                         [(c["chord"], c["sep"]) for c in lines[0]["chords"]])
        # Both land on 'Amazing': `G7 - Am` is narrower than the first word.
        self.assertEqual([("Am", 0), ("G7", 0)],
                         placements(structure.to_chordpro(lines)))


class ToChordpro(unittest.TestCase):

    def test_a_chord_lands_at_the_start_of_its_word(self):
        got = structure.to_chordpro([
            {"kind": "lyric", "text": "Amazing grace",
             "chords": [{"chord": "D", "word": 1}], "after": []}])
        self.assertEqual("        D\nAmazing grace", got)

    def test_two_chords_on_one_word_are_spread_rather_than_lost(self):
        got = structure.to_chordpro([
            {"kind": "lyric", "text": "Amazing grace",
             "chords": [{"chord": "G", "word": 0}, {"chord": "D", "word": 0}],
             "after": []}])
        self.assertEqual(["G", "D"], got.split("\n")[0].split())

    def test_a_trailing_chord_lands_past_the_end(self):
        # `D7` rather than `D`: a row whose only chord is a bare root reads as
        # lyrics, so a bare `D` here would generate a line that parses back as
        # words. That is the one-bare-root rule, not a conversion bug, and
        # test_a_lone_trailing_bare_root_cannot_be_expressed pins it.
        got = structure.to_chordpro([
            {"kind": "lyric", "text": "Amazing grace", "chords": [],
             "after": ["D7"]}])
        self.assertEqual([("D7", -1)], placements(got))

    def test_a_lone_trailing_root_now_survives_in_either_case(self):
        # It used not to: the generated row was correct text that the parser
        # then resolved to lyrics, so the editor could not express a one-chord
        # turnaround at all.
        for chord in ("D", "d"):
            with self.subTest(chord=chord):
                got = structure.to_chordpro([
                    {"kind": "lyric", "text": "Amazing grace", "chords": [],
                     "after": [chord]}])
                self.assertEqual([(chord, -1)], placements(got))

    def test_a_line_that_merely_starts_with_a_brace_is_kept(self):
        # Real OCR output on 105-kosz-jol-vagyok. A looser directive test
        # dropped it, so saving that page would have deleted a line.
        lines = structure.to_lines("Amazing grace\n{ad 'nsber, 25")
        self.assertEqual(["Amazing grace", "{ad 'nsber, 25"],
                         [line["text"] for line in lines])

    def test_a_real_directive_is_still_dropped(self):
        lines = structure.to_lines("{title: Van egy ut}\nAmazing grace")
        self.assertEqual(["Amazing grace"], [line["text"] for line in lines])

    def test_an_out_of_range_word_is_dropped_not_misplaced(self):
        got = structure.to_chordpro([
            {"kind": "lyric", "text": "Amazing grace",
             "chords": [{"chord": "D", "word": 9}], "after": []}])
        self.assertEqual("Amazing grace", got)

    def test_a_blank_kind_becomes_a_blank_line(self):
        got = structure.to_chordpro([
            {"kind": "lyric", "text": "one", "chords": [], "after": []},
            {"kind": "blank"},
            {"kind": "lyric", "text": "two", "chords": [], "after": []}])
        self.assertEqual("one\n\ntwo", got)

    def test_a_chords_only_line_keeps_its_chords(self):
        got = structure.to_chordpro([{"kind": "chords",
                                      "chords": ["Em7", "Cadd9"]}])
        self.assertEqual("Em7  Cadd9", got)

    def test_an_empty_chord_is_ignored(self):
        got = structure.to_chordpro([
            {"kind": "lyric", "text": "Amazing grace",
             "chords": [{"chord": "  ", "word": 0}], "after": []}])
        self.assertEqual("Amazing grace", got)

    def test_a_lyric_line_with_no_chords_emits_no_chord_row(self):
        got = structure.to_chordpro([
            {"kind": "lyric", "text": "Amazing grace", "chords": [],
             "after": []}])
        self.assertEqual("Amazing grace", got)


class RoundTrip(unittest.TestCase):
    """Text -> structure -> text has to preserve every placement."""

    CASES = (
        "G       D\nAmazing grace",
        "G                    D\nAmazing grace",
        "Em7 Cadd9-Csus2 G5\n\nG   D\nAmazing grace how",
        "G   D\nC   G\nAmazing grace",
        "   G     C        D    -  C\n1. Jézus szívedbe lát!",
        "G          C      C7    D   G - C - D - ( C )\n"
        "Mi az, mit benne, benne ott talál?",
        "      G      D           em H7\nJézus Krisztusom, mentő oltalom",
        "one\n\ntwo\n\nthree",
    )

    def _again(self, text):
        return structure.to_chordpro(structure.to_lines(text))

    def test_placements_survive(self):
        for text in self.CASES:
            with self.subTest(text=text.split("\n")[0]):
                self.assertEqual(placements(text),
                                 placements(self._again(text)))

    def test_lyrics_survive(self):
        for text in self.CASES:
            with self.subTest(text=text.split("\n")[0]):
                self.assertEqual(reading.parse(text).lyrics,
                                 reading.parse(self._again(text)).lyrics)

    def test_blocks_survive(self):
        for text in self.CASES:
            with self.subTest(text=text.split("\n")[0]):
                self.assertEqual(reading.parse(text).blocks,
                                 reading.parse(self._again(text)).blocks)

    def test_a_second_pass_changes_nothing(self):
        # Idempotent: opening a file in the editor and saving it untouched must
        # not produce a diff, or every save churns the gold files.
        for text in self.CASES:
            with self.subTest(text=text.split("\n")[0]):
                once = self._again(text)
                self.assertEqual(once, self._again(once))


class RoundTripEveryGoldFile(unittest.TestCase):
    """The same guarantee over what is actually on disk."""

    def test_placements_and_lyrics_survive(self):
        for page in gold.pages(with_gold=True):
            with self.subTest(page=page.file):
                text = page.gold.chordpro
                again = structure.to_chordpro(structure.to_lines(text))
                self.assertEqual(placements(text), placements(again))
                self.assertEqual(reading.parse(text).lyrics,
                                 reading.parse(again).lyrics)


if __name__ == "__main__":
    unittest.main()


class RememberedColumns(unittest.TestCase):
    """A measured column survives until the words under it change."""

    TEXT = "      G      D           em H7\nJézus Krisztusom, mentő oltalom"

    def test_an_untouched_save_is_byte_identical(self):
        # Without this, opening a file and saving it flattened every chord onto
        # its word's first letter and lost the alignment a reviewer compares
        # against the photograph.
        self.assertEqual(
            self.TEXT, structure.to_chordpro(structure.to_lines(self.TEXT)))

    def test_every_gold_file_survives_an_untouched_save(self):
        # A `{title:}` directive is expected to go: the title lives in its own
        # field and the editor writes it from there. Everything else, including
        # the punctuation the page prints, has to come back byte for byte.
        for page in gold.pages(with_gold=True):
            with self.subTest(page=page.file):
                text = page.gold.chordpro
                keep = [line for line in text.split("\n")
                        if not line.strip().startswith("{title")]
                want = "\n".join(keep).strip("\n")
                got = structure.to_chordpro(structure.to_lines(text))
                self.assertEqual(want, got.strip("\n"))

    def test_editing_the_words_drops_a_column_that_no_longer_fits(self):
        lines = structure.to_lines(self.TEXT)
        lines[0]['text'] = 'Jézus Úr, mentő oltalom'
        row = structure.to_chordpro(lines).split('\n')[0]
        # 'Úr,' is short, so the remembered column 13 is past it; the chord
        # falls back to the word's start rather than sliding onto another word.
        self.assertEqual([('D', 1), ('G', 1), ('H7', 3), ('em', 3)],
                         placements(structure.to_chordpro(lines)))
        self.assertLess(len(row), 32)

    def test_a_column_pointing_at_another_word_is_ignored(self):
        got = structure.to_chordpro([
            {'kind': 'lyric', 'text': 'Amazing grace',
             'chords': [{'chord': 'D7', 'word': 0, 'col': 9}], 'after': []}])
        self.assertEqual([('D7', 0)], placements(got))

    def test_a_missing_column_falls_back_to_the_word_start(self):
        got = structure.to_chordpro([
            {'kind': 'lyric', 'text': 'Amazing grace',
             'chords': [{'chord': 'D7', 'word': 1}], 'after': []}])
        self.assertEqual("        D7\nAmazing grace", got)
