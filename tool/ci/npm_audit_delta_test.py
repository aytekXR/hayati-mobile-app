#!/usr/bin/env python3
"""Self-tests for tool/ci/npm_audit_delta.py (repo convention: every tool under
tool/ carries one, run by ci.yml's quality job).

These are hermetic: no npm, no network, no emulator. Every test either drives a
pure function or builds a throwaway git repo in a temp dir, so this can sit in
`quality` next to the other pre-`pub get` self-tests.

THE MUTATION CHECK acceptance criterion 4 asks for lives in
`test_seeded_advisory_fails` and `test_publication_event_cancels_out`. It is not
enough to prove the script RUNS — a delta check that returned "nothing
introduced" unconditionally would pass a smoke test and guard nothing, which is
precisely the `store_metadata` failure shape this repo has paid for twice. So
each guard is asserted in BOTH directions: the seeded advisory must FAIL, and
the same advisory present on both sides must PASS.

Run: python3 tool/ci/npm_audit_delta_test.py
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import pathlib
import subprocess
import tempfile

_MODULE_PATH = pathlib.Path(__file__).with_name("npm_audit_delta.py")
_spec = importlib.util.spec_from_file_location("npm_audit_delta", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
nad = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(nad)

_failures: list[str] = []


def check(label: str, actual: object, expected: object) -> None:
    if actual == expected:
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         expected: {expected!r}\n         actual:   {actual!r}")
        _failures.append(label)


def check_raises(label: str, fn, needle: str) -> None:
    try:
        fn()
    except Exception as exc:  # noqa: BLE001 - a self-test wants the widest net
        if needle.lower() in str(exc).lower():
            print(f"  ok   {label}")
        else:
            print(f"  FAIL {label}\n         wanted {needle!r} in: {exc}")
            _failures.append(label)
        return
    print(f"  FAIL {label}\n         expected a raise, got none")
    _failures.append(label)


def _advisory(ghsa: str, name: str, severity: str) -> dict:
    return {
        "source": 1,
        "name": name,
        "title": f"{name}: something bad",
        "url": f"https://github.com/advisories/{ghsa}",
        "severity": severity,
        "range": "<1.2.3",
    }


def _report(*advisories: dict, wrappers: int = 0) -> dict:
    """Build an npm-audit-shaped report. `wrappers` adds the "depends on a
    vulnerable version of X" entries npm emits for every package ABOVE the
    real advisory in the chain — the ones that inflate its headline count."""
    vulns: dict[str, dict] = {}
    for adv in advisories:
        vulns[adv["name"]] = {"name": adv["name"], "severity": adv["severity"], "via": [adv]}
    for i in range(wrappers):
        vulns[f"wrapper-{i}"] = {
            "name": f"wrapper-{i}",
            "severity": "high",
            "via": [advisories[0]["name"] if advisories else "something"],
        }
    return {"vulnerabilities": vulns}


# --------------------------------------------------------------------------
# The wrapper collapse — the measurement that reframed issue #131 itself.
# --------------------------------------------------------------------------

def test_wrappers_collapse_to_advisories() -> None:
    # npm's shape for this repo at the time of writing: 12 entries, 2 advisories.
    report = _report(
        _advisory("GHSA-mh99-v99m-4gvg", "brace-expansion", "high"),
        _advisory("GHSA-w5hq-g745-h8pq", "uuid", "moderate"),
        wrappers=10,
    )
    got = nad.distinct_advisories(report)
    check("12 npm entries collapse to 2 distinct advisories", len(got), 2)
    check("keyed by GHSA id", sorted(got), ["GHSA-mh99-v99m-4gvg", "GHSA-w5hq-g745-h8pq"])
    check("severity preserved", got["GHSA-mh99-v99m-4gvg"]["severity"], "high")
    # The other direction: a report with NO wrappers must not lose anything.
    check("no-wrapper report keeps its advisory", len(nad.distinct_advisories(
        _report(_advisory("GHSA-aaaa-bbbb-cccc", "x", "critical")))), 1)


def test_advisory_without_url_is_not_dropped() -> None:
    adv = _advisory("ignored", "weird-pkg", "high")
    adv["url"] = ""
    got = nad.distinct_advisories(_report(adv))
    check("an advisory with no URL still counts", len(got), 1)
    # The fallback key must be derived from the TITLE, not the package name. The
    # build-diff review proved this mutation survived: keying on the package name
    # instead collapses two different advisories affecting the SAME package into
    # one, so the second would look neither introduced nor present.
    check("the fallback key is title-derived", list(got)[0].startswith("untitled:"), True)
    two = _report(
        {**_advisory("x", "same-pkg", "high"), "url": "", "title": "first flaw"},
        {**_advisory("y", "same-pkg", "high"), "url": "", "title": "second flaw"},
    )
    # _report keys its dict by package name, so build this one by hand to get two
    # advisories on one package — the shape that exposes the mutation.
    two = {"vulnerabilities": {"same-pkg": {"name": "same-pkg", "severity": "high", "via": [
        {**_advisory("x", "same-pkg", "high"), "url": "", "title": "first flaw"},
        {**_advisory("y", "same-pkg", "high"), "url": "", "title": "second flaw"},
    ]}}}
    check("two URL-less advisories on ONE package stay distinct",
          len(nad.distinct_advisories(two)), 2)


def test_base_ref_resolution_order() -> None:
    """Which candidate wins is policy, and it lives in the tool so this can see it
    (ADR-024 D1: outcome logic in YAML is invisible to the self-test)."""
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        _git(root, "init", "-q")
        _git(root, "config", "user.email", "t@t.t")
        _git(root, "config", "user.name", "t")
        (root / "f.txt").write_text("1\n")
        _git(root, "add", "-A")
        _git(root, "commit", "-qm", "one")
        head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root,
                              capture_output=True, text=True).stdout.strip()

        zeros = "0" * 40
        check("an empty candidate is skipped",
              nad.resolve_base_ref(["", head], root), head)
        check("an all-zeros sha is skipped, not treated as an error",
              nad.resolve_base_ref([zeros, head], root), head)
        check("the FIRST resolvable candidate wins",
              nad.resolve_base_ref([head, "HEAD"], root), head)
        check("an unresolvable candidate falls through",
              nad.resolve_base_ref(["no-such-ref", "HEAD"], root), "HEAD")
        check("no resolvable candidate returns None",
              nad.resolve_base_ref(["", zeros, "no-such-ref"], root), None)


def test_no_resolvable_base_skips_without_failing_the_build() -> None:
    """The honest skip: nothing to compare is not a failure, but it must be loud
    and it must not be reachable by accident (a resolvable base must NOT skip)."""
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        _git(root, "init", "-q")
        _git(root, "config", "user.email", "t@t.t")
        _git(root, "config", "user.name", "t")
        (root / "functions").mkdir()
        (root / "functions" / "package-lock.json").write_text('{"lockfileVersion": 3}\n')
        _git(root, "add", "-A")
        _git(root, "commit", "-qm", "x")
        # Exit code alone cannot tell "skipped" from "compared and found nothing" —
        # both are 0 — so assert on what was actually printed, or this pair of
        # checks would be vacuous in exactly the way it exists to rule out.
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = nad.main(["--base-ref", "", "--base-ref", "0" * 40,
                           "--base-ref", "nope", "--repo-root", str(root)])
        skipped = buf.getvalue()
        check("no resolvable base exits 0 (skip, not failure)", rc, 0)
        check("and says so loudly", "::notice::no resolvable base ref" in skipped, True)

        # The other direction: a resolvable base must reach the COMPARISON, so the
        # skip path cannot silently swallow a real check.
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = nad.main(["--base-ref", "nope", "--base-ref", "HEAD",
                           "--repo-root", str(root)])
        compared = buf.getvalue()
        check("a resolvable base exits 0 too", rc, 0)
        check("but reached the comparison instead of skipping",
              "is unchanged against HEAD" in compared, True)
        check("and did NOT emit the skip notice",
              "no resolvable base ref" in compared, False)


# --------------------------------------------------------------------------
# THE MUTATION CHECK — both directions.
# --------------------------------------------------------------------------

def test_seeded_advisory_fails() -> None:
    """A lockfile change that brings a NEW advisory must be caught."""
    base = nad.distinct_advisories(_report(_advisory("GHSA-old0-0000-0000", "already-here", "high")))
    head = nad.distinct_advisories(_report(
        _advisory("GHSA-old0-0000-0000", "already-here", "high"),
        _advisory("GHSA-seed-ed00-0001", "freshly-introduced", "critical"),
    ))
    introduced, resolved = nad.delta(base, head)
    check("the seeded advisory is detected", [a["id"] for a in introduced], ["GHSA-seed-ed00-0001"])
    check("nothing spuriously reported as resolved", resolved, [])
    check("it is blocking at threshold high", len(nad.at_or_above(introduced, "high")), 1)


def test_publication_event_cancels_out() -> None:
    """THE load-bearing property. An advisory published against dependencies
    the change did not touch appears on BOTH sides, so it must NOT fire —
    this is what makes the check structurally unable to cry wolf."""
    both = _report(
        _advisory("GHSA-pub0-lish-0000", "untouched-dep", "critical"),
        _advisory("GHSA-old0-0000-0000", "already-here", "high"),
    )
    introduced, resolved = nad.delta(
        nad.distinct_advisories(both), nad.distinct_advisories(both)
    )
    check("a publication event introduces nothing", introduced, [])
    check("and resolves nothing", resolved, [])
    check("so nothing blocks", nad.at_or_above(introduced, "low"), [])


def test_resolved_advisories_are_reported_not_failed() -> None:
    base = nad.distinct_advisories(_report(_advisory("GHSA-gone-0000-0000", "fixed-dep", "high")))
    head = nad.distinct_advisories(_report())
    introduced, resolved = nad.delta(base, head)
    check("a fixed advisory shows as resolved", [a["id"] for a in resolved], ["GHSA-gone-0000-0000"])
    check("and introduces nothing", introduced, [])


# --------------------------------------------------------------------------
# Severity threshold, both directions.
# --------------------------------------------------------------------------

def test_severity_threshold_both_directions() -> None:
    introduced = [
        {"id": "GHSA-mod0", "package": "p", "severity": "moderate", "title": "", "range": ""},
    ]
    check("an introduced moderate does NOT block at threshold high",
          nad.at_or_above(introduced, "high"), [])
    check("the same moderate DOES block at threshold moderate",
          len(nad.at_or_above(introduced, "moderate")), 1)


def test_unknown_severity_ranks_above_critical() -> None:
    """A severity npm invents later must never slip under a threshold."""
    check("unknown outranks critical",
          nad.severity_rank("apocalyptic") > nad.severity_rank("critical"), True)
    introduced = [
        {"id": "GHSA-new0", "package": "p", "severity": "apocalyptic", "title": "", "range": ""},
    ]
    check("and therefore still blocks at threshold critical",
          len(nad.at_or_above(introduced, "critical")), 1)


# --------------------------------------------------------------------------
# Fail-closed behaviour: the check must never pass when it could not measure.
# --------------------------------------------------------------------------

def test_audit_output_without_vulnerabilities_key_is_an_error() -> None:
    def fake_run(*_args, **_kwargs):
        class R:
            returncode = 0
            stdout = json.dumps({"someOtherShape": True}).encode()
            stderr = b""
        return R()

    real = subprocess.run
    nad.subprocess.run = fake_run  # type: ignore[assignment]
    try:
        check_raises("unrecognised audit JSON fails closed",
                     lambda: nad.audit_lockfile(b"{}"), "vulnerabilities")
    finally:
        nad.subprocess.run = real  # type: ignore[assignment]


def test_unparseable_audit_output_is_an_error() -> None:
    def fake_run(*_args, **_kwargs):
        class R:
            returncode = 1
            stdout = b"npm ERR! network timeout"
            stderr = b"boom"
        return R()

    real = subprocess.run
    nad.subprocess.run = fake_run  # type: ignore[assignment]
    try:
        check_raises("non-JSON audit output fails closed",
                     lambda: nad.audit_lockfile(b"{}"), "parseable")
    finally:
        nad.subprocess.run = real  # type: ignore[assignment]


def test_missing_base_ref_is_an_error_with_actionable_text() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        check_raises("an unreachable base ref fails closed",
                     lambda: nad.read_blob("no-such-ref", "x.json", root), "cannot read")


# --------------------------------------------------------------------------
# End to end, hermetically: an unchanged lockfile short-circuits before npm.
# --------------------------------------------------------------------------

def _git(root: pathlib.Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=root, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def test_unchanged_lockfile_exits_zero_without_npm() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        _git(root, "init", "-q")
        _git(root, "config", "user.email", "t@t.t")
        _git(root, "config", "user.name", "t")
        lock = root / "functions"
        lock.mkdir()
        (lock / "package-lock.json").write_text('{"lockfileVersion": 3}\n')
        _git(root, "add", "-A")
        _git(root, "commit", "-qm", "x")

        # If this ever tried to shell out to npm, the fake below would make it
        # explode — which is the point: an unchanged lockfile must not audit.
        real = subprocess.run

        def explode_on_npm(cmd, *a, **k):
            if isinstance(cmd, list) and cmd and cmd[0] == "npm":
                raise AssertionError("npm was invoked for an UNCHANGED lockfile")
            return real(cmd, *a, **k)

        nad.subprocess.run = explode_on_npm  # type: ignore[assignment]
        try:
            rc = nad.main(["--base-ref", "HEAD", "--repo-root", str(root)])
        finally:
            nad.subprocess.run = real  # type: ignore[assignment]
        check("unchanged lockfile exits 0", rc, 0)

        # Other direction: a CHANGED lockfile must NOT short-circuit. We prove it
        # reaches the audit step by asserting npm is invoked (then fail-closed).
        (lock / "package-lock.json").write_text('{"lockfileVersion": 3, "changed": true}\n')
        invoked: list[str] = []

        def record_npm(cmd, *a, **k):
            if isinstance(cmd, list) and cmd and cmd[0] == "npm":
                invoked.append("npm")

                class R:
                    returncode = 1
                    stdout = b"not json"
                    stderr = b""
                return R()
            return real(cmd, *a, **k)

        nad.subprocess.run = record_npm  # type: ignore[assignment]
        try:
            rc = nad.main(["--base-ref", "HEAD", "--repo-root", str(root)])
        finally:
            nad.subprocess.run = real  # type: ignore[assignment]
        check("a changed lockfile DOES reach the audit", invoked != [], True)
        check("and a broken audit fails closed with exit 2", rc, 2)


def test_missing_lockfile_fails_closed() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        _git(root, "init", "-q")
        rc = nad.main(["--base-ref", "HEAD", "--repo-root", str(root)])
        check("a missing lockfile exits 2, never 0", rc, 2)


def main() -> int:
    print("npm_audit_delta self-tests")
    for fn in (
        test_wrappers_collapse_to_advisories,
        test_advisory_without_url_is_not_dropped,
        test_base_ref_resolution_order,
        test_no_resolvable_base_skips_without_failing_the_build,
        test_seeded_advisory_fails,
        test_publication_event_cancels_out,
        test_resolved_advisories_are_reported_not_failed,
        test_severity_threshold_both_directions,
        test_unknown_severity_ranks_above_critical,
        test_audit_output_without_vulnerabilities_key_is_an_error,
        test_unparseable_audit_output_is_an_error,
        test_missing_base_ref_is_an_error_with_actionable_text,
        test_unchanged_lockfile_exits_zero_without_npm,
        test_missing_lockfile_fails_closed,
    ):
        print(f"\n{fn.__name__}")
        fn()
    print()
    if _failures:
        print(f"FAILED: {len(_failures)} check(s): {', '.join(_failures)}")
        return 1
    print("all checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
