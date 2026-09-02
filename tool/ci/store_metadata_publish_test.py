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
    check("clean", publish.exit_code(refusals=0, read_back=0, wrote=True), publish.EXIT_OK)
    check("a refusal is a FINDING, not an unmeasurable", publish.exit_code(refusals=1, read_back=0, wrote=True), publish.EXIT_FINDING)
    check("so is a read-back disagreement", publish.exit_code(refusals=0, read_back=3, wrote=True), publish.EXIT_FINDING)


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
        publish.exit_code(refusals=len(outcome.findings), read_back=0, wrote=bool(outcome.written)),
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
    check_true("names a locale", "tr" in report)
    check_true("and the field count, so a reader can sanity-check it", "field" in report)
    # ⚠️ The founder decides operator 6(b) from this. It must not print the
    # store's own copy into a public Actions log (ADR-070 D7.4) — only ours,
    # which is already public in this repo, and only as a count.
    check("the committed TEXT is not dumped", "A question a day, for two." in report, False)


def main() -> int:
    print("store_metadata_publish self-tests")
    test_empty_fields_are_skipped_never_sent()
    test_a_locale_with_nothing_writable_plans_nothing()
    test_app_info_is_planned_before_the_version_localization()
    test_create_versus_update_and_the_parent_it_hangs_from()
    test_a_refused_locale_does_not_stop_the_others()
    test_the_reverse_partial_state_is_reported_naming_both_halves()
    test_read_back_expectation_excludes_what_was_never_written()
    test_read_back_catches_a_write_that_did_not_land()
    test_dry_run_sends_nothing_and_is_not_a_stub()
    test_a_wrong_confirm_is_refused_not_quietly_downgraded()
    test_exit_codes()
    test_an_error_after_a_write_is_a_finding_not_could_not_measure()
    test_render_names_every_action_and_says_which_ran()

    if _failures:
        print(f"\n{len(_failures)} FAILED: {', '.join(_failures)}")
        return 1
    print("\nall store_metadata_publish self-tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
