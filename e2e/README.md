# End-to-end: photographing a song

Drives the real release build in a real browser, both import engines, against
real photographs. It exists because unit tests could not have caught either of
the bugs it now guards: one lived in JavaScript interop the Dart VM never runs,
and the other looked like a correct widget tree.

## Running it

```bash
cd songbook_app
flutter build web --release --no-web-resources-cdn \
  --dart-define=PHOTO_IMPORT_ENDPOINT=http://127.0.0.1:8911/extract

# The Content-Security-Policy in web/index.html does not allow loopback, and it
# should not — so the *built copy* is amended for the test run only.
python - <<'PY'
import io
p = 'build/web/index.html'
s = io.open(p, encoding='utf-8').read()
io.open(p, 'w', encoding='utf-8', newline='\n').write(
    s.replace("connect-src 'self' data: blob:",
              "connect-src 'self' data: blob: http://127.0.0.1:8911", 1))
PY

cd ../e2e
python stub_omr.py 8911 &                                   # the sheet-music reader
(cd ../songbook_app/build/web && python -m http.server 8912 --bind 127.0.0.1 &)
NODE_PATH=$(npm root -g) node import.e2e.cjs
```

Playwright is expected to be installed globally, hence `NODE_PATH`. Screenshots
of both runs land in `shots/`, which is worth looking at even when everything
passes — that is how the `J` in the Title box was found.

## What is real and what is not

| | |
|---|---|
| A chord sheet | **entirely real.** The device path: canvas, page cleaning, Tesseract fetched from its CDN, the chords-over-lyrics bridge. `chord-sheet.png` is an actual photograph of song 149. |
| A page of sheet music | **the app is real, the reader is stubbed.** `stub_omr.py` answers with real Audiveris output. |

The reader is stubbed for two reasons: the live one requires a Supabase access
token that a headless browser has no way to hold, and the half worth testing is
what the app does with the answer — the grey rectangle came from there, not from
Audiveris.

`score.musicxml` is genuine Audiveris output
(`tools/audiveris_output/zsolt-090.width-800.xml`) with one deliberate change,
made by `make_fixture.py`: the notes of its second bar are moved to a voice that
is not the melody. The app renders the melody only, so that bar arrives with
nothing in it — the exact shape a photographed page of song 151 produced, and
what the renderer used to throw on.

## Two assertions that were wrong before they were right

Both mistakes are the interesting part of this directory.

**"The preview mentions the title."** It passed on the *lyrics*, which contain
the same words. It would have passed with the Title box empty.

**"No blocker text is present."** The blocker sentences are only rendered when
there is no draft at all; with a successful import the screen shows the preview
instead and merely disables Save. So it was true for every successful import,
and it passed while the Title held a single stray letter `J` and the Number was
empty. Save's own `aria-disabled` is the screen's real answer, and that is what
is asserted now.

The lesson both share: assert on what the user would see, and prefer the signal
the screen itself computes over a signal that merely correlates with it.

## Driving a Flutter canvas

`dom.cjs` holds the three things that cost an hour each to learn.

1. There is nothing to click until accessibility is switched on. Clicking
   Flutter's off-screen "Enable accessibility" placeholder turns the canvas into
   a tree of `<flt-semantics>`.
2. Labels live in **both** text content and `aria-label`, depending on the
   control. Reading one of the two finds half the screen and looks exactly like
   the screen having failed to render.
3. A semantics node can sit outside the viewport while the widget it describes
   is plainly visible, so Playwright's own click refuses it. Clicking through
   the DOM is the way in.

And one about the app rather than the harness: navigating to `#/import` twice
does nothing, because neither the document nor the hash changed. Each import gets
a fresh page.
