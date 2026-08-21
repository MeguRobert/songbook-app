# The measurement corpus

Eleven photographed song pages, and the answer each one is scored against.

**The images are not in git.** They are photographs of a copyrighted Hungarian
hymnal and this repo is public, so they stay on the machine that took them —
the same treatment `deploy/omr/app/` gets, for the same reason. What travels is
everything derived from them:

| Committed | What it is |
|---|---|
| `manifest.json` | one entry per page: tier, engine, layout, and what each one stresses |
| `checksums.txt` | SHA-256 per file, so a corpus can be proved identical |
| `../gold/*.gold.json` | the hand-verified answer each page is scored against |
| `../../ocr_harness/baseline.json` | the last accepted score per page per metric |

To rebuild the corpus on another machine you need the photographs themselves.
Ask Robert; `sha256sum -c checksums.txt` then proves you have the same bytes.

## Every image came through WhatsApp

EXIF stripped, long edge 2048px, 0.021–0.108 bytes per pixel.
`photo_import_worker.resolution_note` warns about exactly this, and
`HANDOFF-photo-import.md` says not to route photographs through a messenger,
because that compression is what destroys `ő` and `ű`.

Treat this corpus as the real distribution anyway. If a congregation shares a
song page at all, it shares it through a chat app — so this is what the feature
receives. Keep any future camera-direct corpus in a sibling directory rather
than mixing it in, so the two stay comparable.

## Tiers

- **A** — clean print, one column. Must reach a high score and stay there; a
  regression here means something basic broke.
- **B** — the current frontier: two columns, italic chord rows, a second song
  on the page, letterboxing.
- **C** — scored and shown, but kept out of the headline average. Both tier-C
  pages carry a handwritten chord written *over* a printed one, which is a
  product question — which set does the importer keep? — and not something an
  OCR setting resolves. Averaging them in would make every real improvement
  look flat.

## Working on it

```bash
python -m tools.ocr_harness list -v            # the corpus and what it stresses
python -m tools.ocr_harness run                # read, score, table, gate
python -m tools.ocr_harness trace 185          # why each row went where
python -m tools.ocr_harness align 166          # measured geometry, for gold
python -m tools.ocr_harness symbols            # chords no rule can spell
python -m tools.ocr_harness run --accept DATE  # promote to baseline
```

`run` exits non-zero when a gated metric moves the wrong way against the
committed baseline.
