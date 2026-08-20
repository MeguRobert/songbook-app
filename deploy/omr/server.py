#!/usr/bin/env python3
"""Audiveris behind the photo-import contract.

Speaks exactly what the app already speaks, so this is a drop-in for the local
worker rather than a second integration:

    POST /extract   multipart/form-data, image under `image`
    -> 200 {"kind": "musicxml", "content": "...", "warnings": [...]}

This half reads NOTATION only. Audiveris returns no lyrics at all — measured,
zero syllables on a page full of them — so the words come from the text OCR
running in the browser. Sending a chord sheet here would waste 10 seconds and
return nothing useful, which is why the app asks before using it.
"""

import base64
import hashlib
import hmac
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import zipfile
from email.parser import BytesParser
from email.policy import default as default_policy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


# ---------------------------------------------------------------------------
# Who is allowed to spend this quota
#
# A browser calls this service directly, so Google's own IAM cannot gate it —
# the caller is a person's browser, not a service account. The gate is instead
# the Supabase access token the app already holds for a signed-in user.
#
# Supabase signs with HS256, so verifying one needs nothing beyond hmac and
# hashlib. If SUPABASE_JWT_SECRET is unset the service refuses everything: a
# misconfigured deployment that quietly accepts all callers is worse than one
# that refuses them, because the bill is the owner's and the failure is silent.
# ---------------------------------------------------------------------------

JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET", "")

# Supabase issues these to signed-in users. `anon` is the key that ships inside
# the app itself, so anyone can read it — it must not open the door.
REQUIRED_AUDIENCE = "authenticated"
ALLOWED_ROLES = {"authenticated", "service_role"}


class AuthError(Exception):
    """The caller is not a signed-in user of this app."""


def _b64(segment: str) -> bytes:
    return base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))


def bearer(header) -> str:
    """The token out of an Authorization header."""
    if not header:
        raise AuthError("Sign in to read a page.")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise AuthError("Sign in to read a page.")
    return token.strip()


def verify_token(token: str, secret) -> dict:
    """The claims of [token], or [AuthError] if it is not a signed-in user."""
    if not secret:
        raise AuthError("This service is not configured for sign-in yet.")
    try:
        header_segment, payload_segment, signature_segment = token.split(".")
        header = json.loads(_b64(header_segment))
        claims = json.loads(_b64(payload_segment))
        signature = _b64(signature_segment)
    except Exception as exc:  # noqa: BLE001 - any malformed token lands here
        raise AuthError("That sign-in could not be read.") from exc

    # Pinned, not read from the token: `alg: none` and algorithm substitution
    # are the classic ways a JWT check is talked out of checking anything.
    if header.get("alg") != "HS256":
        raise AuthError("That sign-in could not be read.")

    expected = hmac.new(
        secret.encode(),
        f"{header_segment}.{payload_segment}".encode(),
        hashlib.sha256).digest()
    if not hmac.compare_digest(signature, expected):
        raise AuthError("That sign-in is not valid here.")

    if claims.get("exp") is not None and time.time() >= float(claims["exp"]):
        raise AuthError("That sign-in has expired. Sign in again.")
    if claims.get("aud") != REQUIRED_AUDIENCE:
        raise AuthError("That sign-in is not valid here.")
    if claims.get("role") not in ALLOWED_ROLES:
        raise AuthError("Sign in to read a page.")
    return claims


APP = pathlib.Path(__file__).with_name("app")

# Headless is enough — Audiveris is a Swing application but its batch mode never
# opens a window, and no xvfb is needed. Verified in this image.
JAVA = [
    "java",
    "-Djava.awt.headless=true",
    "-Xmx2g",
    "-cp", f"{APP}/*",
    "Audiveris",
    "-batch",
    "-export",
]

# Audiveris takes about 10s on a clean page. The app gives up at 90, and a cold
# container has to start first, so cut it off with room to answer properly.
TIMEOUT_SECONDS = int(os.environ.get("OMR_TIMEOUT", "150"))


def parse_multipart(body: bytes, content_type: str):
    """Returns (field name -> bytes, field name -> filename)."""
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


def musicxml_from(image_bytes: bytes, filename: str) -> tuple[str, list]:
    """Run Audiveris over one page. Returns (MusicXML, warnings)."""
    suffix = pathlib.Path(filename).suffix.lower() or ".png"
    if suffix not in (".png", ".jpg", ".jpeg", ".tif", ".tiff", ".bmp", ".pdf"):
        suffix = ".png"

    with tempfile.TemporaryDirectory() as work:
        page = pathlib.Path(work) / f"page{suffix}"
        page.write_bytes(image_bytes)
        output = pathlib.Path(work) / "out"
        output.mkdir()

        finished = subprocess.run(
            JAVA + ["-output", str(output), str(page)],
            capture_output=True, text=True, timeout=TIMEOUT_SECONDS)
        if finished.returncode != 0:
            # Audiveris says why on stdout as often as stderr.
            detail = (finished.stderr or finished.stdout or "").strip()
            raise RuntimeError(detail.splitlines()[-1] if detail
                               else "Audiveris failed with no message.")

        # `.mxl` is zipped MusicXML; the app's importer wants the XML itself.
        archives = list(output.glob("*.mxl"))
        if not archives:
            plain = list(output.glob("*.xml")) + list(output.glob("*.musicxml"))
            if not plain:
                return "", ["No staves were found on that page."]
            return plain[0].read_text(encoding="utf-8"), []

        with zipfile.ZipFile(archives[0]) as archive:
            inner = [n for n in archive.namelist()
                     if n.endswith((".xml", ".musicxml"))
                     and not n.startswith("META-INF")]
            if not inner:
                return "", ["That page produced an unreadable score."]
            return archive.read(inner[0]).decode("utf-8"), []


class Handler(BaseHTTPRequestHandler):

    def _cors(self):
        # The app is served from a different origin, so without these the
        # browser discards a perfectly good reply — the failure that reads as
        # "the service never answered" while the log shows a 200.
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
        # Cloud Run health checks and anyone who opens the URL in a browser.
        self._json(200, {"service": "songbook-omr", "engine": "audiveris",
                         "authenticated": bool(JWT_SECRET),
                         "post": "/extract  multipart/form-data, "
                                 "image under `image`, "
                                 "Authorization: Bearer <supabase token>"})

    def do_POST(self):  # noqa: N802
        if self.path.rstrip("/") not in ("/extract", ""):
            self._json(404, {"error": "POST /extract"})
            return

        try:
            claims = verify_token(
                bearer(self.headers.get("Authorization")), JWT_SECRET)
        except AuthError as denied:
            # 401 rather than 403: the app can act on this by sending the user
            # to sign in, which a 403 would not tell it to do.
            sys.stderr.write(f"[omr] refused: {denied}\n")
            self._json(401, {"error": str(denied)})
            return

        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        files, names = parse_multipart(body, self.headers.get("Content-Type", ""))
        image = files.get("image")
        if not image:
            self._json(400, {"error": "no `image` part in the request"})
            return

        filename = names.get("image") or "page.png"
        sys.stderr.write(
            f"[omr] {filename}: {len(image)} bytes for {claims.get('sub')}\n")
        try:
            content, warnings = musicxml_from(image, filename)
        except subprocess.TimeoutExpired:
            self._json(504, {"error": "Reading the notation took too long. A "
                                      "flat, sharp photo of a single page is "
                                      "read in about ten seconds."})
            return
        except Exception as exc:  # noqa: BLE001 - reported, not swallowed
            sys.stderr.write(f"[omr] failed: {exc}\n")
            self._json(500, {"error": f"The notation could not be read. {exc}"})
            return

        if not content.strip():
            self._json(200, {"kind": "musicxml", "content": "",
                             "warnings": warnings})
            return

        # Measured: a curled page collapses to a tenth of its notes, because
        # staff detection needs straight lines. Tilt is fine; curve is not.
        warnings = warnings + [
            "Notation was read by OMR and is a transcription — check the "
            "pitches, and set the time signature, which Audiveris does not "
            "report. If a lot is missing, the page was probably not flat."]
        self._json(200, {"kind": "musicxml", "content": content,
                         "warnings": warnings})

    def log_message(self, fmt, *args):
        sys.stderr.write("[omr] " + (fmt % args) + "\n")


def main():
    port = int(os.environ.get("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"songbook-omr listening on {port}", flush=True)
    if not JWT_SECRET:
        print("WARNING: SUPABASE_JWT_SECRET is not set - every request will be "
              "refused. Set it with:  gcloud run services update songbook-omr "
              "--region europe-central2 --set-env-vars SUPABASE_JWT_SECRET=...",
              flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
