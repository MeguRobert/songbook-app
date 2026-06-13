#!/usr/bin/env python3
"""
Unit tests for song_validator (stdlib unittest, no third-party deps).

Run:
    python tools/test_song_validator.py
    python -m unittest tools.test_song_validator
"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import song_validator as sv  # noqa: E402


def valid_song(**overrides):
    """A minimal fully-valid song; override fields per test."""
    song = {
        "number": 42,
        "title": "Test Song",
        "originalKey": "G",
        "book": "Zsoltárok",
        "verses": [
            {
                "number": 1,
                "hasNotation": True,
                "lines": [
                    {"text": "Hello world", "chords": [{"chord": "G", "position": 0}]},
                ],
            },
            {"number": 2, "plainText": "Second verse text"},
        ],
    }
    song.update(overrides)
    return song


def errors(issues):
    return [i for i in issues if i.severity == sv.ERROR]


def warnings(issues):
    return [i for i in issues if i.severity == sv.WARNING]


def fields(issues):
    return [i.field for i in issues]


class ValidSongTests(unittest.TestCase):
    def test_valid_song_has_no_errors(self):
        self.assertFalse(sv.has_errors(sv.validate_song(valid_song())))

    def test_minor_and_accidental_keys_accepted(self):
        for key in ("Am", "Bb", "F#", "C", "Eb"):
            issues = sv.validate_song(valid_song(originalKey=key))
            self.assertFalse(sv.has_errors(issues), f"{key} should be valid")


class NumberTests(unittest.TestCase):
    def test_missing_number(self):
        s = valid_song()
        del s["number"]
        self.assertTrue(sv.has_errors(sv.validate_song(s)))

    def test_non_int_number(self):
        self.assertTrue(sv.has_errors(sv.validate_song(valid_song(number="42"))))

    def test_bool_is_not_int_number(self):
        self.assertTrue(sv.has_errors(sv.validate_song(valid_song(number=True))))

    def test_non_positive_number(self):
        self.assertTrue(sv.has_errors(sv.validate_song(valid_song(number=0))))
        self.assertTrue(sv.has_errors(sv.validate_song(valid_song(number=-3))))


class TitleTests(unittest.TestCase):
    def test_missing_title(self):
        s = valid_song()
        del s["title"]
        self.assertTrue(sv.has_errors(sv.validate_song(s)))

    def test_empty_title(self):
        self.assertTrue(sv.has_errors(sv.validate_song(valid_song(title="   "))))


class KeyTests(unittest.TestCase):
    def test_missing_key_is_error(self):
        s = valid_song()
        del s["originalKey"]
        self.assertTrue(sv.has_errors(sv.validate_song(s)))

    def test_unrecognized_key_is_warning_not_error(self):
        issues = sv.validate_song(valid_song(originalKey="H"))
        self.assertFalse(sv.has_errors(issues))
        self.assertTrue(any(i.field == "originalKey" for i in warnings(issues)))


class VerseTests(unittest.TestCase):
    def test_empty_verses_is_error(self):
        self.assertTrue(sv.has_errors(sv.validate_song(valid_song(verses=[]))))

    def test_verses_not_a_list(self):
        self.assertTrue(sv.has_errors(sv.validate_song(valid_song(verses={}))))

    def test_line_text_not_string(self):
        s = valid_song(verses=[
            {"number": 1, "hasNotation": True, "lines": [{"text": 5, "chords": []}]}
        ])
        self.assertTrue(sv.has_errors(sv.validate_song(s)))

    def test_hasnotation_without_lines_warns(self):
        s = valid_song(verses=[{"number": 1, "hasNotation": True, "lines": []}])
        issues = sv.validate_song(s)
        self.assertFalse(sv.has_errors(issues))
        self.assertTrue(warnings(issues))


class ChordTests(unittest.TestCase):
    def _song_with_chord(self, chord):
        return valid_song(verses=[
            {"number": 1, "hasNotation": True,
             "lines": [{"text": "abcde", "chords": [chord]}]}
        ])

    def test_empty_chord_symbol_is_error(self):
        self.assertTrue(sv.has_errors(
            sv.validate_song(self._song_with_chord({"chord": "", "position": 0}))))

    def test_negative_position_is_error(self):
        self.assertTrue(sv.has_errors(
            sv.validate_song(self._song_with_chord({"chord": "G", "position": -1}))))

    def test_non_int_position_is_error(self):
        self.assertTrue(sv.has_errors(
            sv.validate_song(self._song_with_chord({"chord": "G", "position": "0"}))))

    def test_position_past_end_is_warning(self):
        issues = sv.validate_song(self._song_with_chord({"chord": "G", "position": 99}))
        self.assertFalse(sv.has_errors(issues))
        self.assertTrue(warnings(issues))


class DuplicateTests(unittest.TestCase):
    def test_duplicate_numbers_reported_once(self):
        issues = sv.validate_songs([valid_song(number=1), valid_song(number=1),
                                    valid_song(number=2)])
        dup = [i for i in errors(issues)
               if "duplicate song number 1" in i.message]
        self.assertEqual(len(dup), 1)

    def test_no_duplicates_no_dup_error(self):
        issues = sv.validate_songs([valid_song(number=1), valid_song(number=2)])
        self.assertFalse(any("duplicate" in i.message for i in issues))


class LoadAndValidateTests(unittest.TestCase):
    def test_missing_file(self):
        issues = sv.load_and_validate("does/not/exist.json")
        self.assertTrue(sv.has_errors(issues))

    def test_malformed_json(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False,
                                         encoding="utf-8") as f:
            f.write("{ not valid json ")
            path = f.name
        try:
            issues = sv.load_and_validate(path)
            self.assertTrue(sv.has_errors(issues))
        finally:
            os.unlink(path)

    def test_valid_file_round_trip(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False,
                                         encoding="utf-8") as f:
            json.dump([valid_song(number=1), valid_song(number=2)], f, ensure_ascii=False)
            path = f.name
        try:
            self.assertFalse(sv.has_errors(sv.load_and_validate(path)))
        finally:
            os.unlink(path)


class HasErrorsTests(unittest.TestCase):
    def test_true_false(self):
        self.assertFalse(sv.has_errors([sv.ValidationIssue(sv.WARNING, 1, "x", "m")]))
        self.assertTrue(sv.has_errors([sv.ValidationIssue(sv.ERROR, 1, "x", "m")]))


if __name__ == "__main__":
    unittest.main()
