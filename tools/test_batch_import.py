#!/usr/bin/env python3
"""
Unit tests for batch_import (stdlib unittest, no third-party deps, no subprocess).

Run:
    python tools/test_batch_import.py
    python -m unittest tools.test_batch_import
"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import batch_import as bi  # noqa: E402


def write_temp(suffix, content):
    f = tempfile.NamedTemporaryFile("w", suffix=suffix, delete=False, encoding="utf-8")
    f.write(content)
    f.close()
    return f.name


class LoadManifestTests(unittest.TestCase):
    def test_json_manifest(self):
        path = write_temp(".json", json.dumps([
            {"image": "a.jpg", "song": "42", "book": "Zsoltárok",
             "systems": "6", "ocr_lyrics": "true"},
        ]))
        try:
            rows = bi.load_manifest(path)
        finally:
            os.unlink(path)
        self.assertEqual(len(rows), 1)
        r = rows[0]
        self.assertEqual(r["song"], 42)
        self.assertEqual(r["systems"], 6)
        self.assertIs(r["ocr_lyrics"], True)
        self.assertEqual(r["book"], "Zsoltárok")

    def test_csv_manifest(self):
        path = write_temp(".csv",
                          "song,image,book,systems\n42,a.jpg,Zsoltárok,6\n151,b.png,Dicséretek,8\n")
        try:
            rows = bi.load_manifest(path)
        finally:
            os.unlink(path)
        self.assertEqual([r["song"] for r in rows], [42, 151])
        self.assertEqual(rows[1]["systems"], 8)

    def test_missing_song_raises(self):
        path = write_temp(".json", json.dumps([{"image": "a.jpg"}]))
        try:
            with self.assertRaises(ValueError):
                bi.load_manifest(path)
        finally:
            os.unlink(path)

    def test_neither_image_nor_xml_raises(self):
        path = write_temp(".json", json.dumps([{"song": 1}]))
        try:
            with self.assertRaises(ValueError):
                bi.load_manifest(path)
        finally:
            os.unlink(path)

    def test_missing_file_raises(self):
        with self.assertRaises(FileNotFoundError):
            bi.load_manifest("nope/missing.json")


class BuildCommandTests(unittest.TestCase):
    def test_image_row(self):
        row = bi._normalize_row({"image": "a.jpg", "song": 42, "book": "Zsoltárok",
                                 "systems": 6})
        cmd = bi.build_command(row, python="py", script="convert_hymn.py")
        self.assertIn("a.jpg", cmd)
        self.assertIn("--song", cmd)
        self.assertEqual(cmd[cmd.index("--song") + 1], "42")
        self.assertIn("--book", cmd)
        self.assertIn("--num-systems", cmd)
        self.assertNotIn("--from-xml", cmd)

    def test_from_xml_row(self):
        row = bi._normalize_row({"from_xml": "song.mxl", "song": 90})
        cmd = bi.build_command(row, python="py", script="convert_hymn.py")
        self.assertIn("--from-xml", cmd)
        self.assertIn("song.mxl", cmd)

    def test_ocr_and_no_validate_flags(self):
        row = bi._normalize_row({"image": "a.jpg", "song": 1, "ocr_lyrics": True,
                                 "no_validate": True})
        cmd = bi.build_command(row)
        self.assertIn("--ocr-lyrics", cmd)
        self.assertIn("--no-validate", cmd)

    def test_no_optional_flags_when_absent(self):
        row = bi._normalize_row({"image": "a.jpg", "song": 1})
        cmd = bi.build_command(row)
        self.assertNotIn("--ocr-lyrics", cmd)
        self.assertNotIn("--no-validate", cmd)
        self.assertNotIn("--book", cmd)
        self.assertNotIn("--num-systems", cmd)


class RunBatchTests(unittest.TestCase):
    def _rows(self):
        return [bi._normalize_row({"image": "a.jpg", "song": 1}),
                bi._normalize_row({"image": "b.jpg", "song": 2})]

    def test_dry_run_never_calls_runner(self):
        def boom(cmd):
            raise AssertionError("runner should not be called in dry-run")
        results = bi.run_batch(self._rows(), dry_run=True, runner=boom)
        self.assertEqual(len(results), 2)
        self.assertTrue(all(r["returncode"] == "dry-run" and r["ok"] for r in results))

    def test_all_ok_with_fake_runner(self):
        class Done:
            returncode = 0
        results = bi.run_batch(self._rows(), runner=lambda cmd: Done())
        self.assertTrue(all(r["ok"] for r in results))

    def test_stops_on_error_when_not_continue(self):
        calls = {"n": 0}

        def runner(cmd):
            calls["n"] += 1

            class R:
                returncode = 1
            return R()

        results = bi.run_batch(self._rows(), continue_on_error=False, runner=runner)
        self.assertEqual(len(results), 1)  # stopped after first failure
        self.assertEqual(calls["n"], 1)

    def test_continues_on_error_when_flagged(self):
        def runner(cmd):
            class R:
                returncode = 1
            return R()

        results = bi.run_batch(self._rows(), continue_on_error=True, runner=runner)
        self.assertEqual(len(results), 2)
        self.assertTrue(all(not r["ok"] for r in results))


if __name__ == "__main__":
    unittest.main()
