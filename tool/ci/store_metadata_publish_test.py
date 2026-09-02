#!/usr/bin/env python3
"""Self-tests for tool/ci/store_metadata_publish.py (#278, ADR-071).

Repo convention: every tool under tool/ carries one, run by ci.yml's quality job.

WHAT IS ACTUALLY UNDER TEST. Not "does urllib work" — the four properties that
can be quietly wrong, each of which is a decision in ADR-071:

  * **D2, and it is the whole issue**: one locale Apple refuses must not stop
    another. And the unit of isolation is the LOCALE — `appInfoLocalizations`
    goes FIRST, because `name` lives there and `name` is what Apple refuses, so
    the other order leaves a Turkish listing carrying a description and no name.
  * **D2.2**: ordering is not a transaction. The reverse partial state — app info
    lands, version localization fails — is possible and must be reported naming
    BOTH halves rather than as a locale-wide failure or, worse, a success.
  * **D4**: an empty committed field is SKIPPED, never sent. Emptying a file is
    not how you delete store copy, and a write that blanked a field the founder
    typed is the `COMMITTED IS EMPTY` hazard ADR-070 D7 named.
  * **D5.1**: the read-back compares only what was actually WRITTEN. Reusing the
    auditor's whole committed set would fail the read-back for a field the writer
    correctly declined to write — the design review's one blocking finding.

And the two guards: a dry run sends NOTHING, and a wrong `--confirm` is REFUSED
rather than quietly downgraded to a dry run (D6).

⚠️ NOTHING HERE HAS EVER RUN AGAINST APPLE. The request shapes are the JSON:API
form this repo already uses for `betaGroups`/`betaTesters`
(`testflight_testers.py::create_group`), and ADR-071 D3 separates what is known
from what is assumed. These tests pin the shape we send; they cannot pin the
shape Apple accepts.

Run: python3 tool/ci/store_metadata_publish_test.py
"""
from __future__ import annotations

import importlib.util
import pathlib
import tempfile

_MODULE_PATH = pathlib.Path(__file__).with_name("store_metadata_publish.py")
_spec = importlib.util.spec_from_file_location("store_metadata_publish", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
publish = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(publish)

audit = publish.audit
tf = publish.tf

_failures: list[str] = []


def check(label: str, actual: object, expected: object) -> None:
    if actual == expected:
        print(f"  ok   {label}")
    else:
        print(f"  FAIL {label}\n         expected: {expected!r}\n         actual:   {actual!r}")
        _failures.append(label)


def check_true(label: str, value: bool) -> None:
    check(label, bool(value), True)


# --- fixtures ---------------------------------------------------------------

EN = {
    "description.txt": "A question a day, for two.\n",
    "keywords.txt": "couples,relationship\n",
    "name.txt": "ikimiz\n",
    "subtitle.txt": "One question a day\n",
    "privacy_url.txt": "https://example.test/privacy\n",
    "marketing_url.txt": "\n",          # empty on purpose — ADR-020 D5 rev 2
}
TR = {
    "description.txt": "Her gün bir soru.\n",
    "name.txt": "ikimiz\n",
    "marketing_url.txt": "",            # empty on purpose
}


def recorder(script):
    """A scripted `call(method, path, body)` that RECORDS every request.

    ⚠️ Matching is by SUBSTRING and the FIRST match wins, exactly like
    `store_metadata_audit_test._fake_call`, so a script must list the LONGER
    fragment first (`appStoreVersionLocalizations` before `appStoreVersions`).
    Repeated here rather than imported because getting it wrong does not error —
    it silently returns the wrong payload and the failure lands somewhere else.

    A script entry whose response is an Exception raises it, which is how a
    refusal is simulated.
    """
    seen: list[tuple[str, str, dict | None]] = []

    def call(method, path, body=None):
        seen.append((method, path, body))
        for match_method, fragment, response in script:
            if method == match_method and fragment in path:
                if isinstance(response, Exception):
                    raise response
                return response
        return {"data": {"id": "new-id"}}

    return call, seen


def _install_fake(script):
    """`recorder`, but patched over `tf._call` so `main` uses it end to end."""
    call, seen = recorder(script)
    tf._call = lambda _token, method, path, body=None: call(method, path, body)
    return seen


def writes(seen):
    """Only the requests that CHANGE something. A dry run must produce none."""
    return [(m, p) for m, p, _b in seen if m in {"POST", "PATCH", "DELETE", "PUT"}]


# --- D4: an empty committed field is never sent -----------------------------


def test_empty_fields_are_skipped_never_sent() -> None:
    print("D4: an empty committed file is SKIPPED, never written as a blank")
    info, version = publish.writable_fields(EN)
    check("name reaches the app-info resource", info.get("name"), "ikimiz")
    check("subtitle too", info.get("subtitle"), "One question a day")
    check("privacyPolicyUrl too", info.get("privacyPolicyUrl"), "https://example.test/privacy")
    check("description reaches the version resource", version.get("description"), "A question a day, for two.")
    # The whole point: marketingUrl is empty on disk and must appear in NEITHER
    # payload. Sending "" would blank a field the founder may have typed by hand
    # — ADR-070 D7's COMMITTED IS EMPTY, which is a hazard, not a no-op.
    check("marketingUrl is absent, not empty", "marketingUrl" in version, False)
    check("and it is not on the other resource either", "marketingUrl" in info, False)


def test_a_locale_with_nothing_writable_plans_nothing() -> None:
    print("D4: a locale whose every file is empty produces no actions at all")
    actions = publish.plan(
        {"tr": {"marketing_url.txt": "\n", "promotional_text.txt": "  \n"}},
        version_id="v1", app_info_id="ai1",
        existing_version={}, existing_app_info={},
    )
    check("no actions", actions, [])


# --- D2: the ordering, and the isolation --------------------------------------


def test_app_info_is_planned_before_the_version_localization() -> None:
    print("D2: appInfoLocalizations goes FIRST — `name` is what Apple refuses")
    actions = publish.plan(
        {"en-US": dict(EN)}, version_id="v1", app_info_id="ai1",
        existing_version={}, existing_app_info={},
    )
    check("two actions for one locale", len(actions), 2)
    check("app info first", actions[0].resource, publish.APP_INFO_TYPE)
    check("version second", actions[1].resource, publish.VERSION_TYPE)


def test_create_versus_update_and_the_parent_it_hangs_from() -> None:
    print("D3: POST for a missing locale, PATCH for one that exists")
    actions = publish.plan(
        {"en-US": dict(EN), "tr": dict(TR)},
        version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
    )
    by = {(a.locale, a.resource): a for a in actions}

    en_info = by[("en-US", publish.APP_INFO_TYPE)]
    check("existing locale is a PATCH", en_info.verb, "PATCH")
    check("addressed by its own id", en_info.path, "/v1/appInfoLocalizations/iloc-en")
    check("a PATCH carries the id in the body", en_info.body["data"]["id"], "iloc-en")
    check("and no relationships", "relationships" in en_info.body["data"], False)

    tr_info = by[("tr", publish.APP_INFO_TYPE)]
    check("missing locale is a POST", tr_info.verb, "POST")
    check("to the collection", tr_info.path, "/v1/appInfoLocalizations")
    check("carrying the locale", tr_info.body["data"]["attributes"]["locale"], "tr")
    # ⚠️ The parent is the editable appInfo, NOT the app. Revision 1 of ADR-071
    # did not mention this and would have hung the create off the wrong resource.
    check(
        "hung off the editable appInfo, not the app",
        tr_info.body["data"]["relationships"]["appInfo"]["data"],
        {"type": "appInfos", "id": "ai1"},
    )
    tr_version = by[("tr", publish.VERSION_TYPE)]
    check(
        "and the version localization hangs off the VERSION",
        tr_version.body["data"]["relationships"]["appStoreVersion"]["data"],
        {"type": "appStoreVersions", "id": "v1"},
    )


def test_a_refused_locale_does_not_stop_the_others() -> None:
    print("D2: THE DEFECT #278 IS ABOUT — tr refused, en-US still published")
    refusal = tf.AscError(
        "POST /v1/appInfoLocalizations -> HTTP 409: "
        "You cannot add this localization because the app name is already being used"
    )
    call, seen = recorder([
        # tr's app info is the one Apple refuses. Matching is by substring, so
        # this entry must be narrower than the generic ones below it: the fake
        # inspects the BODY to find the tr create.
        ("POST", "/v1/appInfoLocalizations", refusal),
        ("PATCH", "/v1/appInfoLocalizations", {"data": {"id": "iloc-en"}}),
        ("PATCH", "/v1/appStoreVersionLocalizations", {"data": {"id": "vloc-en"}}),
    ])
    actions = publish.plan(
        {"en-US": dict(EN), "tr": dict(TR)},
        version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
    )
    # ⚠️ Caught deliberately. If a refusal ESCAPES `execute`, the property this
    # test exists for is broken — but an escaping exception would crash the
    # harness, and a mutant reddened by a crash proves the crash, not the
    # assertion this test advertises (S095's lesson, applied here).
    try:
        outcome = publish.execute(call, actions, dry_run=False)
    except Exception as escaped:  # noqa: BLE001 - that is the failure being named
        check("a refusal must NOT escape execute — the locale is the unit",
              repr(escaped), "<no exception>")
        return

    check("one locale refused", [f.locale for f in outcome.findings], ["tr"])
    check_true("and Apple's own words are carried", "already being used" in outcome.findings[0].detail)
    # The property the whole issue is about.
    check_true(
        "en-US was written anyway",
        ("PATCH", "/v1/appInfoLocalizations/iloc-en") in writes(seen)
        and ("PATCH", "/v1/appStoreVersionLocalizations/vloc-en") in writes(seen),
    )
    # And the locale-unit rule: tr's version localization is never attempted.
    check(
        "tr's version localization was NOT attempted",
        [p for m, p in writes(seen) if "appStoreVersionLocalizations" in p and "vloc-en" not in p],
        [],
    )
    check("tr is skipped, so the read-back does not expect it",
          "tr" in publish.read_back_expectation(outcome), False)


def test_the_reverse_partial_state_is_reported_naming_both_halves() -> None:
    print("D2.2: app info lands, version fails — ordering is NOT a transaction")
    call, seen = recorder([
        ("POST", "/v1/appStoreVersionLocalizations",
         tf.AscError("POST /v1/appStoreVersionLocalizations -> HTTP 422: whatsNew is too long")),
        ("POST", "/v1/appInfoLocalizations", {"data": {"id": "iloc-tr"}}),
    ])
    actions = publish.plan(
        {"tr": dict(TR)}, version_id="v1", app_info_id="ai1",
        existing_version={}, existing_app_info={},
    )
    outcome = publish.execute(call, actions, dry_run=False)

    check("one finding", len(outcome.findings), 1)
    finding = outcome.findings[0]
    check("about tr", finding.locale, "tr")
    # A partial write reported as a locale-wide failure would send someone looking
    # for a Turkish listing that is in fact half there; reported as a success it
    # would be the defect this issue is made of.
    check_true("named as PARTIAL", finding.partial)
    check_true("naming the half that landed", publish.APP_INFO_TYPE in finding.detail)
    check_true("and the half that did not", publish.VERSION_TYPE in finding.detail)
    check_true("with Apple's words", "too long" in finding.detail)
    # The read-back must expect ONLY the half that landed.
    expectation = publish.read_back_expectation(outcome)
    check("tr is still expected", sorted(expectation), ["tr"])
    check("but only its app-info files", sorted(expectation["tr"]), ["name.txt"])


def test_a_network_error_isolates_the_same_way_a_refusal_does() -> None:
    print("D2: isolation is per LOCALE for ANY error, not only for AscError")
    # ⚠️ Found by the built-diff review with this exact shape. `tf._call` turns
    # an HTTPError into AscError and lets URLError, socket.timeout and a
    # malformed body propagate raw — so an `except AscError` would let a DNS blip
    # on one locale abort every remaining locale. That is #278's own defect, one
    # exception type over, inside the tool written to fix it.
    import urllib.error

    calls: list[str] = []

    def call(method, path, body=None):
        calls.append(f"{method} {path}")
        if body and body.get("data", {}).get("attributes", {}).get("locale") == "en-US":
            raise urllib.error.URLError("temporary failure in name resolution")
        return {"data": {"id": "new-id"}}

    expected = {
        "ar": {"name.txt": "ikimiz\n"},
        "en-US": {"name.txt": "ikimiz\n"},
        "tr": {"name.txt": "ikimiz\n"},
    }
    actions = publish.plan(
        expected, version_id="v1", app_info_id="ai1",
        existing_version={}, existing_app_info={},
    )
    try:
        outcome = publish.execute(call, actions, dry_run=False)
    except Exception as escaped:  # noqa: BLE001 - that is the failure being named
        check("a NETWORK error must not escape execute either", repr(escaped), "<no exception>")
        return

    check("the locale after the failure was still attempted",
          [a.locale for a in outcome.written], ["ar", "tr"])
    check("one finding", [f.locale for f in outcome.findings], ["en-US"])
    # The diagnostic must not lose which KIND of failure it was: an AscError
    # carries Apple's words, and anything else must name its own type or the
    # reader cannot tell a refusal from a broken network.
    check_true("named by its exception type", "URLError" in outcome.findings[0].detail)


# --- D5.1: the read-back compares only what was WRITTEN ----------------------


def test_read_back_expectation_excludes_what_was_never_written() -> None:
    print("D5.1: the read-back asks `did what I wrote land`, not `does everything match`")
    call, _seen = recorder([])
    actions = publish.plan(
        {"en-US": dict(EN)}, version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
    )
    outcome = publish.execute(call, actions, dry_run=False)
    expectation = publish.read_back_expectation(outcome)

    # ⚠️ THE BLOCKING FINDING OF THE DESIGN REVIEW. `marketing_url.txt` is empty,
    # so D4 skipped it. Passing the whole committed set to audit_findings would
    # report COMMITTED IS EMPTY against a field the writer correctly declined to
    # write, failing a read-back for a write that did everything right.
    check("marketing_url is not expected back", "marketing_url.txt" in expectation["en-US"], False)
    check(
        "everything actually written IS expected back",
        sorted(expectation["en-US"]),
        ["description.txt", "keywords.txt", "name.txt", "privacy_url.txt", "subtitle.txt"],
    )
    # And the expectation is in the shape audit_findings takes, so a clean store
    # produces no findings at all.
    published = {"en-US": {
        "locale": "en-US", "name": "ikimiz", "subtitle": "One question a day",
        "privacyPolicyUrl": "https://example.test/privacy",
        "description": "A question a day, for two.", "keywords": "couples,relationship",
    }}
    check("and it feeds audit_findings cleanly", audit.audit_findings(expectation, published), [])


def test_read_back_catches_a_write_that_did_not_land() -> None:
    print("D5: a 2xx is not proof — Apple's STATE is")
    call, _seen = recorder([])
    actions = publish.plan(
        {"en-US": dict(EN)}, version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
    )
    outcome = publish.execute(call, actions, dry_run=False)
    expectation = publish.read_back_expectation(outcome)
    # Every request "succeeded" and the store still shows the old description.
    published = {"en-US": {
        "locale": "en-US", "name": "ikimiz", "subtitle": "One question a day",
        "privacyPolicyUrl": "https://example.test/privacy",
        "description": "Something else entirely", "keywords": "couples,relationship",
    }}
    findings = audit.audit_findings(expectation, published)
    check("the read-back objects", len(findings), 1)
    check_true("naming the field", "description differs" in findings[0].text)


# --- D6: the two guards -------------------------------------------------------


def test_dry_run_sends_nothing_and_is_not_a_stub() -> None:
    print("D6: a dry run plans everything and writes nothing")
    call, seen = recorder([])
    actions = publish.plan(
        {"en-US": dict(EN), "tr": dict(TR)}, version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
    )
    outcome = publish.execute(call, actions, dry_run=True)

    check("NOTHING was written", writes(seen), [])
    check("nothing was requested at all", seen, [])
    # "Not a stub": the plan is fully resolved — every action, both verbs.
    check("but the whole plan is there", len(outcome.planned), 4)
    check("with both verbs resolved", sorted({a.verb for a in outcome.planned}), ["PATCH", "POST"])
    check("and nothing is reported as written", outcome.written, [])


def test_a_wrong_confirm_is_refused_not_quietly_downgraded() -> None:
    print("D6: absence means `I am looking`; a wrong literal means `I fumbled`")
    # Revision 1 of ADR-071 said any wrong confirm was simply a dry run. The
    # design review checked the precedent (appid_capability_enable.py returns
    # REFUSED) and it is right: answering a typo with a cheerful dry run tells
    # someone who meant to publish that they did.
    check("no --confirm at all is a dry run", publish.resolve_mode(None), publish.MODE_DRY_RUN)
    check("the literal writes", publish.resolve_mode(publish.CONFIRM_LITERAL), publish.MODE_WRITE)
    check("a near-miss is REFUSED", publish.resolve_mode("publish"), publish.MODE_REFUSED)
    check("and so is anything else", publish.resolve_mode("yes"), publish.MODE_REFUSED)
    check("refused has its own exit code", publish.EXIT_REFUSED, 64)
    check_true("which is not one of the taxonomy's three",
               publish.EXIT_REFUSED not in {publish.EXIT_OK, publish.EXIT_FINDING,
                                            publish.EXIT_CANNOT_MEASURE})


# --- D7: the exit taxonomy, and the line 2 stops at ---------------------------


def test_exit_codes() -> None:
    print("D7: 0 / 1 / 2, and 2 stops at the first write attempt")
    check("clean", publish.exit_code(refusals=0, read_back=0), publish.EXIT_OK)
    check("a refusal is a FINDING, not an unmeasurable", publish.exit_code(refusals=1, read_back=0), publish.EXIT_FINDING)
    check("so is a read-back disagreement", publish.exit_code(refusals=0, read_back=3), publish.EXIT_FINDING)


def test_an_error_after_a_write_is_a_finding_not_could_not_measure() -> None:
    print("D7: once something has been written, an error is about the LISTING")
    # The founder submits the version for review mid-run and it stops being
    # editable. Reporting that as "could not measure" would describe a CHANGED
    # listing as an unobserved one — the confusion ADR-063 built exit 2 to stop.
    call, _seen = recorder([
        ("PATCH", "/v1/appStoreVersionLocalizations",
         tf.AscError("PATCH … -> HTTP 409: the version is no longer editable")),
        ("PATCH", "/v1/appInfoLocalizations", {"data": {"id": "iloc-en"}}),
    ])
    actions = publish.plan(
        {"en-US": dict(EN)}, version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
    )
    outcome = publish.execute(call, actions, dry_run=False)
    check_true("something was written before it broke", len(outcome.written) > 0)
    check(
        "so the verdict is a FINDING",
        publish.exit_code(refusals=len(outcome.findings), read_back=0),
        publish.EXIT_FINDING,
    )


def test_render_names_every_action_and_says_which_ran() -> None:
    print("render: a human can read the plan before authorising it")
    call, _seen = recorder([])
    actions = publish.plan(
        {"en-US": dict(EN), "tr": dict(TR)}, version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
    )
    outcome = publish.execute(call, actions, dry_run=True)
    report = publish.render(outcome, dry_run=True)

    check_true("says it wrote nothing", "DRY RUN" in report)
    check_true("names the create", "POST" in report)
    check_true("and the update", "PATCH" in report)
    check_true("names a locale, anchored", "tr: POST" in report)
    check_true("and the field count, so a reader can sanity-check it", "field" in report)
    # ⚠️ The founder decides operator 6(b) from this. It must not print the
    # store's own copy into a public Actions log (ADR-070 D7.4) — only ours,
    # which is already public in this repo, and only as a count.
    check("the committed TEXT is not dumped", "A question a day, for two." in report, False)


# --- ADR-072 / #281: what would CHANGE, and a dry run that stops lying --------
#
# The publisher's dry run exited 0 — glossed by its own workflow as "published" —
# while `store_metadata_audit` exited 1 on the same listing state (runs
# 33685509829 and 33685506236, minutes apart). Two tools, one subject, opposite
# verdicts, and the one saying "fine" is the one that did nothing (lesson 155).


def test_changing_is_the_subset_that_actually_differs() -> None:
    print("ADR-072 D1: an Action carries the fields that would actually change")
    published = {"en-US": {
        "locale": "en-US",
        "name": "ikimiz",                       # matches the committed file
        "subtitle": "Something else",           # differs
        "privacyPolicyUrl": "https://example.test/privacy",   # matches
    }}
    actions = publish.plan(
        {"en-US": dict(EN)}, version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
        published=published,
    )
    info = [a for a in actions if a.resource == publish.APP_INFO_TYPE][0]
    check("all three are still SENT", sorted(info.files),
          ["name.txt", "privacy_url.txt", "subtitle.txt"])
    # The write still sends everything — "make it so" must not depend on the
    # comparison being right (ADR-072 D1). Only the REPORT and the exit code use
    # this subset.
    check("but only one would change", sorted(info.changing), ["subtitle.txt"])

    version = [a for a in actions if a.resource == publish.VERSION_TYPE][0]
    # The store carries nothing for these, so all of them would change.
    check("a locale present but blank changes everything it holds",
          sorted(version.changing), ["description.txt", "keywords.txt"])


def test_a_trailing_newline_is_not_a_change() -> None:
    print("ADR-072 D1: one definition of `differs`, and it is the auditor's")
    # Every committed file ends in a newline and Apple's stored value does not.
    # Using anything but `normalize` here would report all eight fields as
    # changing forever — the cries-wolf failure, in the tool built to stop one.
    actions = publish.plan(
        {"tr": {"name.txt": "ikimiz\n"}}, version_id="v1", app_info_id="ai1",
        existing_version={}, existing_app_info={"tr": "iloc-tr"},
        published={"tr": {"locale": "tr", "name": "ikimiz"}},
    )
    check("nothing would change", sorted(actions[0].changing), [])


def test_an_absent_locale_changes_everything_it_would_write() -> None:
    print("ADR-072 D1: a locale Apple does not have changes every field")
    actions = publish.plan(
        {"tr": dict(TR)}, version_id="v1", app_info_id="ai1",
        existing_version={}, existing_app_info={},
        published={"en-US": {"locale": "en-US"}},   # tr absent entirely
    )
    for action in actions:
        check(f"{action.resource}: all of it", sorted(action.changing), sorted(action.files))


def test_unknown_published_state_assumes_it_would_change() -> None:
    print("ADR-072 D1: not knowing is not the same as nothing to do")
    # `published=None` is what a caller that never read Apple passes. The safe
    # direction is to say the field WOULD change: a tool that answers "nothing to
    # do" because it did not look is the exact defect this ADR exists to fix.
    actions = publish.plan(
        {"tr": dict(TR)}, version_id="v1", app_info_id="ai1",
        existing_version={}, existing_app_info={},
    )
    for action in actions:
        check(f"{action.resource}: assumed changing", sorted(action.changing), sorted(action.files))


def test_would_change_counts_across_the_plan() -> None:
    print("ADR-072 D2: the number the exit code is computed from")
    published = {"en-US": {
        "locale": "en-US", "name": "ikimiz",
        "subtitle": "One question a day", "privacyPolicyUrl": "https://example.test/privacy",
        "description": "A question a day, for two.", "keywords": "couples,relationship",
    }}
    matching = publish.plan(
        {"en-US": dict(EN)}, version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
        published=published,
    )
    check("a listing that already matches changes nothing", publish.would_change(matching), 0)
    drifted = publish.plan(
        {"en-US": dict(EN)}, version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
        published={"en-US": {"locale": "en-US"}},   # present, and blank — today's real state
    )
    check("an empty listing changes all five committed fields",
          publish.would_change(drifted), 5)


def test_a_dry_run_over_an_unpublished_listing_is_a_FINDING() -> None:
    print("ADR-072 D2: 0 no longer means `published` when nothing was published")
    # THE DEFECT. Before this, a dry run over the empty listing exited 0 while
    # the auditor exited 1 about the same listing.
    check("would-change makes it a finding",
          publish.exit_code(refusals=0, read_back=0, would_change=5), publish.EXIT_FINDING)
    check("nothing to do is the only 0",
          publish.exit_code(refusals=0, read_back=0, would_change=0), publish.EXIT_OK)
    # And the write path is UNTOUCHED: it passes no would_change and decides from
    # the post-write read-back, which is a different moment, not a different rule.
    check("a successful write still exits 0",
          publish.exit_code(refusals=0, read_back=0), publish.EXIT_OK)
    check("a failed read-back still exits 1",
          publish.exit_code(refusals=0, read_back=2), publish.EXIT_FINDING)


def test_render_says_how_much_would_change() -> None:
    print("ADR-072 D3: the number the founder reads")
    actions = publish.plan(
        {"en-US": dict(EN)}, version_id="v1", app_info_id="ai1",
        existing_version={"en-US": "vloc-en"}, existing_app_info={"en-US": "iloc-en"},
        published={"en-US": {"locale": "en-US", "name": "ikimiz"}},
    )
    call, _seen = recorder([])
    report = publish.render(publish.execute(call, actions, dry_run=True), dry_run=True)
    check_true("counts what would change", "would change" in report)
    # FOUR, not five: the fixture already publishes `name`, so it is the one
    # committed field that would not move. Counted by running it rather than by
    # eye — the first draft of this assertion said five (lesson 133).
    check("the plan agrees", publish.would_change(actions), 4)
    check_true("and names the total", "4 field(s) would change" in report)
    # Still no store text, still one purpose (ADR-070 D7.4).
    check("the committed TEXT is still not dumped", "A question a day, for two." in report, False)


def test_render_says_so_when_nothing_would_change() -> None:
    print("ADR-072 D3: and it says so OUT LOUD when there is nothing to do")
    # A tool that only speaks when something is wrong is indistinguishable from a
    # tool that is not running (lesson 65, ADR-047's own rule one tool over).
    published = {"tr": {"locale": "tr", "name": "ikimiz", "description": "Her gün bir soru."}}
    actions = publish.plan(
        {"tr": dict(TR)}, version_id="v1", app_info_id="ai1",
        existing_version={"tr": "vloc-tr"}, existing_app_info={"tr": "iloc-tr"},
        published=published,
    )
    call, _seen = recorder([])
    report = publish.render(publish.execute(call, actions, dry_run=True), dry_run=True)
    check("nothing would change", publish.would_change(actions), 0)
    check_true("and the report says so", "nothing would change" in report.lower())


def _script_the_store(en_attributes: dict, tr_present: bool = False) -> list:
    """A whole App Store Connect, scripted. LONGER fragments first (substring match)."""
    version_rows = [{"id": "vloc-en", "attributes": {"locale": "en-US", **en_attributes}}]
    info_rows = [{"id": "iloc-en", "attributes": {"locale": "en-US", **en_attributes}}]
    if tr_present:
        version_rows.append({"id": "vloc-tr", "attributes": {"locale": "tr"}})
        info_rows.append({"id": "iloc-tr", "attributes": {"locale": "tr"}})
    return [
        ("GET", "appStoreVersionLocalizations", {"data": version_rows}),
        ("GET", "appInfoLocalizations", {"data": info_rows}),
        ("GET", "appStoreVersions", {"data": [
            {"id": "v1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}}]}),
        ("GET", "appInfos", {"data": [
            {"id": "i1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}}]}),
    ]


def test_main_dry_run_over_the_real_metadata_tree_is_a_FINDING() -> None:
    print("main: end to end — the empty listing, dry run, and it must NOT say 0")
    # ⚠️ This test exists because a mutant survived: replacing main's
    # `published = audit.published_locales(...)` with `None` changed the
    # founder-facing number and NOTHING caught it. main() was the one piece of
    # wiring no test touched — between the read and the report.
    tf._token = lambda: "token"
    tf.find_app = lambda _t, _b: {"id": "app"}
    root = pathlib.Path(__file__).resolve().parents[2] / "fastlane" / "metadata"

    # The measured production state: en-US exists and holds NOTHING, tr absent.
    seen = _install_fake(_script_the_store({}))
    with tempfile.TemporaryDirectory() as raw:
        summary = pathlib.Path(raw) / "summary"
        code = publish.main(["--metadata-dir", str(root), "--summary", str(summary)])
        report = summary.read_text(encoding="utf-8")

    check("exit 1 — a FINDING, not `published`", code, publish.EXIT_FINDING)
    check("and nothing was written", writes(seen), [])
    check_true("the report says so", "would change" in report)
    check_true("and it is a dry run", "DRY RUN" in report)


def test_main_dry_run_exits_0_when_the_listing_already_matches() -> None:
    print("main: 0 is reachable, and only when there is genuinely nothing to do")
    # The other half of the rule. Without this, `exit 1` could be hard-coded and
    # the suite would not notice — the assertion above would still pass.
    tf._token = lambda: "token"
    tf.find_app = lambda _t, _b: {"id": "app"}
    root = pathlib.Path(__file__).resolve().parents[2] / "fastlane" / "metadata"
    committed = audit.expected_locales(root)

    def attributes_for(locale: str) -> dict:
        info, version = publish.writable_fields(committed[locale])
        return {**info, **version}

    script = [
        ("GET", "appStoreVersionLocalizations", {"data": [
            {"id": "vloc-en", "attributes": {"locale": "en-US", **attributes_for("en-US")}},
            {"id": "vloc-tr", "attributes": {"locale": "tr", **attributes_for("tr")}}]}),
        ("GET", "appInfoLocalizations", {"data": [
            {"id": "iloc-en", "attributes": {"locale": "en-US", **attributes_for("en-US")}},
            {"id": "iloc-tr", "attributes": {"locale": "tr", **attributes_for("tr")}}]}),
        ("GET", "appStoreVersions", {"data": [
            {"id": "v1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}}]}),
        ("GET", "appInfos", {"data": [
            {"id": "i1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}}]}),
    ]
    seen = _install_fake(script)
    with tempfile.TemporaryDirectory() as raw:
        summary = pathlib.Path(raw) / "summary"
        code = publish.main(["--metadata-dir", str(root), "--summary", str(summary)])
        report = summary.read_text(encoding="utf-8")

    check("exit 0 — nothing to do", code, publish.EXIT_OK)
    check("still wrote nothing", writes(seen), [])
    check_true("and says so out loud", "nothing would change" in report.lower())


def main() -> int:
    print("store_metadata_publish self-tests")
    test_empty_fields_are_skipped_never_sent()
    test_a_locale_with_nothing_writable_plans_nothing()
    test_app_info_is_planned_before_the_version_localization()
    test_create_versus_update_and_the_parent_it_hangs_from()
    test_a_refused_locale_does_not_stop_the_others()
    test_a_network_error_isolates_the_same_way_a_refusal_does()
    test_the_reverse_partial_state_is_reported_naming_both_halves()
    test_read_back_expectation_excludes_what_was_never_written()
    test_read_back_catches_a_write_that_did_not_land()
    test_dry_run_sends_nothing_and_is_not_a_stub()
    test_a_wrong_confirm_is_refused_not_quietly_downgraded()
    test_exit_codes()
    test_an_error_after_a_write_is_a_finding_not_could_not_measure()
    test_render_names_every_action_and_says_which_ran()
    # ADR-072 / #281
    test_changing_is_the_subset_that_actually_differs()
    test_a_trailing_newline_is_not_a_change()
    test_an_absent_locale_changes_everything_it_would_write()
    test_unknown_published_state_assumes_it_would_change()
    test_would_change_counts_across_the_plan()
    test_a_dry_run_over_an_unpublished_listing_is_a_FINDING()
    test_render_says_how_much_would_change()
    test_render_says_so_when_nothing_would_change()
    test_main_dry_run_over_the_real_metadata_tree_is_a_FINDING()
    test_main_dry_run_exits_0_when_the_listing_already_matches()

    if _failures:
        print(f"\n{len(_failures)} FAILED: {', '.join(_failures)}")
        return 1
    print("\nall store_metadata_publish self-tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
