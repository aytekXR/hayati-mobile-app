#!/usr/bin/env python3
"""Read the capabilities ticked on the App ID in Apple's Developer portal.

WHY THIS EXISTS. Three questions have sat in `docs/operator-expected.md` for
months with the same non-answer — *"a session cannot read the portal, so nobody
knows"*:

  * **4(a)** — is **Push Notifications** enabled? It gates the entire
    notification feature, because the entitlement must exist in the
    PROVISIONING PROFILE too and `match` fetches profiles readonly (ADR-032),
    so a build claiming `aps-environment` without the capability fails at
    CODESIGN.
  * **2(d)** — is **Associated Domains** enabled? ADR-040 removed that
    entitlement, and cost a release finding out.
  * the third capability question — is **App Attest** in the list? Prod App
    Check attestation cannot succeed without it (ADR-039).

None of the three is actually unanswerable. The portal's capability list is
readable over the App Store Connect API — the same credential the release lane
and `testflight_testers.py` already use — so "ask the founder to look" was a
missing tool, not a missing permission. QUERY THE PLATFORM, NOT THE DOCS.

WHAT IT IS NOT. It reads. It cannot tick a capability, and it deliberately has
no code path that could: enabling a capability changes how a real binary signs,
which is a founder decision, and a tool that could do it would also be a tool
that could do it by accident.

FAIL-CLOSED, ALWAYS. Exit codes are a taxonomy, not a boolean — the same one
`rules_drift.py` uses, for the same reason (ADR-041):

    0   MEASURED, and every --require capability is enabled
    1   MEASURED, and at least one --require capability is absent. The finding.
    2   COULD NOT MEASURE — no credential, an HTTP error, a 403 because this API
        key's role does not cover Certificates/Identifiers, a bundle id this key
        cannot see, an unexpected response shape, or a paginated list this tool
        did not fully follow. NEVER 0, and never 1.

THE 1-VERSUS-2 DISTINCTION IS THE WHOLE POINT. An App Store Connect key carries
a role. If it is not permitted to read Certificates, Identifiers & Profiles,
Apple answers **403** — and collapsing that into "the capability is not ticked"
would hand the founder a measured-sounding lie, and send a session off to build
around a blocker that may not exist. "I looked and it is absent" and "I could
not look" are different facts and this tool never conflates them.

PARTIAL IS NOT ABSENT, EITHER. If Apple paginates the capability list and this
tool holds only page one, the enabled set it has is incomplete — and an
incomplete set can only ever produce a FALSE absence. So an unfollowed `next`
link is exit 2, the same way `rules_drift.py` fails closed on a second
firestore release rather than comparing a partial view.

Run (CI, the manual dispatch lane):
    python3 tool/ci/appid_capabilities.py --bundle-id com.beyondkaira.hayati \
        --require PUSH_NOTIFICATIONS --require ASSOCIATED_DOMAINS --require APP_ATTEST

Run with no --require at all for a plain read-out of everything that is ticked.
"""

from __future__ import annotations

import argparse
import dataclasses
import importlib.util
import pathlib
import re
import sys
import urllib.parse

# The credential gate is IMPORTED, never re-implemented. `testflight_testers`
# already owns the one place this repo turns three secrets into an ES256
# assertion, including the fail-closed "name the missing variables, never their
# values" behaviour the release lane depends on. A second copy would be a second
# thing that can drift, and drift in a credential gate fails in the reassuring
# direction. Loaded by path because tool/ci is not a package and this must work
# regardless of the caller's cwd.
_SIBLING = pathlib.Path(__file__).with_name("testflight_testers.py")
_spec = importlib.util.spec_from_file_location("testflight_testers", _SIBLING)
assert _spec is not None and _spec.loader is not None
_tft = importlib.util.module_from_spec(_spec)
sys.modules.setdefault("testflight_testers", _tft)
_spec.loader.exec_module(_tft)

# Deliberately the SAME exception class, not a parallel one: a caller that
# catches AscError must catch it from either half of the credential path.
AscError = _tft.AscError

EXIT_OK = 0
EXIT_ABSENT = 1
EXIT_CANNOT_MEASURE = 2

# Apple's own spelling of the three capabilityType values this repo cares about.
# These strings ARE the contract: a typo can only ever report a ticked
# capability as absent, which is the false blocker this tool exists to prevent,
# so they are pinned by a self-test rather than trusted to a careful moment.
PUSH_NOTIFICATIONS = "PUSH_NOTIFICATIONS"
ASSOCIATED_DOMAINS = "ASSOCIATED_DOMAINS"
APP_ATTEST = "APP_ATTEST"
APPLE_ID_AUTH = "APPLE_ID_AUTH"

# The vocabulary a --require value is validated against. NOT a list of every
# capability Apple has — only the ones this repo has a reason to assert on. An
# unknown value is refused (exit 2) rather than reported absent, because an
# unknown value can ONLY come back absent and that would be a measurement-shaped
# guess. Same closed-vocabulary discipline as ADR-026's seasonalWindow.
KNOWN_CAPABILITIES = frozenset(
    {PUSH_NOTIFICATIONS, ASSOCIATED_DOMAINS, APP_ATTEST, APPLE_ID_AUTH}
)

# The portal click-path, printed with an "absent" verdict so the output is
# actionable by the person who has to act on it rather than only by CI.
PORTAL_PATH = (
    "Apple Developer portal -> Certificates, Identifiers & Profiles -> "
    "Identifiers -> {bundle_id} -> tick the capability -> Save"
)


def _redact(text: str) -> str:
    """Strip anything credential-shaped out of text bound for stdout.

    This tool prints Apple's own error bodies, and an HTTP failure raised from
    a request that carried an `Authorization: Bearer <assertion>` header is
    exactly where a signed JWT ends up in a public CI log. Same anti-leak
    sentinel as `slack_notify.sh` and `rules_drift.py`, and asserted by a test
    that plants a fake secret in an error message.
    """
    text = re.sub(r"[Bb]earer\s+\S+", "[redacted-credential]", text)
    # A bare JWT with no `Bearer` in front of it (a body that echoes the token).
    text = re.sub(r"eyJ[A-Za-z0-9_\-]{8,}(?:\.[A-Za-z0-9_\-]+){1,2}", "[redacted-jwt]", text)
    return text


@dataclasses.dataclass(frozen=True)
class Report:
    """One measurement. `exit_code` is the taxonomy; the lists are the evidence."""

    exit_code: int
    bundle_id: str
    #: Every capabilityType the portal reports as ticked, sorted. Empty on a
    #: could-not-measure, where it means "unknown", NOT "none".
    enabled: list[str]
    #: The requested capabilities that ARE ticked, in the order requested.
    present: list[str]
    #: The requested capabilities that are NOT ticked, in the order requested.
    #: ALWAYS empty on a could-not-measure — that is the invariant this whole
    #: file exists to hold.
    absent: list[str]
    #: Why, in one human sentence. Redacted.
    reason: str

    @property
    def measured(self) -> bool:
        return self.exit_code != EXIT_CANNOT_MEASURE


def _cannot_measure(bundle_id: str, reason: str) -> Report:
    return Report(
        exit_code=EXIT_CANNOT_MEASURE,
        bundle_id=bundle_id,
        enabled=[],
        present=[],
        absent=[],  # never populated here, by construction
        reason=_redact(reason),
    )


def find_bundle_id(call, identifier: str) -> str:
    """The App Store Connect primary key for `identifier`.

    Raises AscError when the key cannot see it — which the caller turns into
    exit 2, not into an absence: a bundle id this credential cannot resolve
    means the wrong App ID was read (or none was), never that the right one has
    no capabilities.
    """
    query = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": 200})
    payload = call("GET", f"/v1/bundleIds?{query}")
    entries = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(entries, list):
        raise AscError(f"unexpected /v1/bundleIds response shape for {identifier}")
    # filter[identifier] is a PREFIX-ish filter on Apple's side for some
    # resources, so match the attribute exactly rather than taking entries[0].
    # Taking the first row would happily return `com.beyondkaira.hayati.dev`.
    for entry in entries:
        attributes = entry.get("attributes") if isinstance(entry, dict) else None
        if isinstance(attributes, dict) and attributes.get("identifier") == identifier:
            key = entry.get("id")
            if not isinstance(key, str) or not key:
                raise AscError(f"bundle id {identifier} resolved to an entry with no id")
            return key
    raise AscError(
        f"no App ID with identifier {identifier} is visible to this API key "
        f"(the key may lack Certificates/Identifiers permission, or the App ID "
        f"may live in another team)"
    )


def list_capabilities(call, bundle_key: str) -> list[str]:
    """Every capabilityType ticked on the App ID, sorted.

    Fails CLOSED on a paginated response: holding page one only means the
    enabled set is PARTIAL, and a partial set can produce a false absence.
    """
    query = urllib.parse.urlencode({"limit": 200})
    payload = call("GET", f"/v1/bundleIds/{bundle_key}/bundleIdCapabilities?{query}")
    if not isinstance(payload, dict):
        raise AscError("unexpected bundleIdCapabilities response shape (not an object)")
    entries = payload.get("data")
    if not isinstance(entries, list):
        raise AscError("unexpected bundleIdCapabilities response shape ('data' is not a list)")

    links = payload.get("links")
    if isinstance(links, dict) and links.get("next"):
        raise AscError(
            "bundleIdCapabilities returned a paginated response and this read is "
            "PARTIAL; a partial capability list can only produce a false absence"
        )

    capabilities: list[str] = []
    for entry in entries:
        attributes = entry.get("attributes") if isinstance(entry, dict) else None
        capability = attributes.get("capabilityType") if isinstance(attributes, dict) else None
        if not isinstance(capability, str) or not capability:
            raise AscError(
                "a bundleIdCapabilities entry carries no capabilityType; the "
                "enabled set cannot be established from this response"
            )
        capabilities.append(capability)
    return sorted(set(capabilities))


def probe(call, bundle_id: str, required: list[str]) -> Report:
    """Measure `bundle_id`'s capabilities and judge them against `required`."""
    unknown = [name for name in required if name not in KNOWN_CAPABILITIES]
    if unknown:
        # Refused rather than reported absent: a capability name Apple has never
        # heard of comes back absent every single time, which is a false blocker
        # wearing a measurement's clothes.
        return _cannot_measure(
            bundle_id,
            "not a capability name this tool knows: "
            + ", ".join(unknown)
            + ". Known: "
            + ", ".join(sorted(KNOWN_CAPABILITIES)),
        )

    try:
        bundle_key = find_bundle_id(call, bundle_id)
        enabled = list_capabilities(call, bundle_key)
    except AscError as failure:
        message = str(failure)
        hint = ""
        if "403" in message or "FORBIDDEN" in message.upper():
            hint = (
                " -- a 403 here is almost always the API key's permission/role: "
                "reading Certificates, Identifiers & Profiles needs an Admin or "
                "App Manager key. This is NOT evidence about the capability."
            )
        elif "401" in message:
            hint = " -- the assertion was rejected; check the key id / issuer id."
        return _cannot_measure(bundle_id, message + hint)
    except Exception as failure:  # noqa: BLE001 - any surprise is still "could not look"
        return _cannot_measure(bundle_id, f"unexpected failure reading the portal: {failure}")

    enabled_set = set(enabled)
    present = [name for name in required if name in enabled_set]
    absent = [name for name in required if name not in enabled_set]
    return Report(
        exit_code=EXIT_ABSENT if absent else EXIT_OK,
        bundle_id=bundle_id,
        enabled=enabled,
        present=present,
        absent=absent,
        reason=(
            "every requested capability is ticked"
            if not absent
            else "absent from the portal's capability list: " + ", ".join(absent)
        ),
    )


def probe_or_explain(call, bundle_id: str, required: list[str]) -> Report:
    """`probe`, but a missing transport (i.e. a missing credential) is exit 2.

    The CI-without-secrets case. It is the same fact as a 403 — nobody looked —
    and it must not read as an absence either.
    """
    if call is None:
        return _cannot_measure(
            bundle_id,
            "no App Store Connect credential is available, so the portal was "
            "never read (see docs/operator-expected.md)",
        )
    return probe(call, bundle_id, required)


def render(report: Report) -> None:
    """Print the measurement. Written to be read by the FOUNDER, not only by CI."""
    print(f"App ID: {report.bundle_id}")

    if not report.measured:
        # Deliberate wording. A human skimming the log of a 403 run must not come
        # away believing anything about the capability itself.
        print("\nCOULD NOT MEASURE (exit 2) — nothing below is evidence about the portal.")
        print(f"  reason: {report.reason}")
        print("\nThis is NOT a finding. Nobody looked; the capabilities are unknown.")
        return

    print("\ncapabilities ticked on this App ID (the portal's own list):")
    if report.enabled:
        for capability in report.enabled:
            print(f"  - {capability}")
    else:
        print("  (none)")

    if report.present:
        print("\nrequested AND ticked:")
        for capability in report.present:
            print(f"  ok      {capability}")

    if report.absent:
        print("\nrequested and ABSENT from that list:")
        for capability in report.absent:
            print(f"  MISSING {capability}")
        print("\nto fix, one visit, one tick each:")
        print("  " + PORTAL_PATH.format(bundle_id=report.bundle_id))
        print(
            "\nUntil a capability is ticked, an entitlement claiming it cannot be "
            "signed: `match` fetches provisioning profiles READONLY (ADR-032), so "
            "CI cannot add it, and the build fails at codesign (ADR-040)."
        )
    else:
        print("\nevery requested capability is ticked.")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Read the capabilities ticked on an App ID (read-only).",
    )
    parser.add_argument("--bundle-id", required=True, help="e.g. com.beyondkaira.hayati")
    parser.add_argument(
        "--require",
        action="append",
        default=[],
        dest="required",
        metavar="CAPABILITY",
        help=(
            "Capability that must be ticked; repeatable. Absent -> exit 1. "
            "Omit entirely for a plain read-out. Known: "
            + ", ".join(sorted(KNOWN_CAPABILITIES))
        ),
    )
    args = parser.parse_args(argv)

    call = None
    try:
        token = _tft._token()

        def call(method: str, path: str) -> dict:  # noqa: F811 - the real transport
            return _tft._call(token, method, path)

    except AscError as failure:
        # A missing/partial credential set is exit 2 with the NAMES it is missing
        # (never the values) — testflight_testers._token already phrases it that
        # way, so the message is reused rather than restated.
        report = _cannot_measure(args.bundle_id, str(failure))
        render(report)
        return report.exit_code

    report = probe_or_explain(call, args.bundle_id, args.required)
    render(report)
    return report.exit_code


if __name__ == "__main__":
    sys.exit(main())
