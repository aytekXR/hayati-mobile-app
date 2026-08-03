#!/usr/bin/env python3
"""Self-tests for tool/ci/testflight_testers.py (repo convention: every tool
under tool/ carries one, run by ci.yml's quality job).

Scope is deliberately the parts that can be wrong WITHOUT Apple noticing: the
email list parse, and the ES256 assertion. The HTTP calls are not mocked —
Apple's JSON:API shapes are not something a local fake can validate, and a fake
that agrees with a wrong assumption is worse than no test. Those are proven by
dispatching the workflow with --dry-run, which reads and writes nothing.

Run: python3 tool/ci/testflight_testers_test.py
"""

from __future__ import annotations

import base64
import contextlib
import importlib.util
import io
import os
import pathlib
import sys

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

_MODULE_PATH = pathlib.Path(__file__).with_name("testflight_testers.py")
_spec = importlib.util.spec_from_file_location("testflight_testers", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
tf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tf)

# `test_await_build` monkeypatches tf.list_builds and never puts it back, so any
# later test that drives main() would silently inherit its last stub — which is
# an EXPIRED build, quietly turning "assignment happened" into "nothing to
# assign". Captured here, restored by the test that needs the real one.
_REAL_LIST_BUILDS = tf.list_builds

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
    except tf.AscError as failure:
        if needle in str(failure):
            print(f"  ok   {label}")
        else:
            print(f"  FAIL {label}: message lacked {needle!r} -> {failure}")
            _failures.append(label)
        return
    print(f"  FAIL {label}: no AscError raised")
    _failures.append(label)


def test_parse_emails() -> None:
    print("parse_emails")
    check("comma separated", tf.parse_emails("a@x.com,b@x.com"), ["a@x.com", "b@x.com"])
    check("whitespace tolerated", tf.parse_emails(" a@x.com ,\n b@x.com "), ["a@x.com", "b@x.com"])
    check("empty is empty", tf.parse_emails(""), [])
    check("trailing comma", tf.parse_emails("a@x.com,"), ["a@x.com"])
    # The duplicate guard is the one that protects a real person's inbox.
    check("case-insensitive dedupe", tf.parse_emails("A@x.com,a@x.com"), ["A@x.com"])
    check("order preserved", tf.parse_emails("c@x.com b@x.com a@x.com"),
          ["c@x.com", "b@x.com", "a@x.com"])


def _pkcs8_pem() -> str:
    key = ec.generate_private_key(ec.SECP256R1())
    return key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()


def _set_creds(pem_b64: str) -> None:
    os.environ["ASC_KEY_ID"] = "TESTKEYID1"
    os.environ["ASC_ISSUER_ID"] = "11111111-2222-3333-4444-555555555555"
    os.environ["ASC_API_KEY_P8_BASE64"] = pem_b64


def test_token() -> None:
    print("_token")
    pem = _pkcs8_pem()
    flat = base64.b64encode(pem.encode()).decode()

    _set_creds(flat)
    token = tf._token()
    header = jwt.get_unverified_header(token)
    check("alg is ES256", header["alg"], "ES256")
    check("kid is the key id", header["kid"], "TESTKEYID1")
    claims = jwt.decode(
        token,
        serialization.load_pem_private_key(pem.encode(), password=None).public_key(),
        algorithms=["ES256"],
        audience="appstoreconnect-v1",
    )
    check("iss is the issuer id", claims["iss"], "11111111-2222-3333-4444-555555555555")
    check("ttl within Apple's 20-minute cap", claims["exp"] - claims["iat"] <= 1200, True)

    # The release lane's documented footgun: a base64 secret pasted with
    # newlines. Ruby's decode64 ignores them, strict decoders do not — so the
    # wrapped form must mint the SAME token payload as the flat one.
    wrapped = "\n".join(flat[i:i + 64] for i in range(0, len(flat), 64))
    _set_creds(wrapped)
    check("newline-wrapped base64 decodes identically",
          jwt.get_unverified_header(tf._token())["kid"], "TESTKEYID1")

    # Fail CLOSED, naming what is absent — never a silent unauthenticated call.
    _set_creds(flat)
    for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_API_KEY_P8_BASE64"):
        saved = os.environ[name]
        os.environ[name] = ""
        check_raises(f"missing {name} fails closed", tf._token, name)
        os.environ[name] = saved

    os.environ["ASC_API_KEY_P8_BASE64"] = base64.b64encode(b"not a pem").decode()
    check_raises("non-PEM secret fails closed", tf._token, "PKCS#8 PEM")


def _build(version, state, expired=False):
    return {"id": f"id-{version}", "attributes": {"version": version,
            "processingState": state, "expired": expired}}


def test_await_build() -> None:
    """`await_build` is what stops the release lane attaching a build that has
    no installable asset yet — reporting success while delivering nothing."""
    calls = {"n": 0}
    naps = []

    def once(builds):
        return lambda _t, _a, limit=5: builds

    # VALID straight away.
    tf.list_builds = once([_build("110", "VALID"), _build("109", "VALID")])
    got = tf.await_build("t", "app", "110", 600, sleep=naps.append)
    check("returns the VALID build", got["id"], "id-110")
    check("and did not sleep", naps, [])

    # PROCESSING, then VALID — the case the polling exists for.
    seq = [[_build("110", "PROCESSING")], [_build("110", "PROCESSING")],
           [_build("110", "VALID")]]
    def stepper(_t, _a, limit=5):
        calls["n"] += 1
        return seq[min(calls["n"] - 1, len(seq) - 1)]
    tf.list_builds = stepper
    naps.clear()
    got = tf.await_build("t", "app", "110", 600, sleep=naps.append)
    check("waits through PROCESSING then returns", got["id"], "id-110")
    check("and slept between polls", len(naps) >= 1, True)

    # Apple rejected it: stop immediately rather than burning the timeout.
    tf.list_builds = once([_build("110", "INVALID")])
    naps.clear()
    check("INVALID gives up at once", tf.await_build("t", "app", "110", 600, sleep=naps.append), None)
    check("without sleeping", naps, [])

    # Timeout is not an error, and must not return a not-VALID build.
    tf.list_builds = once([_build("110", "PROCESSING")])
    check("timeout returns None", tf.await_build("t", "app", "110", 60, sleep=lambda _s: None), None)

    # Matches by NUMBER, not by position — the newest build is not necessarily ours.
    tf.list_builds = once([_build("111", "VALID"), _build("110", "VALID")])
    check("matches the requested build number",
          tf.await_build("t", "app", "110", 600, sleep=lambda _s: None)["id"], "id-110")

    # An expired build is not installable either.
    tf.list_builds = once([_build("110", "VALID", expired=True)])
    check("an expired build is not accepted",
          tf.await_build("t", "app", "110", 60, sleep=lambda _s: None), None)


# ---------------------------------------------------------------------------
# ADR-038 — Test Information and Beta App Review
# ---------------------------------------------------------------------------

# Values chosen so a leak is unmistakable in a diff AND so each is a distinct
# needle: a sentinel test that reuses one string cannot tell you WHICH field
# escaped. The phone shape mirrors a real one because that is the value whose
# escape into a public log actually costs the founder something.
SENTINELS = {
    "ASC_REVIEW_CONTACT_FIRST_NAME": "SENTINELFIRST",
    "ASC_REVIEW_CONTACT_LAST_NAME": "SENTINELLAST",
    "ASC_REVIEW_CONTACT_EMAIL": "sentinel@leak.invalid",
    "ASC_REVIEW_CONTACT_PHONE": "+905550000000",
}


def _fake_call(script):
    """Replace tf._call with a scripted responder; records every request."""
    seen = []

    def call(_token, method, path, body=None):
        seen.append((method, path, body))
        for match_method, match_fragment, response in script:
            if method == match_method and match_fragment in path:
                if isinstance(response, Exception):
                    raise response
                return response
        return {}

    tf._call = call
    return seen


def test_read_review_contact() -> None:
    print("read_review_contact")
    check("all four present", tf.read_review_contact(dict(SENTINELS)),
          {"contactFirstName": "SENTINELFIRST", "contactLastName": "SENTINELLAST",
           "contactEmail": "sentinel@leak.invalid", "contactPhone": "+905550000000"})
    check("whitespace stripped",
          tf.read_review_contact({**SENTINELS, "ASC_REVIEW_CONTACT_EMAIL": "  a@b.co \n"})
          ["contactEmail"], "a@b.co")
    # ALL FOUR or nothing: a partial write leaves the readiness check reporting
    # a gap the log just claimed to close.
    partial = {k: v for k, v in SENTINELS.items() if k != "ASC_REVIEW_CONTACT_PHONE"}
    check_raises("missing phone fails closed",
                 lambda: tf.read_review_contact(partial), "ASC_REVIEW_CONTACT_PHONE")
    check_raises("names ALL missing secrets",
                 lambda: tf.read_review_contact({}), "ASC_REVIEW_CONTACT_FIRST_NAME")
    # And the failure must name the secret, never a value it did receive.
    try:
        tf.read_review_contact(partial)
    except tf.AscError as failure:
        check("failure text leaks no value",
              any(s in str(failure) for s in SENTINELS.values()), False)


def test_set_review_contact_never_leaks() -> None:
    """THE guarantee of ADR-038 D1, asserted rather than promised (rule S020).

    This repository is PUBLIC and workflow logs are permanent. GitHub's secret
    masking is a backstop; the design is that a value is never formatted into
    an output string at all. That is only true if something checks."""
    print("set_review_contact")
    contact = tf.read_review_contact(dict(SENTINELS))

    # Nothing set yet -> a real PATCH, and the summary names FIELDS only.
    seen = _fake_call([
        ("GET", "betaAppReviewDetail", {"data": {"id": "detail-1", "attributes": {}}}),
        ("PATCH", "betaAppReviewDetails/detail-1", {}),
    ])
    line = tf.set_review_contact("t", "app-1", contact)
    check("summary names the fields", sorted(line.split("set ")[1].split(", ")),
          ["contactEmail", "contactFirstName", "contactLastName", "contactPhone"])
    check("summary leaks NO value", [s for s in SENTINELS.values() if s in line], [])
    check("patched the id read from the app relationship",
          [p for m, p, _ in seen if m == "PATCH"], ["/v1/betaAppReviewDetails/detail-1"])
    check("the values DID reach Apple",
          [b for m, _, b in seen if m == "PATCH"][0]["data"]["attributes"], contact)

    # Already correct -> no write at all, and still no value in the line.
    seen = _fake_call([
        ("GET", "betaAppReviewDetail", {"data": {"id": "detail-1", "attributes": contact}}),
    ])
    line = tf.set_review_contact("t", "app-1", contact)
    check("unchanged says so", "unchanged" in line, True)
    check("unchanged writes nothing", [m for m, _, _ in seen if m != "GET"], [])
    check("unchanged leaks NO value", [s for s in SENTINELS.values() if s in line], [])

    # dry-run must not write. The review found this unspecified; it is now pinned.
    seen = _fake_call([
        ("GET", "betaAppReviewDetail", {"data": {"id": "detail-1", "attributes": {}}}),
    ])
    line = tf.set_review_contact("t", "app-1", contact, dry_run=True)
    check("dry-run says WOULD SET", "WOULD SET" in line, True)
    check("dry-run writes nothing", [m for m, _, _ in seen if m != "GET"], [])
    check("dry-run leaks NO value", [s for s in SENTINELS.values() if s in line], [])

    # No detail resource yet -> create it, with the app relationship.
    seen = _fake_call([
        ("GET", "betaAppReviewDetail", {"data": None}),
        ("POST", "betaAppReviewDetails", {}),
    ])
    line = tf.set_review_contact("t", "app-1", contact)
    posted = [b for m, p, b in seen if m == "POST"][0]
    check("creates when absent",
          posted["data"]["relationships"]["app"]["data"]["id"], "app-1")
    check("create leaks NO value", [s for s in SENTINELS.values() if s in line], [])


def test_submit_for_review() -> None:
    print("submit_for_review")
    ready = {"contactEmail": "a@b.co", "contactFirstName": "A",
             "contactLastName": "B", "contactPhone": "+1"}
    build = {"id": "b-110", "attributes": {"version": "110"}}

    def script(state, *extra):
        return [
            ("GET", "betaAppReviewDetail", {"data": {"id": "d", "attributes": ready}}),
            ("GET", "betaAppLocalizations",
             {"data": [{"attributes": {"locale": "en-US", "description": "d",
                                       "feedbackEmail": "f@x.co"}}]}),
            ("GET", "buildBetaDetail",
             {"data": {"attributes": {"externalBuildState": state}}}),
            *extra,
        ]

    seen = _fake_call(script("PROCESSING", ("POST", "betaAppReviewSubmissions", {})))
    check("submits when eligible",
          "submitted for Beta App Review" in tf.submit_for_review("t", "app", build), True)
    check("posted the build relationship",
          [b for m, p, b in seen if m == "POST"][0]["data"]["relationships"]["build"]["data"]["id"],
          "b-110")

    # dry-run: no POST. Unspecified in the first draft of the ADR; pinned here.
    seen = _fake_call(script("PROCESSING", ("POST", "betaAppReviewSubmissions", {})))
    line = tf.submit_for_review("t", "app", build, dry_run=True)
    check("dry-run says WOULD", "WOULD submit" in line, True)
    check("dry-run posts nothing", [m for m, _, _ in seen if m == "POST"], [])

    # Already through the gate -> a no-op that SAYS SO, not an error and not a
    # second submission. Each state checked, because a wrong one submits twice.
    for state in sorted(tf.ALREADY_SUBMITTED_STATES):
        seen = _fake_call(script(state, ("POST", "betaAppReviewSubmissions", {})))
        line = tf.submit_for_review("t", "app", build)
        check(f"{state} is a no-op", "nothing to submit" in line, True)
        check(f"{state} posts nothing", [m for m, _, _ in seen if m == "POST"], [])

    # Export compliance blocks review, and the message must name the fix.
    for state in tf.BLOCKED_BEFORE_REVIEW_STATES:
        _fake_call(script(state))
        check_raises(f"{state} refuses",
                     lambda: tf.submit_for_review("t", "app", build), state)

    # An unknown state is NOT treated as "already submitted" — it tries, which
    # is the safe direction because the POST is itself a guard.
    _fake_call(script("SOME_STATE_APPLE_ADDED_LATER",
                      ("POST", "betaAppReviewSubmissions", {})))
    check("an unknown state still attempts",
          "submitted for Beta App Review" in tf.submit_for_review("t", "app", build), True)

    # Refuses outright when Test Information is incomplete: an avoidable
    # rejection is recorded against the founder's app forever.
    _fake_call([
        ("GET", "betaAppReviewDetail", {"data": {"id": "d", "attributes": {}}}),
        ("GET", "betaAppLocalizations", {"data": []}),
    ])
    check_raises("refuses when Test Information is incomplete",
                 lambda: tf.submit_for_review("t", "app", build), "refusing to submit")

    # ---- THE 2026-08-02 DEFECT -------------------------------------------
    # Apple's conflict phrases span two OPPOSITE outcomes, and the version that
    # read them as one reported a REFUSAL as `already submitted — no-op` with
    # exit 0: build 114 was never submitted, build 113 was still in review, and
    # the operator was told the opposite. The sentence cannot settle which build
    # holds the queue. The RE-READ can, so these assert the re-read.
    conflict = tf.AscError(
        "POST /v1/betaAppReviewSubmissions -> HTTP 409: "
        "{'detail':'Another build is in review'}"
    )

    def sequenced(*states):
        """buildBetaDetail answers `states` in order, the last one repeating.

        The pre-flight read and the post-failure re-read must be able to DIFFER,
        which the flat script fake cannot express — it matches by path and would
        hand both reads the same state, making the race and the refusal
        indistinguishable in exactly the way the code under test must not be.
        """
        remaining = list(states)
        seen = []

        def call(_token, method, path, body=None):
            seen.append((method, path, body))
            if "betaAppReviewDetail" in path:
                return {"data": {"id": "d", "attributes": ready}}
            if "betaAppLocalizations" in path:
                return {"data": [{"attributes": {"locale": "en-US",
                                                 "description": "d",
                                                 "feedbackEmail": "f@x.co"}}]}
            if "buildBetaDetail" in path:
                state = remaining.pop(0) if len(remaining) > 1 else remaining[0]
                return {"data": {"attributes": {"externalBuildState": state}}}
            if method == "POST":
                raise conflict
            return {}

        tf._call = call
        return seen

    # A DIFFERENT build holds the queue: the re-read shows this one never moved,
    # so this is a refusal and must be loud. Each needle checked separately —
    # the operator acts on all four, and the fake is stable under repetition.
    for label, needle in (
        ("a refusal is NOT reported as a no-op", "was NOT submitted"),
        ("names the state it is STILL in", "still READY_FOR_BETA_SUBMISSION"),
        ("says why, so the operator knows to wait", "per VERSION TRAIN"),
        ("quotes Apple rather than paraphrasing", "Another build is in review"),
    ):
        sequenced("READY_FOR_BETA_SUBMISSION", "READY_FOR_BETA_SUBMISSION")
        check_raises(label, lambda: tf.submit_for_review("t", "app", build), needle)

    # THIS build got submitted by an overlapping dispatch between our state read
    # and our POST — the race the backstop exists for, and still a real no-op.
    seen = sequenced("PROCESSING", "WAITING_FOR_BETA_REVIEW")
    line = tf.submit_for_review("t", "app", build)
    check("the RACE is still a no-op", "no-op" in line, True)
    check("the race no-op names the state Apple moved it to",
          "WAITING_FOR_BETA_REVIEW" in line, True)
    check("the race no-op does NOT claim we submitted it",
          "submitted for Beta App Review" in line, False)
    check("the re-read actually happened",
          len([p for m, p, _ in seen if m == "GET" and "buildBetaDetail" in p]), 2)

    # The re-read must not become a new way to swallow a real failure: an error
    # that is not the queue talking propagates untouched, with no second GET.
    seen = _fake_call(script("PROCESSING", (
        "POST", "betaAppReviewSubmissions",
        tf.AscError("POST /v1/x -> HTTP 401: Authentication credentials are missing"),
    )))
    check_raises("a real failure still raises",
                 lambda: tf.submit_for_review("t", "app", build), "HTTP 401")
    check("and is not re-read first",
          len([p for m, p, _ in seen if m == "GET" and "buildBetaDetail" in p]), 1)


def test_print_store_status() -> None:
    """The APP STORE side of the house, which is NOT the TestFlight side.

    A build can be `BETA_APPROVED` and live to six testers while the app has no
    App Store version at all — `deliver` writes to the version, so this is the
    only reader that can answer "is there something to upload screenshots to?".
    It must never fail closed on the sub-reads: a listing that shows the
    versions but not their locales is more useful than a traceback."""
    print("print_store_status")
    app = {"id": "app-1", "attributes": {"name": "ikimiz"}}

    def run(script) -> tuple[str, list]:
        seen = _fake_call(script)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            tf.print_store_status("t", app)
        return out.getvalue(), seen

    # EVERY fragment below ends in `?` on purpose. These four endpoints NEST —
    # `/v1/appStoreVersions/v-1/appStoreVersionLocalizations?…` contains the
    # literal `appStoreVersions`, and `_fake_call` returns the FIRST substring
    # match — so the bare names make the versions entry swallow the locale call
    # and hand it a version list. Caught here by two assertions going red, which
    # is the only reason this is a comment and not a live bug: the fake would
    # otherwise have agreed with the wrong assumption. `?` only ever appears
    # where the query string starts, i.e. on the LAST path segment.

    # NO version at all — the state this app was actually in, and the one a
    # naive reader would render as an empty section that looks like success.
    text, seen = run([("GET", "appStoreVersions?", {"data": []})])
    check("no version says so", "never had an App Store version" in text, True)
    check("no version names what deliver needs",
          "PREPARE_FOR_SUBMISSION" in text, True)
    check("no version asks Apple nothing further",
          [p for _, p, _ in seen if "Localizations" in p], [])

    def version(state):
        return [
            ("GET", "appStoreVersions?", {"data": [{
                "id": "v-1",
                "attributes": {"versionString": "1.0", "appStoreState": state,
                               "platform": "IOS"},
            }]}),
            ("GET", "appStoreVersionLocalizations?", {"data": [
                {"id": "loc-1", "attributes": {"locale": "tr"}},
            ]}),
            ("GET", "appScreenshotSets?", {"data": [
                {"id": "set-1",
                 "attributes": {"screenshotDisplayType": "APP_IPHONE_67"}},
            ]}),
            ("GET", "appScreenshots?", {"data": [{"id": "s-1"}, {"id": "s-2"}]}),
        ]

    text, _ = run(version("PREPARE_FOR_SUBMISSION"))
    check("an editable version is marked", "<-- editable" in text, True)
    check("the state is printed verbatim",
          "state=PREPARE_FOR_SUBMISSION" in text, True)
    check("the locale is listed", "tr:" in text, True)
    check("existing screenshots are COUNTED, not just named",
          "APP_IPHONE_67=2" in text, True)

    # A state Apple adds tomorrow: printed verbatim, NOT marked editable, and
    # never suppressed. The hint is a hint; hiding the row would hide the one
    # thing the operator opened this for.
    text, _ = run(version("SOME_STATE_APPLE_ADDED_LATER"))
    check("an unknown state still appears",
          "state=SOME_STATE_APPLE_ADDED_LATER" in text, True)
    check("an unknown state is not called editable", "<-- editable" in text, False)

    # A live version mid-review is shown and correctly NOT editable — the
    # difference between "there is a version" and "you can write to it".
    text, _ = run(version("WAITING_FOR_REVIEW"))
    check("a non-editable state is shown but unmarked",
          ("WAITING_FOR_REVIEW" in text, "<-- editable" in text), (True, False))

    # DEGRADATION, both levels. A sub-read that dies must cost its own line and
    # nothing else — the version list is the part the operator came for.
    text, _ = run([
        version("PREPARE_FOR_SUBMISSION")[0],
        ("GET", "appStoreVersionLocalizations?",
         tf.AscError("GET /v1/x -> HTTP 403: forbidden")),
    ])
    check("a locale failure keeps the version row",
          ("1.0" in text, "locales unavailable" in text), (True, True))

    text, _ = run([
        *version("PREPARE_FOR_SUBMISSION")[:2],
        ("GET", "appScreenshotSets?", tf.AscError("GET /v1/x -> HTTP 403: nope")),
    ])
    check("a screenshot-set failure keeps the locale row",
          ("tr:" in text, "screenshot sets unavailable" in text), (True, True))


def test_looks_like_submission_conflict() -> None:
    """The BACKSTOP for a duplicate submission. The primary guard is the state
    read; this only covers the race. It requires BOTH an error family AND a
    phrase precisely because this repo has NOT measured which status Apple
    returns — the design review found 409 and 422 both claimed in the wild.

    It recognises the QUEUE and deliberately does NOT say which build is holding
    it: both outcomes live in one phrase list, and `submit_for_review` settles
    them by re-reading the state. Splitting them here by sentence is what the
    2026-08-02 measurement falsified."""
    print("looks_like_submission_conflict")
    check("422 + phrase", tf.looks_like_submission_conflict(
        "POST /v1/x -> HTTP 422: {'detail':'Another build is in review'}"), True)
    check("409 + phrase", tf.looks_like_submission_conflict(
        "POST /v1/x -> HTTP 409: already submitted"), True)
    # Both outcomes match, on purpose. The predicate's job is "re-read", not
    # "decide" — asserted so a future split here has to argue with a test.
    check("'another build' and 'already submitted' are ONE family",
          [tf.looks_like_submission_conflict("POST /v1/x -> HTTP 409: " + phrase)
           for phrase in ("Another build is in review", "already been submitted")],
          [True, True])
    # The two halves that must NOT be enough on their own.
    check("422 without the phrase is a REAL error", tf.looks_like_submission_conflict(
        "POST /v1/x -> HTTP 422: {'detail':'Invalid build id'}"), False)
    check("the phrase without the family is a REAL error", tf.looks_like_submission_conflict(
        "POST /v1/x -> HTTP 500: already submitted"), False)
    check("401 is never swallowed", tf.looks_like_submission_conflict(
        "POST /v1/x -> HTTP 401: Authentication credentials are missing"), False)


def test_missing_contact_does_not_block_assignment() -> None:
    """ADR-037's guarantee must survive ADR-038's new flag.

    `release.yml` passes --set-review-contact on EVERY release. If a missing
    ASC_REVIEW_CONTACT_* secret aborted the run, the build assignment would
    stop happening for any founder who has not set the four secrets — a
    regression invisible to every other test, because the release step is
    continue-on-error and would still look green."""
    print("missing contact does not block assignment")
    tf.list_builds = _REAL_LIST_BUILDS  # see the note beside _REAL_LIST_BUILDS
    for name in SENTINELS:
        os.environ.pop(name, None)

    seen = _fake_call([
        ("GET", "/v1/apps?", {"data": [{"id": "app-1", "attributes": {"name": "ikimiz"}}]}),
        ("GET", "/v1/betaGroups?", {"data": [{"id": "g-1", "attributes": {
            "name": "Friends", "isInternalGroup": False}}]}),
        ("GET", "betaGroups/g-1/betaTesters", {"data": []}),
        ("GET", "/v1/builds?", {"data": [{"id": "b-110", "attributes": {
            "version": "110", "processingState": "VALID", "expired": False}}]}),
        ("GET", "betaAppReviewDetail", {"data": {"id": "d", "attributes": {}}}),
        ("GET", "betaAppLocalizations", {"data": []}),
        ("POST", "builds/b-110/relationships/betaGroups", {}),
    ])
    argv, real_token = sys.argv, tf._token
    tf._token = lambda: "fake-jwt"  # the ASC key path has its own tests above
    sys.argv = ["testflight_testers.py", "--bundle-id", "com.beyondkaira.hayati",
                "--group", "Friends", "--set-review-contact", "--assign-latest-build"]
    try:
        code = tf.main()
    finally:
        sys.argv, tf._token = argv, real_token

    check("the build WAS still assigned",
          [p for m, p, _ in seen if m == "POST" and "relationships/betaGroups" in p],
          ["/v1/builds/b-110/relationships/betaGroups"])
    check("no contact was written",
          [p for m, p, _ in seen if m in ("PATCH",) or (m == "POST" and "betaAppReviewDetails" in p)],
          [])
    check("but the run still exits non-zero", code, 1)


def test_dry_run_against_a_missing_group_still_exits_non_zero() -> None:
    """Found by the build-diff review, and it is the MOST LIKELY first dispatch.

    `dry_run` defaults to true in the workflow, and a group that does not exist
    yet is exactly the state someone dry-runs against. The early return in that
    branch was an unconditional `return 0`, so it discarded the exit code a
    failed contact write had just set — reporting a clean run for the one case
    where the log had literally printed the error."""
    print("dry-run against a missing group still exits non-zero")
    tf.list_builds = _REAL_LIST_BUILDS
    for name in SENTINELS:
        os.environ.pop(name, None)

    _fake_call([
        ("GET", "/v1/apps?", {"data": [{"id": "app-1", "attributes": {"name": "ikimiz"}}]}),
        ("GET", "/v1/betaGroups?", {"data": []}),  # no group of that name
        ("GET", "betaAppReviewDetail", {"data": {"id": "d", "attributes": {}}}),
    ])
    argv, real_token = sys.argv, tf._token
    tf._token = lambda: "fake-jwt"
    sys.argv = ["testflight_testers.py", "--bundle-id", "com.beyondkaira.hayati",
                "--group", "Nope", "--set-review-contact", "--dry-run"]
    try:
        code = tf.main()
    finally:
        sys.argv, tf._token = argv, real_token
    check("the early return carries the exit code", code, 1)

    # And the other direction: with the secrets present, the same dry run is a
    # clean 0 — otherwise the check above would pass for a tool that always
    # failed.
    os.environ.update(SENTINELS)
    _fake_call([
        ("GET", "/v1/apps?", {"data": [{"id": "app-1", "attributes": {"name": "ikimiz"}}]}),
        ("GET", "/v1/betaGroups?", {"data": []}),
        ("GET", "betaAppReviewDetail", {"data": {"id": "d", "attributes": {}}}),
    ])
    argv, real_token = sys.argv, tf._token
    tf._token = lambda: "fake-jwt"
    sys.argv = ["testflight_testers.py", "--bundle-id", "com.beyondkaira.hayati",
                "--group", "Nope", "--set-review-contact", "--dry-run"]
    try:
        code = tf.main()
    finally:
        sys.argv, tf._token = argv, real_token
        for name in SENTINELS:
            os.environ.pop(name, None)
    check("and is 0 when nothing failed", code, 0)


def test_group_membership_is_looked_up_the_readable_way() -> None:
    """The direction is the whole point, and Apple decided it, not us.

    `GET /v1/builds/{id}/betaGroups` returns 403 FORBIDDEN_ERROR — that
    relationship allows only CREATE and DELETE. Measured against the real API
    AFTER the hermetic tests, five review lenses and a completeness critic had
    all passed the forward version. This test pins the direction so nobody
    "simplifies" it back."""
    print("group membership is looked up the readable way")
    seen = _fake_call([
        ("GET", "/v1/betaGroups?", {"data": [
            {"id": "g-1", "attributes": {"name": "Friends"}},
            {"id": "g-2", "attributes": {"name": "arkadaslar"}},
        ]}),
        ("GET", "betaGroups/g-1/builds", {"data": [{"id": "b-110"}]}),
        ("GET", "betaGroups/g-2/builds", {"data": [{"id": "b-109"}, {"id": "b-110"}]}),
    ])
    got = tf.group_names_by_build("t", "app-1")
    check("a build in two groups lists both", sorted(got["b-110"]),
          ["Friends", "arkadaslar"])
    check("a build in one group lists one", got["b-109"], ["arkadaslar"])
    check("a build in none is absent", "b-1" in got, False)
    # The forbidden call must never be made.
    check("never asks builds->betaGroups",
          [p for _, p, _ in seen if "/betaGroups" in p and p.startswith("/v1/builds")],
          [])
    check("one call per group, not per build",
          len([p for _, p, _ in seen if "/builds" in p and "betaGroups/" in p]), 2)


def test_merge_group() -> None:
    """Merging is a DELETE wearing a friendly name, so every guard is pinned.

    The founder asked to collapse `arkadaslar` into `Friends` and keep one
    group. The dangerous version of that request is the one that deletes the
    source before proving the members landed — a silent, unrecoverable loss of
    someone's access that every status read afterwards would report as clean.
    So the ordering (link -> RE-READ -> delete) is the guarantee, and the
    re-read is asserted here rather than assumed."""
    print("merge_group")
    target = {"id": "tgt-1", "attributes": {"name": "Friends", "isInternalGroup": False}}

    def groups(source=None):
        return [
            {"id": "tgt-1", "attributes": {"name": "Friends", "isInternalGroup": False}},
            *([source] if source else []),
        ]

    external_source = {"id": "src-1",
                       "attributes": {"name": "arkadaslar", "isInternalGroup": False}}

    # Merging a group into itself is a pure delete with a reassuring label.
    _fake_call([("GET", "/v1/betaGroups?", {"data": groups(external_source)})])
    check_raises("refuses merging a group into itself",
                 lambda: tf.merge_group("t", "app-1", "friends", target), "itself")

    # A typo must NOT read as "already merged" — that is the false-clean this
    # repo keeps being bitten by. Refuse, and name what does exist.
    _fake_call([("GET", "/v1/betaGroups?", {"data": groups(external_source)})])
    try:
        tf.merge_group("t", "app-1", "arkadaslr", target)
        check("refuses an unknown source group", "no error", "AscError")
    except tf.AscError as failure:
        check("unknown source names the typo", "arkadaslr" in str(failure), True)
        check("unknown source lists what exists", "arkadaslar" in str(failure), True)

    # Internal groups mean App Store Connect SEATS, not invites. Deleting one is
    # a different act than the founder asked for.
    _fake_call([("GET", "/v1/betaGroups?", {"data": groups(
        {"id": "src-1", "attributes": {"name": "founders", "isInternalGroup": True}})})])
    check_raises("refuses to delete an INTERNAL group",
                 lambda: tf.merge_group("t", "app-1", "founders", target), "internal")

    # ---- the happy path, with a stateful fake: the target membership must
    # actually CHANGE between the link and the verification re-read, which a
    # fragment-matched script cannot express.
    def stateful(*, link_lands: bool):
        state = {"target": [{"id": "u2", "attributes": {"email": "b@x.co"}}],
                 "deleted": [], "linked": [], "reads": 0}

        def call(_token, method, path, body=None):
            if method == "GET" and "/v1/betaGroups?" in path:
                return {"data": groups(external_source)}
            if method == "GET" and "betaGroups/src-1/betaTesters" in path:
                return {"data": [{"id": "u1", "attributes": {"email": "A@x.co"}},
                                 {"id": "u2", "attributes": {"email": "b@x.co"}}]}
            if method == "GET" and "betaGroups/tgt-1/betaTesters" in path:
                state["reads"] += 1
                return {"data": list(state["target"])}
            if method == "POST" and "betaGroups/tgt-1/relationships" in path:
                state["linked"] = [d["id"] for d in body["data"]]
                if link_lands:
                    state["target"].append(
                        {"id": "u1", "attributes": {"email": "A@x.co"}})
                return {}
            if method == "DELETE":
                state["deleted"].append(path)
                return {}
            return {}

        tf._call = call
        return state

    state = stateful(link_lands=True)
    lines = tf.merge_group("t", "app-1", "arkadaslar", target)
    check("links ONLY the member not already in the target", state["linked"], ["u1"])
    check("deletes the source group, once", state["deleted"], ["/v1/betaGroups/src-1"])
    check("re-reads the target to verify before deleting", state["reads"] >= 2, True)
    check("says what moved", any("A@x.co" in line for line in lines), True)
    # Case-insensitivity is not cosmetic: 'A@x.co' vs 'a@x.co' deciding
    # membership would re-invite a tester who is already there.
    state = stateful(link_lands=True)
    state["target"] = [{"id": "u1", "attributes": {"email": "a@x.co"}},
                       {"id": "u2", "attributes": {"email": "b@x.co"}}]
    tf.merge_group("t", "app-1", "arkadaslar", target)
    check("a case-differing email counts as already present", state["linked"], [])
    check("an already-merged group is still deleted",
          state["deleted"], ["/v1/betaGroups/src-1"])

    # THE load-bearing case: the link did not land. Deleting now would strip a
    # real person's access and every later status read would look clean.
    state = stateful(link_lands=False)
    check_raises("refuses to delete when a member did not land",
                 lambda: tf.merge_group("t", "app-1", "arkadaslar", target), "A@x.co")
    check("nothing deleted when verification fails", state["deleted"], [])

    # dry run touches nothing at all — especially not DELETE.
    state = stateful(link_lands=True)
    lines = tf.merge_group("t", "app-1", "arkadaslar", target, dry_run=True)
    check("dry run links nothing", state["linked"], [])
    check("dry run deletes nothing", state["deleted"], [])
    check("dry run says WOULD", any("WOULD" in line for line in lines), True)


def test_tester_line() -> None:
    """Apple's tester state is printed VERBATIM, for the ADR-038 D5 reason.

    Nobody here has measured what `betaTesters` actually returns — the fields
    below are what the docs imply, and addendum 63 says only the vendor can
    settle a vendor API shape. So this must not switch-case on a closed enum:
    whatever Apple sends has to reach the founder's eyes unaltered, including a
    field added tomorrow. The test pins that property, not a field list."""
    print("tester_line")
    line = tf.tester_line({"email": "a@b.co", "inviteType": "EMAIL",
                           "state": "INSTALLED"})
    check("email leads", line.startswith("a@b.co"), True)
    check("state is present verbatim", "state='INSTALLED'" in line, True)
    check("inviteType is present verbatim", "inviteType='EMAIL'" in line, True)

    # A field this code has never heard of must still be printed.
    line = tf.tester_line({"email": "a@b.co", "somethingApplAddedLater": "NEW"})
    check("an unknown field survives", "somethingApplAddedLater='NEW'" in line, True)

    # Attributes are sorted, so two runs are diffable against each other.
    line = tf.tester_line({"email": "a@b.co", "zeta": 1, "alpha": 2})
    check("fields sorted for a stable diff", line.index("alpha") < line.index("zeta"), True)

    # No attributes at all must not crash or invent a state.
    check("no email reads as unknown, not blank",
          tf.tester_line({}).startswith("(no email)"), True)


def main() -> int:
    test_parse_emails()
    test_token()
    test_await_build()
    test_read_review_contact()
    test_set_review_contact_never_leaks()
    test_submit_for_review()
    test_print_store_status()
    test_looks_like_submission_conflict()
    test_missing_contact_does_not_block_assignment()
    test_dry_run_against_a_missing_group_still_exits_non_zero()
    test_group_membership_is_looked_up_the_readable_way()
    test_merge_group()
    test_tester_line()
    if _failures:
        print(f"\n{len(_failures)} check(s) FAILED: {', '.join(_failures)}")
        return 1
    print("\nall testflight_testers self-tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
