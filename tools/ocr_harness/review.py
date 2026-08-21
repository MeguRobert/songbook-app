"""A page for checking a gold answer against its photograph.

The one job nobody can automate: reading a transcription beside the page it came
from. Everything here exists to make that a scroll rather than a hunt - the
photograph and the answer side by side, a column ruler over the ChordPro, and
each line marked with how the parser will actually classify it.

Written to a local file and opened in a browser. Not published anywhere: these
are photographs of a copyrighted hymnal, which is the same reason they are not
in git.
"""
from __future__ import annotations

import html
import pathlib

from . import gold, reading as reading_mod

OUT = gold.TOOLS / "fixtures" / "review.html"

# How many characters of ruler to draw. Long enough for the widest line in the
# corpus - 166-tekozlo-fiu runs past 90 once both columns are on one line.
RULER = 110

CSS = """
:root { --bg:#faf9f7; --ink:#1a1a1a; --dim:#6b6b6b; --rule:#d9d5cf;
        --chord:#0b6bcb; --chordbg:#eaf3fd; --lyric:#1a1a1a;
        --warn:#b3541e; --warnbg:#fdf1e7; --ok:#2f7d32; --okbg:#eaf5ea; }
* { box-sizing:border-box; }
body { margin:0; font:15px/1.55 -apple-system,Segoe UI,Roboto,sans-serif;
       background:var(--bg); color:var(--ink); }
header { position:sticky; top:0; z-index:5; background:var(--bg);
         border-bottom:2px solid var(--rule); padding:14px 20px; }
header h1 { margin:0 0 4px; font-size:19px; }
header p { margin:0; color:var(--dim); font-size:13px; max-width:80ch; }
nav { padding:10px 20px 16px; border-bottom:1px solid var(--rule); }
nav a { display:inline-block; margin:0 10px 6px 0; font-size:12px;
        font-family:ui-monospace,SFMono-Regular,Menlo,monospace;
        text-decoration:none; color:var(--chord); }
section { border-bottom:1px solid var(--rule); padding:22px 20px 30px; }
h2 { margin:0 0 2px; font-size:17px; }
.meta { color:var(--dim); font-size:13px; margin:0 0 14px; }
.badge { display:inline-block; padding:1px 7px; border-radius:3px;
         font-size:11px; font-weight:600; letter-spacing:.02em;
         text-transform:uppercase; margin-right:6px; }
.todo { background:var(--warnbg); color:var(--warn); }
.check { background:var(--okbg); color:var(--ok); }
.grid { display:grid; grid-template-columns:minmax(340px,44%) 1fr; gap:22px;
        align-items:start; }
@media (max-width:1000px) { .grid { grid-template-columns:1fr; } }
.shot { position:sticky; top:74px; }
.shot img { width:100%; border:1px solid var(--rule); background:#fff;
            display:block; }
.shot a { font-size:12px; color:var(--chord); }
.pane { min-width:0; }
pre { margin:0 0 14px; padding:12px 14px; background:#fff; overflow-x:auto;
      border:1px solid var(--rule); font-family:ui-monospace,SFMono-Regular,
      Menlo,monospace; font-size:13px; line-height:1.5; white-space:pre;
      tab-size:1; }
.ruler { color:var(--dim); }
.row { display:block; }
.row.c { background:var(--chordbg); color:var(--chord); }
.row.bare { background:var(--warnbg); color:var(--warn); }
.tag { color:var(--dim); font-size:11px; }
ul { margin:6px 0 14px; padding-left:20px; }
li { font-size:13px; margin-bottom:3px; }
h3 { font-size:13px; text-transform:uppercase; letter-spacing:.04em;
     color:var(--dim); margin:16px 0 4px; }
code { font-family:ui-monospace,Menlo,monospace; font-size:12px;
       background:#fff; border:1px solid var(--rule); padding:0 3px; }
.path { font-family:ui-monospace,Menlo,monospace; font-size:12px;
        color:var(--dim); word-break:break-all; }
"""


def _ruler() -> str:
    """A two-line character ruler: the column number above, units below.

    Zero-based, because a chord's `column` is an index into the line - column 6
    is the seventh character, and a ruler that started at 1 would be off by one
    against every gold file.

    The top row writes the whole number at each tens boundary rather than just
    its tens digit. With the digit alone, column 100 printed `0` and was
    indistinguishable from column 0, which is a real risk on
    `166-tekozlo-fiu`: both its columns land on one line and it runs past 90.
    """
    top = [" "] * RULER
    for start in range(0, RULER, 10):
        for offset, digit in enumerate(str(start)):
            if start + offset < RULER:
                top[start + offset] = digit
    units = "".join(str(i % 10) for i in range(RULER))
    return f'<span class="ruler">{"".join(top)}\n{units}</span>\n'


def _lines(chordpro: str) -> str:
    """The ChordPro, each line marked with how the parser classifies it."""
    out = []
    for line in chordpro.split("\n"):
        text = html.escape(line) or "&nbsp;"
        cls = "row c" if reading_mod.is_chord_row(line) else "row"
        out.append(f'<span class="{cls}">{text}</span>')
    # Joined with nothing: `.row` is a block, so a newline between two of them
    # renders an extra empty line and reads as a verse break that is not there.
    return "".join(out)


def build() -> pathlib.Path:
    """Write the review page. Returns its path."""
    pages = gold.pages(with_gold=True)
    # Whatever still holds an engine's own reading comes first: those need
    # transcribing, not checking, and they are the ones blocking the corpus.
    pages.sort(key=lambda p: (p.reviewed, p.drafted_from != "easyocr", p.file))

    parts = [f"<style>{CSS}</style>", """
<header>
  <h1>Gold review — read each answer beside its page</h1>
  <p>Blue rows are what the parser will read as chords; orange rows are a single
  bare root, which resolves to lyrics on purpose. The ruler above each block
  counts characters: a chord's column is the character it sits over, so keep the
  alignment when you fix a word. Edit the JSON file named under each block, then
  set <code>reviewed_by</code>.</p>
</header>
<nav>"""]
    for page in pages:
        mark = "check" if page.reviewed else "TODO"
        parts.append(f'<a href="#{html.escape(page.stem)}">{mark} '
                     f'{html.escape(page.file)}</a>')
    parts.append("</nav>")

    for page in pages:
        if page.reviewed:
            badge = f'<span class="badge check">reviewed {html.escape(page.reviewed_by)}</span>'
            task = "Spot-check only."
        elif page.drafted_from == "easyocr":
            badge = '<span class="badge todo">transcribe</span>'
            task = ("This still holds EasyOCR's own reading. Rewrite it from "
                    "the photograph — every word and every chord column. "
                    "<code>python -m tools.ocr_harness align "
                    f"{page.stem.split('-')[0]}</code> prints the measured "
                    "pixel spans if you want the columns checked.")
        else:
            badge = '<span class="badge todo">verify</span>'
            task = ("Transcribed from the photograph, not from any engine, so "
                    "the scores against it are real — but the transcription "
                    "itself is unchecked. A word misread here becomes an error "
                    "no engine can ever score against.")

        rel = "photos/" + page.file
        stresses = "".join(f"<li>{html.escape(s)}</li>"
                           for s in page.stresses) or "<li>—</li>"
        parts.append(f"""
<section id="{html.escape(page.stem)}">
  <h2>{badge}{html.escape(page.file)}</h2>
  <p class="meta">tier {html.escape(page.tier)} &middot;
     {html.escape(page.engine)} engine &middot;
     {html.escape(page.layout)}</p>
  <div class="grid">
    <div class="shot">
      <img src="{html.escape(rel)}" alt="{html.escape(page.file)}">
      <a href="{html.escape(rel)}" target="_blank">open full size</a>
    </div>
    <div class="pane">
      <p class="meta">{task}</p>
      <h3>gold answer</h3>
      <pre>{_ruler()}{_lines(page.gold.chordpro)}</pre>
      <h3>expected warnings</h3>
      <p class="meta">{html.escape(", ".join(page.gold.warnings) or "none")}</p>
      <h3>what this page stresses</h3>
      <ul>{stresses}</ul>
      <p class="path">tools/fixtures/gold/{html.escape(page.stem)}.gold.json</p>
    </div>
  </div>
</section>""")

    OUT.write_text("\n".join(parts), encoding="utf-8")
    return OUT
