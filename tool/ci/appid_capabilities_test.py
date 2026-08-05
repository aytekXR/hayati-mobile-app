#!/usr/bin/env python3
"""Self-tests for tool/ci/appid_capabilities.py (repo convention: every tool
under tool/ carries one, run by ci.yml's quality job).

Hermetic: no network, no Apple, no credential. Every test drives either a pure
function or an injected fake transport.

WHAT THESE TESTS ARE ACTUALLY DEFENDING. This tool exists to answer a question
that has been sitting in `operator-expected.md` as "nobody can read the portal
from a laptop" for months: is a capability ticked on the App ID? The whole
value of the answer is that it is TRUSTWORTHY, and there is exactly one way for
it to be worthless — reporting "not enabled" when what really happened is "this
API key is not allowed to look". Apple answers that case with an HTTP 403, and
a 403 that maps to exit 1 would hand the founder a measured-sounding lie and
send a session off to build around a blocker that may not exist.

So the mutation-relevant assertions here are the ones that pin the 0/1/2
TAXONOMY (ADR-041's, restated), not the ones that prove the happy path:

  * test_forbidden_is_cannot_measure_not_absent   <- the one that matters most
  * test_unauthorized_is_cannot_measure
  * test_missing_credentials_is_cannot_measure
  * test_unknown_bundle_id_is_cannot_measure
  * test_unexpected_shape_is_cannot_measure
  * test_paginated_response_fails_closed

Every one of those would pass if `evaluate` returned 2 unconditionally, which
is why the two directional tests exist alongside them
(`test_all_required_present_exits_zero` / `test_missing_required_exits_one`):
together they pin the guard in BOTH directions, which is the standing rule.

`test_bearer_token_is_never_printed` is the anti-leak sentinel, same shape as
rules_drift_test.py's and slack_notify_test.sh's: a tool that mints a signed
JWT and prints a report about a security artifact is exactly where a credential
ends up in a public CI log.

Run: python3 tool/ci/appid_capabilities_test.py
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import pathlib
import sys

_MODULE_PATH = pathlib.Path(__file__).with_name("appid_capabilities.py")
_spec = importlib.util.spec_from_file_location("appid_capabilities", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
ac = importlib.util.module_from_spec(_spec)
# Registered BEFORE exec: the module defines a @dataclass under `from __future__
# import annotations`, and dataclasses resolves those string annotations through
# sys.modules[cls.__module__]. A module loaded by path and never registered
# resolves to None there and the class body raises at import.
sys.modules["appid_capabilities"] = ac
_spec.loader.exec_module(ac)

_failures: list[str] = []


def check(label: str, actual: object, expected: object) -> None:
    if actual == expected:
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         expected: {expected!r}\n         actual:   {actual!r}")
        _failures.append(label)


def check_in(label: str, needle: str, haystack: str) -> None:
    if needle.lower() in haystack.lower():
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         wanted {needle!r} in: {haystack[:400]!r}")
        _failures.append(label)


def check_not_in(label: str, needle: str, haystack: str) -> None:
    if needle.lower() not in haystack.lower():
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         {needle!r} LEAKED into: {haystack[:400]!r}")
        _failures.append(label)


# --------------------------------------------------------------------------
# fakes


BUNDLE_PK = "ABCDE12345"


def fake_transport(pages: dict[str, object]):
    """A transport over a canned {path_prefix: response} map.

    Matching is by prefix so a test does not have to reproduce Apple's exact
    query-string ordering, which is an implementation detail of urlencode.
    """

    def call(method: str, path: str) -> dict:
        for prefix, response in pages.items():
            if path.startswith(prefix):
                if isinstance(response, Exception):
                    raise response
                return response
        raise AssertionError(f"fake transport has no canned response for {method} {path}")

    return call


def bundle_page(identifier: str = "com.beyondkaira.hayati") -> dict:
    return {"data": [{"id": BUNDLE_PK, "attributes": {"identifier": identifier, "name": "ikimiz"}}]}


def caps_page(types: list[str], next_link: str | None = None) -> dict:
    page: dict = {
        "data": [
            {"id": f"{BUNDLE_PK}_{t}", "attributes": {"capabilityType": t, "settings": []}}
            for t in types
        ]
    }
    if next_link is not None:
        page["links"] = {"next": next_link}
    return page


# --------------------------------------------------------------------------
# the taxonomy: 0 measured+present, 1 measured+absent, 2 could not measure


def test_all_required_present_exits_zero() -> None:
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": caps_page(
                ["PUSH_NOTIFICATIONS", "ASSOCIATED_DOMAINS", "APPLE_ID_AUTH"]
            ),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("all required present -> exit 0", report.exit_code, ac.EXIT_OK)
    check("present list is reported", report.present, ["PUSH_NOTIFICATIONS"])
    check("absent list is empty", report.absent, [])


def test_missing_required_exits_one() -> None:
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": caps_page(["APPLE_ID_AUTH"]),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS", "ASSOCIATED_DOMAINS"])
    check("a required capability absent -> exit 1", report.exit_code, ac.EXIT_ABSENT)
    check(
        "both absent capabilities are named",
        report.absent,
        ["PUSH_NOTIFICATIONS", "ASSOCIATED_DOMAINS"],
    )
    check("the enabled set is still reported", report.enabled, ["APPLE_ID_AUTH"])


def test_partial_presence_exits_one_and_separates_the_two() -> None:
    """The founder is asked for three ticks in one portal visit; a report that
    collapsed 'two of three' into a single verdict would send them back twice."""
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": caps_page(
                ["PUSH_NOTIFICATIONS", "APPLE_ID_AUTH"]
            ),
        }
    )
    report = ac.probe(
        call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS", "ASSOCIATED_DOMAINS", "APP_ATTEST"]
    )
    check("partial presence -> exit 1", report.exit_code, ac.EXIT_ABSENT)
    check("the ticked one is in present", report.present, ["PUSH_NOTIFICATIONS"])
    check(
        "the two unticked ones are in absent",
        report.absent,
        ["ASSOCIATED_DOMAINS", "APP_ATTEST"],
    )


def test_no_requirements_reports_and_exits_zero() -> None:
    """--require is optional: with none given the tool is a pure read-out and
    must not invent a finding."""
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": caps_page(["APPLE_ID_AUTH"]),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", [])
    check("read-out with no requirements -> exit 0", report.exit_code, ac.EXIT_OK)
    check("the enabled set is still reported", report.enabled, ["APPLE_ID_AUTH"])


# --------------------------------------------------------------------------
# THE tests: every "I could not look" is 2, never 1


def test_forbidden_is_cannot_measure_not_absent() -> None:
    """An App Store Connect key carries a ROLE. If it is not permitted to read
    Certificates, Identifiers & Profiles, Apple answers 403 — and mapping that
    to 'the capability is not enabled' is the single failure that would make
    this whole tool worse than not having it."""
    call = fake_transport({"/v1/bundleIds?": ac.AscError("GET /v1/bundleIds -> HTTP 403: FORBIDDEN")})
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("403 -> exit 2, NOT exit 1", report.exit_code, ac.EXIT_CANNOT_MEASURE)
    check("403 is not reported as absent", report.absent, [])
    check_in("the reason names the key's permissions", "permission", report.reason)


def test_unauthorized_is_cannot_measure() -> None:
    call = fake_transport({"/v1/bundleIds?": ac.AscError("GET /v1/bundleIds -> HTTP 401: NOT_AUTHORIZED")})
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("401 -> exit 2", report.exit_code, ac.EXIT_CANNOT_MEASURE)
    check("401 is not reported as absent", report.absent, [])


def test_unknown_bundle_id_is_cannot_measure() -> None:
    """A bundle id this key cannot see is 'I could not look at the right App
    ID', not 'that App ID has no capabilities'."""
    call = fake_transport({"/v1/bundleIds?": {"data": []}})
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("no such bundle id -> exit 2", report.exit_code, ac.EXIT_CANNOT_MEASURE)
    check("no such bundle id is not reported as absent", report.absent, [])
    check_in("the reason names the bundle id", "com.beyondkaira.hayati", report.reason)


def test_a_near_miss_bundle_id_is_never_accepted() -> None:
    """Apple's filter[identifier] is not guaranteed to be an exact match, and a
    team that also owns `com.beyondkaira.hayati.dev` would get that row back.
    Reading the WRONG App ID's capabilities is the worst outcome available here:
    it produces a confident, measured, completely inapplicable answer.

    Added because the mutation harness proved this was unasserted — replacing
    the identifier comparison with `if True:` reddened nothing.
    """
    call = fake_transport(
        {
            "/v1/bundleIds?": {
                "data": [
                    # deliberately FIRST, so entries[0] is the wrong one
                    {"id": "WRONGPK", "attributes": {"identifier": "com.beyondkaira.hayati.dev"}},
                    {"id": BUNDLE_PK, "attributes": {"identifier": "com.beyondkaira.hayati"}},
                ]
            },
            "/v1/bundleIds/WRONGPK/bundleIdCapabilities": caps_page(["PUSH_NOTIFICATIONS"]),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": caps_page(["APPLE_ID_AUTH"]),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("the exactly-matching App ID is the one read", report.enabled, ["APPLE_ID_AUTH"])
    check("so the verdict is the real one -> exit 1", report.exit_code, ac.EXIT_ABSENT)


def test_only_a_near_miss_present_is_cannot_measure() -> None:
    """If the exact identifier is not in the response at all, the answer is 'I
    could not find the App ID', never 'that App ID has no capabilities'."""
    call = fake_transport(
        {
            "/v1/bundleIds?": {
                "data": [{"id": "WRONGPK", "attributes": {"identifier": "com.beyondkaira.hayati.dev"}}]
            },
            "/v1/bundleIds/WRONGPK/bundleIdCapabilities": caps_page(["PUSH_NOTIFICATIONS"]),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("only a near-miss row -> exit 2", report.exit_code, ac.EXIT_CANNOT_MEASURE)
    check("a near-miss row is never reported as absence", report.absent, [])


def test_capability_call_failure_is_cannot_measure() -> None:
    """The bundle id resolves and the SECOND call dies: still 'could not look'."""
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": ac.AscError(
                "GET /v1/bundleIds/X/bundleIdCapabilities -> HTTP 403: FORBIDDEN"
            ),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("capability read failure -> exit 2", report.exit_code, ac.EXIT_CANNOT_MEASURE)
    check("capability read failure is not absence", report.absent, [])


def test_unexpected_shape_is_cannot_measure() -> None:
    """Apple changing the response shape must not silently read as 'nothing is
    enabled' — only the vendor can refute a vendor API shape, so an unparseable
    body is a measurement failure."""
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": {"data": "not-a-list"},
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("unparseable capability payload -> exit 2", report.exit_code, ac.EXIT_CANNOT_MEASURE)
    check("unparseable payload is not absence", report.absent, [])


def test_capability_entry_without_a_type_is_cannot_measure() -> None:
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": {
                "data": [{"id": "x", "attributes": {"settings": []}}]
            },
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("capability entry with no capabilityType -> exit 2", report.exit_code, ac.EXIT_CANNOT_MEASURE)


def test_paginated_response_fails_closed() -> None:
    """A second page this tool did not follow means the enabled set it holds is
    PARTIAL, and a partial set can only produce a false 'absent'. Same shape as
    rules_drift.py failing closed on a second firestore release."""
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": caps_page(
                ["APPLE_ID_AUTH"], next_link="https://api.appstoreconnect.apple.com/v1/...&cursor=2"
            ),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("an unfollowed next page -> exit 2", report.exit_code, ac.EXIT_CANNOT_MEASURE)
    check("a partial page is never reported as absence", report.absent, [])
    check_in("the reason says the read was partial", "partial", report.reason)


def test_missing_credentials_is_cannot_measure() -> None:
    """No credential is the CI-without-secrets case. It must be 2 and it must
    name the missing variables, never their values (the release lane's rule)."""
    report = ac.probe_or_explain(None, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    check("no transport/credential -> exit 2", report.exit_code, ac.EXIT_CANNOT_MEASURE)
    check("no credential is not absence", report.absent, [])


# --------------------------------------------------------------------------
# reporting


def test_report_prints_the_full_enabled_set_even_when_it_passes() -> None:
    """One portal visit answers three questions (4(a) Push, 2(d) Associated
    Domains, App Attest). The read-out must print everything it saw, not only
    the verdict on what was asked."""
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": caps_page(
                ["PUSH_NOTIFICATIONS", "APPLE_ID_AUTH", "IN_APP_PURCHASE"]
            ),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        ac.render(report)
    printed = buffer.getvalue()
    check_in("prints APPLE_ID_AUTH it was never asked about", "APPLE_ID_AUTH", printed)
    check_in("prints IN_APP_PURCHASE it was never asked about", "IN_APP_PURCHASE", printed)
    check_in("prints the bundle id", "com.beyondkaira.hayati", printed)


def test_absent_report_names_the_portal_path() -> None:
    """The output is read by the founder, not only by CI: an 'absent' verdict
    must carry the click-path that fixes it."""
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": caps_page(["APPLE_ID_AUTH"]),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        ac.render(report)
    printed = buffer.getvalue()
    check_in("names Identifiers", "identifiers", printed)
    check_in("names the missing capability", "PUSH_NOTIFICATIONS", printed)


def test_cannot_measure_report_never_says_not_enabled() -> None:
    """Prose matters as much as the exit code here: a human reading the log of
    a 403 run must not come away believing the capability is off."""
    call = fake_transport({"/v1/bundleIds?": ac.AscError("GET /v1/bundleIds -> HTTP 403: FORBIDDEN")})
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        ac.render(report)
    printed = buffer.getvalue()
    check_in("says it could not measure", "could not measure", printed)
    check_not_in("never claims the capability is not enabled", "is not enabled", printed)


def test_bearer_token_is_never_printed() -> None:
    """The anti-leak sentinel. The report is designed to be pasted into an
    issue and read by the founder; a signed JWT must never ride along."""
    secret = "eyJhbGciOiJFUzI1NiJ9.THIS-IS-THE-SECRET.signature"
    call = fake_transport(
        {
            "/v1/bundleIds?": ac.AscError(
                f"GET /v1/bundleIds -> HTTP 403: FORBIDDEN (Authorization: Bearer {secret})"
            )
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATIONS"])
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        ac.render(report)
    printed = buffer.getvalue()
    check_not_in("the JWT body never reaches stdout", "THIS-IS-THE-SECRET", printed)
    check_not_in("no 'Bearer ' prefix reaches stdout", "bearer ", printed)


# --------------------------------------------------------------------------
# the capability vocabulary is asserted, not assumed


def test_known_capability_names_are_apple_s_own_spelling() -> None:
    """These three strings are the whole contract with Apple. A typo turns a
    real tick into a reported absence, which is the false-blocker this tool
    exists to prevent — so they are pinned by a test rather than trusted to a
    careful moment."""
    check("push", ac.PUSH_NOTIFICATIONS, "PUSH_NOTIFICATIONS")
    check("associated domains", ac.ASSOCIATED_DOMAINS, "ASSOCIATED_DOMAINS")
    check("app attest", ac.APP_ATTEST, "APP_ATTEST")


def test_requirements_are_validated_against_the_known_vocabulary() -> None:
    """A --require value Apple has never heard of can only ever report absent,
    which is a false blocker dressed as a measurement. Refuse it instead."""
    call = fake_transport(
        {
            "/v1/bundleIds?": bundle_page(),
            f"/v1/bundleIds/{BUNDLE_PK}/bundleIdCapabilities": caps_page(["PUSH_NOTIFICATIONS"]),
        }
    )
    report = ac.probe(call, "com.beyondkaira.hayati", ["PUSH_NOTIFICATION"])  # missing S
    check("an unknown --require value -> exit 2", report.exit_code, ac.EXIT_CANNOT_MEASURE)
    check("an unknown --require value is not absence", report.absent, [])
    check_in("the reason names the typo", "PUSH_NOTIFICATION", report.reason)


# --------------------------------------------------------------------------

TESTS = [value for name, value in sorted(globals().items()) if name.startswith("test_")]

if __name__ == "__main__":
    print(f"appid_capabilities self-tests ({len(TESTS)} cases)\n")
    for test in TESTS:
        print(f"{test.__name__}:")
        test()
    print()
    if _failures:
        print(f"FAILED ({len(_failures)}): " + ", ".join(_failures))
        raise SystemExit(1)
    print("all green")
