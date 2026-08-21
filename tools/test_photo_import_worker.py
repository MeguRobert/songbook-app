#!/usr/bin/env python3
"""Tests for the OCR -> ChordPro bridge in photo_import_worker.

The worker's `--easyocr` mode has two halves. One is EasyOCR itself, which is a
black box we cannot usefully test. The other is the bridge: turning a bag of
(text, bounding box) tuples back into chords-over-lyrics text. That half is pure
arithmetic on boxes, so it is tested here with hand-built boxes and no OCR, no
model and no network.

Getting the bridge right is the whole feature. `ChordPosition.position` is a
*character column* into the lyric, and EasyOCR gives *pixels*, so the mapping
between the two is where the chords end up over the wrong syllable — or where a
Hungarian line whose words begin with note letters gets shredded into chords.
Both failures are pinned below, and the classification rules are deliberately
the same ones `ChordSheetParser` uses on the Dart side: the two must agree about
what a chord is or the app re-reads our output differently than we wrote it.
"""

import math
import pathlib
import shutil
import tempfile
import unittest

import photo_import_worker as worker
from photo_import_worker import Box


def render(boxes):
    """The ChordPro text for [boxes], dropping the warnings."""
    return worker.chordpro_from_boxes(boxes)[0]


def row(y, height, *tokens):
    """Boxes on one baseline: (text, x0, x1) triples at [y]..[y]+[height]."""
    return [Box(text=t, x0=x0, y0=y, x1=x1, y1=y + height)
            for t, x0, x1 in tokens]


# A plain English couplet with a 10px monospace-ish grid, used wherever the test
# is about placement rather than about language.
LYRICS = ('Amazing', 0, 70), ('grace', 80, 130), ('how', 140, 170), \
         ('sweet', 180, 230)


def tilt(boxes, degrees):
    """[boxes] where they would land if the page were photographed crooked."""
    radians = math.radians(degrees)
    sin, cos = math.sin(radians), math.cos(radians)
    tilted = []
    for b in boxes:
        cx, cy = (b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2
        nx, ny = cx * cos - cy * sin, cx * sin + cy * cos
        half_w, half_h = (b.x1 - b.x0) / 2, (b.y1 - b.y0) / 2
        tilted.append(Box(b.text, nx - half_w, ny - half_h,
                          nx + half_w, ny + half_h))
    return tilted


# Four rows: two chord/lyric pairs. Enough boxes for a skew estimate to have
# something to work with, which two rows would not be.
def page():
    # `A` sits at x=80, over "grace", so its placement is checkable.
    return (row(70, 16, ('D', 0, 20), ('A', 80, 100))
            + row(100, 20, *LYRICS)
            + row(160, 16, ('G', 0, 20), ('C', 300, 320))
            + row(190, 20, ('Nem', 0, 60), ('kell', 70, 130),
                  ('már', 140, 200), ('félnem', 210, 330)))


class SkewTests(unittest.TestCase):
    """A photographed page is never square-on.

    `group_rows` clusters by y centre, so tilt is the one distortion that
    destroys it: across a wide line a few degrees lifts the left end several
    line-heights above the right, and one line arrives as several rows with
    the chords shuffled into the lyrics. Measured on a simulated photo, 2 deg
    was harmless and 6.5 deg was unreadable.

    EasyOCR is no help here — it returns axis-aligned rectangles whatever the
    text does, so the angle has to be recovered from how the boxes sit.
    """

    def test_a_known_tilt_is_recovered(self):
        for degrees in (-8.0, -3.0, 0.0, 2.5, 6.5):
            found = worker.estimate_skew(tilt(page(), degrees))
            self.assertAlmostEqual(found, degrees, delta=0.75,
                                   msg=f'{degrees} deg read as {found}')

    def test_a_flat_page_is_read_as_flat(self):
        self.assertAlmostEqual(worker.estimate_skew(page()), 0.0, delta=0.3)

    def test_a_tilted_page_reads_the_same_as_a_flat_one(self):
        def shape(boxes):
            return [' '.join(line.split())
                    for line in render(boxes).split('\n')]

        self.assertEqual(shape(tilt(page(), 6.5)), shape(page()))

    def test_a_chord_on_a_tilted_page_keeps_its_syllable(self):
        chords, lyrics = render(tilt(page(), 6.5)).split('\n')[:2]
        self.assertEqual(chords.index('D'), lyrics.index('Amazing'))
        self.assertEqual(lyrics[chords.index('A')], 'g')

    def test_too_few_boxes_to_judge_leaves_them_alone(self):
        # One word is not evidence of an angle, and guessing one would move it.
        boxes = row(100, 20, ('Amazing', 0, 70))
        self.assertEqual(render(boxes), 'Amazing')


class ColumnTests(unittest.TestCase):
    """A hymnal sets two songs side by side, and rows are clustered by y.

    So a line in the left column and an unrelated line at the same height in the
    right one become a single row: the two songs interleave and every lyric ends
    up holding half of another song. Measured on a rendered two-column page, the
    titles merged into `{title: 148 Az Úr ... 149 Mondd, ki ...}`.

    The gutter is found from the union of every box's x-extent. Using the union
    is what makes it safe: a chord row has huge gaps of its own, but some lyric
    line below always covers them, so only a gap that NO box crosses anywhere on
    the page counts as a column break.
    """

    @staticmethod
    def two_columns():
        return (row(100, 20, ('Az', 0, 40), ('Úr', 50, 90))
                + row(100, 20, ('Mondd,', 900, 1010), ('ki', 1020, 1050))
                + row(140, 20, ('irgalma', 0, 120))
                + row(140, 20, ('egész', 900, 1000)))

    def test_a_gutter_splits_the_page(self):
        columns = worker.split_columns(self.two_columns())
        self.assertEqual(len(columns), 2)
        self.assertEqual([b.text for b in columns[0]],
                         ['Az', 'Úr', 'irgalma'])
        self.assertEqual([b.text for b in columns[1]],
                         ['Mondd,', 'ki', 'egész'])

    def test_the_left_column_is_read_first(self):
        text = render(self.two_columns())
        self.assertLess(text.index('irgalma'), text.index('Mondd,'))

    def test_the_two_songs_stop_sharing_lines(self):
        for line in render(self.two_columns()).split('\n'):
            self.assertFalse('Az' in line and 'Mondd,' in line, line)

    def test_a_wide_chord_gap_is_not_a_gutter(self):
        # A chord row is nearly all whitespace. The lyric line beneath covers
        # the same x, so the union has no hole and the page stays whole.
        boxes = row(70, 16, ('D', 0, 20), ('A', 900, 920)) \
            + row(100, 20, ('Az Úr irgalma végtelen, minden reggel', 0, 950))
        self.assertEqual(len(worker.split_columns(boxes)), 1)

    def test_empty_space_at_the_edge_is_not_a_gutter(self):
        # Short left-aligned lines leave the right of the page bare; that is
        # margin, not a column break.
        boxes = row(100, 20, ('rövid', 0, 90)) + row(140, 20, ('sor', 0, 60))
        self.assertEqual(len(worker.split_columns(boxes)), 1)

    def test_a_single_stray_mark_does_not_become_a_column(self):
        boxes = row(100, 20, ('Az', 0, 40), ('Úr', 50, 90)) \
            + row(140, 20, ('irgalma', 0, 120)) \
            + [Box('.', 2000, 100, 2008, 108)]
        self.assertEqual(len(worker.split_columns(boxes)), 1)

    def test_two_songs_on_one_page_are_reported(self):
        _, warnings = worker.chordpro_from_boxes(self.two_columns())
        self.assertTrue(any('side by side' in w for w in warnings), warnings)


class ChordTokenTests(unittest.TestCase):
    """Mirrors ChordSheetParser.isChordToken's whitelist."""

    def test_accepts_a_plain_triad(self):
        self.assertTrue(worker.is_chord_token('G'))

    def test_accepts_quality_and_extension(self):
        for token in ('Am', 'C#m7', 'Em7b5', 'Gsus4', 'Ddim', 'F+'):
            self.assertTrue(worker.is_chord_token(token), token)

    def test_accepts_a_slash_bass(self):
        self.assertTrue(worker.is_chord_token('D/F#'))

    def test_accepts_a_parenthesised_chord(self):
        self.assertTrue(worker.is_chord_token('(Em)'))

    def test_rejects_hungarian_words_that_start_with_note_letters(self):
        # The exact trap the Dart whitelist exists for.
        for token in ('Csak', 'Egy', 'Az', 'Gyere', 'Adj'):
            self.assertFalse(worker.is_chord_token(token), token)

    def test_rejects_a_double_flat(self):
        self.assertFalse(worker.is_chord_token('Bbb'))


class ChordRowTests(unittest.TestCase):
    """Mirrors ChordSheetParser.isChordLine's all-or-nothing rule."""

    def test_a_row_of_chords_is_a_chord_row(self):
        self.assertTrue(worker.is_chord_row(['G', 'C', 'D']))

    def test_one_ordinary_word_makes_the_whole_row_lyrics(self):
        self.assertFalse(worker.is_chord_row(['G', 'C', 'grace']))

    def test_bar_lines_and_repeats_are_tolerated(self):
        self.assertTrue(worker.is_chord_row(['|:', 'C', 'G', ':|', 'x2']))

    def test_punctuation_alone_is_not_a_chord_row(self):
        self.assertFalse(worker.is_chord_row(['|', '-', '|']))

    def test_a_lone_root_is_a_chord_row_in_either_case(self):
        # A row holding nothing but one letter is not a plausible line of words.
        # `A` is the Hungarian definite article, but that ambiguity only arises
        # when it stands among words — and one ordinary word already makes the
        # whole row lyrics. Reading every one-letter row as lyrics cost four
        # real chords across two pages of the measurement corpus.
        for root in ('A', 'C', 'D', 'E', 'G', 'H', 'a', 'd', 'e', 'h'):
            with self.subTest(root=root):
                self.assertTrue(worker.is_chord_row([root]))

    def test_a_lone_root_with_punctuation_is_a_chord_row(self):
        self.assertTrue(worker.is_chord_row(['D', '-']))
        self.assertTrue(worker.is_chord_row(['a', '-']))

    def test_a_lone_root_beside_a_word_is_still_lyrics(self):
        # The all-or-nothing rule is what actually protects the article, and it
        # is untouched: one ordinary word makes the whole row words.
        self.assertFalse(worker.is_chord_row(['A', 'szívemben']))
        self.assertFalse(worker.is_chord_row(['a', 'szívemben']))

    def test_a_lone_parenthesised_root_is_a_chord_row(self):
        self.assertTrue(worker.is_chord_row(['(A)']))


class GroupRowsTests(unittest.TestCase):

    def test_boxes_on_one_baseline_become_one_row(self):
        rows = worker.group_rows(row(100, 20, *LYRICS))
        self.assertEqual(len(rows), 1)
        self.assertEqual([b.text for b in rows[0]],
                         ['Amazing', 'grace', 'how', 'sweet'])

    def test_rows_come_back_top_to_bottom_and_left_to_right(self):
        # Fed in deliberately scrambled order, which is what OCR returns.
        boxes = row(200, 20, ('second', 50, 110), ('line', 0, 40)) \
            + row(100, 20, ('first', 0, 50))
        rows = worker.group_rows(boxes)
        self.assertEqual([[b.text for b in r] for r in rows],
                         [['first'], ['line', 'second']])

    def test_one_overtall_box_does_not_swallow_the_row_above(self):
        """A region can arrive far taller than the text in it.

        Measured on song 149: the page is thin enough to show the reverse side
        through, and CRAFT merged that show-through into the real lyric line,
        giving a region 132px tall for ~60px letters. The tolerance used to be a
        fraction of the row's *own* height, so an inflated box widened its own
        gate and pulled the chord row above it in — which is why every chord on
        that line was imported as a word.
        """
        boxes = row(70, 62, ('D', 0, 60), ('A', 1300, 1360)) \
            + [Box('Mondd, ki a dzsungel Királya? n bbod', 0, 105, 1600, 237)]
        rows = worker.group_rows(boxes)
        self.assertEqual(len(rows), 2, [[b.text for b in r] for r in rows])
        self.assertEqual([b.text for b in rows[0]], ['D', 'A'])

    def test_a_slightly_wavy_baseline_stays_one_row(self):
        # A phone photo is never square-on; tokens on one line differ by a few
        # pixels of y. Splitting on that would put every word on its own line.
        boxes = row(100, 20, ('Amazing', 0, 70)) \
            + row(104, 20, ('grace', 80, 130)) \
            + row(97, 20, ('how', 140, 170))
        self.assertEqual(len(worker.group_rows(boxes)), 1)


class LayoutTests(unittest.TestCase):

    def test_lyrics_alone_come_back_as_a_plain_line(self):
        self.assertEqual(render(row(100, 20, *LYRICS)),
                         'Amazing grace how sweet')

    def test_a_chord_lands_over_the_syllable_it_sits_above(self):
        boxes = row(70, 16, ('G', 0, 10), ('C', 180, 190)) \
            + row(100, 20, *LYRICS)
        chords, lyrics = render(boxes).split('\n')
        self.assertEqual(chords.index('G'), lyrics.index('Amazing'))
        self.assertEqual(chords.index('C'), lyrics.index('sweet'))

    def test_a_chord_between_two_words_lands_inside_the_nearer_one(self):
        # x=100 is two fifths of the way through "grace" (80..130). Two chords,
        # because a row holding one bare root reads as lyrics — see
        # test_a_lone_bare_root_reads_as_lyrics.
        boxes = row(70, 16, ('G', 0, 10), ('D', 100, 110)) \
            + row(100, 20, *LYRICS)
        chords, lyrics = render(boxes).split('\n')
        self.assertEqual(lyrics[chords.index('D')], 'a')

    def test_two_chords_that_want_the_same_column_do_not_merge(self):
        boxes = row(70, 16, ('G', 0, 10), ('C', 2, 12)) \
            + row(100, 20, *LYRICS)
        chords = render(boxes).split('\n')[0]
        self.assertEqual(chords.split(), ['G', 'C'])

    def test_a_chord_row_with_nothing_under_it_is_kept(self):
        # An intro run. Dropping it would silently lose the intro.
        boxes = row(70, 16, ('G', 0, 10), ('C', 100, 110))
        self.assertEqual(render(boxes).split(), ['G', 'C'])

    def test_a_wide_vertical_gap_starts_a_new_verse(self):
        boxes = row(100, 20, ('first', 0, 50)) \
            + row(130, 20, ('second', 0, 60)) \
            + row(300, 20, ('third', 0, 50))
        self.assertEqual(render(boxes).split('\n'),
                         ['first', 'second', '', 'third'])

    def test_a_larger_first_line_becomes_the_title(self):
        boxes = row(20, 40, ('Csak', 0, 80), ('egyszer', 90, 230)) \
            + row(120, 20, ('Amazing', 0, 70))
        self.assertEqual(render(boxes).split('\n')[0],
                         '{title: Csak egyszer}')

    def test_an_ordinary_first_line_is_not_a_title(self):
        boxes = row(20, 20, ('Csak', 0, 40)) + row(60, 20, ('Amazing', 0, 70))
        self.assertNotIn('title', render(boxes))


class HungarianRepairTests(unittest.TestCase):
    """The OCR-confusion pass carried over from convert_hymn.ocr_lyrics_from_image."""

    def test_a_one_inside_a_word_is_read_as_i(self):
        boxes = row(100, 20, ('m1nden', 0, 60))
        self.assertEqual(render(boxes), 'minden')

    def test_a_stray_one_after_a_word_is_read_as_i(self):
        boxes = row(100, 20, ('le', 0, 20), ('1', 30, 40), ('től', 50, 80))
        self.assertEqual(render(boxes), 'le i től')

    def test_a_leading_verse_number_survives(self):
        boxes = row(100, 20, ('1', 0, 10), ('Amazing', 20, 90))
        self.assertEqual(render(boxes), '1 Amazing')

    def test_a_six_inside_a_word_is_read_as_o_double_acute(self):
        # Measured: every error in the ground-truth hymn scan was `ő`, read as
        # ó, ö or 6. `id6ben` is the real one it produced.
        boxes = row(100, 20, ('id6ben', 0, 120))
        self.assertEqual(render(boxes), 'időben')

    def test_a_standalone_six_survives(self):
        # A verse number, a fret number, a repeat count. Only a 6 wedged
        # against a letter is evidence of a misread glyph.
        boxes = row(100, 20, ('6', 0, 10), ('Amazing', 20, 90))
        self.assertEqual(render(boxes), '6 Amazing')

    def test_a_real_o_acute_is_left_alone(self):
        # `ó` and `ö` are ordinary Hungarian letters, so the same repair cannot
        # be extended to them: `jó` and `föld` would be broken to fix `tól`.
        boxes = row(100, 20, ('jó', 0, 20), ('föld', 30, 70))
        self.assertEqual(render(boxes), 'jó föld')

    def test_the_repair_never_touches_a_chord_row(self):
        # `x1` is a repeat marker, and the in-word rule would read it as `xi`.
        boxes = row(70, 16, ('C7', 0, 20), ('x1', 30, 50), ('G', 60, 70))
        self.assertIn('x1', render(boxes))


class GermanNotationTests(unittest.TestCase):
    """`H` is B natural in Hungary, and the app now accepts it.

    ChordSheetParser takes `[A-GH]` and renames `H` to `B` on the way into
    storage (ChordTransposer.toEnglishNotation). These pin the Python to the
    same reading: the worker emits what the page says, and the app owns the
    rename, so a photographed `Hm` reaches the song as `Bm`.
    """

    def test_a_lowercase_root_is_a_chord(self):
        # Central European notation: uppercase major, lowercase minor. The app
        # raises the case on the way into storage; the worker only has to agree
        # that these are chords, or the row is emitted as lyrics.
        for token in ('em', 'a', 'c', 'c7', 'c#m', 'gm7', 'h', 'hm'):
            self.assertTrue(worker.is_chord_token(token), token)

    def test_a_lowercase_hungarian_word_is_not_a_chord(self):
        for token in ('az', 'ad', 'egy', 'hogy', 'ki', 'nekem'):
            self.assertFalse(worker.is_chord_token(token), token)

    def test_a_dash_before_an_extension_continues_the_chord_before_it(self):
        # `A  -7  D` — the book's shorthand for "that A, with a seventh".
        self.assertFalse(worker.is_chord_token('-7'))
        self.assertTrue(worker.is_continuation('-7'))
        self.assertFalse(worker.is_continuation('-'), 'plain filler dash')
        self.assertTrue(worker.is_chord_row(['em', 'A', '-7', 'D']))

    def test_dashes_alone_are_still_not_a_chord_row(self):
        self.assertFalse(worker.is_chord_row(['-7', '-m']))

    def test_h_is_a_chord(self):
        for token in ('H', 'Hm', 'H7', 'Hm7', 'Hsus4', '(Hm)', 'G/H'):
            self.assertTrue(worker.is_chord_token(token), token)

    def test_hungarian_words_starting_with_h_are_still_not_chords(self):
        for token in ('Hogy', 'Hozzád', 'Ha', 'Hív', 'Halld'):
            self.assertFalse(worker.is_chord_token(token), token)

    def test_hadd_is_the_one_collision_admitting_h_costs(self):
        # Mirrors the Dart pin: H+add is a legal chord shape and `hadd` is a
        # Hungarian word. The all-or-nothing row rule contains it.
        self.assertTrue(worker.is_chord_token('Hadd'))
        self.assertFalse(worker.is_chord_row(['Hadd', 'menjek', 'el']))

    def test_a_row_with_an_h_chord_is_a_chord_row(self):
        self.assertTrue(worker.is_chord_row(['D', 'A', 'Hm']))

    def test_an_h_chord_lands_over_the_right_syllable(self):
        # The case that started all of this: before H was a chord, this row was
        # emitted as a lyric line and every chord on it became a word.
        boxes = row(70, 16, ('D', 0, 10), ('Hm', 180, 210)) \
            + row(100, 20, *LYRICS)
        chords, lyrics = render(boxes).split('\n')
        self.assertEqual(chords.index('Hm'), lyrics.index('sweet'))

    def test_the_rename_to_b_is_reported(self):
        boxes = row(70, 16, ('D', 0, 10), ('A', 100, 110), ('Hm', 200, 220)) \
            + row(100, 20, *LYRICS)
        _, warnings = worker.chordpro_from_boxes(boxes)
        self.assertTrue(any('Hm' in w for w in warnings), warnings)

    def test_an_ordinary_lyric_row_raises_no_such_warning(self):
        boxes = row(100, 20, ('Hogy', 0, 60), ('még', 70, 110)) \
            + row(140, 20, ('sem', 0, 40), ('ég', 50, 80))
        _, warnings = worker.chordpro_from_boxes(boxes)
        self.assertFalse(any('Hm' in w or 'H ' in w for w in warnings), warnings)

    def test_a_plain_chord_row_raises_no_such_warning(self):
        boxes = row(70, 16, ('D', 0, 10), ('A', 100, 110)) \
            + row(100, 20, *LYRICS)
        _, warnings = worker.chordpro_from_boxes(boxes)
        self.assertEqual(warnings, [])


class EasyOcrResultTests(unittest.TestCase):
    """Turning EasyOCR's (bbox, text, confidence) tuples into [Box]es."""

    @staticmethod
    def result(text, x0, y0, x1, y1, confidence):
        return ([[x0, y0], [x1, y0], [x1, y1], [x0, y1]], text, confidence)

    def test_a_quadrilateral_becomes_its_bounding_box(self):
        # A photographed page is never square-on, so the quad is not a rect.
        quad = ([[10, 100], [70, 96], [72, 118], [12, 122]], 'grace', 0.9)
        box, = worker.boxes_from_easyocr([quad])
        self.assertEqual((box.x0, box.y0, box.x1, box.y1), (10, 96, 72, 122))

    def test_low_confidence_reads_are_dropped(self):
        results = [self.result('grace', 0, 100, 50, 120, 0.9),
                   self.result('rn1c', 60, 100, 90, 120, 0.05)]
        self.assertEqual([b.text for b in worker.boxes_from_easyocr(results)],
                         ['grace'])

    def test_whitespace_only_reads_are_dropped(self):
        results = [self.result('  ', 0, 100, 50, 120, 0.99)]
        self.assertEqual(worker.boxes_from_easyocr(results), [])


class SpacedPunctuationTests(unittest.TestCase):
    """The recogniser puts a space before its own comma, inside one region.

    Measured on a simulated photo: a region came back as `vagy ,` at 0.60
    confidence, so the lyric imported as `mert velem vagy ,`. It is one region
    and not two — checked, and no punctuation ever arrived as a box of its own
    across six real runs — so nothing about the layout reaches this. The
    recognised text itself is what is wrong.
    """

    def test_a_space_before_a_comma_is_closed(self):
        boxes = row(100, 20, ('vagy ,', 0, 120))
        self.assertEqual(render(boxes), 'vagy,')

    def test_a_space_before_a_full_stop_is_closed(self):
        boxes = row(100, 20, ('mutat .', 0, 140))
        self.assertEqual(render(boxes), 'mutat.')

    def test_a_spaced_dash_is_left_alone(self):
        # ` - ` separates syllables all over a hymnal page.
        boxes = row(100, 20, ('for-mál - va', 0, 240))
        self.assertEqual(render(boxes), 'for-mál - va')

    def test_an_ordinary_gap_between_words_is_left_alone(self):
        boxes = row(100, 20, ('velem vagy', 0, 200))
        self.assertEqual(render(boxes), 'velem vagy')

    def test_closing_the_gap_does_not_move_the_chord_above(self):
        # The line gets shorter, so the chord has to follow the text rather
        # than the pixels.
        boxes = row(70, 16, ('D', 0, 20), ('A', 130, 150)) \
            + row(100, 20, ('vagy ,', 0, 120), ('mert', 130, 210))
        chords, lyrics = render(boxes).split('\n')
        self.assertEqual(lyrics, 'vagy, mert')
        self.assertEqual(chords.index('A'), lyrics.index('mert'))

    def test_a_chord_row_is_not_touched(self):
        # Only lyric rows are repaired; nothing on a chord row needs it.
        boxes = row(70, 16, ('C7', 0, 20), ('x1', 30, 50), ('G', 60, 70))
        self.assertIn('x1', render(boxes))


class NotationNoiseTests(unittest.TestCase):
    """Stave furniture read as text.

    Photographing a hymnal page puts clefs, time signatures and slurs in front
    of the recogniser, and it dutifully returns things like `4=`. A row holding
    no letter at all is not a lyric and not a chord, so it is dropped rather
    than pasted into the song.
    """

    def test_a_row_with_no_letters_is_dropped(self):
        boxes = row(100, 20, ('Amazing', 0, 70)) \
            + row(140, 20, ('4=', 0, 20)) \
            + row(180, 20, ('grace', 0, 50))
        self.assertEqual(render(boxes).split('\n'), ['Amazing', 'grace'])

    def test_a_chord_row_is_never_mistaken_for_noise(self):
        boxes = row(70, 16, ('C7', 0, 20), ('x1', 30, 50), ('G', 60, 70))
        self.assertIn('C7', render(boxes))

    def test_a_page_of_nothing_but_noise_reads_as_empty(self):
        content, warnings = worker.chordpro_from_boxes(row(100, 20, ('4=', 0, 20)))
        self.assertEqual(content, '')
        self.assertTrue(warnings)


class SaveUploadTests(unittest.TestCase):
    """`--save-dir` keeps what was sent next to what it produced.

    A photo posted from a phone lives only in the request, so when someone
    reports "it read this song badly" there is nothing left to reproduce with.
    Keeping both halves turns a report into a test case.
    """

    def setUp(self):
        self.directory = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.directory, ignore_errors=True)

    def test_the_image_and_its_reading_are_kept_together(self):
        worker.save_upload(self.directory, '7569.jpg', b'\xff\xd8jpeg',
                           '{title: Isten fénye}', [])
        self.assertEqual(
            sorted(p.name for p in self.directory.iterdir()),
            ['001-7569.jpg', '001-7569.txt'])
        self.assertEqual((self.directory / '001-7569.jpg').read_bytes(),
                         b'\xff\xd8jpeg')
        self.assertIn('Isten fénye',
                      (self.directory / '001-7569.txt').read_text('utf-8'))

    def test_the_warnings_are_kept_with_the_reading(self):
        worker.save_upload(self.directory, 'a.jpg', b'x', 'text',
                           ['H was renamed'])
        self.assertIn('H was renamed',
                      (self.directory / '001-a.txt').read_text('utf-8'))

    def test_a_second_upload_does_not_overwrite_the_first(self):
        # The same phone sends the same name twice; 7568 was sent twice.
        worker.save_upload(self.directory, '7568.jpg', b'one', 'first', [])
        worker.save_upload(self.directory, '7568.jpg', b'two', 'second', [])
        self.assertEqual((self.directory / '001-7568.jpg').read_bytes(), b'one')
        self.assertEqual((self.directory / '002-7568.jpg').read_bytes(), b'two')

    def test_a_hostile_filename_cannot_escape_the_directory(self):
        # The name arrives off the wire, so it is not to be trusted as a path.
        worker.save_upload(self.directory, '../../etc/passwd', b'x', 't', [])
        written = list(self.directory.iterdir())
        self.assertEqual(len(written), 2)
        for path in written:
            self.assertEqual(path.parent, self.directory)


class EmptyPageTests(unittest.TestCase):

    def test_no_boxes_produce_no_content(self):
        content, warnings = worker.chordpro_from_boxes([])
        self.assertEqual(content, '')
        self.assertTrue(warnings)


if __name__ == '__main__':
    unittest.main()


class ResolutionNoteTests(unittest.TestCase):
    """Tell the user when the upload itself is the limiting factor.

    Robert's phone handed over 2048x1532 at roughly JPEG quality 35 with the
    EXIF stripped — the gallery's re-encoded copy, not the camera original. At
    that size the two strokes over `ő` are gone, so the page read `erót` for
    `erőt` and no parser change can recover it. Worth saying out loud, because
    the fix is on the phone rather than in here.
    """

    def test_a_small_upload_is_reported_with_its_size(self):
        note = worker.resolution_note(2048, 1532, 80372)
        self.assertIsNotNone(note)
        self.assertIn('2048', note)

    def test_a_full_resolution_upload_says_nothing(self):
        self.assertIsNone(worker.resolution_note(4032, 3024, 3_500_000))

    def test_heavy_compression_is_reported_even_at_a_good_size(self):
        # Plenty of pixels, but squeezed hard enough to erase the accents.
        self.assertIsNotNone(worker.resolution_note(4032, 3024, 90_000))

    def test_a_generous_file_at_a_modest_size_is_accepted(self):
        # A lightly compressed 2048px scan has the detail; do not nag.
        self.assertIsNone(worker.resolution_note(2048, 1532, 1_200_000))
