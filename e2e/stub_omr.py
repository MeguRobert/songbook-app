#!/usr/bin/env python3
"""The sheet-music reader, standing in for Cloud Run.

Speaks the same contract (`POST /extract` multipart -> JSON) and the same CORS
preamble, and answers with real Audiveris output. It exists because the live
service requires a Supabase access token that a headless browser has no way to
obtain, and because the interesting half of that round trip is what the *app*
does with the answer -- which is where the grey rectangle came from.

Deliberately no authentication: this is a stub on loopback, and adding a fake
token check would test the fake.
"""
import io
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
XML = io.open(os.path.join(HERE, 'score.musicxml'), encoding='utf-8').read()

# What the real service sends back, verbatim. Only this one: the
# additional-voice warning comes from the app's own importer, and sending
# it from here too made it appear twice — a duplicate the stub invented.
WARNINGS = [
    "Notation was read by OMR and is a transcription — check the pitches, "
    "and set the time signature, which Audiveris does not report. If a lot is "
    "missing, the page was probably not flat.",
]


class Handler(BaseHTTPRequestHandler):

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers",
                         "Authorization, Content-Type")

    def do_OPTIONS(self):  # noqa: N802
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self):  # noqa: N802
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        sys.stderr.write(f"[stub] {len(body)} bytes posted to {self.path}, "
                         f"auth={'yes' if self.headers.get('Authorization') else 'no'}\n")
        sys.stderr.flush()
        payload = json.dumps({"kind": "musicxml", "content": XML,
                              "warnings": WARNINGS}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self._cors()
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8911
    print(f"stub omr on {port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
