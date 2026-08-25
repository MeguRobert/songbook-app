"""A local editor for the gold answers.

Why a server and not a file: a page opened with `file://` cannot write to disk,
and the whole point is to stop anyone hand-editing JSON. This is the smallest
thing that can save - `http.server`, no dependencies, bound to the loopback
address only.

Why it is not published anywhere: the photographs are of a copyrighted hymnal.
Same reason they are not in git.

The editor works in `(which word, which chord)`. Character columns are generated
on save by `structure.to_chordpro`, so nobody counts spaces and editing a lyric
cannot slide a chord onto the wrong word.
"""
from __future__ import annotations

import functools
import http.server
import json
import pathlib
import re
import socketserver
import threading
import webbrowser

import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import photo_import_worker as worker  # noqa: E402

from . import gold, reading as reading_mod, structure  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
PAGE = HERE / "editor.html"

# Every warning slug the worker can emit, offered as checkboxes so nobody has
# to remember the spellings.
SLUGS = tuple(slug for _, slug in reading_mod.WARNING_SLUGS)

_SAFE_STEM = re.compile(r"^[A-Za-z0-9._-]+$")


def rules() -> dict:
    """The row-classification patterns, for the browser to build from.

    The preview colours each row live as you type, so it has to classify rows
    client-side. It used to hold its own hand-copied JavaScript translation of
    these, which is how a rule removed from both parsers went on being applied
    in the preview for another two rounds. Shipping the patterns themselves
    leaves one source of truth.

    Python and JavaScript agree on this subset of regex syntax - no lookbehind,
    no named groups, no inline flags. test_editor pins that.
    """
    return {
        "chord_token": worker._CHORD_TOKEN.pattern,
        "separator": worker._SEPARATOR.pattern,
        "continuation": worker._CONTINUATION.pattern,
        "parenthesised": worker._PARENTHESISED.pattern,
    }


def _page_json(page: gold.Page) -> dict:
    return {
        "stem": page.stem,
        "file": page.file,
        "tier": page.tier,
        "engine": page.engine,
        "layout": page.layout,
        "stresses": list(page.stresses),
        "number": page.gold.number if page.gold else page.book_number,
        "title": page.gold.title if page.gold else page.title,
        "warnings": list(page.gold.warnings) if page.gold else [],
        "reviewed_by": page.reviewed_by,
        "drafted_from": page.drafted_from,
        "lines": structure.to_lines(page.gold.chordpro) if page.gold else [],
        "chordpro": page.gold.chordpro if page.gold else "",
    }


def _save(stem: str, body: dict) -> dict:
    """Write [body] into the gold file for [stem]. Returns what was stored."""
    if not _SAFE_STEM.match(stem):
        raise ValueError("bad page name")
    path = gold.gold_path(stem)
    if not path.exists():
        raise FileNotFoundError(stem)
    existing = json.loads(path.read_text(encoding="utf-8"))

    if body.get("raw") is not None:
        # The escape hatch. Syllable-level chords under an engraved staff cannot
        # be said in words-and-chords, so the raw tab has to be able to say
        # anything the file could hold.
        chordpro = str(body["raw"]).replace("\r\n", "\n").rstrip("\n")
    else:
        chordpro = structure.to_chordpro(body.get("lines", []))

    reviewer = (body.get("reviewed_by") or "").strip() or None
    number = body.get("number")
    if isinstance(number, str):
        number = int(number) if number.strip().isdigit() else None

    updated = dict(existing)
    updated["reviewed_by"] = reviewer
    # Once a human has signed it off, where the draft came from stops mattering:
    # `evidence_for` already prefers the review. Kept for the record.
    updated["drafted_from"] = existing.get("drafted_from")
    updated["number"] = number
    updated["title"] = (body.get("title") or "").strip() or None
    updated["warnings"] = [s for s in body.get("warnings", []) if s in SLUGS]
    updated["chordpro"] = chordpro
    path.write_text(json.dumps(updated, indent=2, ensure_ascii=False) + "\n",
                    encoding="utf-8")
    return updated


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "SongbookGoldEditor/1"

    def log_message(self, fmt, *args):  # noqa: A003 - quiet by default
        pass

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        # Nothing here should be cached: the point is to see the file you just
        # saved.
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code: int, payload) -> None:
        self._send(code, json.dumps(payload, ensure_ascii=False).encode("utf-8"),
                   "application/json; charset=utf-8")

    def do_GET(self):  # noqa: N802
        if self.path in ("/", "/index.html"):
            self._send(200, PAGE.read_bytes(), "text/html; charset=utf-8")
            return
        if self.path == "/api/pages":
            self._json(200, {
                "slugs": list(SLUGS),
                "rules": rules(),
                "pages": [_page_json(p) for p in gold.pages(with_gold=True)],
            })
            return
        if self.path.startswith("/photos/"):
            name = self.path[len("/photos/"):].split("?")[0]
            # Only names the manifest lists, so the path cannot be steered
            # anywhere else on the disk.
            known = {p.file for p in gold.pages()}
            if name not in known:
                self._json(404, {"error": "unknown page"})
                return
            # Listed but absent is a NORMAL state, not an exceptional one: the
            # manifest is committed and the photographs are not, so every
            # machine except the one that took them has the list without the
            # images. Reading straight through raised FileNotFoundError inside
            # the handler, which drops the connection with no response at all —
            # the client then reports a disconnect, which says nothing about
            # what is wrong. Say what is missing instead.
            photo = gold.PHOTOS / name
            if not photo.is_file():
                self._json(404, {
                    "error": "photograph not on this machine",
                    "file": name,
                })
                return
            self._send(200, photo.read_bytes(), "image/jpeg")
            return
        self._json(404, {"error": "not found"})

    def do_POST(self):  # noqa: N802
        if not self.path.startswith("/api/gold/"):
            self._json(404, {"error": "not found"})
            return
        stem = self.path[len("/api/gold/"):].split("?")[0]
        length = int(self.headers.get("Content-Length") or 0)
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
            stored = _save(stem, body)
        except (ValueError, FileNotFoundError, KeyError, TypeError) as error:
            self._json(400, {"error": f"{type(error).__name__}: {error}"})
            return
        # The stored file re-parsed, so the browser shows what is on disk rather
        # than what it hoped it had sent.
        page = next((p for p in gold.pages(with_gold=True) if p.stem == stem),
                    None)
        self._json(200, {
            "saved": True,
            "chordpro": stored["chordpro"],
            "page": _page_json(page) if page else None,
        })


class Server(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = True


def serve(port: int = 8799, open_browser: bool = True) -> None:
    """Run the editor until interrupted."""
    address = ("127.0.0.1", port)
    with Server(address, Handler) as httpd:
        url = f"http://127.0.0.1:{port}/"
        print(f"gold editor on {url}")
        print("  edits are written straight into tools/fixtures/gold/")
        print("  ctrl-c to stop")
        if open_browser:
            threading.Timer(0.4, functools.partial(webbrowser.open, url)).start()
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")
