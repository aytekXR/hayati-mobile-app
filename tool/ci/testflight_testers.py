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


def find_group(token: str, app_id: str, name: str) -> dict | None:
    """Look the group up by app, then match the name HERE rather than with a
    server-side filter[name]: the list filter is exact and case-sensitive, and
    a near-miss would silently create a second 'friends' beside 'Friends'."""
    query = urllib.parse.urlencode({"filter[app]": app_id, "limit": 200})
    for group in _call(token, "GET", f"/v1/betaGroups?{query}").get("data", []):
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


def group_member_emails(token: str, group_id: str) -> set[str]:
    query = urllib.parse.urlencode({"limit": 200})
    members = _call(
        token, "GET", f"/v1/betaGroups/{group_id}/betaTesters?{query}"
    ).get("data", [])
    return {
        (tester["attributes"].get("email") or "").casefold() for tester in members
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
    args = parser.parse_args()

    emails = parse_emails(args.testers)
    token = _token()
    app = find_app(token, args.bundle_id)
    print(f"app: {app['attributes']['name']} ({args.bundle_id}) id={app['id']}")

    group = find_group(token, app["id"], args.group)
    if group is None:
        if args.dry_run:
            print(f"group: {args.group!r} does NOT exist — would create (external)")
            for email in emails:
                print(f"  would add {email}")
            return 0
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
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AscError as failure:
        print(f"::error::{failure}", file=sys.stderr)
        sys.exit(1)
