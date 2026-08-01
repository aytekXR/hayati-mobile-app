#!/usr/bin/env python3
"""Compare the firestore ruleset that is LIVE against the one on this ref (#140).

WHY THIS EXISTS. `ci.yml`'s `functions-rules` job proves `firestore.rules`
against the emulator, honestly, on every PR — but the emulator loads the
WORKING-TREE file. It guards a ruleset the runtime never reads. Between
2026-07-09 and 2026-07-27 both projects served the M2.1 ruleset while six
milestones of rules sat merged and undeployed; every one of those PRs was
green, and a founder bug report found it rather than a gate. A green check that
guards nothing is worse than no check, because it is also a claim.

WHAT IT IS AND IS NOT. This asks the PLATFORM what is released and diffs it
against the file on disk. There is deliberately no committed
"last-deployed.sha" marker to compare against instead: that would be ADR-025
D8's shape — a declaration nothing enforces — and it would fail in the
reassuring direction, because the lane whose omission IS the bug is the same
lane that would update the marker. Only the authority can answer.

FAIL-CLOSED, ALWAYS (ADR-034 D5's rule, restated). Exit codes are a taxonomy,
not a boolean:

    0   every requested project's live ruleset is byte-identical to the file
    1   DRIFT — at least one project differs. This is the finding.
    2   COULD NOT MEASURE — no credential, an API error, an unreadable ruleset,
        an unexpected response shape, or a firestore release this tool does not
        compare. NEVER 0.

The difference between 1 and 2 matters: 1 means "I looked and they differ",
2 means "I could not look". Collapsing them would reintroduce the very defect,
because a check that reports success when it could not measure is exactly what
`functions-rules` was doing.

NO NORMALIZATION. The comparison is byte-exact. A ruleset that differs from the
reviewed bytes by a trailing space is not the reviewed ruleset, and normalizing
would let a real edit hide behind a whitespace rule.

COVERAGE IS ASSERTED, NOT ASSUMED. A Firestore NAMED DATABASE gets its own
release (`cloud.firestore/{db}`). Comparing only `releases/cloud.firestore`
would be silently partial the day one appears — this tool's own failure mode,
one level down — so it lists every release and fails CLOSED on any second
firestore release. Other services (`firebase.storage/...`) are out of contract
and are reported, not failed: this tool's subject is firestore rules.

Run (CI, read-only service account):
    python3 tool/ci/rules_drift.py --project hayatiapp-prod --project hayatiapp-dev

Run (a session on the founder's box, reusing the logged-in firebase CLI):
    python3 tool/ci/rules_drift.py --from-firebase-cli \
        --project hayatiapp-prod --project hayatiapp-dev
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

RULES_API = "https://firebaserules.googleapis.com/v1/"
TOKEN_URI = "https://oauth2.googleapis.com/token"
# Read-only by construction: this tool must never be able to cause the drift it
# reports. The deploy lane holds the writing credential; see ADR-041 D4.
READONLY_SCOPE = "https://www.googleapis.com/auth/firebase.readonly"
CONFIGSTORE = "~/.config/configstore/firebase-tools.json"
VIEWER_SECRET = "FIREBASE_RULES_VIEWER_SA"

EXIT_OK = 0
EXIT_DRIFT = 1
EXIT_CANNOT_MEASURE = 2


class MeasurementError(Exception):
    """Raised whenever the tool cannot establish what is live. Always exit 2."""


# --------------------------------------------------------------------------
# credential plumbing
# --------------------------------------------------------------------------

def client_credentials_from_api_js(text: str) -> tuple[str, str]:
    """Pull firebase-tools' OAuth client id/secret out of its INSTALLED source.

    Read at runtime rather than hardcoded so that a firebase-tools upgrade which
    rotates or moves them produces a clear error instead of a silent 401. These
    are published constants shipped in every install, not a secret of ours; the
    repo still holds none (architecture.md §9).
    """
    def grab(var: str) -> str | None:
        m = re.search(r'envOverride\(\s*"%s"\s*,\s*"([^"]+)"' % re.escape(var), text)
        return m.group(1) if m else None

    cid, csec = grab("FIREBASE_CLIENT_ID"), grab("FIREBASE_CLIENT_SECRET")
    if not cid or not csec:
        raise MeasurementError(
            "could not find FIREBASE_CLIENT_ID/FIREBASE_CLIENT_SECRET in the installed "
            "firebase-tools api.js — the CLI layout changed; use --sa-file instead")
    return cid, csec


def refresh_token_from_configstore(store: dict) -> str:
    token = (store.get("tokens") or {}).get("refresh_token")
    if not token:
        raise MeasurementError(
            f"the firebase CLI is not logged in ({CONFIGSTORE} holds no refresh token) "
            "— run `firebase login`")
    return token


def sa_assertion_claims(sa: dict, now: int) -> dict:
    """The JWT-bearer claims for a service-account token grant (pure, testable)."""
    for field in ("client_email", "private_key"):
        if not sa.get(field):
            raise MeasurementError(
                f"service-account JSON is missing {field!r} — it is not a service-account key")
    return {
        "iss": sa["client_email"],
        "scope": READONLY_SCOPE,
        "aud": sa.get("token_uri") or TOKEN_URI,
        "iat": now,
        "exp": now + 3600,
    }


def _post_token(payload: dict, token_uri: str = TOKEN_URI) -> str:
    body = urllib.parse.urlencode(payload).encode()
    try:
        with urllib.request.urlopen(
            urllib.request.Request(token_uri, data=body), timeout=30
        ) as resp:
            token = json.load(resp).get("access_token")
    except urllib.error.HTTPError as exc:
        # Deliberately does NOT echo the request body — it holds the credential.
        raise MeasurementError(f"token endpoint returned HTTP {exc.code}") from None
    except OSError as exc:
        raise MeasurementError(f"token endpoint unreachable: {exc}") from None
    if not token:
        raise MeasurementError("token endpoint returned no access_token")
    return token


def token_from_service_account(sa: dict) -> str:
    try:
        import jwt  # pyjwt[crypto]; CI installs it for the testflight tool too
    except ImportError:
        raise MeasurementError(
            "pyjwt[crypto] is required for --sa-file — `python3 -m pip install "
            "'pyjwt[crypto]==2.10.1'`") from None
    claims = sa_assertion_claims(sa, now=int(time.time()))
    assertion = jwt.encode(claims, sa["private_key"], algorithm="RS256")
    return _post_token({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }, claims["aud"])


def token_from_firebase_cli() -> str:
    store_path = pathlib.Path(os.path.expanduser(CONFIGSTORE))
    if not store_path.exists():
        raise MeasurementError(f"{CONFIGSTORE} does not exist — run `firebase login`")
    refresh = refresh_token_from_configstore(json.loads(store_path.read_text()))
    api_js = _find_firebase_tools_api_js()
    cid, csec = client_credentials_from_api_js(api_js.read_text())
    return _post_token({
        "client_id": cid,
        "client_secret": csec,
        "refresh_token": refresh,
        "grant_type": "refresh_token",
    })


def _find_firebase_tools_api_js() -> pathlib.Path:
    import shutil
    import subprocess

    candidates: list[pathlib.Path] = []
    try:
        root = subprocess.run(["npm", "root", "-g"], capture_output=True, text=True,
                              timeout=30).stdout.strip()
        if root:
            candidates.append(pathlib.Path(root) / "firebase-tools" / "lib" / "api.js")
    except (OSError, subprocess.SubprocessError):
        pass
    exe = shutil.which("firebase")
    if exe:
        base = pathlib.Path(exe).resolve().parent.parent
        candidates.append(base / "lib" / "node_modules" / "firebase-tools" / "lib" / "api.js")
        candidates.append(base / "lib" / "api.js")
    for c in candidates:
        if c.exists():
            return c
    raise MeasurementError(
        "could not locate the installed firebase-tools (lib/api.js) — use --sa-file")


def resolve_credential(args: argparse.Namespace) -> str:
    """First credential that resolves, most explicit first. No default."""
    if args.access_token:
        return args.access_token
    if os.environ.get("FIREBASE_RULES_ACCESS_TOKEN"):
        return os.environ["FIREBASE_RULES_ACCESS_TOKEN"]
    if args.sa_file:
        return token_from_service_account(json.loads(pathlib.Path(args.sa_file).read_text()))
    if os.environ.get(VIEWER_SECRET):
        return token_from_service_account(json.loads(os.environ[VIEWER_SECRET]))
    if args.from_firebase_cli:
        return token_from_firebase_cli()
    raise MeasurementError(
        "no credential. This check cannot run without one, and it will not pretend "
        f"to pass: set the {VIEWER_SECRET} repository secret (a service account with "
        "roles/firebaserules.viewer on BOTH projects) — see docs/operator-expected.md "
        "item 2(e)(iv) — or pass --from-firebase-cli on a box where the firebase CLI "
        "is logged in.")


# --------------------------------------------------------------------------
# the API surface
# --------------------------------------------------------------------------

class RulesApi:
    def __init__(self, access_token: str) -> None:
        self._token = access_token

    def get(self, path: str) -> dict:
        req = urllib.request.Request(
            RULES_API + path, headers={"Authorization": "Bearer " + self._token})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as exc:
            detail = ""
            try:
                detail = json.loads(exc.read().decode()).get("error", {}).get("message", "")
            except Exception:  # noqa: BLE001 - the status code is the real signal
                pass
            raise MeasurementError(f"HTTP {exc.code} on {path}: {detail}") from None
        except OSError as exc:
            raise MeasurementError(f"{RULES_API}{path} unreachable: {exc}") from None


# --------------------------------------------------------------------------
# comparison
# --------------------------------------------------------------------------

def release_id(full_name: str) -> str:
    """`projects/p/releases/cloud.firestore/db` -> `cloud.firestore/db`."""
    marker = "/releases/"
    return full_name.split(marker, 1)[1] if marker in full_name else full_name


def audit_releases(releases: list[dict]) -> list[str]:
    """Return out-of-contract release ids; raise if a firestore release exists
    that this tool would not compare.

    The raise is the point. A named database's rules would otherwise sit
    unguarded behind a green check — the same shape as #140 itself.
    """
    others: list[str] = []
    unexpected_firestore: list[str] = []
    for rel in releases:
        rid = release_id(rel.get("name", ""))
        if rid == "cloud.firestore":
            continue
        if rid.startswith("cloud.firestore"):
            unexpected_firestore.append(rid)
        else:
            others.append(rid)
    if unexpected_firestore:
        raise MeasurementError(
            "this project has firestore release(s) this check does not compare: "
            + ", ".join(sorted(unexpected_firestore))
            + ". A named database has its own ruleset; failing closed rather than "
              "reporting a partial green.")
    return others


def live_source(ruleset: dict, expected_filename: str) -> tuple[str, list[str]]:
    """(concatenated source, complaints). Complaints mean drift, not an error."""
    source = ruleset.get("source")
    if not isinstance(source, dict) or not isinstance(source.get("files"), list):
        raise MeasurementError(
            f"ruleset {ruleset.get('name', '?')} has no readable `source.files` — "
            "unexpected API response shape")
    files = source["files"]
    if not files:
        raise MeasurementError(f"ruleset {ruleset.get('name', '?')} contains no files")
    complaints: list[str] = []
    names = [f.get("name", "?") for f in files]
    if len(files) > 1:
        complaints.append(
            f"the live ruleset contains {len(files)} files ({', '.join(names)}); "
            "firebase.json declares exactly one")
    elif names[0] != expected_filename:
        complaints.append(
            f"the live ruleset's file is named {names[0]!r}, expected {expected_filename!r}")
    return "".join(f.get("content", "") for f in files), complaints


def check_project(project: str, local: str, expected_filename: str, api) -> tuple[bool, list[str]]:
    """(matches, report lines). Raises MeasurementError if it could not look."""
    lines: list[str] = []
    listing = api.get(f"projects/{project}/releases?pageSize=100")
    others = audit_releases(listing.get("releases", []) or [])
    for other in others:
        lines.append(
            f"  note: {other} is released on this project and is deliberately NOT "
            "compared — this check's contract is firestore rules only")

    release = api.get(f"projects/{project}/releases/cloud.firestore")
    ruleset_name = release.get("rulesetName")
    if not ruleset_name:
        raise MeasurementError(
            f"release cloud.firestore on {project} names no ruleset — "
            "unexpected API response shape")
    lines.append(f"  live ruleset : {ruleset_name.rsplit('/', 1)[-1]}")
    lines.append(f"  live since   : {release.get('updateTime') or release.get('createTime')}")

    remote, complaints = live_source(api.get(ruleset_name), expected_filename)
    lines.extend(f"  DRIFT: {c}" for c in complaints)

    if remote == local and not complaints:
        lines.append("  MATCHES the ruleset on this ref")
        return True, lines

    lines.append("  DRIFT: the live ruleset is NOT the ruleset on this ref")
    diff = list(difflib.unified_diff(
        local.splitlines(), remote.splitlines(),
        fromfile=f"{expected_filename} (this ref)", tofile=f"{project} (live)",
        lineterm="", n=1))
    shown = diff[:40]
    lines.extend("  " + d for d in shown)
    if len(diff) > len(shown):
        lines.append(f"  … {len(diff) - len(shown)} more diff lines suppressed")
    return False, lines


# --------------------------------------------------------------------------

def main(argv: list[str] | None = None, api_factory=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", action="append", default=[],
                        help="project id; repeatable")
    parser.add_argument("--rules-file", default="firestore.rules")
    parser.add_argument("--access-token", default=None,
                        help="an OAuth access token (never logged)")
    parser.add_argument("--sa-file", default=None,
                        help="path to a service-account JSON with roles/firebaserules.viewer")
    parser.add_argument("--from-firebase-cli", action="store_true",
                        help="mint a token from the logged-in firebase CLI (local use)")
    args = parser.parse_args(argv)

    if not args.project:
        print("::error::rules_drift: no --project given")
        return EXIT_CANNOT_MEASURE

    try:
        credential = resolve_credential(args)
    except MeasurementError as exc:
        print(f"::error::rules_drift could not measure: {exc}")
        return EXIT_CANNOT_MEASURE

    rules_path = pathlib.Path(args.rules_file)
    try:
        local = rules_path.read_text()
    except OSError as exc:
        print(f"::error::rules_drift could not read {args.rules_file}: {exc.strerror}")
        return EXIT_CANNOT_MEASURE

    api = (api_factory or RulesApi)(credential)
    expected_filename = rules_path.name

    print(f"local {args.rules_file}: {len(local.encode())} bytes")
    drifted: list[str] = []
    for project in args.project:
        print(f"\n=== {project} ===")
        try:
            matches, lines = check_project(project, local, expected_filename, api)
        except MeasurementError as exc:
            print(f"  {exc}")
            print(f"::error::rules_drift could not measure {project}: {exc}")
            return EXIT_CANNOT_MEASURE
        for line in lines:
            print(line)
        if not matches:
            drifted.append(project)

    print()
    if drifted:
        for project in drifted:
            print(f"::error::{project} is serving a firestore ruleset that is not the one "
                  "on this ref. Deploy it with the deploy-rules workflow "
                  "(dispatch-only), then re-run this check.")
        return EXIT_DRIFT
    print(f"no drift: {len(args.project)} project(s) serve the ruleset on this ref "
          f"({', '.join(args.project)})")
    return EXIT_OK


if __name__ == "__main__":
    raise SystemExit(main())
