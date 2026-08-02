#!/usr/bin/env python3
"""Create (idempotently) a TestFlight beta group and add testers to it.

Why this exists, and why it is a CI script rather than a dev-box one: the App
Store Connect API key lives ONLY in GitHub secrets (ASC_KEY_ID / ASC_ISSUER_ID
in the `release` environment, ASC_API_KEY_P8_BASE64 as a repository secret) —
architecture.md §9's zero-credentials-in-repo rule means no operator can run
this locally without first exporting the key, and nothing should encourage
that. The workflow that calls it (.github/workflows/testflight-testers.yml)
resolves the same three secrets the release lane uses.

Idempotent BY DESIGN, because the failure mode of a tester script is a
duplicate invite email to a real person: an existing group of the same name is
reused rather than duplicated (App Store Connect happily accepts two groups
with the same name), an existing tester is looked up by email and linked to the
group instead of re-created, and a tester already in the group is left alone.
Re-running it is a no-op that prints the same final membership.

External groups are the default (`isInternalGroup` is read-only on create and
Apple defaults it to false). NOTE the operational consequence, which this
script cannot do anything about: an external tester receives nothing until a
build is assigned to their group AND that build clears Beta App Review. Adding
people here is necessary, not sufficient.

Usage (see the workflow for the credential wiring):

    python3 tool/ci/testflight_testers.py \
        --bundle-id com.beyondkaira.hayati \
        --group Friends \
        --testers a@example.com,b@example.com \
        [--dry-run]
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt  # PyJWT, with the `cryptography` backend for ES256.

API = "https://api.appstoreconnect.apple.com"


class AscError(RuntimeError):
    """An App Store Connect API call that did not do what we asked."""


def _token() -> str:
    """Mint a short-lived ES256 JWT from the three release secrets.

    Fails CLOSED with the missing NAMES (never values), mirroring the release
    lane's own signing-secrets gate: a partial credential set must not reach
    Apple to die on an opaque 401.
    """
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    issuer_id = os.environ.get("ASC_ISSUER_ID", "").strip()
    key_b64 = os.environ.get("ASC_API_KEY_P8_BASE64", "").strip()
    missing = [
        name
        for name, value in (
            ("ASC_KEY_ID", key_id),
            ("ASC_ISSUER_ID", issuer_id),
            ("ASC_API_KEY_P8_BASE64", key_b64),
        )
        if not value
    ]
    if missing:
        raise AscError(
            "App Store Connect credentials are not configured: "
            + ", ".join(missing)
            + " unset. See docs/operator-expected.md."
        )

    # The same whitespace strip the release lane's `tr -d '[:space:]'` applies:
    # a base64 secret pasted with newlines decodes to garbage under strict
    # decoders while working fine under lenient ones, so normalise here too.
    private_key = base64.b64decode("".join(key_b64.split())).decode("utf-8")
    if "BEGIN PRIVATE KEY" not in private_key:
        raise AscError(
            "ASC_API_KEY_P8_BASE64 did not decode to a PKCS#8 PEM private key "
            "(expected a '-----BEGIN PRIVATE KEY-----' line)."
        )

    now = int(time.time())
    return jwt.encode(
        {
            "iss": issuer_id,
            "iat": now,
            "exp": now + 1200,  # Apple caps team-key tokens at 20 minutes.
            "aud": "appstoreconnect-v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def _call(token: str, method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={
            "Authorization": "Bearer " + token,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as failure:
        detail = failure.read().decode("utf-8", "replace")
        raise AscError(f"{method} {path} -> HTTP {failure.code}: {detail}") from None


def find_app(token: str, bundle_id: str) -> dict:
    query = urllib.parse.urlencode({"filter[bundleId]": bundle_id})
    found = _call(token, "GET", f"/v1/apps?{query}").get("data", [])
    if not found:
        raise AscError(
            f"No app with bundle id {bundle_id} is visible to this API key."
        )
    return found[0]


def list_groups(token: str, app_id: str) -> list[dict]:
    query = urllib.parse.urlencode({"filter[app]": app_id, "limit": 200})
    return _call(token, "GET", f"/v1/betaGroups?{query}").get("data", [])


def find_group(token: str, app_id: str, name: str) -> dict | None:
    """Look the group up by app, then match the name HERE rather than with a
    server-side filter[name]: the list filter is exact and case-sensitive, and
    a near-miss would silently create a second 'friends' beside 'Friends'."""
    for group in list_groups(token, app_id):
        if group["attributes"]["name"].strip().casefold() == name.strip().casefold():
            return group
    return None


def create_group(token: str, app_id: str, name: str) -> dict:
    payload = {
        "data": {
            "type": "betaGroups",
            "attributes": {"name": name},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    return _call(token, "POST", "/v1/betaGroups", payload)["data"]


def group_members(token: str, group_id: str) -> list[dict]:
    """The tester RECORDS in a group, not just their addresses.

    `merge_group` needs the ids: linking a tester to another group by id is one
    call and cannot mis-resolve, whereas re-deriving them from an email would
    round-trip through `filter[email]` and depend on Apple's case handling for
    an address we already hold."""
    query = urllib.parse.urlencode({"limit": 200})
    return _call(
        token, "GET", f"/v1/betaGroups/{group_id}/betaTesters?{query}"
    ).get("data", [])


def group_member_emails(token: str, group_id: str) -> set[str]:
    return {
        (tester["attributes"].get("email") or "").casefold()
        for tester in group_members(token, group_id)
    }


def find_tester(token: str, email: str) -> dict | None:
    query = urllib.parse.urlencode({"filter[email]": email})
    found = _call(token, "GET", f"/v1/betaTesters?{query}").get("data", [])
    return found[0] if found else None


def add_tester(token: str, group_id: str, email: str) -> str:
    """Add one tester, returning a one-word outcome for the summary line.

    No firstName/lastName is sent. They are optional to Apple, and a name
    invented from an email local part would show up in the founder's App Store
    Connect forever — a guess about a real person is worse than a blank field.
    """
    existing = find_tester(token, email)
    if existing is not None:
        _call(
            token,
            "POST",
            f"/v1/betaGroups/{group_id}/relationships/betaTesters",
            {"data": [{"type": "betaTesters", "id": existing["id"]}]},
        )
        return "linked-existing"
    _call(
        token,
        "POST",
        "/v1/betaTesters",
        {
            "data": {
                "type": "betaTesters",
                "attributes": {"email": email},
                "relationships": {
                    "betaGroups": {
                        "data": [{"type": "betaGroups", "id": group_id}]
                    }
                },
            }
        },
    )
    return "invited-new"


def tester_line(attributes: dict) -> str:
    """One tester, with everything Apple says about them, printed VERBATIM.

    ADR-038 D5's rule applied one resource down. Nothing in this repo has ever
    measured what `betaTesters` returns — whether the state field is called
    `state`, `betaTesterState`, or lives on a `betaTesterMetrics` relationship
    entirely — and addendum 63 is explicit that only the vendor can settle a
    vendor API shape. So this formats whatever arrived instead of selecting the
    fields someone guessed: a field Apple adds tomorrow still reaches the
    founder's eyes, and a field that is missing is visibly missing rather than
    silently defaulted.

    The email leads because that is what the founder matches against a person;
    the rest is sorted so two runs diff cleanly against each other.
    """
    email = attributes.get("email") or "(no email)"
    rest = ", ".join(
        f"{key}={attributes[key]!r}" for key in sorted(attributes) if key != "email"
    )
    return f"{email}  {rest}" if rest else email


def merge_group(
    token: str,
    app_id: str,
    source_name: str,
    target: dict,
    dry_run: bool = False,
) -> list[str]:
    """Move every tester from `source_name` into `target`, then DELETE the source.

    Founder request (S057): *"merge those groups and only keep Friends"* — two
    external groups had been a standing source of confusion (issue #146), and
    one group that always gets the build is simpler than two that might.

    THE ORDER IS THE GUARANTEE: link, then RE-READ the target, then delete. A
    version that deletes on the strength of a 2xx from the link call would, on
    the day Apple accepts the request and does not apply it, silently strip a
    real person's access — and every `--status` afterwards would report a clean
    single-group setup, because the evidence would be gone with the group. This
    refuses to delete unless it has SEEN each member on the other side.

    Deleting a beta group does not delete its testers: `betaTesters` are
    app-scoped, so anyone who was only in the source remains a tester on the app
    and is now in the target as well.
    """
    lines: list[str] = []
    target_name = target["attributes"]["name"]
    if source_name.strip().casefold() == target_name.strip().casefold():
        raise AscError(
            f"refusing to merge {source_name!r} into itself — that is a plain "
            "delete wearing a friendlier name. Name a different source group."
        )

    source = find_group(token, app_id, source_name)
    if source is None:
        # Loudly, NOT as a no-op. A mistyped source that reported "nothing to
        # merge" would read exactly like a successful second run while the real
        # group sat untouched — the false-clean this repo keeps paying for.
        existing = ", ".join(
            repr(group["attributes"]["name"]) for group in list_groups(token, app_id)
        )
        raise AscError(
            f"no beta group named {source_name!r} exists for this app. "
            f"Existing groups: {existing}. (If you have already merged it, that "
            "is the expected message — there is nothing left to do.)"
        )
    if source["attributes"].get("isInternalGroup"):
        raise AscError(
            f"{source_name!r} is an internal group. Internal membership is an "
            "App Store Connect USER SEAT, not an invite, so deleting it is a "
            "different act than merging external testers. Refusing."
        )

    members = group_members(token, source["id"])
    already = group_member_emails(token, target["id"])
    moving = [
        tester
        for tester in members
        if (tester["attributes"].get("email") or "").casefold() not in already
    ]
    staying = len(members) - len(moving)
    lines.append(
        f"merge: {source_name!r} has {len(members)} tester(s); "
        f"{staying} already in {target_name!r}, {len(moving)} to move"
    )
    for tester in moving:
        lines.append(f"  move {tester['attributes'].get('email')}")

    if dry_run:
        lines.append(
            f"  WOULD move the above into {target_name!r}, verify, then "
            f"DELETE the group {source_name!r}"
        )
        return lines

    if moving:
        _call(
            token,
            "POST",
            f"/v1/betaGroups/{target['id']}/relationships/betaTesters",
            {
                "data": [
                    {"type": "betaTesters", "id": tester["id"]} for tester in moving
                ]
            },
        )

    # The re-read. Not a formality — this is the only thing standing between a
    # partially-applied link and an unrecoverable delete.
    confirmed = group_member_emails(token, target["id"])
    missing = sorted(
        (tester["attributes"].get("email") or "")
        for tester in members
        if (tester["attributes"].get("email") or "").casefold() not in confirmed
    )
    if missing:
        raise AscError(
            f"NOT deleting {source_name!r}: after the move, "
            f"{', '.join(missing)} still cannot be seen in {target_name!r}. "
            "Both groups are intact — re-run, or add them by hand. Nothing was "
            "lost, which is the point of checking."
        )

    _call(token, "DELETE", f"/v1/betaGroups/{source['id']}")
    lines.append(
        f"  verified all {len(members)} tester(s) in {target_name!r}; "
        f"deleted the group {source_name!r}"
    )
    return lines


def list_builds(token: str, app_id: str, limit: int = 5) -> list[dict]:
    """Newest-first builds for the app, with their processing state."""
    query = urllib.parse.urlencode(
        {"filter[app]": app_id, "sort": "-version", "limit": limit}
    )
    return _call(token, "GET", f"/v1/builds?{query}").get("data", [])


# ---------------------------------------------------------------------------
# ADR-038 — Test Information, Beta App Review, and the state that actually
# answers "can my friends install it?"
# ---------------------------------------------------------------------------

# The four Beta App Review contact fields, as (secret name, Apple attribute).
# They arrive as SECRETS and never as workflow inputs: this repository is
# public, and `workflow_dispatch` inputs are recorded in run metadata that
# anyone can read — a dispatch box would publish the founder's mobile number
# permanently (ADR-038 D1).
REVIEW_CONTACT_ENV = (
    ("ASC_REVIEW_CONTACT_FIRST_NAME", "contactFirstName"),
    ("ASC_REVIEW_CONTACT_LAST_NAME", "contactLastName"),
    ("ASC_REVIEW_CONTACT_EMAIL", "contactEmail"),
    ("ASC_REVIEW_CONTACT_PHONE", "contactPhone"),
)


def read_review_contact(env: dict | None = None) -> dict:
    """Collect the four contact values, or fail closed naming what is missing.

    ALL FOUR or nothing, deliberately. Apple accepts a partial contact and the
    Test Information page still reads as incomplete, so a three-of-four write
    would leave `review_readiness()` reporting a gap the log had just claimed
    to close — a green step guarding nothing, which is the defect shape this
    repo keeps meeting.

    Raises with the missing NAMES. Never echoes a value; see `set_review_contact`.
    """
    source = os.environ if env is None else env
    values: dict[str, str] = {}
    missing: list[str] = []
    for name, attribute in REVIEW_CONTACT_ENV:
        raw = (source.get(name) or "").strip()
        if raw:
            values[attribute] = raw
        else:
            missing.append(name)
    if missing:
        raise AscError(
            "Beta App Review contact is not configured: "
            + ", ".join(missing)
            + " unset. All four are required — Apple accepts a partial contact "
            "and the page still reads as incomplete. See docs/operator-expected.md."
        )
    return values


def set_review_contact(
    token: str, app_id: str, contact: dict, dry_run: bool = False
) -> str:
    """PATCH (or create) the app's betaAppReviewDetail. Returns a status LINE.

    THE RETURN VALUE IS THE POINT OF THE FUNCTION'S SHAPE: it names the
    ATTRIBUTES that changed and never their values, because this string is
    printed into a public repository's workflow log. GitHub's own masking is a
    backstop, not the design — a value that is never formatted into a string
    cannot be un-masked by an accident. `testflight_testers_test.py` pins this
    with a sentinel test that fails if any contact value reaches the output.

    The detail resource's id is READ from the app relationship rather than
    assumed to equal the app id: it is the only shape here Apple documents but
    this repo has not measured, and a GET we already make answers it for free.
    """
    detail = _call(token, "GET", f"/v1/apps/{app_id}/betaAppReviewDetail").get("data")
    current = (detail or {}).get("attributes") or {}
    changed = sorted(
        attribute
        for attribute, wanted in contact.items()
        if (current.get(attribute) or "").strip() != wanted
    )
    if not changed:
        return "review contact: unchanged (all four already match)"
    if dry_run:
        return "review contact: WOULD SET " + ", ".join(changed)

    detail_id = (detail or {}).get("id")
    if detail_id:
        _call(
            token,
            "PATCH",
            f"/v1/betaAppReviewDetails/{detail_id}",
            {
                "data": {
                    "type": "betaAppReviewDetails",
                    "id": detail_id,
                    "attributes": contact,
                }
            },
        )
    else:
        _call(
            token,
            "POST",
            "/v1/betaAppReviewDetails",
            {
                "data": {
                    "type": "betaAppReviewDetails",
                    "attributes": contact,
                    "relationships": {
                        "app": {"data": {"type": "apps", "id": app_id}}
                    },
                }
            },
        )
    return "review contact: set " + ", ".join(changed)


def build_beta_detail(token: str, build_id: str) -> dict:
    """The build's BETA states — what Apple's reviewer thinks, not its encoder.

    `processingState` (which `list_builds` returns) is about Apple's ENCODER.
    A build can read VALID forever and never reach a tester. `externalBuildState`
    is the only field that answers the question the founder is actually asking,
    and until ADR-038 nothing here printed it.

    Fetched per build rather than via `include=`: the builds list is capped at
    five in `print_status`, and a separate GET keeps a failure attributable to
    one build instead of emptying the whole listing.
    """
    data = _call(token, "GET", f"/v1/builds/{build_id}/buildBetaDetail").get("data")
    return (data or {}).get("attributes") or {}


def group_names_by_build(token: str, app_id: str) -> dict:
    """Map build id -> the beta groups it is attached to. Inverted DELIBERATELY.

    The obvious call is `GET /v1/builds/{id}/betaGroups`, and Apple refuses it:

        403 FORBIDDEN_ERROR — The relationship 'betaGroups' does not allow
        'GET_RELATED'. Allowed operations are: CREATE, DELETE

    Measured against the real API on 2026-07-28, after the hermetic tests, five
    design-review lenses and a completeness critic had all passed the forward
    version — none of them can call Apple, which is exactly what this file's own
    test docstring says about mocking Apple's shapes. The readable direction is
    group -> builds, so ask each group once and invert.

    Cost is one call per beta group (three here), not one per build.
    """
    query = urllib.parse.urlencode({"filter[app]": app_id, "limit": 200})
    groups = _call(token, "GET", f"/v1/betaGroups?{query}").get("data", [])
    by_build: dict[str, list[str]] = {}
    for group in groups:
        name = group.get("attributes", {}).get("name", "?")
        builds = _call(
            token, "GET", f"/v1/betaGroups/{group['id']}/builds?limit=200"
        ).get("data", [])
        for build in builds:
            by_build.setdefault(build["id"], []).append(name)
    return by_build


# States meaning the build has already entered, or passed, the external gate.
# Read as DATA and never as a closed enum: Apple has added states to this field
# before (the export-compliance pair below among them), and a tool that
# switch-cases on a fixed list would read an unknown state as "not submitted"
# and submit a second time. Anything not named here is printed VERBATIM and
# treated as not-yet-submitted, which is the safe direction: the submission
# call itself is the second guard.
ALREADY_SUBMITTED_STATES = frozenset(
    {
        "WAITING_FOR_BETA_REVIEW",
        "IN_BETA_REVIEW",
        "READY_FOR_BETA_TESTING",
        "BETA_APPROVED",
    }
)

# States where submitting is guaranteed to fail, and for a reason the founder
# can fix in one click. Naming it beats letting Apple return an opaque error.
BLOCKED_BEFORE_REVIEW_STATES = {
    "MISSING_EXPORT_COMPLIANCE": (
        "Apple needs the export-compliance answer for this build first "
        "(App Store Connect -> TestFlight -> the build -> 'Manage' next to "
        "Export Compliance). It is one question about encryption."
    ),
    "IN_EXPORT_COMPLIANCE_REVIEW": (
        "Apple is still reviewing this build's export-compliance declaration. "
        "Beta App Review cannot start until that clears."
    ),
}

# Backstop only. The PRIMARY guard against a duplicate submission is reading
# `externalBuildState` first; this exists for the race where two dispatches
# overlap. Deliberately requires BOTH an error-family match AND a phrase match:
# this repo has NOT measured which status Apple returns for a duplicate (the
# design review found 409 and 422 both claimed in the wild), so a rule keyed on
# either one alone would swallow an unrelated failure or miss the real one.
#
# WHAT A MATCH HERE DOES *NOT* SETTLE — and used to. These phrases span TWO
# opposite outcomes: "THIS build is already submitted" (a genuine no-op) and
# "ANOTHER build is in review" (a refusal — nothing was submitted). MEASURED
# 2026-08-02: with build 113 `WAITING_FOR_BETA_REVIEW`, submitting build 114 was
# refused by Apple, matched here, and reported as `already submitted — no-op`
# with exit 0. Build 114 stayed `READY_FOR_BETA_SUBMISSION` and the operator was
# told it had been submitted. So a match now means only "the queue is talking —
# RE-READ the state before deciding", which `submit_for_review` does.
_SUBMISSION_CONFLICT_MARKERS = (
    "already been submitted",
    "already submitted",
    "another build is in review",
    "is in review",
    "already in review",
)


def looks_like_submission_conflict(message: str) -> bool:
    """Does this read like Apple's submission QUEUE rather than a real failure?

    Says nothing about WHICH build is holding that queue. Deciding that from the
    sentence is the defect this predicate was split away from; the caller settles
    it by re-reading `externalBuildState`.
    """
    lowered = message.lower()
    if "http 409" not in lowered and "http 422" not in lowered:
        return False
    return any(marker in lowered for marker in _SUBMISSION_CONFLICT_MARKERS)


def submit_for_review(
    token: str, app_id: str, build: dict, dry_run: bool = False
) -> str:
    """Submit ONE build for Beta App Review. Refuses rather than earning a no.

    Outward-facing: this puts the founder's app in front of an Apple reviewer,
    and a rejection is recorded against the app. So it is never implied by
    another flag (ADR-038 D3), and it refuses outright if `review_readiness`
    still reports a gap — submitting an app Apple will bounce costs a round
    trip and teaches the lane's operator to ignore its output.
    """
    gaps = review_readiness(token, app_id)
    if gaps:
        raise AscError(
            "refusing to submit for Beta App Review — Apple would reject it:\n  "
            + "\n  ".join(gaps)
        )

    version = build.get("attributes", {}).get("version")
    state = build_beta_detail(token, build["id"]).get("externalBuildState") or "UNKNOWN"
    if state in ALREADY_SUBMITTED_STATES:
        return f"build {version}: already {state} — nothing to submit"
    if state in BLOCKED_BEFORE_REVIEW_STATES:
        raise AscError(
            f"build {version} is {state} and cannot be submitted yet. "
            + BLOCKED_BEFORE_REVIEW_STATES[state]
        )
    if dry_run:
        return f"build {version}: WOULD submit for Beta App Review (state={state})"

    try:
        _call(
            token,
            "POST",
            "/v1/betaAppReviewSubmissions",
            {
                "data": {
                    "type": "betaAppReviewSubmissions",
                    "relationships": {
                        "build": {"data": {"type": "builds", "id": build["id"]}}
                    },
                }
            },
        )
    except AscError as failure:
        if not looks_like_submission_conflict(str(failure)):
            raise
        # The queue is talking, but not about WHICH build. We only reached the
        # POST because this build was NOT in ALREADY_SUBMITTED_STATES, so either
        # an overlapping dispatch submitted it since that read (the race this
        # backstop exists for — a real no-op), or a DIFFERENT build is holding
        # the queue (a refusal that submitted nothing). RE-READ rather than parse
        # the sentence: the phrase list covers both outcomes and cannot tell them
        # apart, and the version that guessed reported a refusal as a no-op.
        after = (
            build_beta_detail(token, build["id"]).get("externalBuildState")
            or "UNKNOWN"
        )
        if after in ALREADY_SUBMITTED_STATES:
            return (
                f"build {version}: already {after} — an overlapping dispatch got "
                "there first, no-op"
            )
        raise AscError(
            f"build {version} was NOT submitted — it is still {after}. Apple "
            f"refused: {failure}\n"
            "Beta App Review submissions serialize per APP, not per build "
            "(measured 2026-08-02): another build is still in review. Wait for "
            "that one to be approved or rejected, then re-run this lane."
        )
    return f"build {version}: submitted for Beta App Review"


def await_build(
    token: str,
    app_id: str,
    build_number: str,
    wait_seconds: int,
    sleep: "callable" = None,
) -> dict | None:
    """Poll until the build with `build_number` reaches VALID, or give up.

    WHY POLLING IS NEEDED AT ALL. `pilot` uploads with
    `skip_waiting_for_build_processing: true` so the release job does not sit
    idle for Apple's processing queue. But a build that is still PROCESSING has
    no installable asset, and attaching it to a group would report success while
    delivering nothing — the exact failure shape this repo keeps meeting. So the
    release lane uploads fast and this waits separately.

    Returns the build dict once VALID, or None on timeout/absence. Never raises
    on timeout: a build that has not finished processing is not a broken release,
    and reddening the release job for Apple's queue would be the same
    cries-wolf mistake as gating on a third party's schedule (ADR-034).
    """
    import time as _time

    naptime = sleep or _time.sleep
    deadline_polls = max(1, wait_seconds // 30)
    for attempt in range(deadline_polls):
        for build in list_builds(token, app_id, limit=20):
            attributes = build.get("attributes", {})
            if str(attributes.get("version")) != str(build_number):
                continue
            state = attributes.get("processingState")
            if state == "VALID" and not attributes.get("expired"):
                return build
            if state in ("INVALID", "FAILED"):
                print(f"build {build_number} is {state} — Apple rejected the upload.")
                return None
            print(f"build {build_number} is {state}; waiting…")
            break
        else:
            print(f"build {build_number} not visible to the API yet; waiting…")
        if attempt < deadline_polls - 1:
            naptime(30)
    return None


def assign_build(token: str, build_id: str, group_id: str) -> None:
    _call(
        token,
        "POST",
        f"/v1/builds/{build_id}/relationships/betaGroups",
        {"data": [{"type": "betaGroups", "id": group_id}]},
    )


def review_readiness(token: str, app_id: str) -> list[str]:
    """What Apple still needs before an EXTERNAL group can receive a build.

    Returned as a list of human-readable gaps (empty = nothing missing that this
    API can see). Beta App Review is the reason a filled-in group can still
    deliver nothing, so naming the gaps beats a generic "submit for review".

    THE GAPS SPLIT IN TWO, and this docstring used to blur them. The four
    CONTACT fields are founder-owned FACTS — a name, an email, a phone — and
    `--set-review-contact` writes them from secrets (ADR-038). The localization
    fields (description, feedback email) are founder-owned COPY: the founder's
    voice in the founder's languages, which a session filling in with an AI
    draft would be the unhelpful kind of helpful. Only the second half is
    something no session can write.
    """
    gaps: list[str] = []
    detail = _call(token, "GET", f"/v1/apps/{app_id}/betaAppReviewDetail").get(
        "data", {}
    )
    attributes = detail.get("attributes", {}) if detail else {}
    for field, label in (
        ("contactEmail", "review contact email"),
        ("contactFirstName", "review contact first name"),
        ("contactLastName", "review contact last name"),
        ("contactPhone", "review contact phone"),
    ):
        if not (attributes.get(field) or "").strip():
            gaps.append(f"Test Information: {label} is empty")

    localizations = _call(
        token, "GET", f"/v1/apps/{app_id}/betaAppLocalizations"
    ).get("data", [])
    if not localizations:
        gaps.append("Test Information: no beta app localization (description) at all")
    else:
        for localization in localizations:
            locale = localization["attributes"].get("locale", "?")
            if not (localization["attributes"].get("description") or "").strip():
                gaps.append(f"Test Information: {locale} beta description is empty")
            if not (localization["attributes"].get("feedbackEmail") or "").strip():
                gaps.append(f"Test Information: {locale} feedback email is empty")
    return gaps


def print_status(token: str, app: dict, group_name: str) -> None:
    """Read-only. Writes nothing, invites nobody."""
    app_id = app["id"]
    print("\nbeta groups:")
    for group in list_groups(token, app_id):
        attributes = group["attributes"]
        kind = "internal" if attributes.get("isInternalGroup") else "external"
        marker = " <-- target" if attributes["name"] == group_name else ""
        print(f"  {attributes['name']!r} ({kind}){marker}")
        # Issue #146's actual request, finally in the read-only path: membership
        # used to print ONLY on the add/assign path, so the one command the
        # founder was told to run for a safe look could not answer "who is in
        # this group, and did anything reach them?".
        #
        # A failure here must not empty the listing, for the same reason the
        # build/group inversion below degrades instead of dying.
        try:
            for tester in group_members(token, group["id"]):
                print(f"      {tester_line(tester.get('attributes') or {})}")
        except AscError as failure:
            print(f"      (membership unavailable: {failure})")

    # One inverted lookup for the whole listing (see group_names_by_build), and
    # a FAILURE HERE MUST NOT EMPTY THE LISTING: a read-only status command that
    # dies on an optional extra tells the founder less than one that degrades and
    # says so. This is what the forbidden per-build call actually cost — it took
    # the build list down with it.
    try:
        groups_by_build = group_names_by_build(token, app_id)
        groups_available = True
    except AscError as failure:
        print(f"\n(group membership unavailable: {failure})")
        groups_by_build, groups_available = {}, False

    print("\nbuilds (newest first):")
    for build in list_builds(token, app_id):
        attributes = build["attributes"]
        print(
            f"  build {attributes.get('version')}  "
            f"processing={attributes.get('processingState')}  "
            f"expired={attributes.get('expired')}  "
            f"uploaded={attributes.get('uploadedDate')}"
        )
        # The icon Apple ACTUALLY extracted from the uploaded binary. Printed
        # because "the right icon is on main" and "the right icon is in the
        # build" are different claims, and this repo just spent eighteen days
        # on a bug that was exactly that gap in another guise (issue #140).
        # Session 052 shipped build 110 to replace a 109 that carried the stock
        # Flutter icon; a differing token between two builds is the evidence.
        icon = attributes.get("iconAssetToken")
        if isinstance(icon, dict):
            print(
                f"      icon: {icon.get('templateUrl')}  "
                f"({icon.get('width')}x{icon.get('height')})"
            )
        elif icon:
            print(f"      icon: {icon}")
        else:
            print("      icon: (not reported by the API for this build)")

        # ADR-038 D5. `processingState` above is Apple's ENCODER; these two are
        # Apple's REVIEWER and the internal lane. Printed verbatim — no mapping
        # through a closed enum, so a state Apple adds tomorrow still shows up.
        # Group membership sits on the same rows because a build in no group
        # delivers to nobody however healthy every other field looks.
        try:
            beta = build_beta_detail(token, build["id"])
            print(
                f"      external={beta.get('externalBuildState') or '(none)'}  "
                f"internal={beta.get('internalBuildState') or '(none)'}"
            )
        except AscError as failure:
            print(f"      beta state unavailable: {failure}")
        if groups_available:
            groups = groups_by_build.get(build["id"], [])
            print(
                f"      groups: {', '.join(groups) if groups else '(none — inert)'}"
            )

    gaps = review_readiness(token, app_id)
    print("\nbeta app review readiness (external testers need this):")
    if not gaps:
        print("  nothing missing that the API can see")
    for gap in gaps:
        print(f"  MISSING - {gap}")


def parse_emails(raw: str) -> list[str]:
    """Split a comma/whitespace separated list, preserving order, dropping
    case-insensitive duplicates.

    Case-insensitive because the duplicate that matters is the human one: a
    founder pasting `A@x.com` on one dispatch and `a@x.com` on the next means
    one person, and Apple would treat the second as a fresh invite email.
    """
    emails: list[str] = []
    seen: set[str] = set()
    for chunk in raw.replace(",", " ").split():
        candidate = chunk.strip()
        if candidate and candidate.casefold() not in seen:
            seen.add(candidate.casefold())
            emails.append(candidate)
    return emails


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--group", required=True)
    parser.add_argument("--testers", default="", help="comma/space separated emails")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would change and touch nothing.",
    )
    parser.add_argument(
        "--status",
        action="store_true",
        help="Read-only: print groups, builds and Beta App Review readiness, then exit.",
    )
    parser.add_argument(
        "--assign-build-number",
        help=(
            "Attach THIS build number to the group once Apple finishes "
            "processing it. Used by release.yml so every new build reaches the "
            "group automatically; --assign-latest-build is the manual twin."
        ),
    )
    parser.add_argument(
        "--wait-minutes",
        type=int,
        default=20,
        help=(
            "How long to wait for --assign-build-number to become VALID. A "
            "timeout is NOT a failure: the build is fine, Apple's queue is slow, "
            "and the assignment can be re-run."
        ),
    )
    parser.add_argument(
        "--assign-latest-build",
        action="store_true",
        help=(
            "Also attach the newest VALID build to the group. Without this a "
            "group full of testers is inert — membership alone delivers nothing."
        ),
    )
    parser.add_argument(
        "--merge-group",
        help=(
            "Move every tester out of THIS group into --group, then delete it. "
            "Outward-facing and destructive: links, RE-READS to confirm each "
            "member landed, and only then deletes. Refuses on an unknown or "
            "internal source rather than reporting a false clean."
        ),
    )
    parser.add_argument(
        "--set-review-contact",
        action="store_true",
        help=(
            "Write the four Beta App Review contact fields from the "
            "ASC_REVIEW_CONTACT_* secrets. Never from a workflow input: this "
            "repo is public and dispatch inputs are world-readable (ADR-038 D1)."
        ),
    )
    parser.add_argument(
        "--submit-for-review",
        action="store_true",
        help=(
            "Submit the newest VALID build for Beta App Review. Outward-facing: "
            "refuses if Test Information is incomplete, and is never implied by "
            "another flag (ADR-038 D3)."
        ),
    )
    args = parser.parse_args()

    emails = parse_emails(args.testers)
    token = _token()
    app = find_app(token, args.bundle_id)
    print(f"app: {app['attributes']['name']} ({args.bundle_id}) id={app['id']}")

    if args.status:
        print_status(token, app, args.group)
        return 0

    # Before the group work, so a contact write is not hostage to a group
    # problem — and idempotent, so an earlier partial run costs nothing.
    #
    # NOT fatal, and that is load-bearing. `release.yml` passes this flag on
    # every release. If a missing ASC_REVIEW_CONTACT_* secret aborted here, the
    # BUILD ASSIGNMENT below would never run and ADR-037's guarantee — every
    # release build reaches the Friends group — would silently stop holding for
    # any founder who has not set the four secrets yet. Report it, remember it,
    # keep going, and still exit non-zero so nothing reads as clean.
    exit_code = 0
    if args.set_review_contact:
        try:
            print(set_review_contact(
                token, app["id"], read_review_contact(), dry_run=args.dry_run
            ))
        except AscError as failure:
            print(f"::error::{failure}", file=sys.stderr)
            print("continuing — the build assignment below is a separate promise.")
            exit_code = 1

    group = find_group(token, app["id"], args.group)
    if group is None:
        if args.dry_run:
            print(f"group: {args.group!r} does NOT exist — would create (external)")
            for email in emails:
                print(f"  would add {email}")
            # `exit_code`, NOT 0. A dry run against a group that does not exist
            # yet is the most likely FIRST dispatch anyone makes — the workflow's
            # dry_run input defaults to true — so returning 0 here would report
            # a clean run for the exact case where a missing contact secret was
            # just announced. Found by the build-diff review.
            return exit_code
        group = create_group(token, app["id"], args.group)
        print(f"group: created {args.group!r} id={group['id']} (external)")
    else:
        internal = group["attributes"].get("isInternalGroup")
        kind = "internal" if internal else "external"
        print(f"group: reusing existing {args.group!r} id={group['id']} ({kind})")
        if internal:
            # Refuse rather than quietly add external testers to an INTERNAL
            # group: internal membership requires an App Store Connect user
            # seat, so the request would mean something different than asked.
            raise AscError(
                f"A group named {args.group!r} already exists but is INTERNAL. "
                "Rename it or pick another name — adding external testers to it "
                "is not the same request."
            )

    # BEFORE the tester adds, so `already` below is computed against the merged
    # membership — otherwise a merge and an --testers add naming the same person
    # in one dispatch would try to link them twice.
    if args.merge_group:
        for line in merge_group(
            token, app["id"], args.merge_group, group, dry_run=args.dry_run
        ):
            print(line)

    already = group_member_emails(token, group["id"])
    for email in emails:
        if email.casefold() in already:
            print(f"  {email}: already in the group — untouched")
            continue
        if args.dry_run:
            print(f"  {email}: would add")
            continue
        print(f"  {email}: {add_tester(token, group['id'], email)}")

    if not args.dry_run:
        final = sorted(group_member_emails(token, group["id"]))
        print(f"\n{args.group!r} now has {len(final)} tester(s):")
        for email in final:
            print(f"  - {email}")

    if args.assign_build_number:
        build = await_build(
            token, app["id"], args.assign_build_number, args.wait_minutes * 60
        )
        if build is None:
            print(
                f"\nbuild {args.assign_build_number} did not reach VALID within "
                f"{args.wait_minutes} min — NOT assigned. Re-run this workflow, or "
                "use --assign-latest-build once processing finishes."
            )
        elif args.dry_run:
            print(f"\nwould assign build {args.assign_build_number} to {args.group!r}")
        else:
            assign_build(token, build["id"], group["id"])
            print(f"\nassigned build {args.assign_build_number} to {args.group!r}")
        for gap in review_readiness(token, app["id"]):
            print(f"  - {gap}")

    if args.assign_latest_build:
        # VALID only: a build still PROCESSING has no installable asset, and
        # attaching one would look like success while delivering nothing.
        builds = [
            build
            for build in list_builds(token, app["id"], limit=10)
            if build["attributes"].get("processingState") == "VALID"
            and not build["attributes"].get("expired")
        ]
        if not builds:
            print("\nno VALID unexpired build to assign — is one still processing?")
        else:
            newest = builds[0]
            version = newest["attributes"].get("version")
            if args.dry_run:
                print(f"\nwould assign build {version} to {args.group!r}")
            else:
                assign_build(token, newest["id"], group["id"])
                print(f"\nassigned build {version} to {args.group!r}")

        gaps = review_readiness(token, app["id"])
        if gaps:
            # Loud, because this is the difference between "the group is set up"
            # and "your friends can actually install it".
            print("\nBUT external testers still cannot install until Beta App")
            print("Review passes, and Apple needs this first:")
            for gap in gaps:
                print(f"  MISSING - {gap}")
            # Say what closes it. The line this replaced claimed every gap here
            # was "founder-owned copy that no session can write for them", which
            # ADR-038 falsified for the contact half — and leaving it would have
            # sent the founder to fill a form by hand next to the flag that
            # fills it. Only printed when a CONTACT gap is actually present.
            if any("review contact" in gap for gap in gaps):
                print("\nThe contact fields are writable from secrets — see")
                print("docs/operator-expected.md item 2(c): set the four")
                print("ASC_REVIEW_CONTACT_* secrets, then re-run this workflow")
                print("with set_review_contact=true.")

    if args.submit_for_review:
        # Deliberately LAST: a build should be attached to the group before it
        # goes to review, so an approval lands on a build testers can already
        # see. Newest VALID build only — the same rule --assign-latest-build
        # uses, for the same reason (a PROCESSING build has no asset).
        candidates = [
            build
            for build in list_builds(token, app["id"], limit=10)
            if build["attributes"].get("processingState") == "VALID"
            and not build["attributes"].get("expired")
        ]
        if not candidates:
            print("\nno VALID unexpired build to submit for review.")
        else:
            print("\n" + submit_for_review(
                token, app["id"], candidates[0], dry_run=args.dry_run
            ))
    return exit_code


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AscError as failure:
        print(f"::error::{failure}", file=sys.stderr)
        sys.exit(1)
