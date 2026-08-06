#!/usr/bin/env python3
"""Enable (or disable) ONE capability on an App ID, over the App Store Connect API.

WHY THIS EXISTS, AND WHY ITS SIBLING SAYS IT SHOULDN'T.

`appid_capabilities.py` — the read half — states in its own header:

    WHAT IT IS NOT. It reads. It cannot tick a capability, and it deliberately
    has no code path that could: enabling a capability changes how a real
    binary signs, which is a founder decision, and a tool that could do it
    would also be a tool that could do it by accident.

Both halves of that sentence are still true, and this tool does not overturn
either. The FIRST half — "a founder decision" — was settled on 2026-08-06: the
founder was shown the trade-off (do it in the portal yourself vs. authorise the
API path, which regenerates the provisioning profile while `match` runs
readonly and may break the release lane) and chose the API path explicitly.
This file exists because of that answer, not in spite of it.

The SECOND half — "could do it by accident" — is the real engineering problem,
and it is answered rather than waved at. Two locks, both from this repo's own
prior art:

  * a **wire-level confirm literal** (`--confirm ENABLE`), the ADR-019
    `confirm: 'DELETE'` precedent: a literal the app sends and the server
    checks verbatim, so no typo, no default and no truthy flag can invoke it;
  * the **closed capability vocabulary** shared with the read half, checked
    BEFORE any request — on the read side an unknown value could only produce
    a false absence, but here it would POST an arbitrary string at a live App ID.

WHAT ENABLING ACTUALLY COSTS, stated where the person running it will see it.
A capability change INVALIDATES the App ID's existing provisioning profiles.
`match` runs `readonly: true` in CI (fastlane/Fastfile) precisely so CI can
never mint credentials, so the next release will fetch a stale profile and fail
at codesign UNLESS the profile is regenerated — which the Fastfile's documented
escape hatch does: set the repo variable `MATCH_BOOTSTRAP=true` for one run,
then remove it. That sequence is the operator's job and this tool does not
attempt it; what this tool guarantees is that its own change is UNDOABLE, from
the same place, by someone who has just watched a build fail (`--disable`).

EXIT CODES — a taxonomy, the ADR-041 discipline, and note that two of the three
are failures for DIFFERENT reasons:

    0   the capability is enabled (or was already, which is not an error)
    1   REFUSED — a guard said no. Nothing was sent. Not Apple's opinion, ours.
    2   FAILED  — a request was sent and did not succeed, or a credential was
        missing. "I would not" and "I could not" are different facts.

Run:
    python3 tool/ci/appid_capability_enable.py --bundle-id com.beyondkaira.hayati \\
        --enable PUSH_NOTIFICATIONS --confirm ENABLE

    python3 tool/ci/appid_capability_enable.py --disable-id CAP123 --confirm ENABLE
"""

from __future__ import annotations

import argparse
import dataclasses
import importlib.util
import pathlib
import sys

# The credential gate AND the read half are IMPORTED, never re-implemented.
# Re-deriving the capability vocabulary or the redaction here would be a second
# thing that can drift, and drift in either fails in the reassuring direction.
_HERE = pathlib.Path(__file__).parent


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, _HERE / f"{name}.py")
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules.setdefault(name, module)
    spec.loader.exec_module(module)
    return module


_probe = _load("appid_capabilities")
_tft = _probe._tft

AscError = _probe.AscError
KNOWN_CAPABILITIES = _probe.KNOWN_CAPABILITIES
PUSH_NOTIFICATIONS = _probe.PUSH_NOTIFICATIONS
ASSOCIATED_DOMAINS = _probe.ASSOCIATED_DOMAINS
APP_ATTEST = _probe.APP_ATTEST
APPLE_ID_AUTH = _probe.APPLE_ID_AUTH
_redact = _probe._redact

EXIT_OK = 0
EXIT_REFUSED = 1
EXIT_FAILED = 2

#: The literal a caller must send verbatim. Never typed by a human in normal
#: use — CI and the operator runbook pass it — so it costs nothing and turns an
#: accidental invocation from unlikely into impossible (ADR-019 D2 precedent).
CONFIRM_LITERAL = "ENABLE"


@dataclasses.dataclass(frozen=True)
class Result:
    exit_code: int
    capability: str = ""
    #: Apple's id for the created capability resource — the handle `--disable-id`
    #: needs. Recorded because the undo path matters most to someone who is
    #: already having a bad afternoon.
    capability_id: str = ""
    #: True when the capability was ALREADY ticked and nothing was sent.
    already_enabled: bool = False
    reason: str = ""


def enable_capability(
    call,
    bundle_key: str,
    capability: str,
    *,
    confirm: str,
    already_enabled: list[str],
) -> Result:
    """POST one bundleIdCapability. Guards first, request second, never both.

    `already_enabled` is passed IN rather than read here so the caller's read
    and this write see the same snapshot — and so the no-op case can be proven
    without a network fake that has to model Apple's duplicate-create error.
    """
    # Guard order is deliberate: the vocabulary check runs before the confirm
    # check so a typo'd capability is reported as a typo even when the operator
    # got the literal right.
    if capability not in KNOWN_CAPABILITIES:
        return Result(
            exit_code=EXIT_REFUSED,
            capability=capability,
            reason=(
                f"{capability!r} is not in this tool's closed vocabulary "
                f"({', '.join(sorted(KNOWN_CAPABILITIES))}). Refusing rather than "
                f"POSTing an unrecognised string at a live App ID."
            ),
        )
    if confirm != CONFIRM_LITERAL:
        return Result(
            exit_code=EXIT_REFUSED,
            capability=capability,
            reason=(
                f"--confirm must be exactly {CONFIRM_LITERAL!r}. Enabling a "
                f"capability invalidates this App ID's provisioning profiles, so "
                f"it is not something to do by flag alone."
            ),
        )

    if capability in already_enabled:
        return Result(
            exit_code=EXIT_OK,
            capability=capability,
            already_enabled=True,
            reason=f"{capability} is already ticked; nothing sent.",
        )

    body = {
        "data": {
            "type": "bundleIdCapabilities",
            "attributes": {"capabilityType": capability},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_key}}},
        }
    }
    try:
        payload = call("POST", "/v1/bundleIdCapabilities", body)
    except AscError as failure:
        return Result(
            exit_code=EXIT_FAILED, capability=capability, reason=_redact(str(failure))
        )

    data = payload.get("data") if isinstance(payload, dict) else None
    capability_id = data.get("id") if isinstance(data, dict) else None
    return Result(
        exit_code=EXIT_OK,
        capability=capability,
        capability_id=capability_id if isinstance(capability_id, str) else "",
        reason=f"{capability} enabled.",
    )


def disable_capability(call, capability_id: str, *, confirm: str) -> Result:
    """DELETE one bundleIdCapability by Apple's resource id — the undo path.

    Also gated on the literal: undoing is as much a live-signing-config change
    as doing, and an accidental untick during a release would be worse than the
    accidental tick it was reverting.
    """
    if confirm != CONFIRM_LITERAL:
        return Result(
            exit_code=EXIT_REFUSED,
            reason=f"--confirm must be exactly {CONFIRM_LITERAL!r} to disable a capability.",
        )
    try:
        call("DELETE", f"/v1/bundleIdCapabilities/{capability_id}")
    except AscError as failure:
        return Result(exit_code=EXIT_FAILED, reason=_redact(str(failure)))
    return Result(exit_code=EXIT_OK, capability_id=capability_id, reason="capability disabled.")


def render(result: Result) -> None:
    if result.exit_code == EXIT_OK and result.already_enabled:
        print(f"no change: {result.reason}")
    elif result.exit_code == EXIT_OK:
        print(f"OK: {result.reason}")
        if result.capability_id:
            print(f"  capability id (for --disable-id): {result.capability_id}")
            print()
            print("  NEXT, and it is not optional: this App ID's provisioning")
            print("  profiles are now INVALID. `match` runs readonly in CI, so the")
            print("  next release will fetch a stale profile and fail at codesign.")
            print("  Regenerate once via the Fastfile's documented escape hatch:")
            print("      gh variable set MATCH_BOOTSTRAP --body true")
            print("      gh workflow run release.yml --ref main")
            print("      gh variable delete MATCH_BOOTSTRAP     # after it lands")
    elif result.exit_code == EXIT_REFUSED:
        print(f"REFUSED (nothing was sent): {result.reason}")
    else:
        print(f"FAILED: {result.reason}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Enable or disable ONE capability on an App ID (WRITES to Apple).",
    )
    parser.add_argument("--bundle-id", help="e.g. com.beyondkaira.hayati (with --enable)")
    parser.add_argument("--enable", metavar="CAPABILITY", help=", ".join(sorted(KNOWN_CAPABILITIES)))
    parser.add_argument("--disable-id", metavar="ID", help="Apple's bundleIdCapability resource id")
    parser.add_argument(
        "--confirm",
        default="",
        help=f"must be exactly {CONFIRM_LITERAL!r}; nothing is sent without it",
    )
    args = parser.parse_args(argv)

    if not args.enable and not args.disable_id:
        print("REFUSED (nothing was sent): pass --enable CAPABILITY or --disable-id ID.")
        return EXIT_REFUSED

    try:
        token = _tft._token()

        def call(method: str, path: str, body: dict | None = None) -> dict:
            return _tft._call(token, method, path, body)

    except AscError as failure:
        print(f"FAILED: {_redact(str(failure))}")
        return EXIT_FAILED

    if args.disable_id:
        result = disable_capability(call, args.disable_id, confirm=args.confirm)
        render(result)
        return result.exit_code

    if not args.bundle_id:
        print("REFUSED (nothing was sent): --enable needs --bundle-id.")
        return EXIT_REFUSED

    # Read first, from the SAME credential and the same snapshot the write will
    # use, so "already enabled" is a fact rather than an assumption.
    try:
        bundle_key = _probe.find_bundle_id(lambda m, p: call(m, p), args.bundle_id)
        enabled = _probe.list_capabilities(lambda m, p: call(m, p), bundle_key)
    except AscError as failure:
        print(f"FAILED: {_redact(str(failure))}")
        return EXIT_FAILED

    print(f"App ID: {args.bundle_id}")
    print(f"  currently ticked: {', '.join(enabled) if enabled else '(none)'}")
    result = enable_capability(
        call, bundle_key, args.enable, confirm=args.confirm, already_enabled=enabled
    )
    render(result)
    return result.exit_code


if __name__ == "__main__":
    sys.exit(main())
