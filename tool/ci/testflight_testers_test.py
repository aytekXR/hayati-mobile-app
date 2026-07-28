#!/usr/bin/env python3
"""Self-tests for tool/ci/testflight_testers.py (repo convention: every tool
under tool/ carries one, run by ci.yml's quality job).

Scope is deliberately the parts that can be wrong WITHOUT Apple noticing: the
email list parse, and the ES256 assertion. The HTTP calls are not mocked —
Apple's JSON:API shapes are not something a local fake can validate, and a fake
that agrees with a wrong assumption is worse than no test. Those are proven by
dispatching the workflow with --dry-run, which reads and writes nothing.

Run: python3 tool/ci/testflight_testers_test.py
"""

from __future__ import annotations

import base64
import importlib.util
import os
import pathlib
import sys

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

_MODULE_PATH = pathlib.Path(__file__).with_name("testflight_testers.py")
_spec = importlib.util.spec_from_file_location("testflight_testers", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
tf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tf)

_failures: list[str] = []


def check(label: str, actual: object, expected: object) -> None:
    if actual == expected:
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         expected: {expected!r}\n         actual:   {actual!r}")
        _failures.append(label)


def check_raises(label: str, fn, needle: str) -> None:
    try:
        fn()
    except tf.AscError as failure:
        if needle in str(failure):
            print(f"  ok   {label}")
        else:
            print(f"  FAIL {label}: message lacked {needle!r} -> {failure}")
            _failures.append(label)
        return
    print(f"  FAIL {label}: no AscError raised")
    _failures.append(label)


def test_parse_emails() -> None:
    print("parse_emails")
    check("comma separated", tf.parse_emails("a@x.com,b@x.com"), ["a@x.com", "b@x.com"])
    check("whitespace tolerated", tf.parse_emails(" a@x.com ,\n b@x.com "), ["a@x.com", "b@x.com"])
    check("empty is empty", tf.parse_emails(""), [])
    check("trailing comma", tf.parse_emails("a@x.com,"), ["a@x.com"])
    # The duplicate guard is the one that protects a real person's inbox.
    check("case-insensitive dedupe", tf.parse_emails("A@x.com,a@x.com"), ["A@x.com"])
    check("order preserved", tf.parse_emails("c@x.com b@x.com a@x.com"),
          ["c@x.com", "b@x.com", "a@x.com"])


def _pkcs8_pem() -> str:
    key = ec.generate_private_key(ec.SECP256R1())
    return key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()


def _set_creds(pem_b64: str) -> None:
    os.environ["ASC_KEY_ID"] = "TESTKEYID1"
    os.environ["ASC_ISSUER_ID"] = "11111111-2222-3333-4444-555555555555"
    os.environ["ASC_API_KEY_P8_BASE64"] = pem_b64


def test_token() -> None:
    print("_token")
    pem = _pkcs8_pem()
    flat = base64.b64encode(pem.encode()).decode()

    _set_creds(flat)
    token = tf._token()
    header = jwt.get_unverified_header(token)
    check("alg is ES256", header["alg"], "ES256")
    check("kid is the key id", header["kid"], "TESTKEYID1")
    claims = jwt.decode(
        token,
        serialization.load_pem_private_key(pem.encode(), password=None).public_key(),
        algorithms=["ES256"],
        audience="appstoreconnect-v1",
    )
    check("iss is the issuer id", claims["iss"], "11111111-2222-3333-4444-555555555555")
    check("ttl within Apple's 20-minute cap", claims["exp"] - claims["iat"] <= 1200, True)

    # The release lane's documented footgun: a base64 secret pasted with
    # newlines. Ruby's decode64 ignores them, strict decoders do not — so the
    # wrapped form must mint the SAME token payload as the flat one.
    wrapped = "\n".join(flat[i:i + 64] for i in range(0, len(flat), 64))
    _set_creds(wrapped)
    check("newline-wrapped base64 decodes identically",
          jwt.get_unverified_header(tf._token())["kid"], "TESTKEYID1")

    # Fail CLOSED, naming what is absent — never a silent unauthenticated call.
    _set_creds(flat)
    for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_API_KEY_P8_BASE64"):
        saved = os.environ[name]
        os.environ[name] = ""
        check_raises(f"missing {name} fails closed", tf._token, name)
        os.environ[name] = saved

    os.environ["ASC_API_KEY_P8_BASE64"] = base64.b64encode(b"not a pem").decode()
    check_raises("non-PEM secret fails closed", tf._token, "PKCS#8 PEM")


def _build(version, state, expired=False):
    return {"id": f"id-{version}", "attributes": {"version": version,
            "processingState": state, "expired": expired}}


def test_await_build() -> None:
    """`await_build` is what stops the release lane attaching a build that has
    no installable asset yet — reporting success while delivering nothing."""
    calls = {"n": 0}
    naps = []

    def once(builds):
        return lambda _t, _a, limit=5: builds

    # VALID straight away.
    tf.list_builds = once([_build("110", "VALID"), _build("109", "VALID")])
    got = tf.await_build("t", "app", "110", 600, sleep=naps.append)
    check("returns the VALID build", got["id"], "id-110")
    check("and did not sleep", naps, [])

    # PROCESSING, then VALID — the case the polling exists for.
    seq = [[_build("110", "PROCESSING")], [_build("110", "PROCESSING")],
           [_build("110", "VALID")]]
    def stepper(_t, _a, limit=5):
        calls["n"] += 1
        return seq[min(calls["n"] - 1, len(seq) - 1)]
    tf.list_builds = stepper
    naps.clear()
    got = tf.await_build("t", "app", "110", 600, sleep=naps.append)
    check("waits through PROCESSING then returns", got["id"], "id-110")
    check("and slept between polls", len(naps) >= 1, True)

    # Apple rejected it: stop immediately rather than burning the timeout.
    tf.list_builds = once([_build("110", "INVALID")])
    naps.clear()
    check("INVALID gives up at once", tf.await_build("t", "app", "110", 600, sleep=naps.append), None)
    check("without sleeping", naps, [])

    # Timeout is not an error, and must not return a not-VALID build.
    tf.list_builds = once([_build("110", "PROCESSING")])
    check("timeout returns None", tf.await_build("t", "app", "110", 60, sleep=lambda _s: None), None)

    # Matches by NUMBER, not by position — the newest build is not necessarily ours.
    tf.list_builds = once([_build("111", "VALID"), _build("110", "VALID")])
    check("matches the requested build number",
          tf.await_build("t", "app", "110", 600, sleep=lambda _s: None)["id"], "id-110")

    # An expired build is not installable either.
    tf.list_builds = once([_build("110", "VALID", expired=True)])
    check("an expired build is not accepted",
          tf.await_build("t", "app", "110", 60, sleep=lambda _s: None), None)


def main() -> int:
    test_parse_emails()
    test_token()
    test_await_build()
    if _failures:
        print(f"\n{len(_failures)} check(s) FAILED: {', '.join(_failures)}")
        return 1
    print("\nall testflight_testers self-tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
