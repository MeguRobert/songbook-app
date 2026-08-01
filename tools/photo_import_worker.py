#!/usr/bin/env python3
"""Local stand-in for the photo-import backend.

Implements the contract the app already speaks, so the whole import flow can be
exercised on this machine before committing to any hosting:

    POST /extract   multipart/form-data, image under `image`
    -> 200 {"kind": "chordpro" | "musicxml", "content": "...", "warnings": [...]}

Run it, then paste the URL into Settings -> Photo import.

    python tools/photo_import_worker.py                # stub, no key needed
    python tools/photo_import_worker.py --port 8790
    ANTHROPIC_API_KEY=sk-... python tools/photo_import_worker.py --live

`--live` calls a vision model for real; without it the server returns a fixed
song, which is what makes the app flow testable with no key and no network.

This is deliberately the same shape as the Cloudflare Worker it stands in for —
read the multipart body, ask a model, answer with the JSON above. Porting it
means replacing the http.server plumbing, not the logic.

Why stdlib only: this has to run on a machine that has Python and nothing else
installed, and adding a dependency to try an experiment is how experiments stop
getting tried.
"""

import argparse
import base64
import json
import os
import re
import sys
from email.parser import BytesParser
from email.policy import default as default_policy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Returned by the stub. Deliberately contains the two things most likely to be
# got wrong downstream: accented Hungarian, and a line whose words start with
# note letters ("Csak Egy Az" must survive as lyrics, not become C, E and A).
STUB_CHORDPRO = """{title: Az Úrra bízom életem}
{key: G}
[G]Az Úrra bízom [C]életem
[G]Ő megtart [D]engem

Csak Egy Az és Ő vezet
[Em]Minden [C]nap velem [G]jár
"""

MODEL_PROMPT = (
    "This is a photograph of a song — lyrics with guitar chords, or a hymn "
    "page. Transcribe it as ChordPro. Put each chord in square brackets "
    "immediately before the syllable it falls on. Separate verses with a blank "
    "line. Include {title: ...} if a title is visible and {key: ...} if you can "
    "tell the key. Output only the ChordPro, no commentary, no code fences. "
    "Preserve the original language and its accents exactly."
)


def extract_with_model(image_bytes: bytes, media_type: str) -> tuple[str, list]:
    """Ask a vision model for ChordPro. Returns (content, warnings)."""
    import urllib.request

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise RuntimeError("--live needs ANTHROPIC_API_KEY in the environment")

    payload = {
        "model": "claude-sonnet-5",
        "max_tokens": 4096,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image", "source": {
                    "type": "base64",
                    "media_type": media_type,
                    "data": base64.b64encode(image_bytes).decode("ascii"),
                }},
                {"type": "text", "text": MODEL_PROMPT},
            ],
        }],
    }
    request = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "content-type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        body = json.load(response)

    text = "".join(
        block.get("text", "") for block in body.get("content", [])
    ).strip()
    # Models wrap output in fences despite being asked not to; the app would
    # otherwise treat ``` as a lyric line.
    text = re.sub(r"^```[a-zA-Z]*\n|\n```$", "", text).strip()

    warnings = []
    if body.get("stop_reason") == "max_tokens":
        warnings.append("The page was long; the end may be missing.")
    return text, warnings


def parse_multipart(body: bytes, content_type: str):
    """Returns (field_name -> bytes, field_name -> filename)."""
    headers = b"Content-Type: " + content_type.encode("latin-1") + b"\r\n\r\n"
    message = BytesParser(policy=default_policy).parsebytes(headers + body)
    files, names = {}, {}
    if not message.is_multipart():
        return files, names
    for part in message.iter_parts():
        name = part.get_param("name", header="content-disposition")
        if name:
            files[name] = part.get_payload(decode=True)
            names[name] = part.get_filename()
    return files, names


class Handler(BaseHTTPRequestHandler):
    live = False

    def _cors(self):
        # The app is served from a different origin (a local file server, or
        # GitHub Pages), so every response needs these or the browser discards
        # a perfectly good reply. This is the failure that looks like "the
        # server never answered" in the app while the server logs a 200.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers",
                         "Authorization, Content-Type")
        self.send_header("Access-Control-Max-Age", "86400")

    def _json(self, status: int, payload: dict):
        encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self._cors()
        self.end_headers()
        self.wfile.write(encoded)

    def do_OPTIONS(self):  # noqa: N802 - BaseHTTPRequestHandler naming
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):  # noqa: N802
        # A browser pointed at the URL should say something useful rather than
        # 501, since the first thing anyone does is open it.
        self._json(200, {
            "service": "photo-import-worker",
            "mode": "live" if self.live else "stub",
            "post": "/extract  multipart/form-data, image under `image`",
        })

    def do_POST(self):  # noqa: N802
        if self.path.rstrip("/") not in ("/extract", ""):
            self._json(404, {"error": "POST /extract"})
            return

        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        content_type = self.headers.get("Content-Type", "")
        files, names = parse_multipart(body, content_type)
        image = files.get("image")

        if not image:
            self._json(400, {"error": "no `image` part in the request"})
            return

        filename = names.get("image") or "photo.jpg"
        sys.stderr.write(
            f"[worker] {filename}: {len(image)} bytes, "
            f"{'live' if self.live else 'stub'}\n")

        if not self.live:
            self._json(200, {
                "kind": "chordpro",
                "content": STUB_CHORDPRO,
                "warnings": ["Stub response — the worker is not in --live mode."],
            })
            return

        media_type = "image/png" if filename.lower().endswith(".png") \
            else "image/jpeg"
        try:
            content, warnings = extract_with_model(image, media_type)
        except Exception as exc:  # noqa: BLE001 - reported, not swallowed
            sys.stderr.write(f"[worker] model call failed: {exc}\n")
            self._json(502, {"error": str(exc)})
            return

        if not content.strip():
            # The app turns an empty content into "Nothing could be read from
            # that photo", which is the honest message for a blank page.
            self._json(200, {"kind": "chordpro", "content": "", "warnings": []})
            return

        self._json(200, {
            "kind": "chordpro",
            "content": content,
            "warnings": warnings,
        })

    def log_message(self, fmt, *args):
        sys.stderr.write("[worker] " + (fmt % args) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8790)
    parser.add_argument("--live", action="store_true",
                        help="call a vision model instead of returning the stub")
    args = parser.parse_args()

    Handler.live = args.live
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    mode = "LIVE (calls a model)" if args.live else "STUB (fixed response)"
    print(f"photo-import worker on http://127.0.0.1:{args.port}/extract  [{mode}]")
    print("Paste that URL into Settings -> Photo import.")
    server.serve_forever()


if __name__ == "__main__":
    main()
