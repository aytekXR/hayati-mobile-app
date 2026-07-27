#!/usr/bin/env python3
"""Fail a build only for advisories a lockfile change INTRODUCES (issue #131).

WHY THIS SHAPE, and not the obvious one. The obvious instrument is
`npm audit --audit-level=high` in the per-PR job. This repo does not carry it,
deliberately, and the reason is ADR-024's lesson: an honest gap beats a guard
that mostly restates something else.

`npm audit`'s absolute output changes for reasons NO COMMIT CAUSED. A third
party publishes an advisory against a lockfile nobody touched and the build
turns red — for something the session did not do, cannot fix that hour, and
which (measured for every advisory in this repo at the time of writing) may not
even be reachable. That is not a guarantee; it is a build that cries wolf, and
the cost of crying wolf is that people stop reading red.

So this compares two points in time instead of one threshold:

    advisories(base lockfile)  vs  advisories(head lockfile)

both resolved in the SAME run, against the SAME registry, moments apart. The
key property falls out of that symmetry: a newly-published advisory appears on
BOTH sides and cancels. The check is therefore *structurally incapable* of
firing for a publication event — it can only fire when the diff itself brings a
new advisory in, which is exactly the case a human can act on.

Three consequences worth stating plainly:

  * There is NO committed baseline file. Git history is the baseline. A
    baseline file would be ADR-025 D8's shape — a declaration nothing enforces,
    which rots quietly and then lies.
  * There is NO cron. GitHub disables scheduled workflows after 60 days without
    commits, i.e. it switches itself off during exactly the quiet period when a
    scheduled audit would be the only thing looking. The half of the problem a
    cron would cover (a new advisory against an UNCHANGED lockfile) is covered
    properly by Dependabot alerts, which are platform-native, cannot rot, and
    watch every ecosystem in this repo rather than just this one lockfile.
  * It keys on GHSA ID, not on npm's headline count. npm reports one entry per
    affected package, so "12 vulnerabilities" in this repo is TWO advisories and
    ten "depends on a vulnerable version of X" wrappers. Counting wrappers makes
    a report look alarming and tells you nothing about what to fix.

FAIL-CLOSED ON ITS OWN FAILURE. If the audit cannot be run, or the base lockfile
cannot be read, this exits non-zero and says why. A gate that passes when it
could not measure is the `store_metadata` failure shape this repo has already
paid for twice (S047, and #140's rules-deploy gap) — green while guarding
nothing. The one case that is NOT an error is an unchanged lockfile: then there
is nothing to compare and it exits 0 without touching the network.

Run:
    python3 tool/ci/npm_audit_delta.py --base-ref origin/main
    python3 tool/ci/npm_audit_delta.py --base-ref <sha> --lockfile functions/package-lock.json
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import tempfile

# npm's severity vocabulary, weakest first. Anything not in this list is treated
# as unknown and ranked above everything so it can never be silently dropped.
_SEVERITY_ORDER = ["info", "low", "moderate", "high", "critical"]

_DEFAULT_LOCKFILE = "functions/package-lock.json"


def severity_rank(severity: str) -> int:
    """Rank a severity. Unknown severities rank ABOVE critical, on purpose:
    a vocabulary npm adds later must not slip under a threshold unnoticed."""
    try:
        return _SEVERITY_ORDER.index(severity)
    except ValueError:
        return len(_SEVERITY_ORDER)


def distinct_advisories(audit: dict) -> dict[str, dict]:
    """Collapse an `npm audit --json` report to its ACTUAL advisories.

    npm emits one `vulnerabilities` entry per affected package, so a single
    advisory deep in a chain produces one real entry plus one wrapper per
    package above it ("depends on a vulnerable version of X"). Only the entries
    whose `via` holds an object carry an advisory; string `via` entries are the
    wrappers. Keyed by GHSA id, which is the only stable identifier here —
    package name and version range both move.
    """
    out: dict[str, dict] = {}
    for entry in (audit.get("vulnerabilities") or {}).values():
        for via in entry.get("via") or []:
            if not isinstance(via, dict):
                continue  # a wrapper, not an advisory
            url = via.get("url") or ""
            ghsa = url.rstrip("/").rsplit("/", 1)[-1] if url else ""
            # No URL means no stable key; fall back to title so it is still
            # counted rather than silently dropped.
            key = ghsa or f"untitled:{via.get('title', '?')}"
            existing = out.get(key)
            if existing is None or severity_rank(via.get("severity", "")) > severity_rank(
                existing["severity"]
            ):
                out[key] = {
                    "id": key,
                    "package": via.get("name", "?"),
                    "severity": via.get("severity", "unknown"),
                    "title": via.get("title", ""),
                    "range": via.get("range", ""),
                }
    return out


def delta(base: dict[str, dict], head: dict[str, dict]) -> tuple[list[dict], list[dict]]:
    """(introduced, resolved) — advisories only in head, and only in base."""
    introduced = [head[k] for k in head if k not in base]
    resolved = [base[k] for k in base if k not in head]
    introduced.sort(key=lambda a: (-severity_rank(a["severity"]), a["id"]))
    resolved.sort(key=lambda a: (-severity_rank(a["severity"]), a["id"]))
    return introduced, resolved


def at_or_above(advisories: list[dict], threshold: str) -> list[dict]:
    floor = severity_rank(threshold)
    return [a for a in advisories if severity_rank(a["severity"]) >= floor]


class AuditError(RuntimeError):
    """The audit could not be performed. Always fail-closed on this."""


def read_blob(ref: str, path: str, repo_root: pathlib.Path) -> bytes:
    """`git show <ref>:<path>`. Raises AuditError with an actionable message."""
    proc = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        cwd=repo_root,
        capture_output=True,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.decode("utf-8", "replace").strip()
        raise AuditError(
            f"cannot read {path} at ref '{ref}': {stderr}\n"
            "  If this is CI, the checkout is probably too shallow to see the base "
            "commit — fetch it (actions/checkout fetch-depth) before running this."
        )
    return proc.stdout


def audit_lockfile(lockfile_bytes: bytes) -> dict:
    """Run `npm audit --package-lock-only` over a lockfile's BYTES.

    --package-lock-only resolves the advisory set from the lockfile alone: no
    install, no node_modules, and no package.json needed. That is what makes
    auditing a historical lockfile cheap enough to do on every run.
    """
    with tempfile.TemporaryDirectory(prefix="npm-audit-delta-") as tmp:
        target = pathlib.Path(tmp) / "package-lock.json"
        target.write_bytes(lockfile_bytes)
        proc = subprocess.run(
            ["npm", "audit", "--package-lock-only", "--json"],
            cwd=tmp,
            capture_output=True,
        )
        stdout = proc.stdout.decode("utf-8", "replace")
        # npm exits non-zero WHEN IT FINDS VULNERABILITIES, which is the normal
        # case here — so the exit code says nothing. Valid JSON on stdout is the
        # real success signal; anything else is an operational failure.
        try:
            report = json.loads(stdout)
        except json.JSONDecodeError as exc:
            stderr = proc.stderr.decode("utf-8", "replace").strip()
            raise AuditError(
                f"npm audit produced no parseable JSON (exit {proc.returncode}): {exc}\n"
                f"  stderr: {stderr[:500]}"
            ) from exc
        if "vulnerabilities" not in report:
            raise AuditError(
                "npm audit JSON has no 'vulnerabilities' key; "
                f"got keys {sorted(report)[:8]}. Refusing to report a clean result "
                "from output this tool does not understand."
            )
        return report


def format_report(
    introduced: list[dict], resolved: list[dict], head_all: dict[str, dict], threshold: str
) -> str:
    lines: list[str] = []
    lines.append(f"advisories after this change: {len(head_all)} "
                 f"(distinct GHSA ids, not npm's per-package count)")
    for a in sorted(head_all.values(), key=lambda x: (-severity_rank(x["severity"]), x["id"])):
        lines.append(f"    {a['severity']:9} {a['id']:22} {a['package']}")
    if resolved:
        lines.append("")
        lines.append(f"RESOLVED by this change ({len(resolved)}):")
        for a in resolved:
            lines.append(f"    {a['severity']:9} {a['id']:22} {a['package']}")
    lines.append("")
    if introduced:
        lines.append(f"INTRODUCED by this change ({len(introduced)}):")
        for a in introduced:
            lines.append(f"    {a['severity']:9} {a['id']:22} {a['package']}  {a['title'][:70]}")
    else:
        lines.append("INTRODUCED by this change: none.")
    lines.append("")
    lines.append(f"failure threshold: {threshold} and above, introduced only")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Fail only for advisories a lockfile change introduces."
    )
    parser.add_argument("--base-ref", required=True,
                        help="git ref holding the lockfile to compare against (e.g. origin/main)")
    parser.add_argument("--lockfile", default=_DEFAULT_LOCKFILE,
                        help=f"repo-relative lockfile path (default: {_DEFAULT_LOCKFILE})")
    parser.add_argument("--severity", default="high", choices=_SEVERITY_ORDER,
                        help="minimum severity of an INTRODUCED advisory that fails the build")
    parser.add_argument("--repo-root", default=".", help="repository root")
    args = parser.parse_args(argv)

    repo_root = pathlib.Path(args.repo_root).resolve()
    head_path = repo_root / args.lockfile

    try:
        if not head_path.exists():
            raise AuditError(f"{args.lockfile} does not exist at {head_path}")
        head_bytes = head_path.read_bytes()
        base_bytes = read_blob(args.base_ref, args.lockfile, repo_root)

        if base_bytes == head_bytes:
            print(f"{args.lockfile} is unchanged against {args.base_ref}; "
                  "nothing to compare, and no advisory this change could have introduced.")
            return 0

        print(f"{args.lockfile} changed against {args.base_ref}; "
              "auditing both revisions in the same run.")
        base_all = distinct_advisories(audit_lockfile(base_bytes))
        head_all = distinct_advisories(audit_lockfile(head_bytes))
    except AuditError as exc:
        # Fail-closed: never report a clean result from a check that did not run.
        print(f"::error::npm audit delta could not run: {exc}")
        return 2

    introduced, resolved = delta(base_all, head_all)
    print(format_report(introduced, resolved, head_all, args.severity))

    blocking = at_or_above(introduced, args.severity)
    if blocking:
        names = ", ".join(f"{a['id']} ({a['package']}, {a['severity']})" for a in blocking)
        print(f"::error::this change introduces {len(blocking)} advisory/advisories "
              f"at or above '{args.severity}': {names}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
