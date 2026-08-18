Drop song photos here, or send them from the phone through the app.

TAKE A FRESH PHOTO of the page. Do not route it through a messenger first.

A messenger re-encodes: 2048px long edge, EXIF stripped, around 0.026 bytes
per pixel. That erases the two strokes over ő and ű, so the page reads "erót"
for "erőt", and it turned a "-7" chord into "27". Nothing in the parser can
recover detail that is no longer in the file.

The worker says so when it sees it — if the review screen mentions the photo
being too compressed, that is a messenger copy rather than the original.

Scored with:  python tools/fixtures/score.py
