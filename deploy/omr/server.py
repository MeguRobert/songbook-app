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
# The project signs with ES256: its JWT keys were rotated to ECC (P-256), and
# the legacy HS256 shared secret is now only a "previous key". Verification is
# therefore against the project's PUBLIC JWKS — which means there is no secret
# to deploy, nothing to rotate here, and nothing that can leak. Strictly better
# than the shared-secret arrangement this replaced.
#
# With no JWKS URL configured the service refuses everything. A misconfigured
# deployment that quietly accepts all callers is worse than one that refuses
# them: the bill is the owner's, and the failure is silent.
# ---------------------------------------------------------------------------

# Either the project URL (the usual case) or a full JWKS URL.
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
JWKS_URL = os.environ.get("SUPABASE_JWKS_URL") or (
    f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json" if SUPABASE_URL else "")

# Pinned, never read from the token. Reading `alg` from the thing you are
# checking is how a verifier is talked out of verifying: `alg: none` removes the
# signature, and HS256 with the public key as the shared secret turns a public
# key into a password everyone already has.
ALLOWED_ALGORITHMS = ["ES256"]

# Supabase issues these to signed-in users. `anon` is the key that ships inside
# the app itself, where anyone can read it — it must not open the door.
REQUIRED_AUDIENCE = "authenticated"
ALLOWED_ROLES = {"authenticated", "service_role"}


class AuthError(Exception):
    """The caller is not a signed-in user of this app."""


_jwks_client = None


def signing_key_resolver():
    """A callable giving the project's public key for a token, or None.

    Built once and reused: PyJWKClient caches the fetched keys and re-fetches
    when it meets a `kid` it has not seen, which is what makes key rotation a
    non-event here.
    """
    global _jwks_client
    if not JWKS_URL:
        return None
    if _jwks_client is None:
        from jwt import PyJWKClient
        _jwks_client = PyJWKClient(JWKS_URL, cache_keys=True, lifespan=600)

    def resolve(token: str):
        return _jwks_client.get_signing_key_from_jwt(token).key

    return resolve


def bearer(header) -> str:
    """The token out of an Authorization header."""
    if not header:
        raise AuthError("Sign in to read a page.")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise AuthError("Sign in to read a page.")
    return token.strip()


def verify_token(token: str, resolve) -> dict:
    """The claims of [token], or [AuthError] if it is not a signed-in user.

    [resolve] maps a token to the public key that should have signed it; None
    means no key source is configured, which refuses everything.
    """
    import jwt as pyjwt

    if resolve is None:
        raise AuthError("This service is not configured for sign-in yet.")
    try:
        key = resolve(token)
    except Exception as exc:  # noqa: BLE001 - an unreachable JWKS must refuse
        raise AuthError("Sign-in could not be checked right now.") from exc
    if key is None:
        raise AuthError("That sign-in is not valid here.")

    try:
        return _checked(pyjwt.decode(
            token, key,
            algorithms=ALLOWED_ALGORITHMS,
            audience=REQUIRED_AUDIENCE,
            options={"require": ["exp", "aud"]}))
    except pyjwt.ExpiredSignatureError as exc:
        raise AuthError("That sign-in has expired. Sign in again.") from exc
    except pyjwt.InvalidAudienceError as exc:
        raise AuthError("That sign-in is not valid here.") from exc
    except pyjwt.PyJWTError as exc:
        raise AuthError("That sign-in could not be read.") from exc


def _checked(claims: dict) -> dict:
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
                         "authenticated": bool(JWKS_URL),
                         "post": "/extract  multipart/form-data, "
                                 "image under `image`, "
                                 "Authorization: Bearer <supabase token>"})

    def do_POST(self):  # noqa: N802
        if self.path.rstrip("/") not in ("/extract", ""):
            self._json(404, {"error": "POST /extract"})
            return

        try:
            claims = verify_token(
                bearer(self.headers.get("Authorization")),
                signing_key_resolver())
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
    if not JWKS_URL:
        print("WARNING: SUPABASE_URL is not set - every request will be "
              "refused. Set it with:  gcloud run services update songbook-omr "
              "--region europe-central2 "
              "--set-env-vars SUPABASE_URL=https://<ref>.supabase.co",
              flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
