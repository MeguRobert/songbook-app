"""The adapters that turn a photograph into a Reading.

The trace is not built here. `photo_import_worker.extract_with_easyocr` takes a
list and appends what each stage decided, so there is exactly one recognition
pass and the trace can never describe a pipeline the app does not run. An
earlier draft of this file re-ran the recogniser purely to observe it, and the
two passes disagreed about one word on the first page tried - which is the whole
argument for the seam being in the worker.
"""
from __future__ import annotations

import dataclasses
import pathlib
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import photo_import_worker as worker  # noqa: E402

from . import reading as reading_mod  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
TOOLS = HERE.parent
PHOTOS = TOOLS / "fixtures" / "photos"
VISION = TOOLS / "fixtures" / "vision"


@dataclasses.dataclass
class Result:
    """One engine's answer for one page."""

    engine: str
    reading: reading_mod.Reading
    trace: list[dict]
    seconds: float


class EasyOcr:
    """The Python arm of the reading path: EasyOCR plus the shared bridge."""

    name = "easyocr"

    def read(self, path: pathlib.Path) -> Result:
        trace: list[dict] = []
        started = time.time()
        content, warnings = worker.extract_with_easyocr(path.read_bytes(),
                                                        trace=trace)
        seconds = time.time() - started
        return Result(engine=self.name, seconds=seconds, trace=trace,
                      reading=reading_mod.parse(
                          content, reading_mod.slugs_for(warnings)))


class Vision:
    """A vision model's unreviewed first read, from a file on disk.

    There is no API call here on purpose. The vision arm exists to say how much
    headroom the shipped engine has, and to turn photographs into gold answers -
    both of which happen at a keyboard, once, not at runtime. So its output is
    text in tools/fixtures/vision/ and this adapter only loads it. That also
    keeps the recorded decision intact: the shipped engine stays Tesseract in
    the browser and Audiveris on Cloud Run.

    The number it scores means nothing while the gold file beside it is still
    unreviewed, because then the two are one read compared with itself.
    report.py says so rather than printing a confident 1.000.
    """

    name = "vision"

    def read(self, path: pathlib.Path) -> Result:
        source = VISION / (path.stem + ".chordpro")
        if not source.exists():
            raise FileNotFoundError(
                f"no vision reading for {path.name}: expected {source}")
        content = source.read_text(encoding="utf-8")
        return Result(engine=self.name, seconds=0.0,
                      trace=[{"stage": "file", "path": str(source)}],
                      reading=reading_mod.parse(content, ()))


def _browser():
    """Imported lazily: it costs a Dart compile and a Chromium launch."""
    from .browser import Browser

    return Browser()


ENGINES = {engine.name: engine for engine in (EasyOcr(), Vision())}

# The shipped path. Registered by name so `run --engine browser` reaches it
# without every other command paying for playwright and a dart compile.
LAZY = {"browser": _browser}


def engine(name):
    """The engine called [name], building it on demand."""
    if name in ENGINES:
        return ENGINES[name]
    if name in LAZY:
        ENGINES[name] = LAZY[name]()
        return ENGINES[name]
    raise KeyError(name)


def names():
    return sorted(set(ENGINES) | set(LAZY))
