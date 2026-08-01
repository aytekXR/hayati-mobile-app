#!/usr/bin/env python3
"""Self-tests for tool/ci/rules_drift.py (repo convention: every tool under
tool/ carries one, run by ci.yml's quality job).

Hermetic: no network, no Firebase, no credential. Every test either drives a
pure function or an injected fake transport, so this sits in `quality` with the
other pre-`pub get` self-tests rather than in the credentialed job.

THE MUTATION CHECK acceptance criterion 4 asks for is spread across
`test_seeded_drift_exits_one`, `test_whitespace_only_difference_is_drift` and
`test_matching_source_exits_zero`. Proving the script RUNS is worth nothing
here: a comparator that returned "no drift" unconditionally would sail through
a smoke test while guarding nothing — which is the `store_metadata` shape and
literally the defect issue #140 was filed about (`functions-rules` is honestly
green while guarding a file the runtime never reads). So every guard is
asserted in BOTH directions.

Two tests exist for reasons that are easy to miss:

  * `test_second_firestore_release_fails_closed` — a Firestore NAMED DATABASE
    gets its own release (`cloud.firestore/{db}`). A check that only ever reads
    `releases/cloud.firestore` would be silently PARTIAL the day one appears,
    which is the failure this whole tool exists to prevent, one level down.
  * `test_access_token_is_never_printed` — the anti-leak sentinel, same shape as
    slack_notify_test.sh's. A tool that mints an OAuth token and reports on a
    security artifact is exactly the place a token ends up in a public CI log.

Run: python3 tool/ci/rules_drift_test.py
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import pathlib
import tempfile

_MODULE_PATH = pathlib.Path(__file__).with_name("rules_drift.py")
_spec = importlib.util.spec_from_file_location("rules_drift", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
rd = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rd)

_failures: list[str] = []

LOCAL_RULES = "rules_version = '2';\nservice cloud.firestore {\n  // real\n}\n"


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


# --------------------------------------------------------------------------
# fakes
# --------------------------------------------------------------------------

def _release(name: str = "cloud.firestore", ruleset: str = "rs-1", project: str = "p") -> dict:
    # rulesetName is PROJECT-SCOPED, exactly as the real API returns it
    # (measured S058: projects/hayatiapp-prod/rulesets/3702186d-…). The first
    # draft of this fake hardcoded `projects/p/…` for every project, which made
    # the two-project test's drift branch unreachable — and its paired assertion
    # still passed, because it matched the section HEADER. A fake that is wrong
    # about the shape tests nothing, and fails in the reassuring direction.
    return {
        "name": f"projects/{project}/releases/{name}",
        "rulesetName": f"projects/{project}/rulesets/{ruleset}",
        "createTime": "2026-07-08T21:02:05Z",
        "updateTime": "2026-07-27T16:16:10Z",
    }


def _ruleset(content: str, filename: str = "firestore.rules") -> dict:
    return {
        "name": "projects/p/rulesets/rs-1",
        "createTime": "2026-07-27T16:16:09Z",
        "source": {"files": [{"name": filename, "content": content}]},
    }


class FakeApi:
    """Stands in for the firebaserules REST surface.

    `routes` maps a path SUFFIX to either a dict (returned) or an Exception
    (raised), so a test can make exactly one call fail.
    """

    def __init__(self, routes: dict[str, object]) -> None:
        self.routes = routes
        self.calls: list[str] = []

    def get(self, path: str) -> dict:
        self.calls.append(path)
        for suffix, value in self.routes.items():
            if path.endswith(suffix) or suffix in path:
                if isinstance(value, Exception):
                    raise value
                return value  # type: ignore[return-value]
        raise rd.MeasurementError(f"fake api: no route for {path}")


def _api_ok(content: str = LOCAL_RULES, filename: str = "firestore.rules") -> FakeApi:
    return FakeApi({
        "/releases?": {"releases": [_release()]},
        "/releases/cloud.firestore": _release(),
        "/rulesets/rs-1": _ruleset(content, filename),
    })


@contextlib.contextmanager
def _rules_file(content: str):
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / "firestore.rules"
        p.write_text(content)
        yield str(p)


def _run(argv: list[str], api: object) -> tuple[int, str]:
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        code = rd.main(argv, api_factory=lambda _cred: api)
    return code, buf.getvalue()


# --------------------------------------------------------------------------
# comparison — the core, asserted in BOTH directions
# --------------------------------------------------------------------------

def test_matching_source_exits_zero() -> None:
    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(["--project", "p", "--rules-file", f, "--access-token", "t"],
                         _api_ok())
    check("exit 0 when live == main", code, 0)
    check_in("says it matches", "matches", out)


def test_seeded_drift_exits_one() -> None:
    """THE mutation check: seed a real difference, demand red."""
    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(["--project", "p", "--rules-file", f, "--access-token", "t"],
                         _api_ok(content=LOCAL_RULES.replace("// real", "// STALE")))
    check("exit 1 on seeded drift", code, 1)
    check_in("prints the offending live line", "STALE", out)
    check_in("tells the reader what to DO about it", "deploy-rules", out)


def test_whitespace_only_difference_is_drift() -> None:
    """No normalization, deliberately. A ruleset that differs from the reviewed
    bytes by so much as a trailing space is not the reviewed ruleset."""
    with _rules_file(LOCAL_RULES) as f:
        code, _ = _run(["--project", "p", "--rules-file", f, "--access-token", "t"],
                       _api_ok(content=LOCAL_RULES + "\n"))
    check("trailing newline counts as drift", code, 1)


def test_unexpected_ruleset_filename_is_drift() -> None:
    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(["--project", "p", "--rules-file", f, "--access-token", "t"],
                         _api_ok(filename="something-else.rules"))
    check("a renamed file in the live ruleset is drift", code, 1)
    check_in("says which filename", "something-else.rules", out)
    # The bytes are identical here, so the report must NOT claim a content
    # difference and then print an empty diff — a report that misdescribes its
    # own finding sends the next reader hunting for something that is not there.
    check_not_in("does not claim the CONTENT differs when it does not",
                 "the live ruleset is NOT the ruleset on this ref", out)
    check_in("names the real reason instead", "the drift is in its shape", out)


def test_multi_file_live_ruleset_is_drift() -> None:
    """firebase.json declares exactly one rules file, so a live ruleset with two
    is a shape we never produced — report it rather than comparing files[0]."""
    api = FakeApi({
        "/releases?": {"releases": [_release()]},
        "/releases/cloud.firestore": _release(),
        "/rulesets/rs-1": {
            "name": "projects/p/rulesets/rs-1",
            "source": {"files": [
                {"name": "firestore.rules", "content": LOCAL_RULES},
                {"name": "extra.rules", "content": "// smuggled"},
            ]},
        },
    })
    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(["--project", "p", "--rules-file", f, "--access-token", "t"], api)
    check("two live files is drift, not a silent files[0] compare", code, 1)
    check_in("names the extra file", "extra.rules", out)


# --------------------------------------------------------------------------
# coverage completeness — the named-database gap
# --------------------------------------------------------------------------

def test_second_firestore_release_fails_closed() -> None:
    """A named database gets `cloud.firestore/{db}`. Comparing only the default
    release would leave it unguarded while still reporting green."""
    api = FakeApi({
        "/releases?": {"releases": [_release(), _release("cloud.firestore/analytics", "rs-2")]},
        "/releases/cloud.firestore": _release(),
        "/rulesets/rs-1": _ruleset(LOCAL_RULES),
    })
    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(["--project", "p", "--rules-file", f, "--access-token", "t"], api)
    check("a second firestore release fails CLOSED, never 0", code, 2)
    check_in("names the release it cannot compare", "cloud.firestore/analytics", out)


def test_non_firestore_release_is_reported_not_failed() -> None:
    """The other direction: storage rules are deliberately out of this tool's
    contract. They must NOT turn the check red — but they must be visible."""
    api = FakeApi({
        "/releases?": {"releases": [_release(), _release("firebase.storage/b.appspot.com", "rs-9")]},
        "/releases/cloud.firestore": _release(),
        "/rulesets/rs-1": _ruleset(LOCAL_RULES),
    })
    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(["--project", "p", "--rules-file", f, "--access-token", "t"], api)
    check("an out-of-contract service does not fail the check", code, 0)
    check_in("but it is reported", "firebase.storage", out)


# --------------------------------------------------------------------------
# fail-closed: never exit 0 without having measured
# --------------------------------------------------------------------------

def test_missing_release_fails_closed() -> None:
    api = FakeApi({
        "/releases?": {"releases": []},
        "/releases/cloud.firestore": rd.MeasurementError("HTTP 404: release not found"),
    })
    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(["--project", "p", "--rules-file", f, "--access-token", "t"], api)
    check("no release at all is exit 2, not 0", code, 2)
    check_in("says why", "404", out)


def test_api_error_fails_closed() -> None:
    api = FakeApi({"/releases": rd.MeasurementError("HTTP 403: caller lacks firebaserules.releases.get")})
    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(["--project", "p", "--rules-file", f, "--access-token", "t"], api)
    check("a permission error is exit 2, never 0", code, 2)
    check_in("surfaces the API reason", "firebaserules.releases.get", out)


def test_ruleset_without_source_fails_closed() -> None:
    api = FakeApi({
        "/releases?": {"releases": [_release()]},
        "/releases/cloud.firestore": _release(),
        "/rulesets/rs-1": {"name": "projects/p/rulesets/rs-1"},
    })
    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(["--project", "p", "--rules-file", f, "--access-token", "t"], api)
    check("an unexpected response shape is exit 2", code, 2)
    check_in("says what was missing", "source", out)


def test_missing_rules_file_fails_closed() -> None:
    code, out = _run(
        ["--project", "p", "--rules-file", "/nonexistent/firestore.rules", "--access-token", "t"],
        _api_ok())
    check("an unreadable local rules file is exit 2", code, 2)
    check_in("names the path", "/nonexistent/firestore.rules", out)


def test_no_credential_fails_closed_with_actionable_text() -> None:
    """The exit code alone is NOT a sufficient assertion here, and the mutation
    check proved it: with `resolve_credential` degraded to return "" instead of
    raising, the tool built a real client, hit the live endpoint, got 401 and
    still exited 2 — the check passed for the wrong reason, and a "hermetic"
    test made a network call. So this also pins the stronger property: with no
    credential the tool must never CONSTRUCT an API client at all."""
    constructed: list[str] = []

    class MustNotBeUsed:
        def get(self, path: str) -> dict:
            raise rd.MeasurementError("the API must not be reached without a credential")

    def factory(cred: str):
        constructed.append(cred)
        return MustNotBeUsed()

    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        code = rd.main(["--project", "p", "--rules-file", "firestore.rules"], api_factory=factory)
    out = buf.getvalue()
    check("no credential is exit 2, NOT a silent skip", code, 2)
    check("never constructs an API client without a credential", constructed, [])
    check_in("points at the operator item", "operator-expected", out)
    check_in("names the secret", "FIREBASE_RULES_VIEWER_SA", out)


def _section(out: str, project: str) -> str:
    """The report block for one project, so an assertion cannot be satisfied by
    text that belongs to a DIFFERENT project's block."""
    blocks = out.split("=== ")
    for b in blocks:
        if b.startswith(project + " ==="):
            return b
    return ""


def test_two_projects_report_independently() -> None:
    """One project drifting must not be hidden by the other matching."""
    class TwoProjectApi:
        def get(self, path: str) -> dict:
            project = path.split("/")[1]
            if "/releases?" in path:
                return {"releases": [_release(project=project)]}
            if "/releases/cloud.firestore" in path:
                return _release(project=project)
            content = LOCAL_RULES.replace("// real", "// STALE") \
                if project == "bad-project" else LOCAL_RULES
            return _ruleset(content)

    with _rules_file(LOCAL_RULES) as f:
        code, out = _run(
            ["--project", "good-project", "--project", "bad-project",
             "--rules-file", f, "--access-token", "t"], TwoProjectApi())
    check("one drifting project reddens the run", code, 1)
    check_in("good project's own block says it matches", "matches", _section(out, "good-project"))
    check_not_in("good project's own block claims no drift", "DRIFT", _section(out, "good-project"))
    check_in("bad project's own block says drift", "DRIFT", _section(out, "bad-project"))
    check_in("the error names only the drifting project", "::error::bad-project", out)
    check_not_in("the error does not name the matching project", "::error::good-project", out)


# --------------------------------------------------------------------------
# credential plumbing — pure functions only, no network
# --------------------------------------------------------------------------

def test_client_credentials_parsed_from_installed_cli() -> None:
    api_js = (
        'const clientId = () => utils.envOverride("FIREBASE_CLIENT_ID", "123-abc.apps.googleusercontent.com");\n'
        'const clientSecret = () => utils.envOverride("FIREBASE_CLIENT_SECRET", "s3cr3t-value");\n'
    )
    cid, csec = rd.client_credentials_from_api_js(api_js)
    check("client id parsed", cid, "123-abc.apps.googleusercontent.com")
    check("client secret parsed", csec, "s3cr3t-value")


def test_api_js_without_credentials_fails_closed() -> None:
    check_raises(
        "a firebase-tools that moved the constants is an error, not a guess",
        lambda: rd.client_credentials_from_api_js("const nothing = 1;\n"),
        "could not find")


def test_refresh_token_read_from_configstore() -> None:
    check("refresh token extracted",
          rd.refresh_token_from_configstore({"tokens": {"refresh_token": "rt"}}), "rt")
    check_raises("a logged-out CLI is an error",
                 lambda: rd.refresh_token_from_configstore({"tokens": {}}),
                 "not logged in")


def test_service_account_assertion_claims() -> None:
    sa = {"client_email": "sa@p.iam.gserviceaccount.com", "private_key": "-----BEGIN...",
          "token_uri": "https://oauth2.googleapis.com/token"}
    claims = rd.sa_assertion_claims(sa, now=1_000_000)
    check("issuer is the service account", claims["iss"], "sa@p.iam.gserviceaccount.com")
    check("audience is the token endpoint", claims["aud"], "https://oauth2.googleapis.com/token")
    check("read-only scope requested", claims["scope"],
          "https://www.googleapis.com/auth/firebase.readonly")
    check("expiry is one hour", claims["exp"] - claims["iat"], 3600)


def test_service_account_missing_field_fails_closed() -> None:
    check_raises("a truncated service-account JSON is an error",
                 lambda: rd.sa_assertion_claims({"client_email": "a@b"}, now=1),
                 "private_key")


# --------------------------------------------------------------------------
# anti-leak sentinel
# --------------------------------------------------------------------------

def test_access_token_is_never_printed() -> None:
    sentinel = "ya29.SENTINEL-DO-NOT-LOG"
    with _rules_file(LOCAL_RULES) as f:
        _, out_match = _run(
            ["--project", "p", "--rules-file", f, "--access-token", sentinel], _api_ok())
        _, out_drift = _run(
            ["--project", "p", "--rules-file", f, "--access-token", sentinel],
            _api_ok(content="// totally different"))
        _, out_err = _run(
            ["--project", "p", "--rules-file", f, "--access-token", sentinel],
            FakeApi({"/releases": rd.MeasurementError("HTTP 403 denied")}))
    check_not_in("token absent from the matching report", sentinel, out_match)
    check_not_in("token absent from the drift report", sentinel, out_drift)
    check_not_in("token absent from the error path", sentinel, out_err)


def main() -> int:
    print("rules_drift self-tests")
    for fn in (
        test_matching_source_exits_zero,
        test_seeded_drift_exits_one,
        test_whitespace_only_difference_is_drift,
        test_unexpected_ruleset_filename_is_drift,
        test_multi_file_live_ruleset_is_drift,
        test_second_firestore_release_fails_closed,
        test_non_firestore_release_is_reported_not_failed,
        test_missing_release_fails_closed,
        test_api_error_fails_closed,
        test_ruleset_without_source_fails_closed,
        test_missing_rules_file_fails_closed,
        test_no_credential_fails_closed_with_actionable_text,
        test_two_projects_report_independently,
        test_client_credentials_parsed_from_installed_cli,
        test_api_js_without_credentials_fails_closed,
        test_refresh_token_read_from_configstore,
        test_service_account_assertion_claims,
        test_service_account_missing_field_fails_closed,
        test_access_token_is_never_printed,
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
