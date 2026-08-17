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
    DETAIL_DIAGNOSIS,
    DEVICE_DIAGNOSIS,
    EXIT_CANNOT_MEASURE,
    EXIT_FINDING,
    EXIT_OK,
    device_reports,
    diagnose,
    diagnose_device,
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


def test_device_report_reader() -> None:
    """The ADR-049 field, read out of the Firestore REST v1 shape.

    The wire shape is MEASURED (hayatiapp-prod, 2026-08-17) rather than guessed:
    a map field arrives as mapValue.fields.<key>.<typedValue>, one level deeper
    than the logical schema suggests. Every junk case below must read as absent
    rather than crash — a device SELF-REPORT must never be able to take down the
    instrument that reads it, because the account writing it is the account being
    diagnosed.
    """
    docs = [
        {"name": "…/users/full", "fields": {"pushDiagnostic": {"mapValue": {"fields": {
            "state": {"stringValue": "denied"},
            "detail": {"stringValue": "permissionRequestRefused"},
            "at": {"timestampValue": "2026-08-18T09:12:03.123Z"}}}}}},
        {"name": "…/users/minimal", "fields": {"pushDiagnostic": {"mapValue": {"fields": {
            "state": {"stringValue": "registered"},
            "at": {"timestampValue": "2026-08-18T10:00:00Z"}}}}}},
        {"name": "…/users/absent", "fields": {"contentLanguage": {"stringValue": "tr"}}},
        {"name": "…/users/notAMap", "fields": {"pushDiagnostic": {"stringValue": "denied"}}},
        {"name": "…/users/emptyMap", "fields": {"pushDiagnostic": {"mapValue": {}}}},
        {"name": "…/users/wrongTypes", "fields": {"pushDiagnostic": {"mapValue": {"fields": {
            "state": {"integerValue": "3"}, "at": {"stringValue": "yesterday"}}}}}},
    ]
    got = {uid: (state, detail, at) for uid, state, detail, at in device_reports(docs)}
    check("device/full", got["full"] == ("denied", "permissionRequestRefused",
                                         "2026-08-18T09:12:03.123Z"), f"got {got.get('full')}")
    check("device/minimal", got["minimal"] == ("registered", None, "2026-08-18T10:00:00Z"))
    check("device/absent", got["absent"] == (None, None, None))
    check("device/not-a-map", got["notAMap"] == (None, None, None),
          "a non-map value must read as no report, never as a state")
    check("device/empty-map", got["emptyMap"] == (None, None, None))
    check("device/wrong-types", got["wrongTypes"] == (None, None, None),
          "an integer state and a string timestamp are junk, not a diagnosis")
    check("device/every-account-listed", len(device_reports(docs)) == len(docs),
          "an account with no report must still appear — silence is a finding too")
    check("device/empty-input", device_reports([]) == [])


def test_absence_is_not_a_negative() -> None:
    """Lesson 65, at the one place this tool will spend most of its life.

    Until a build carrying ADR-049 ships, EVERY account reads as no-report, and a
    message that lets a session conclude 'the feature is broken' — or 'nobody
    tapped' — from that is worse than no message.
    """
    text = diagnose_device(None, None)
    check("absence/names-both-causes", "build" in text.lower() and "measur" in text.lower(),
          "must name BOTH the no-build cause and the never-got-that-far cause")
    check("absence/refuses-to-choose",
          "not distinguishable" in text.lower() or "cannot tell" in text.lower())
    check("absence/not-evidence", "evidence" in text.lower(),
          "must say plainly that this is not evidence of anything")


def test_each_device_state_names_a_different_link() -> None:
    states = ["notDetermined", "denied", "awaitingDeviceToken", "registered"]
    texts = [diagnose_device(s, None) for s in states]
    check("device-taxonomy/distinct", len(set(texts)) == len(texts),
          "two device states produced the same explanation — the ambiguity is back")
    for state, text in zip(states, texts):
        check(f"device-taxonomy/nonempty({state})", len(text) > 40)
    check("device-taxonomy/denied-names-settings",
          "Settings" in diagnose_device("denied", None),
          "denied is the ONE state no build can fix — the fix must be named")
    check("device-taxonomy/registered-defers-to-evidence",
          "claim" in diagnose_device("registered", None).lower(),
          "a self-reported 'registered' must defer to the server-owned token count")


def test_detail_sharpens_rather_than_replaces() -> None:
    for detail in DETAIL_DIAGNOSIS:
        text = diagnose_device("awaitingDeviceToken", detail)
        check(f"detail/kept({detail})", DEVICE_DIAGNOSIS["awaitingDeviceToken"][:30] in text,
              "the detail must SHARPEN the state, not replace its explanation")
        check(f"detail/present({detail})", DETAIL_DIAGNOSIS[detail][:20] in text)
    apns = diagnose_device("awaitingDeviceToken", "captureExhausted")
    server = diagnose_device("awaitingDeviceToken", "registerFailed")
    check("detail/the-219-discrimination", apns != server,
          "'APNs never answered' and 'the callable threw' share a state and MUST "
          "not share an explanation — telling them apart is the whole feature")


def test_unknown_vocabulary_degrades_honestly() -> None:
    """A newer build than this tool is a real case: the app ships on its own clock.

    An unrecognised word must be neither a crash nor a silent 'no report' — it is
    a report this tool cannot read, and it has to say so.
    """
    text = diagnose_device("provisionallyGranted", None)
    check("unknown-state/named", "provisionallyGranted" in text)
    check("unknown-state/not-absence", "no report" not in text.lower(),
          "an unreadable report must not be reported as no report at all")
    detail_text = diagnose_device("denied", "somethingNewer")
    check("unknown-detail/named", "somethingNewer" in detail_text)
    check("unknown-detail/keeps-state", "Settings" in detail_text,
          "an unknown detail must not cost the KNOWN state its explanation")


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
