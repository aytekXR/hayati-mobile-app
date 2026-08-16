#!/usr/bin/env python3
"""Hermetic self-tests for tool/ci/push_delivery_probe.py. No network, no credential.

WHAT THIS GATE IS FOR. The tool's whole value is that it refuses to let four
different failures keep presenting as the same symptom — *nothing arrived*. So
the assertions aim at the DISCRIMINATION and at the SAFETY INTERLOCK, not at the
happy path:

* **Each FCM errorCode must name a DIFFERENT broken link.** Collapsing them (the
  tempting "just print the raw error" simplification) restores the ambiguity that
  cost this feature two sessions.
* **`THIRD_PARTY_AUTH_ERROR` must name the APNs key**, because that is the one
  link no Google API exposes and therefore the one a reader cannot look up.
* **An unknown or absent errorCode must NOT be reported as healthy.** A send that
  failed in a way we do not recognise is "could not tell", never "delivered".
* **The token reader must ignore malformed Firestore shapes** rather than crash
  or, worse, treat junk as a registered device.
"""
from __future__ import annotations

import sys

from push_delivery_probe import (
    EXIT_CANNOT_MEASURE,
    EXIT_FINDING,
    EXIT_OK,
    diagnose,
    fcm_error_code,
    registered_accounts,
)

failures: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if not condition:
        failures.append(f"{name}: {detail or 'assertion failed'}")


def section(name: str, fn) -> None:
    try:
        fn()
    except Exception as exc:
        failures.append(f"{name}: raised {type(exc).__name__}: {exc}")


def test_each_code_names_a_different_link() -> None:
    codes = ["THIRD_PARTY_AUTH_ERROR", "UNREGISTERED", "SENDER_ID_MISMATCH",
             "INVALID_ARGUMENT"]
    texts = [diagnose(c, "hayatiapp-prod") for c in codes]
    check("taxonomy/distinct", len(set(texts)) == len(texts),
          "two error codes produced the same explanation — the ambiguity is back")
    for code, text in zip(codes, texts):
        check(f"taxonomy/nonempty({code})", len(text) > 40, "explanation is too thin to act on")


def test_apns_is_named_and_actionable() -> None:
    text = diagnose("THIRD_PARTY_AUTH_ERROR", "hayatiapp-prod")
    check("apns/names-apns", "APNs" in text)
    check("apns/exonerates-the-rest", "token and the server are fine" in text,
          "must say what is NOT broken, or the reader re-debugs the whole chain")
    check("apns/has-a-fix", ".p8" in text and "cloudmessaging" in text)
    check("apns/project-interpolated", "hayatiapp-prod" in text,
          "the console link must point at the project actually probed")
    other = diagnose("THIRD_PARTY_AUTH_ERROR", "hayatiapp-dev")
    check("apns/project-not-hardcoded", "hayatiapp-dev" in other)


def test_unknown_failure_is_not_health() -> None:
    for code in (None, "SOMETHING_NEW"):
        text = diagnose(code, "hayatiapp-prod")
        check(f"unknown/not-silent({code})", len(text) > 20)
        check(f"unknown/not-claimed-healthy({code})",
              "work" not in text.lower() and "delivered" not in text.lower(),
              "an unrecognised failure must never read as a successful delivery")


def test_error_code_extraction() -> None:
    body = {"error": {"code": 404, "status": "NOT_FOUND",
                      "details": [{"@type": "x"}, {"errorCode": "UNREGISTERED"}]}}
    check("extract/found", fcm_error_code(body) == "UNREGISTERED")
    check("extract/absent", fcm_error_code({"error": {"code": 500}}) is None)
    check("extract/empty", fcm_error_code({}) is None)
    check("extract/malformed-details",
          fcm_error_code({"error": {"details": ["not-a-dict"]}}) is None,
          "a junk details array must not crash the diagnosis")


def test_registered_accounts_reader() -> None:
    docs = [
        {"name": "projects/p/databases/(default)/documents/users/withTokens",
         "fields": {"fcmTokens": {"arrayValue": {"values": [{"stringValue": "t1"},
                                                            {"stringValue": "t2"}]}}}},
        {"name": "…/users/absent", "fields": {"contentLanguage": {"stringValue": "tr"}}},
        {"name": "…/users/emptyArray", "fields": {"fcmTokens": {"arrayValue": {}}}},
        {"name": "…/users/malformed", "fields": {"fcmTokens": {"stringValue": "junk"}}},
        {"name": "…/users/junkEntry",
         "fields": {"fcmTokens": {"arrayValue": {"values": [{"integerValue": "7"}]}}}},
    ]
    found = registered_accounts(docs)
    check("reader/only-real-holders", [uid for uid, _ in found] == ["withTokens"],
          f"got {[u for u, _ in found]} — absent/empty/malformed must not count as registered")
    check("reader/tokens", found and found[0][1] == ["t1", "t2"])
    check("reader/empty-input", registered_accounts([]) == [])


def test_exit_taxonomy() -> None:
    check("taxonomy/values", (EXIT_OK, EXIT_FINDING, EXIT_CANNOT_MEASURE) == (0, 1, 2))
    check("taxonomy/distinct", len({EXIT_OK, EXIT_FINDING, EXIT_CANNOT_MEASURE}) == 3,
          "'refused to send' must not be indistinguishable from 'send failed'")


for name, fn in list(globals().items()):
    if name.startswith("test_"):
        section(name, fn)

if failures:
    print(f"push_delivery_probe_test: {len(failures)} FAILED", file=sys.stderr)
    for f in failures:
        print("  - " + f, file=sys.stderr)
    sys.exit(1)
print("push_delivery_probe_test: all checks passed")
