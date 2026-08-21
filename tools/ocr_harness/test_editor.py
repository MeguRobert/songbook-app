"""The gold editor's server, and the one-source-of-truth rule.

The editor's preview classifies rows in the browser so it can colour them as you
type. It used to do that with a hand-copied JavaScript translation of the
worker's regexes, and that copy went on applying a rule deleted from both
parsers for two more rounds of this. The patterns are now shipped from the
server; these tests are what keep the shipping honest.
"""
import json
import pathlib
import re
import threading
import unittest
import urllib.error
import urllib.request

from . import editor, gold

PAGE = pathlib.Path(editor.PAGE)


class RulesAreShippedNotCopied(unittest.TestCase):

    def test_every_pattern_the_preview_needs_is_shipped(self):
        self.assertEqual({"chord_token", "separator", "continuation",
                          "parenthesised"}, set(editor.rules()))

    def test_the_patterns_are_the_workers_own(self):
        # Not equal-looking strings: the same objects' patterns. A second copy
        # is the whole failure mode this replaces.
        worker = editor.worker
        shipped = editor.rules()
        self.assertEqual(worker._CHORD_TOKEN.pattern, shipped["chord_token"])
        self.assertEqual(worker._SEPARATOR.pattern, shipped["separator"])
        self.assertEqual(worker._CONTINUATION.pattern, shipped["continuation"])
        self.assertEqual(worker._PARENTHESISED.pattern,
                         shipped["parenthesised"])

    def test_the_patterns_use_only_syntax_javascript_shares(self):
        # `new RegExp(pattern)` has to mean the same thing. Lookbehind, named
        # groups, inline flags and possessive quantifiers do not survive the
        # trip, so a pattern that grows one has to stop being shipped raw.
        unportable = (r"(?<", r"(?P", r"(?i", r"(?m", r"(?s", r"(?x", r"\Z",
                      r"\A", "*+", "++")
        for name, pattern in editor.rules().items():
            for token in unportable:
                with self.subTest(rule=name, token=token):
                    self.assertNotIn(token, pattern)

    def test_every_shipped_pattern_compiles(self):
        for name, pattern in editor.rules().items():
            with self.subTest(rule=name):
                re.compile(pattern)

    def test_the_page_holds_no_hand_written_copy_of_them(self):
        # A literal `/^[A-GH...` in the page means someone re-introduced the
        # copy. The preview must build its rules from what the server sent.
        html = PAGE.read_text(encoding="utf-8")
        self.assertIn("buildRules(data.rules)", html)
        self.assertNotIn("A-GHa-gh", html)

    def test_the_page_no_longer_knows_about_a_bare_root_state(self):
        html = PAGE.read_text(encoding="utf-8")
        self.assertNotIn("bare", html)


class Serving(unittest.TestCase):
    """The endpoints, over a real socket on the loopback address."""

    @classmethod
    def setUpClass(cls):
        cls.server = editor.Server(("127.0.0.1", 0), editor.Handler)
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever,
                                      daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def get(self, path):
        url = f"http://127.0.0.1:{self.port}{path}"
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                return response.status, response.read()
        except urllib.error.HTTPError as error:
            return error.code, error.read()

    def test_the_editor_page_is_served(self):
        status, body = self.get("/")
        self.assertEqual(200, status)
        self.assertIn(b"Gold editor", body)

    def test_the_page_list_carries_pages_slugs_and_rules(self):
        status, body = self.get("/api/pages")
        self.assertEqual(200, status)
        data = json.loads(body)
        self.assertEqual({"slugs", "rules", "pages"}, set(data))
        self.assertTrue(data["pages"])

    def test_a_page_carries_its_lines_and_its_provenance(self):
        data = json.loads(self.get("/api/pages")[1])
        page = data["pages"][0]
        for field in ("stem", "file", "tier", "lines", "chordpro",
                      "drafted_from", "reviewed_by", "warnings"):
            self.assertIn(field, page)

    def test_a_photograph_the_manifest_lists_is_served(self):
        listed = gold.pages()[0].file
        status, body = self.get("/photos/" + listed)
        self.assertEqual(200, status)
        self.assertTrue(body)

    def test_a_path_the_manifest_does_not_list_is_refused(self):
        # The name is checked against the manifest rather than sanitised, so
        # nothing outside the corpus is reachable however it is spelled.
        for path in ("/photos/../../photo_import_worker.py",
                     "/photos/passwd", "/photos/"):
            with self.subTest(path=path):
                self.assertEqual(404, self.get(path)[0])

    def test_an_unknown_route_is_refused(self):
        self.assertEqual(404, self.get("/nope")[0])


class Saving(unittest.TestCase):
    """Writes go to disk, so every one of these restores what it touched."""

    def setUp(self):
        self.path = gold.gold_path(gold.pages(with_gold=True)[0].stem)
        self.before = self.path.read_text(encoding="utf-8")
        self.addCleanup(self.path.write_text, self.before, encoding="utf-8")

    def stem(self):
        return self.path.name[: -len(".gold.json")]

    def test_an_untouched_save_leaves_the_file_byte_identical(self):
        data = json.loads(self.before)
        stored = editor._save(self.stem(), {
            "number": data.get("number"), "title": data.get("title"),
            "warnings": data.get("warnings", []),
            "lines": editor.structure.to_lines(data["chordpro"]),
            "reviewed_by": data.get("reviewed_by"),
        })
        self.assertEqual(data["chordpro"], stored["chordpro"])
        self.assertEqual(self.before, self.path.read_text(encoding="utf-8"))

    def test_a_reviewer_name_is_trimmed_and_stored(self):
        editor._save(self.stem(), {"lines": [], "reviewed_by": "  Robert  "})
        self.assertEqual(
            "Robert",
            json.loads(self.path.read_text(encoding="utf-8"))["reviewed_by"])

    def test_a_blank_reviewer_name_clears_the_field(self):
        editor._save(self.stem(), {"lines": [], "reviewed_by": "   "})
        self.assertIsNone(
            json.loads(self.path.read_text(encoding="utf-8"))["reviewed_by"])

    def test_an_unknown_warning_slug_is_dropped(self):
        editor._save(self.stem(), {"lines": [], "warnings": ["made-up",
                                                             "german-chords"]})
        self.assertEqual(
            ["german-chords"],
            json.loads(self.path.read_text(encoding="utf-8"))["warnings"])

    def test_a_number_arrives_as_text_and_is_stored_as_a_number(self):
        editor._save(self.stem(), {"lines": [], "number": "185"})
        self.assertEqual(
            185, json.loads(self.path.read_text(encoding="utf-8"))["number"])

    def test_a_number_that_is_not_a_number_is_cleared(self):
        editor._save(self.stem(), {"lines": [], "number": "abc"})
        self.assertIsNone(
            json.loads(self.path.read_text(encoding="utf-8"))["number"])

    def test_the_raw_tab_wins_over_the_structured_lines(self):
        stored = editor._save(self.stem(), {
            "lines": [{"kind": "lyric", "text": "ignored", "chords": [],
                       "after": []}],
            "raw": "G7    Am\r\nAmazing grace\n\n",
        })
        # CRLF normalised, trailing blank lines trimmed, columns kept verbatim.
        self.assertEqual("G7    Am\nAmazing grace", stored["chordpro"])

    def test_provenance_is_never_rewritten_by_a_save(self):
        # Saving must not be able to launder a draft into evidence. Only a
        # reviewer's name can do that, and it does it through its own field.
        was = json.loads(self.before).get("drafted_from")
        editor._save(self.stem(), {"lines": [], "drafted_from": "vision"})
        self.assertEqual(
            was, json.loads(self.path.read_text(encoding="utf-8"))["drafted_from"])

    def test_a_name_that_is_not_a_page_is_refused(self):
        for bad in ("../evil", "a/b", "with space", ""):
            with self.subTest(name=bad):
                with self.assertRaises((ValueError, FileNotFoundError)):
                    editor._save(bad, {"lines": []})

    def test_a_page_with_no_gold_file_is_refused(self):
        with self.assertRaises(FileNotFoundError):
            editor._save("not-a-page", {"lines": []})


if __name__ == "__main__":
    unittest.main()
