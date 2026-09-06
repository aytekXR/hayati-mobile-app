#!/usr/bin/env python3
"""Does the PROVISIONING PROFILE carry the entitlement the binary claims?

WHY THIS EXISTS. `appid_capabilities.py` answers *is the capability ticked on
the App ID*, and on 2026-09-06 it answered **yes** for `PUSH_NOTIFICATIONS`.
That is not the question a phone asks.

An entitlement has to survive **three** places, and this repo could read two:

    Runner.entitlements  ->  the App ID capability  ->  the PROVISIONING PROFILE
    (in git, readable)       (appid_capabilities)      (nothing could read it)

iOS checks the **third**. A binary signed with `aps-environment` whose embedded
profile does not grant it installs, launches, and is refused by APNs at runtime
with *"no valid 'aps-environment' entitlement string found for application"* —
which is exactly the silence ADR-074 was written to make audible, one link
further out.

⚠️ **AND THE THIRD IS THE ONE THAT CAN SILENTLY GO STALE.** `match` fetches
profiles **readonly** (ADR-032), so CI can never mint one. Ticking a capability
invalidates the App ID's existing profiles and the documented recovery is a
single `MATCH_BOOTSTRAP=true` release run — which, per `git log` and ADR-032, has
happened exactly once, at bootstrap, long before `PUSH_NOTIFICATIONS` was ticked
on 2026-08-06. Nobody has ever verified what the profile in use actually grants.

So this tool reads the profile Apple is serving and prints WHAT IT GRANTS.

HOW, since the ASC API has no "entitlements" field: `/v1/profiles` returns
`profileContent`, base64 of the `.mobileprovision` — a CMS-signed blob with a
plain XML plist inside it, and the plist has an `Entitlements` dictionary. No
signature verification is attempted or needed: Apple served the bytes over TLS,
and the question is what they SAY, not whether they are authentic.

WHAT IT PRINTS, AND WHAT IT REFUSES TO. Profile name, uuid, type, state and
dates; the sorted **KEYS** of the entitlements dictionary; and the *value* of
any key whose name was passed to `--require`. Nothing else — a profile also
carries `DeveloperCertificates` (full DER certificates) and the team's device
list, and this runs in a **public** Actions log. Values are printed only for
keys the caller named, because those are keys that are already in this
repository's own `Runner.entitlements`.

EXIT CODES (the `rules_drift.py` / ADR-041 taxonomy):

    0   MEASURED, and every --require entitlement is granted by a matching
        profile
    1   MEASURED, and at least one is NOT. The finding — and the one that
        explains a phone APNs will not talk to.
    2   COULD NOT MEASURE — no credential, an HTTP error, a 403 because this
        key's role does not cover Certificates/Identifiers, no profile matching
        the filter, an undecodable profile, or a paginated list this tool did
        not fully follow. NEVER 0, and never 1.

USAGE:

    python3 tool/ci/profile_entitlements.py --bundle-id com.beyondkaira.hayati \\
        --require aps-environment
"""
from __future__ import annotations

import argparse
import base64
import dataclasses
import importlib.util
import pathlib
import plistlib
import sys
import urllib.parse

# The transport is `testflight_testers`' — one JWT minter and one `_call` in this
# repo, for the reason `appid_capabilities.py` gives: a second copy is a second
# thing to get wrong about a credential, and the first copy already fails closed
# with the missing NAMES.
def _sibling(name: str):
    """Load a neighbouring tool by path, REGISTERED BEFORE EXEC.

    ⚠️ The registration is not tidiness. Both modules define dataclasses under
    `from __future__ import annotations`, and `dataclasses` resolves those
    string annotations through `sys.modules[cls.__module__]`; a module loaded by
    path and never registered resolves to `None` there and the class body raises
    at import. Learned here the expensive way — a lazy import of the redactor
    blew up inside the ONE code path that handles an Apple error, so the failure
    surfaced only when something else had already gone wrong.
    """
    path = pathlib.Path(__file__).resolve().parent / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


_tft = _sibling("testflight_testers")
# The read half's redactor, reused rather than re-derived: a second copy is a
# second thing to get wrong about what may reach a public log.
_capabilities = _sibling("appid_capabilities")
AscError = _tft.AscError

EXIT_OK = 0
EXIT_ABSENT = 1
EXIT_CANNOT_MEASURE = 2

#: The profile the release lane actually signs with (`match` type `appstore`).
DEFAULT_PROFILE_TYPE = "IOS_APP_STORE"

#: Apple caps `limit` at 200 for this collection.
PAGE_SIZE = 200


@dataclasses.dataclass(frozen=True)
class ProfileFacts:
    """One profile, reduced to what may be printed in a public log."""

    name: str
    uuid: str
    profile_type: str
    state: str
    created: str
    expires: str
    #: Sorted entitlement KEYS. Never the values, except via `granted` below.
    keys: tuple[str, ...]
    #: {requested key: value} for the keys the caller named, and only those.
    granted: dict[str, object]
    #: Set when this profile's content could not be decoded at all.
    undecodable: str = ""


@dataclasses.dataclass(frozen=True)
class Report:
    bundle_id: str
    profile_type: str
    required: tuple[str, ...]
    profiles: tuple[ProfileFacts, ...]
    #: Requested entitlements granted by NO matching profile.
    missing: tuple[str, ...]
    exit_code: int
    reason: str = ""


def entitlements_of(profile_content_b64: str) -> dict:
    """The `Entitlements` dict inside a base64 `.mobileprovision`.

    A `.mobileprovision` is CMS/PKCS#7 DER with an XML plist payload. Rather than
    depending on a CMS parser, the plist is sliced out by its own delimiters —
    the shape Apple has served for the life of the format, and the shape every
    other tool that reads these uses.

    ⚠️ The slice is anchored on `<?xml` and the LAST `</plist>`. `rfind` matters:
    the entitlements dictionary can itself contain the literal `</plist>` inside
    a string value in principle, and a `find` would truncate the document into
    something `plistlib` parses PARTIALLY — a wrong answer rather than an error,
    which is the only failure mode worth engineering against here.
    """
    raw = base64.b64decode(profile_content_b64, validate=False)
    start = raw.find(b"<?xml")
    end = raw.rfind(b"</plist>")
    if start == -1 or end == -1:
        raise AscError("profile content carries no XML plist payload")
    document = plistlib.loads(raw[start : end + len(b"</plist>")])
    entitlements = document.get("Entitlements")
    if not isinstance(entitlements, dict):
        raise AscError("profile plist has no Entitlements dictionary")
    return entitlements


def fetch_profiles(call, bundle_id: str, profile_type: str) -> list[dict]:
    """Every profile of `profile_type` whose App ID is `bundle_id`.

    The bundle id is resolved through each profile's `bundleId` relationship
    rather than by name: `match AppStore com.beyondkaira.hayati` is a convention,
    not a guarantee, and matching on a string someone can rename would make this
    tool quietly report on the wrong app.

    Pagination is FOLLOWED, not sampled. A `links.next` this tool ignored would
    turn "no profile grants it" into a claim about the first page only — the
    exact shape of a finding that is really a could-not-measure.
    """
    query = urllib.parse.urlencode(
        {
            "limit": PAGE_SIZE,
            "include": "bundleId",
            "fields[profiles]": (
                "name,uuid,profileType,profileState,createdDate,"
                "expirationDate,profileContent,bundleId"
            ),
            "fields[bundleIds]": "identifier",
        }
    )
    path = f"/v1/profiles?{query}"
    profiles: list[dict] = []
    identifiers: dict[str, str] = {}
    pages = 0
    while path:
        payload = call("GET", path)
        for included in payload.get("included", []):
            if included.get("type") == "bundleIds":
                identifiers[included.get("id", "")] = (
                    included.get("attributes", {}) or {}
                ).get("identifier", "")
        profiles.extend(payload.get("data", []))
        pages += 1
        nxt = (payload.get("links", {}) or {}).get("next", "")
        # Apple returns an absolute URL; `_call` prepends the API root, so the
        # prefix is stripped rather than the transport duplicated.
        path = nxt.replace(_tft.API, "", 1) if nxt else ""
        if pages > 50:
            raise AscError("profile list did not terminate after 50 pages")

    matching = []
    for profile in profiles:
        attributes = profile.get("attributes", {}) or {}
        if attributes.get("profileType") != profile_type:
            continue
        related = (
            ((profile.get("relationships", {}) or {}).get("bundleId", {}) or {}).get(
                "data", {}
            )
            or {}
        ).get("id", "")
        if identifiers.get(related) == bundle_id:
            matching.append(profile)
    return matching


def facts_of(profile: dict, required: tuple[str, ...]) -> ProfileFacts:
    attributes = profile.get("attributes", {}) or {}
    base = dict(
        name=str(attributes.get("name", "")),
        uuid=str(attributes.get("uuid", "")),
        profile_type=str(attributes.get("profileType", "")),
        state=str(attributes.get("profileState", "")),
        created=str(attributes.get("createdDate", "")),
        expires=str(attributes.get("expirationDate", "")),
    )
    try:
        entitlements = entitlements_of(str(attributes.get("profileContent", "")))
    except Exception as failure:  # noqa: BLE001 - one bad profile is not a crash
        return ProfileFacts(
            **base, keys=(), granted={}, undecodable=str(failure)
        )
    return ProfileFacts(
        **base,
        keys=tuple(sorted(str(key) for key in entitlements)),
        # ONLY the requested keys' values leave this function — see the module
        # docstring's rule about a public Actions log.
        granted={key: entitlements[key] for key in required if key in entitlements},
    )


def probe(call, bundle_id: str, required: list[str], profile_type: str) -> Report:
    wanted = tuple(required)
    try:
        raw = fetch_profiles(call, bundle_id, profile_type)
    except AscError as failure:
        return Report(
            bundle_id=bundle_id,
            profile_type=profile_type,
            required=wanted,
            profiles=(),
            missing=(),
            exit_code=EXIT_CANNOT_MEASURE,
            reason=_capabilities._redact(str(failure)),
        )

    if not raw:
        # NOT "the entitlement is missing" — nobody looked at a profile at all.
        return Report(
            bundle_id=bundle_id,
            profile_type=profile_type,
            required=wanted,
            profiles=(),
            missing=(),
            exit_code=EXIT_CANNOT_MEASURE,
            reason=(
                f"no {profile_type} profile for {bundle_id} is visible to this "
                "API key — so nothing here is evidence about what the release "
                "lane signs with"
            ),
        )

    facts = tuple(facts_of(profile, wanted) for profile in raw)

    if all(fact.undecodable for fact in facts):
        return Report(
            bundle_id=bundle_id,
            profile_type=profile_type,
            required=wanted,
            profiles=facts,
            missing=(),
            exit_code=EXIT_CANNOT_MEASURE,
            reason="every matching profile failed to decode",
        )

    # An entitlement counts as granted when SOME ACTIVE profile grants it. An
    # INVALID profile is one the lane cannot use, so what it grants is history.
    usable = [f for f in facts if f.state == "ACTIVE" and not f.undecodable]
    missing = tuple(
        key for key in wanted if not any(key in fact.granted for fact in usable)
    )
    return Report(
        bundle_id=bundle_id,
        profile_type=profile_type,
        required=wanted,
        profiles=facts,
        missing=missing,
        exit_code=EXIT_ABSENT if missing else EXIT_OK,
    )


def render(report: Report) -> None:
    print(f"{report.bundle_id}: {report.profile_type} provisioning profiles")
    for fact in report.profiles:
        print(f"  {fact.name or '(unnamed)'}  [{fact.state}]  uuid={fact.uuid}")
        print(f"    created {fact.created}   expires {fact.expires}")
        if fact.undecodable:
            print(f"    ⚠️ COULD NOT DECODE: {fact.undecodable}")
            continue
        print(f"    entitlement keys ({len(fact.keys)}): {', '.join(fact.keys)}")
        for key in report.required:
            if key in fact.granted:
                print(f"    ✅ {key} = {fact.granted[key]!r}")
            else:
                print(f"    ❌ {key} — NOT GRANTED by this profile")

    if report.exit_code == EXIT_CANNOT_MEASURE:
        print(f"\nCOULD NOT MEASURE: {report.reason}")
        return
    if report.missing:
        print(
            "\nFINDING: no ACTIVE profile grants "
            + ", ".join(report.missing)
            + ".\n"
            "  The binary claims it (Runner.entitlements) and the App ID may well\n"
            "  tick it — but iOS checks the PROFILE, and this is what the release\n"
            "  lane signs with. For aps-environment the symptom is exactly a phone\n"
            "  APNs never answers.\n"
            "  Recovery is a ONE-RUN MATCH_BOOTSTRAP=true release, which\n"
            "  regenerates the profile — a founder action (`match` is readonly by\n"
            "  ADR-032, so no session and no ordinary run can do it)."
        )
        return
    if report.required:
        print("\nevery required entitlement is granted by an ACTIVE profile.")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Read what a provisioning profile actually grants (read-only).",
    )
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument(
        "--require",
        action="append",
        default=[],
        dest="required",
        metavar="ENTITLEMENT",
        help="Entitlement key that must be granted; repeatable. Absent -> exit 1.",
    )
    parser.add_argument(
        "--profile-type",
        default=DEFAULT_PROFILE_TYPE,
        help=f"default {DEFAULT_PROFILE_TYPE} — what release.yml signs with",
    )
    args = parser.parse_args(argv)

    try:
        token = _tft._token()

        def call(method: str, path: str) -> dict:
            return _tft._call(token, method, path)

    except AscError as failure:
        report = Report(
            bundle_id=args.bundle_id,
            profile_type=args.profile_type,
            required=tuple(args.required),
            profiles=(),
            missing=(),
            exit_code=EXIT_CANNOT_MEASURE,
            reason=str(failure),
        )
        render(report)
        return report.exit_code

    report = probe(call, args.bundle_id, args.required, args.profile_type)
    render(report)
    return report.exit_code


if __name__ == "__main__":
    sys.exit(main())
