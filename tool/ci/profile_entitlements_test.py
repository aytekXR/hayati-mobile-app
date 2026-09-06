#!/usr/bin/env python3
"""Self-tests for tool/ci/profile_entitlements.py (repo convention: every tool
under tool/ carries one, run by ci.yml's quality job).

Hermetic: no network, no Apple, no credential. Every test drives a pure function
or an injected fake transport.

WHAT THESE ARE DEFENDING. This tool exists to answer the question that outlived
`appid_capabilities.py`: the App ID capability is ticked and the phone still gets
no push, because iOS checks the **profile**, not the portal. Its answer decides
whether the founder is asked to run a `MATCH_BOOTSTRAP` release — a one-shot,
signing-affecting operation — so a wrong answer costs either a broken release or
another blind build.

There is exactly one way for it to be worthless: reporting "not granted" when
what really happened is "nobody looked". That is the 1-versus-2 distinction, and
it has more ways to go wrong here than in the capability probe, because a profile
can be absent, invalid, or undecodable and only ONE of those is a finding:

  * test_no_matching_profile_is_cannot_measure   <- the one that matters most
  * test_undecodable_profile_is_cannot_measure
  * test_invalid_profile_does_not_count_as_granting
  * test_http_failure_is_cannot_measure
  * test_pagination_is_followed

All of those pass if `probe` returned 2 unconditionally, so the two directional
tests pin the guard from the other side (`test_granted_exits_zero` /
`test_not_granted_exits_one`).

`test_only_requested_values_are_printed` is the disclosure sentinel: this runs in
a PUBLIC Actions log over an artifact that also carries developer certificates
and a device list.

Run: python3 tool/ci/profile_entitlements_test.py
"""

from __future__ import annotations

import base64
import contextlib
import importlib.util
import io
import pathlib
import plistlib
import sys

_MODULE_PATH = pathlib.Path(__file__).with_name("profile_entitlements.py")
_spec = importlib.util.spec_from_file_location("profile_entitlements", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
pe = importlib.util.module_from_spec(_spec)
# Registered BEFORE exec, for the reason appid_capabilities_test.py records: the
# module defines dataclasses under `from __future__ import annotations`, and
# dataclasses resolves those strings through sys.modules[cls.__module__].
sys.modules["profile_entitlements"] = pe
_spec.loader.exec_module(pe)

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
# fixtures — a .mobileprovision is DER with an XML plist buried in it, so the
# fake is built the same way rather than as a bare plist. A fixture that was
# just a plist would let a `find`-based slicer pass while the real format broke.

BUNDLE_PK = "BID123"
DER_PREFIX = bytes([0x30, 0x82, 0x0B, 0xEE]) + b"\x00\xa0\x03\x02\x01" * 8
DER_SUFFIX = b"\x00\x01\x02signature-bytes-that-are-not-utf8\xff\xfe"

#: A developer certificate is DATA inside the plist. It is in the fixture on
#: purpose: the disclosure sentinel needs something that must NOT be printed.
FAKE_CERT = b"CERTIFICATE-DER-THAT-MUST-NEVER-BE-PRINTED"


def mobileprovision(entitlements: dict, *, name: str = "match AppStore x") -> str:
    document = {
        "Name": name,
        "TeamIdentifier": ["UH7MXG7Z94"],
        "DeveloperCertificates": [FAKE_CERT],
        "ProvisionedDevices": ["00008030-000000000000000E"],
        "Entitlements": entitlements,
    }
    blob = DER_PREFIX + plistlib.dumps(document) + DER_SUFFIX
    return base64.b64encode(blob).decode()


PUSH_ENTITLEMENTS = {
    "application-identifier": "UH7MXG7Z94.com.beyondkaira.hayati",
    "aps-environment": "production",
    "com.apple.developer.applesignin": ["Default"],
    "com.apple.developer.team-identifier": "UH7MXG7Z94",
}

NO_PUSH_ENTITLEMENTS = {
    "application-identifier": "UH7MXG7Z94.com.beyondkaira.hayati",
    "com.apple.developer.applesignin": ["Default"],
    "com.apple.developer.team-identifier": "UH7MXG7Z94",
}


def profile_row(
    content: str,
    *,
    state: str = "ACTIVE",
    profile_type: str = "IOS_APP_STORE",
    name: str = "match AppStore com.beyondkaira.hayati",
    bundle_pk: str = BUNDLE_PK,
) -> dict:
    return {
        "type": "profiles",
        "id": "PROF1",
        "attributes": {
            "name": name,
            "uuid": "7ae73b07-ddba-4998-96d4-89281fa5b1e4",
            "profileType": profile_type,
            "profileState": state,
            "createdDate": "2026-05-01T10:00:00Z",
            "expirationDate": "2027-05-01T10:00:00Z",
            "profileContent": content,
        },
        "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_pk}}},
    }


def payload(rows: list[dict], *, next_link: str = "") -> dict:
    body: dict = {
        "data": rows,
        "included": [
            {
                "type": "bundleIds",
                "id": BUNDLE_PK,
                "attributes": {"identifier": "com.beyondkaira.hayati"},
            }
        ],
    }
    if next_link:
        body["links"] = {"next": next_link}
    return body


def transport(responses: list[dict], seen: list[str] | None = None):
    """Answers successive calls from `responses`, recording every path."""
    calls = {"n": 0}

    def call(method: str, path: str) -> dict:
        if seen is not None:
            seen.append(path)
        index = min(calls["n"], len(responses) - 1)
        calls["n"] += 1
        return responses[index]

    return call


def rendered(report) -> str:
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        pe.render(report)
    return buffer.getvalue()


# --------------------------------------------------------------------------
# the plist slicer


def test_entitlements_are_sliced_out_of_der():
    got = pe.entitlements_of(mobileprovision(PUSH_ENTITLEMENTS))
    check("aps-environment is read from inside the DER", got.get("aps-environment"), "production")


def test_last_plist_terminator_wins():
    """`rfind`, not `find` — a `</plist>` inside a VALUE must not truncate.

    A `find`-based slicer parses a prefix of the document, which `plistlib`
    happily accepts as a smaller dictionary: a WRONG ANSWER rather than an
    error, and the only failure mode worth engineering against here.
    """
    hostile = dict(PUSH_ENTITLEMENTS)
    hostile["keychain-access-groups"] = ["</plist>"]
    got = pe.entitlements_of(mobileprovision(hostile))
    check("a hostile value does not truncate the parse", got.get("aps-environment"), "production")


def test_content_without_a_plist_raises():
    junk = base64.b64encode(b"no plist here at all").decode()
    try:
        pe.entitlements_of(junk)
        check("content with no plist raises", "no raise", "AscError")
    except pe.AscError as failure:
        check_in("content with no plist raises", "no XML plist", str(failure))


# --------------------------------------------------------------------------
# the taxonomy


def test_granted_exits_zero():
    call = transport([payload([profile_row(mobileprovision(PUSH_ENTITLEMENTS))])])
    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    check("a profile that grants it -> exit 0", report.exit_code, pe.EXIT_OK)
    check("nothing is reported missing", report.missing, ())


def test_not_granted_exits_one():
    """The finding this whole tool exists to be able to make."""
    call = transport([payload([profile_row(mobileprovision(NO_PUSH_ENTITLEMENTS))])])
    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    check("a profile without it -> exit 1", report.exit_code, pe.EXIT_ABSENT)
    check("and it is NAMED", report.missing, ("aps-environment",))
    check_in("the report says what to do", "MATCH_BOOTSTRAP", rendered(report))


def test_no_matching_profile_is_cannot_measure():
    """Absence of a profile is NOT absence of an entitlement.

    Collapsing these would report a finding about a signing artifact nobody
    read — and send the founder to regenerate a profile on no evidence.
    """
    call = transport([payload([])])
    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    check("no profile at all -> exit 2", report.exit_code, pe.EXIT_CANNOT_MEASURE)
    check("and NOT a finding", report.missing, ())
    check_in("the reason says nobody looked", "visible to this API key", report.reason)


def test_wrong_profile_type_is_not_a_finding():
    call = transport(
        [payload([profile_row(mobileprovision(PUSH_ENTITLEMENTS), profile_type="IOS_APP_DEVELOPMENT")])]
    )
    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    check("a development profile is not the one signed with", report.exit_code, pe.EXIT_CANNOT_MEASURE)


def test_another_apps_profile_is_not_read():
    """Matched on the bundleId RELATIONSHIP, never on the profile's name."""
    row = profile_row(mobileprovision(PUSH_ENTITLEMENTS), bundle_pk="SOMEONE-ELSE")
    call = transport([payload([row])])
    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    check("a profile for another App ID is skipped", report.exit_code, pe.EXIT_CANNOT_MEASURE)


def test_invalid_profile_does_not_count_as_granting():
    """An INVALID profile is one the lane cannot use; what it grants is history.

    This is the shape that would hide the real defect: Apple keeps the old,
    now-invalid profile listed, and reading it as evidence would report a
    healthy entitlement for a build that cannot use it.
    """
    call = transport([payload([profile_row(mobileprovision(PUSH_ENTITLEMENTS), state="INVALID")])])
    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    check("an INVALID profile does not satisfy --require", report.exit_code, pe.EXIT_ABSENT)


def test_undecodable_profile_is_cannot_measure():
    call = transport([payload([profile_row(base64.b64encode(b"garbage").decode())])])
    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    check("an undecodable profile -> exit 2", report.exit_code, pe.EXIT_CANNOT_MEASURE)
    check_in("and it is visible in the read-out", "COULD NOT DECODE", rendered(report))


def test_http_failure_is_cannot_measure():
    def call(method: str, path: str) -> dict:
        raise pe.AscError("GET /v1/profiles -> HTTP 403: FORBIDDEN")

    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    check("a 403 -> exit 2, never 1", report.exit_code, pe.EXIT_CANNOT_MEASURE)
    check_in("the reason keeps Apple's status", "403", report.reason)


def test_pagination_is_followed():
    """A `links.next` this tool ignored turns a page-1 absence into a finding."""
    seen: list[str] = []
    first = payload([profile_row(mobileprovision(NO_PUSH_ENTITLEMENTS), name="old")],
                    next_link=pe._tft.API + "/v1/profiles?cursor=PAGE2")
    second = payload([profile_row(mobileprovision(PUSH_ENTITLEMENTS), name="new")])
    call = transport([first, second], seen)
    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    check("page 2 is fetched", len(seen), 2)
    check("the cursor is passed through", "cursor=PAGE2" in seen[1], True)
    check("and the grant on page 2 counts", report.exit_code, pe.EXIT_OK)


# --------------------------------------------------------------------------
# disclosure


def test_only_requested_values_are_printed():
    """A profile carries developer certificates and a device list. This runs in
    a PUBLIC Actions log, so keys are printed and values are not — except for
    the keys the caller named, which are already in this repo's own
    Runner.entitlements."""
    call = transport([payload([profile_row(mobileprovision(PUSH_ENTITLEMENTS))])])
    report = pe.probe(call, "com.beyondkaira.hayati", ["aps-environment"], "IOS_APP_STORE")
    text = rendered(report)
    check_in("the requested key's value IS shown", "production", text)
    check_in("other keys are shown by NAME", "com.apple.developer.team-identifier", text)
    check_not_in("but not their values", "UH7MXG7Z94", text)
    check_not_in("no certificate bytes", "CERTIFICATE-DER", text)
    check_not_in("no device udids", "00008030", text)


def test_facts_never_carry_unrequested_values():
    """The structural half of the sentinel: `render` cannot print what `granted`
    does not hold, so the guarantee is pinned at the data rather than at the
    formatting."""
    fact = pe.facts_of(profile_row(mobileprovision(PUSH_ENTITLEMENTS)), ("aps-environment",))
    check("granted holds only the requested key", sorted(fact.granted), ["aps-environment"])
    check_in("keys still list the others", "com.apple.developer.applesignin", ", ".join(fact.keys))


# --------------------------------------------------------------------------

TESTS = [value for name, value in sorted(globals().items()) if name.startswith("test_")]

if __name__ == "__main__":
    print(f"profile_entitlements self-tests ({len(TESTS)} cases)\n")
    for test in TESTS:
        print(f"{test.__name__}:")
        test()
    print()
    if _failures:
        print(f"FAILED ({len(_failures)}): " + ", ".join(_failures))
        raise SystemExit(1)
    print("all green")
