"""Example JWT-like token for local integration tests.

This token mimics the shape of a Supabase-issued JWT. It is NOT signed with
real credentials, so production systems must continue to verify tokens via the
normal GraphQL authentication middleware.

Usage from tests:

    from auth_token_example import AUTH_TOKEN

    headers = {"Authorization": f"Bearer {AUTH_TOKEN}"}
"""
import datetime as _dt

# Supabase-style JWT segments (header.payload.signature). The payload encodes
# a short-lived expiry so automated tests can validate expiry handling logic.
AUTH_TOKEN = (
    "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InRlc3Qta2V5LTEifQ."
    "eyJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzU4OTg0NTYxLCJpYXQiOjE3NTg5NDY1MjEs"
    "ImlzcyI6Imh0dHBzOi8vZXhhbXBsZS5zdXBhYmFzZS5jby9hdXRoL3YxIiwic3ViIjoiMDAwMDAwMDAt"
    "MDAwMC00MDAwLTgwMDAtMDAwMDAwMDAwMDAwIiwicm9sZSI6ImFkbWluIiwiZW1haWwiOiJhZG1pbiFA"
    "ZXhhbXBsZS5jb20ifQ."
    "K3oeaXFVJYPI6C3pwDUXOek3gd2BXLFH_N2X1252BHs"
)

# Helper that lets tests assert the expiry the token encodes without manually
# decoding the payload. Keeping everything in UTC simplifies cross-language tests.
TEST_TOKEN_EXPIRES_AT = _dt.datetime.utcfromtimestamp(1_758_984_561)
