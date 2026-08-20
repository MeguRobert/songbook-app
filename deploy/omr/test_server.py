#!/usr/bin/env python3
"""Tests for the OMR service's Supabase authentication.

The service is reachable from the open internet, because a browser calls it
directly. Google's own IAM cannot gate that — the caller is a user's browser,
not a service account — so the gate is the Supabase access token the app
already holds, verified here.

Supabase signs with HS256 (checked against the project's own publishable key,
whose header is {"alg":"HS256"}), so this needs nothing beyond hmac and
hashlib.

    python -m unittest discover -s deploy/omr
"""

import base64
import hashlib
import hmac
import json
import time
import unittest

import server

SECRET = "test-secret-not-the-real-one"


def encode(payload: dict, secret: str = SECRET, algorithm: str = "HS256") -> str:
    """A signed token, the way Supabase issues them."""
    def part(raw: dict) -> bytes:
        return base64.urlsafe_b64encode(
            json.dumps(raw, separators=(",", ":")).encode()).rstrip(b"=")

    signing_input = part({"alg": algorithm, "typ": "JWT"}) + b"." + part(payload)
    signature = base64.urlsafe_b64encode(
        hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
    ).rstrip(b"=")
    return (signing_input + b"." + signature).decode()


def valid_payload(**overrides):
    now = int(time.time())
    payload = {
        "aud": "authenticated",
        "role": "authenticated",
        "sub": "8b1c0e2a-0000-4000-8000-000000000000",
        "iat": now - 60,
        "exp": now + 3600,
    }
    payload.update(overrides)
    return payload


class VerifyTokenTests(unittest.TestCase):

    def test_a_signed_unexpired_token_is_accepted(self):
        claims = server.verify_token(encode(valid_payload()), SECRET)
        self.assertEqual(claims["sub"], "8b1c0e2a-0000-4000-8000-000000000000")

    def test_a_token_signed_with_another_secret_is_refused(self):
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(valid_payload(), "wrong-secret"), SECRET)

    def test_an_expired_token_is_refused(self):
        with self.assertRaises(server.AuthError):
            server.verify_token(
                encode(valid_payload(exp=int(time.time()) - 10)), SECRET)

    def test_a_token_for_another_audience_is_refused(self):
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(valid_payload(aud="other")), SECRET)

    def test_the_anon_key_is_refused(self):
        # The publishable key is itself a valid Supabase JWT and ships inside
        # the app, so anyone can read it. Signed-in users only.
        with self.assertRaises(server.AuthError):
            server.verify_token(
                encode(valid_payload(role="anon", aud="authenticated")), SECRET)

    def test_an_unsigned_token_is_refused(self):
        # `alg: none` is the classic JWT hole: a token with no signature at all.
        header = base64.urlsafe_b64encode(
            b'{"alg":"none","typ":"JWT"}').rstrip(b"=")
        body = base64.urlsafe_b64encode(
            json.dumps(valid_payload()).encode()).rstrip(b"=")
        with self.assertRaises(server.AuthError):
            server.verify_token((header + b"." + body + b".").decode(), SECRET)

    def test_a_token_signed_with_a_different_algorithm_is_refused(self):
        with self.assertRaises(server.AuthError):
            server.verify_token(
                encode(valid_payload(), algorithm="HS512"), SECRET)

    def test_rubbish_is_refused_rather_than_crashing(self):
        for rubbish in ("", "not.a.token", "a.b", "...", "x" * 200):
            with self.assertRaises(server.AuthError):
                server.verify_token(rubbish, SECRET)


class BearerTests(unittest.TestCase):

    def test_the_scheme_is_stripped(self):
        token = encode(valid_payload())
        self.assertEqual(server.bearer(f"Bearer {token}"), token)
        self.assertEqual(server.bearer(f"bearer {token}"), token)

    def test_a_missing_or_malformed_header_is_refused(self):
        for header in (None, "", "Basic abc", "Bearer", "Bearer   "):
            with self.assertRaises(server.AuthError):
                server.bearer(header)


class FailClosedTests(unittest.TestCase):
    """With no secret configured the service must refuse everything.

    A misconfigured deployment that quietly accepts all callers is worse than
    one that refuses them: the bill is the user's, and the failure is silent.
    """

    def test_no_secret_configured_refuses_even_a_valid_token(self):
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(valid_payload()), "")
        with self.assertRaises(server.AuthError):
            server.verify_token(encode(valid_payload()), None)


if __name__ == "__main__":
    unittest.main()
