"""The app's own reading path, measured in a real browser.

Why this exists: `photo_import_worker.py` is EasyOCR on a developer's machine,
and what ships is Tesseract.js plus `PhotoTextBridge` on a phone. Two separate
implementations of the same idea, and until now only the one that does not ship
was being scored - every number in the baseline described the wrong engine.

Nothing here reimplements the app. `songbook_app/tool/browser_reader_harness.dart`
imports `BrowserPhotoImportService` and `createPageTextRecognizer` and calls
them; this module compiles that to JavaScript, serves it beside the photographs,
and drives it with `browser_driver.cjs`. A fix in the app changes these numbers
without being ported.

Two things it needs that `flutter test` does not: a browser, and the network. The
engine and the Hungarian model come from unpkg on first use, exactly as they do
on a phone.
"""
from __future__ import annotations

import functools
import http.server
import json
import os
import pathlib
import re
import shutil
import socketserver
import subprocess
import threading

from . import gold, reading as reading_mod

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
APP = REPO / "songbook_app"
ENTRY = APP / "tool" / "browser_reader_harness.dart"
DRIVER = HERE / "browser_driver.cjs"
BUILD = REPO / "tools" / "fixtures" / "browser"

# playwright is installed globally on this machine, which is where every other
# browser check in this repo finds it too.
NODE_PATH = os.environ.get(
    "NODE_PATH", r"C:/Users/rober/AppData/Roaming/npm/node_modules")


def _tool(name: str) -> str:
    """[name] as something `subprocess` can start.

    On Windows `dart` is `dart.bat` and `node` is `node.exe`, and subprocess
    without a shell does not apply PATHEXT - so a bare name raises
    FileNotFoundError even though the tool is plainly on the path.
    """
    found = shutil.which(name)
    if not found:
        raise RuntimeError(
            f"{name} is not on PATH. The browser engine needs dart (to compile "
            f"the app's own reading path) and node with playwright (to drive "
            f"it).")
    return found

# The app's own Content-Security-Policy, read out of its own index.html rather
# than approximated here.
#
# A hand-written copy was the first thing this harness got wrong: it omitted
# `cdn.jsdelivr.net`, which is where Tesseract.js fetches its *worker* from, and
# the run failed with a NetworkError that looked exactly like a shipped bug. The
# app's real policy allows it. Testing under a policy the app does not have
# proves nothing in either direction, so the policy comes from one place.
INDEX_HTML = APP / "web" / "index.html"
_CSP = re.compile(
    r'<meta\s+http-equiv="Content-Security-Policy"\s+content="([^"]*)"',
    re.IGNORECASE)


def app_csp() -> str:
    """The policy the app ships with."""
    match = _CSP.search(INDEX_HTML.read_text(encoding="utf-8"))
    if not match:
        raise RuntimeError(
            f"no Content-Security-Policy found in {INDEX_HTML}. The harness "
            f"must run under the app's own policy; refusing to invent one.")
    return match.group(1).strip()


def index_page() -> str:
    return f"""<!doctype html>
<html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="{app_csp()}">
<title>browser reader harness</title></head>
<body><script src="harness.js"></script></body></html>
"""


def newest_source() -> float:
    """When the app's reading path was last touched.

    Every Dart file under `lib`, not just the entry point. Watching the entry
    point alone was a silent lie: the whole claim of this harness is that a fix
    in `photo_text_bridge.dart` moves these numbers without being ported, and
    while the staleness check looked at one file that never changes, a run after
    such a fix quietly re-measured the previous build and reported the old score
    to the digit.
    """
    newest = ENTRY.stat().st_mtime
    for path in (APP / "lib").rglob("*.dart"):
        newest = max(newest, path.stat().st_mtime)
    return newest


def compile_harness(force: bool = False) -> pathlib.Path:
    """Compile the entry point and stage the photographs. Returns the build dir."""
    BUILD.mkdir(parents=True, exist_ok=True)
    out = BUILD / "harness.js"
    stale = (force or not out.exists()
             or out.stat().st_mtime <= newest_source())
    if stale:
        subprocess.run(
            [_tool("dart"), "compile", "js",
             "--packages=.dart_tool/package_config.json", "-O1",
             "-o", str(out), str(ENTRY.relative_to(APP))],
            cwd=APP, check=True, capture_output=True, text=True,
            encoding="utf-8", errors="replace")
    (BUILD / "index.html").write_text(index_page(), encoding="utf-8")
    # Served from here rather than from the corpus directory, so the page fetches
    # them same-origin and the policy above stays honest.
    photos = BUILD / "photos"
    photos.mkdir(exist_ok=True)
    for page in gold.pages():
        target = photos / page.file
        if (not target.exists()
                or target.stat().st_mtime < page.path.stat().st_mtime):
            shutil.copy2(page.path, target)
    return BUILD


class _Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):  # noqa: A003
        pass


class _Server(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = True


class Browser:
    """The shipped reading path. Slower than the Python arm, and the only engine
    whose score describes what a phone actually does.

    Batched on purpose: starting Chromium and downloading the Tesseract model
    costs more than reading a page, so every page goes through one browser.
    """

    name = "browser"

    def __init__(self, *, headed: bool = False, rebuild: bool = False):
        self.headed = headed
        self.rebuild = rebuild
        self._answers: dict[str, dict] = {}

    def prepare(self, pages) -> None:
        """Read every page in [pages] in one browser session."""
        names = [p.file for p in pages]
        if not names:
            return
        directory = compile_harness(force=self.rebuild)
        handler = functools.partial(_Quiet, directory=str(directory))
        httpd = _Server(("127.0.0.1", 0), handler)
        port = httpd.server_address[1]
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        try:
            command = [_tool("node"), str(DRIVER),
                       "--base", f"http://127.0.0.1:{port}/",
                       "--pages", ",".join(names)]
            if self.headed:
                command.append("--headed")
            env = dict(os.environ, NODE_PATH=NODE_PATH)
            # utf-8 explicitly: the driver prints Hungarian lyrics, and the
            # Windows default of cp1252 fails on the first `ő`, taking stdout
            # with it and leaving a NoneType to explain.
            result = subprocess.run(command, capture_output=True, text=True,
                                    encoding="utf-8", errors="replace",
                                    env=env, cwd=str(REPO))
            if result.returncode != 0:
                raise RuntimeError(
                    "browser driver failed:\n" + (result.stderr or "")[-2000:])
            for line in result.stdout.splitlines():
                line = line.strip()
                if line.startswith("{"):
                    answer = json.loads(line)
                    self._answers[answer["page"]] = answer
        finally:
            httpd.shutdown()
            httpd.server_close()

    def read(self, path: pathlib.Path):
        from .engines import Result

        answer = self._answers.get(path.name)
        if answer is None:
            raise RuntimeError(
                f"{path.name} was not read; call prepare() with it first")
        # The app's own stages first, then what driving it looked like. The
        # reader reports what it measured - the pale fraction behind the
        # show-through verdict, the bytes per pixel behind the compression one,
        # where it cut the page into columns - the way `extract_with_easyocr`
        # always has for the arm that does not ship.
        trace = list(answer.get("trace") or [])
        trace.append({"stage": "browser", "words": answer.get("words"),
                      "page_ms": answer.get("ms"),
                      "csp_violations": answer.get("csp") or [],
                      "console_errors": answer.get("consoleErrors") or []})
        if answer.get("error"):
            raise RuntimeError(f"{path.name}: {answer['error']}")
        if answer.get("refused"):
            # The app would have shown this sentence and imported nothing. That
            # is a measurable outcome, so it scores as an empty reading rather
            # than crashing the run.
            trace.append({"stage": "refused", "message": answer["refused"]})
            return Result(engine=self.name, seconds=answer.get("seconds", 0.0),
                          trace=trace, reading=reading_mod.parse("", ()),
                          boxes=answer.get("boxes") or [])
        return Result(
            engine=self.name, seconds=answer.get("seconds", 0.0), trace=trace,
            boxes=answer.get("boxes") or [],
            reading=reading_mod.parse(
                answer["chordPro"],
                reading_mod.slugs_for(answer.get("warnings", []))))
