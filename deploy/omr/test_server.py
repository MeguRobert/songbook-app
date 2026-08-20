#!/usr/bin/env python3
"""Tests for the OMR service's Supabase authentication.

The service is reachable from the open internet, because a browser calls it
directly. Google's own IAM cannot gate that — the caller is a user's browser,
not a service account — so the gate is the Supabase access token the app
already holds, verified here.

The project signs with **ES256**: its JWT keys were rotated to ECC (P-256) and
the legacy HS256 shared secret is now only a previous key. So verification is
against the project's PUBLIC JWKS, which means there is no secret to deploy at
all — a strictly better position than the shared-secret one this replaced.

Every key below is generated in-process, so these tests never touch the network
and the attacks are real signatures rather than fixtures.

    python -m unittest discover -s deploy/omr
"""

import io
import sys
import time
import unittest

import jwt
from cryptography.hazmat.primitives.asymmetric import ec, rsa

import server

# One key pair for the whole file: generating EC keys is cheap, but not free.
_SIGNING_KEY = ec.generate_private_key(ec.SECP256R1())
_PUBLIC_KEY = _SIGNING_KEY.public_key()
_OTHER_KEY = ec.generate_private_key(ec.SECP256R1())

KID = "764c33ed-4caa-4c73-820a-e6e0c375116d"


def resolver(key=None):
    """A stand-in for the JWKS lookup, returning [key] for any kid."""
    return lambda token: key if key is not None else _PUBLIC_KEY


def encode(payload=None, key=None, algorithm="ES256", headers=None, **overrides):
    now = int(time.time())
    claims = {
        "aud": "authenticated",
        "role": "authenticated",
        "sub": "8b1c0e2a-0000-4000-8000-000000000000",
        "iat": now - 60,
        "exp": now + 3600,
    }
    claims.update(payload or {})
    claims.update(overrides)
    return jwt.encode(claims, key or _SIGNING_KEY, algorithm=algorithm,
                      headers={"kid": KID, **(headers or {})})


class VerifyTokenTests(unittest.TestCase):

    def test_a_token_signed_by_the_project_key_is_accepted(self):
        claims = server.verify_token(encode(), resolver())
        self.assertEqual(claims["sub"], "8b1c0e2a-0000-4000-8000-000000000000")

    def test_a_token_signed_by_another_key_is_refused(self):
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(key=_OTHER_KEY), resolver())

    def test_an_expired_token_is_refused(self):
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(exp=int(time.time()) - 10), resolver())

    def test_a_token_for_another_audience_is_refused(self):
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(aud="other-project"), resolver())

    def test_the_anon_role_is_refused(self):
        # The publishable key ships inside the app where anyone can read it, so
        # an anon token must not open the door.
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(role="anon"), resolver())

    def test_an_unsigned_token_is_refused(self):
        # `alg: none` — a token with no signature at all.
        unsigned = jwt.encode({"aud": "authenticated", "role": "authenticated",
                               "exp": int(time.time()) + 999},
                              key=None, algorithm="none")
        with self.assertRaises(server.AuthError):
            server.verify_token(unsigned, resolver())

    def test_an_hmac_token_is_refused_even_using_the_public_key(self):
        """The algorithm-confusion attack.

        Sign with HS256 using the PUBLIC key bytes as the shared secret. A
        verifier that reads `alg` from the token instead of pinning it will
        check that HMAC with the same public key — which everyone has — and let
        it through.

        Hand-rolled, because PyJWT refuses to *encode* this: it guards against
        the attack from the signing side too.
        """
        import base64
        import hashlib
        import hmac
        import json

        from cryptography.hazmat.primitives import serialization

        public_bytes = _PUBLIC_KEY.public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo)

        def segment(raw):
            return base64.urlsafe_b64encode(
                json.dumps(raw, separators=(",", ":")).encode()).rstrip(b"=")

        signing_input = (segment({"alg": "HS256", "typ": "JWT", "kid": KID}) +
                         b"." +
                         segment({"aud": "authenticated",
                                  "role": "authenticated",
                                  "exp": int(time.time()) + 999}))
        signature = base64.urlsafe_b64encode(
            hmac.new(public_bytes, signing_input, hashlib.sha256).digest()
        ).rstrip(b"=")
        forged = (signing_input + b"." + signature).decode()

        with self.assertRaises(server.AuthError):
            server.verify_token(forged, resolver())

    def test_an_rsa_token_is_refused(self):
        # Only the curve the project actually uses is accepted.
        rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        token = jwt.encode(
            {"aud": "authenticated", "role": "authenticated",
             "exp": int(time.time()) + 999},
            rsa_key, algorithm="RS256", headers={"kid": KID})
        with self.assertRaises(server.AuthError):
            server.verify_token(token, resolver(rsa_key.public_key()))

    def test_rubbish_is_refused_rather_than_crashing(self):
        for rubbish in ("", "not.a.token", "a.b", "...", "x" * 200):
            with self.assertRaises(server.AuthError):
                server.verify_token(rubbish, resolver())

    def test_an_unknown_key_is_refused(self):
        # A kid the project has never published — a rotated-away or invented one.
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(), lambda token: None)

    def test_a_lookup_failure_is_refused_rather_than_letting_it_through(self):
        def broken(token):
            raise RuntimeError('JWKS unreachable')

        with self.assertRaises(server.AuthError):
            server.verify_token(encode(), broken)


class BearerTests(unittest.TestCase):

    def test_the_scheme_is_stripped(self):
        token = encode()
        self.assertEqual(server.bearer(f"Bearer {token}"), token)
        self.assertEqual(server.bearer(f"bearer {token}"), token)

    def test_a_missing_or_malformed_header_is_refused(self):
        for header in (None, "", "Basic abc", "Bearer", "Bearer   "):
            with self.assertRaises(server.AuthError):
                server.bearer(header)


class FailClosedTests(unittest.TestCase):
    """Unconfigured must mean refused, not open.

    A deployment that quietly accepts everyone is worse than one that refuses
    everyone: the bill is the owner's, and the failure is silent.
    """

    def test_no_key_source_configured_refuses_a_valid_token(self):
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(), None)


class LoggingTests(unittest.TestCase):
    """What the service writes down about a request.

    This matters more than it looks. An imported song is stored on the device,
    so a page that was read badly and then abandoned exists nowhere except in
    what this wrote to stderr — which Cloud Run keeps. If the log does not say
    who asked, how long it took and what came out, the answer to "this page came
    out wrong" is a shrug.
    """

    def capture(self, fn):
        stream = io.StringIO()
        original, sys.stderr = sys.stderr, stream
        try:
            fn()
        finally:
            sys.stderr = original
        return stream.getvalue()

    def test_a_line_carries_the_request_number_so_lines_can_be_paired(self):
        # The interesting questions are about one request across time, so the
        # before line and the after line have to be joinable.
        first = self.capture(lambda: server.log(7, "reading page.png"))
        self.assertIn("#7", first)
        self.assertIn("reading page.png", first)

    def test_request_numbers_advance(self):
        a = next(server._request_numbers)
        b = next(server._request_numbers)
        self.assertEqual(b, a + 1)

    def test_every_line_is_flushed(self):
        # Cloud Run kills an instance without warning. An unflushed line is a
        # line that never existed.
        stream = io.StringIO()
        original, sys.stderr = sys.stderr, stream
        try:
            server.log(1, "x")
        finally:
            sys.stderr = original
        self.assertTrue(stream.getvalue().endswith("\n"))


if __name__ == "__main__":
    unittest.main()
