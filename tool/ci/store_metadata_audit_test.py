#!/usr/bin/env python3
"""Self-tests for tool/ci/store_metadata_audit.py (#204).

Repo convention: every tool under tool/ carries one, run by ci.yml's quality job.

WHAT IS ACTUALLY UNDER TEST. Not "does urllib work" — the taxonomy and the
comparison, which are the parts that can be quietly wrong:

  * a MISSING locale is a finding, and it is reported ONCE rather than as twelve
    field diffs under a locale that does not exist;
  * a locale that EXISTS but whose text is stale is also a finding — the case a
    presence-only check would call green, and the case production is actually in
    (`en-US` exists and has never been refreshed, because deliver dies in
    `verify_available_version_languages!` before the upload phase);
  * `name` is read from `appInfoLocalizations`, NOT from the version
    localization. `name` is the field Apple refuses, so a tool that looked in
    only one place would miss the whole bug;
  * trailing newlines are not drift — every file on disk ends in one and Apple's
    stored value does not, so a byte-exact compare would report all twelve fields
    as drifted forever and get itself ignored;
  * an unreadable API is EXIT 2 ("could not measure"), never EXIT 1 ("the copy
    did not land"). Conflating those is how a green signal that measured nothing
    gets read as a pass.

THE HEADLINE FIXTURE is the state measured in production on 2026-08-16 via
`testflight-testers.yml -f store_status=true`: one App Store version, `en-US`
only, `tr` absent. It must come out as a finding naming `tr`.

Run: python3 tool/ci/store_metadata_audit_test.py
"""
from __future__ import annotations

import importlib.util
import pathlib
import tempfile

_MODULE_PATH = pathlib.Path(__file__).with_name("store_metadata_audit.py")
_spec = importlib.util.spec_from_file_location("store_metadata_audit", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
audit_tool = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(audit_tool)

tf = audit_tool.tf

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

EN_FILES = {
    "description.txt": "A question a day, for two.\n",
    "keywords.txt": "couples,relationship\n",
    "name.txt": "ikimiz\n",
    "subtitle.txt": "One question a day\n",
    "privacy_url.txt": "https://ikimiz.web.app/privacy\n",
}
TR_FILES = {
    "description.txt": "Her gün bir soru, iki kişiye.\n",
    "keywords.txt": "çift,ilişki\n",
    "name.txt": "ikimiz\n",
    "subtitle.txt": "Günde tek soru\n",
    "privacy_url.txt": "https://ikimiz.web.app/privacy\n",
}


def expected_two_locales() -> dict[str, dict[str, str]]:
    return {"en-US": dict(EN_FILES), "tr": dict(TR_FILES)}


def published(locale_files: dict[str, dict[str, str]]) -> dict[str, dict]:
    """Turn committed files into the ASC attribute shape they would publish as."""
    out: dict[str, dict] = {}
    for locale, files in locale_files.items():
        attributes: dict[str, str] = {"locale": locale}
        for filename, text in files.items():
            field = audit_tool.VERSION_FIELDS.get(
                filename
            ) or audit_tool.APP_INFO_FIELDS.get(filename)
            if field:
                attributes[field] = text.strip()
        out[locale] = attributes
    return out


def _fake_call(script):
    """Replace tf._call with a scripted responder; records every request.

    ⚠️ Matching is by SUBSTRING and the FIRST match wins, so `appStoreVersions`
    also matches `appStoreVersionLocalizations` and `appInfos` also matches
    `appInfoLocalizations`. Every script below therefore lists the LONGER
    fragment first. (`testflight_testers_test.py` records the same trap; it is
    repeated here because getting it wrong does not error — it silently returns
    the wrong payload and the assertion fails somewhere unrelated.)
    """
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


# --- the comparison ---------------------------------------------------------


def test_everything_published() -> None:
    print("audit: everything published")
    expected = expected_two_locales()
    check("no findings", audit_tool.audit(expected, published(expected)), [])
    check(
        "and it SAYS so rather than staying silent",
        "OK: every committed locale is published and matches."
        in audit_tool.render(expected, published(expected), []),
        True,
    )


def test_production_state_2026_08_16() -> None:
    print("audit: the measured production state — en-US only, tr absent")
    expected = expected_two_locales()
    actual = published({"en-US": dict(EN_FILES)})

    # `audit_findings` rather than `audit`: since ADR-070 D7.1 the classification
    # is a FIELD on the finding, and `one_line` counts those fields rather than
    # grepping the sentence (lesson 142).
    findings = audit_tool.audit_findings(expected, actual)

    check("exactly one finding", len(findings), 1)
    check_true("and it names tr", findings[0].text.startswith("tr: NOT PUBLISHED"))
    check("classified as the missing kind", findings[0].kind, audit_tool.NOT_PUBLISHED)
    check_true(
        "the one-liner names tr too",
        "tr not published" in audit_tool.one_line(findings, expected, actual),
    )
    check_true(
        "the report says FINDING",
        "FINDING: 1 problem" in audit_tool.render(expected, actual, findings),
    )


def test_missing_locale_is_reported_once() -> None:
    print("audit: a missing locale is ONE finding, not one per field")
    expected = expected_two_locales()
    findings = audit_tool.audit(expected, published({"en-US": dict(EN_FILES)}))
    # tr carries five files; a naive implementation reports five diffs under a
    # locale that does not exist, burying the sentence that matters.
    check("still one line", len(findings), 1)


def test_present_but_stale_is_a_finding() -> None:
    print("audit: a locale that exists with stale copy is NOT green")
    # This is the case production is actually in for en-US: deliver aborts in
    # verify_available_version_languages! BEFORE uploading, so a locale created
    # long ago sits there with copy nobody has refreshed since build 112.
    expected = expected_two_locales()
    actual = published(expected)
    actual["en-US"]["description"] = "Copy from a build nobody remembers"

    findings = audit_tool.audit_findings(expected, actual)

    check("one finding", len(findings), 1)
    check_true("names the field and the file", "description differs" in findings[0].text)
    check_true(
        "the one-liner says stale, not missing",
        "stale" in audit_tool.one_line(findings, expected, actual),
    )


def test_name_comes_from_app_info_not_the_version() -> None:
    print("audit: `name` — the field Apple refuses — is compared at all")
    expected = {"tr": {"name.txt": "ikimiz\n"}}
    actual = {"tr": {"locale": "tr", "name": "Something else"}}

    findings = audit_tool.audit(expected, actual)

    check("one finding", len(findings), 1)
    check_true("and it is about name", "name differs" in findings[0])
    check(
        "name is mapped from the appInfo resource, not the version one",
        audit_tool.APP_INFO_FIELDS["name.txt"],
        "name",
    )
    check("and is NOT also claimed by the version resource",
          "name.txt" in audit_tool.VERSION_FIELDS, False)


def test_absent_field_is_named_as_absent() -> None:
    print("audit: a field the store simply does not carry")
    expected = {"tr": {"description.txt": "Bir soru\n"}}
    findings = audit_tool.audit(expected, {"tr": {"locale": "tr"}})
    check("one finding", len(findings), 1)
    check_true("says ABSENT, not `differs`", "is ABSENT" in findings[0])
    # ⚠️ The sentence and the FIELD are different assertions, and only the field
    # reaches `one_line`'s tally. A regression that kept the wording and set
    # kind=SUBSTANTIVE would have passed the line above and mis-tallied the
    # notifier's only view of it (built-diff review).
    detailed = audit_tool.audit_findings(expected, {"tr": {"locale": "tr"}})
    check("classified as ABSENT", detailed[0].kind, audit_tool.ABSENT)
    check("and it names the field it could not find", detailed[0].field, "description")
    check_true("which is what the tally then counts",
               "1 absent" in audit_tool.one_line(detailed, expected, {}).lower())


def test_trailing_newline_is_not_drift() -> None:
    print("normalize: whitespace at the edges is not a copy change")
    check("trailing newline", audit_tool.normalize("hello\n"), "hello")
    check("CRLF folded", audit_tool.normalize("a\r\nb\n"), "a\nb")
    check("None is empty", audit_tool.normalize(None), "")
    check(
        "but INTERIOR text is untouched",
        audit_tool.normalize("  a  b  \n"),
        "a  b",
    )


def test_unknown_txt_file_is_not_invented_drift() -> None:
    print("audit: a .txt this map does not own is not a finding")
    expected = {"tr": {"apple_tv_privacy_policy.txt": "n/a\n"}}
    check("no findings", audit_tool.audit(expected, {"tr": {"locale": "tr"}}), [])


# --- reading the repo -------------------------------------------------------


def test_expected_locales_reads_the_repo() -> None:
    print("expected_locales: the EXPECTED set comes from the repo, never Apple")
    with tempfile.TemporaryDirectory() as raw:
        root = pathlib.Path(raw)
        for locale, files in expected_two_locales().items():
            (root / locale).mkdir()
            for name, text in files.items():
                (root / locale / name).write_text(text, encoding="utf-8")
        (root / ".DS_Store").write_text("junk", encoding="utf-8")
        (root / "review_information").mkdir()  # no .txt inside: not a locale

        found = audit_tool.expected_locales(root)

        check("both locales", sorted(found), ["en-US", "tr"])
        check("all five files for tr", len(found["tr"]), 5)


def test_expected_locales_refuses_an_empty_tree() -> None:
    print("expected_locales: nothing committed is EXIT 2, not a silent pass")
    with tempfile.TemporaryDirectory() as raw:
        try:
            audit_tool.expected_locales(pathlib.Path(raw))
        except tf.AscError as failure:
            check_true("raises", "no locale directories" in str(failure))
        else:
            _failures.append("empty metadata tree did not raise")


def test_the_real_repo_tree_parses() -> None:
    print("expected_locales: against the ACTUAL fastlane/metadata in this repo")
    root = pathlib.Path(__file__).resolve().parents[2] / "fastlane" / "metadata"
    found = audit_tool.expected_locales(root)
    # A change-detector on purpose, in the ADR-032 mold: the release lane pins
    # this pair, and a third locale appearing without anyone deciding to publish
    # it is exactly the kind of drift that should stop and be read.
    check("the two locales the release lane ships", sorted(found), ["en-US", "tr"])
    check_true("en-US carries a name.txt", "name.txt" in found["en-US"])
    check_true("tr carries a name.txt", "name.txt" in found["tr"])


# --- the ASC read -----------------------------------------------------------


def test_editable_version_is_chosen_by_state() -> None:
    print("editable_version: picks the state deliver can write to")
    _fake_call([
        ("GET", "appStoreVersions", {"data": [
            {"id": "v-live", "attributes": {"appStoreState": "READY_FOR_SALE"}},
            {"id": "v-edit", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}},
        ]}),
    ])
    check("the editable one", audit_tool.editable_version("t", "app")["id"], "v-edit")


def test_no_editable_version_is_could_not_measure() -> None:
    print("editable_version: nothing to write to is EXIT 2, not an accusation")
    _fake_call([
        ("GET", "appStoreVersions", {"data": [
            {"id": "v-live", "attributes": {"appStoreState": "READY_FOR_SALE"}},
        ]}),
    ])
    try:
        audit_tool.editable_version("t", "app")
    except tf.AscError as failure:
        check_true("names the states it saw", "READY_FOR_SALE" in str(failure))
    else:
        _failures.append("a non-editable-only app did not raise")


def test_published_locales_merges_both_resources() -> None:
    print("published_locales: version + appInfo, merged per locale")
    _fake_call([
        ("GET", "appStoreVersionLocalizations", {"data": [
            {"id": "l1", "attributes": {"locale": "en-US", "description": "D"}},
        ]}),
        ("GET", "appInfoLocalizations", {"data": [
            {"id": "a1", "attributes": {"locale": "en-US", "name": "İkimiz"}},
        ]}),
        ("GET", "appStoreVersions", {"data": [
            {"id": "v1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}},
        ]}),
        ("GET", "appInfos", {"data": [
            {"id": "i1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}},
        ]}),
    ])

    merged = audit_tool.published_locales("t", "app")

    check("one locale", sorted(merged), ["en-US"])
    check("carries the version field", merged["en-US"]["description"], "D")
    check("AND the appInfo field", merged["en-US"]["name"], "İkimiz")


def test_app_info_absent_does_not_kill_the_read() -> None:
    print("published_locales: no appInfos is degraded, not fatal")
    _fake_call([
        ("GET", "appStoreVersionLocalizations", {"data": [
            {"id": "l1", "attributes": {"locale": "tr", "description": "D"}},
        ]}),
        ("GET", "appStoreVersions", {"data": [
            {"id": "v1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}},
        ]}),
        ("GET", "appInfos", {"data": []}),
    ])
    check("still reports the locale", sorted(audit_tool.published_locales("t", "a")), ["tr"])


def test_api_error_is_exit_2_not_exit_1() -> None:
    print("main: an unreadable API is COULD NOT MEASURE, never a finding")
    tf._token = lambda: "token"
    tf.find_app = lambda _t, _b: {"id": "app"}
    _fake_call([("GET", "appStoreVersions", tf.AscError("HTTP 401"))])

    root = pathlib.Path(__file__).resolve().parents[2] / "fastlane" / "metadata"
    code = audit_tool.main(["--metadata-dir", str(root)])

    check("exit 2", code, audit_tool.EXIT_CANNOT_MEASURE)


def test_main_reports_the_production_finding_and_writes_its_outputs() -> None:
    print("main: end to end on the measured production state")
    tf._token = lambda: "token"
    tf.find_app = lambda _t, _b: {"id": "app"}

    root = pathlib.Path(__file__).resolve().parents[2] / "fastlane" / "metadata"
    committed = audit_tool.expected_locales(root)
    en_attributes = published({"en-US": committed["en-US"]})["en-US"]

    _fake_call([
        ("GET", "appStoreVersionLocalizations", {"data": [
            {"id": "l1", "attributes": en_attributes},
        ]}),
        ("GET", "appInfoLocalizations", {"data": [
            {"id": "a1", "attributes": en_attributes},
        ]}),
        ("GET", "appStoreVersions", {"data": [
            {"id": "v1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}},
        ]}),
        ("GET", "appInfos", {"data": [
            {"id": "i1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}},
        ]}),
    ])

    with tempfile.TemporaryDirectory() as raw:
        out = pathlib.Path(raw) / "out"
        summary = pathlib.Path(raw) / "summary"
        code = audit_tool.main([
            "--metadata-dir", str(root),
            "--github-output", str(out),
            "--summary", str(summary),
        ])

        check("exit 1 — a FINDING", code, audit_tool.EXIT_FINDING)
        written = out.read_text(encoding="utf-8")
        check_true("job output is one key=value line", written.count("\n") == 1)
        check_true("named store_metadata_audit", written.startswith("store_metadata_audit="))
        check_true("and it names tr", "tr not published" in written)
        check_true("summary carries the full report", "tr: NOT PUBLISHED" in summary.read_text(encoding="utf-8"))


def test_main_exit_0_when_everything_matches() -> None:
    print("main: a healthy listing is exit 0 and says so")
    tf._token = lambda: "token"
    tf.find_app = lambda _t, _b: {"id": "app"}

    root = pathlib.Path(__file__).resolve().parents[2] / "fastlane" / "metadata"
    committed = audit_tool.expected_locales(root)
    rows = [
        {"id": locale, "attributes": published({locale: files})[locale]}
        for locale, files in committed.items()
    ]

    _fake_call([
        ("GET", "appStoreVersionLocalizations", {"data": rows}),
        ("GET", "appInfoLocalizations", {"data": rows}),
        ("GET", "appStoreVersions", {"data": [
            {"id": "v1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}},
        ]}),
        ("GET", "appInfos", {"data": [
            {"id": "i1", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}},
        ]}),
    ])

    with tempfile.TemporaryDirectory() as raw:
        out = pathlib.Path(raw) / "out"
        code = audit_tool.main([
            "--metadata-dir", str(root),
            "--github-output", str(out),
        ])
        check("exit 0", code, audit_tool.EXIT_OK)
        check_true(
            "and the output line is positive, not empty",
            "published and current" in out.read_text(encoding="utf-8"),
        )


# --- ADR-070 D7: WHAT KIND of difference, and WHAT VERSION was read ---------
#
# `X differs from X.txt` is true and is not decision-grade. The founder is being
# asked whether the committed English copy may be published AT ALL (ADR-070 D4b),
# and "differs" does not distinguish a trailing-punctuation edit from a wholly
# different paragraph, nor say which side is longer. These tests pin the five
# verdicts, the two numbers, and the one refusal that goes with them.


def test_classify_the_five_verdicts() -> None:
    print("classify_difference: the five verdicts, in their checked order")
    c = audit_tool.classify_difference
    check("published empty", c("", "Bir soru"), audit_tool.PUBLISHED_EMPTY)
    check("published missing entirely", c(None, "Bir soru"), audit_tool.PUBLISHED_EMPTY)
    # The reverse, and it is NOT the same fact: under deliver(force: true) this
    # one ERASES a field the founder typed. Folding the two into "one side is
    # empty" would hide the difference between a fix and a regression.
    check("committed empty", c("Bir soru", ""), audit_tool.COMMITTED_EMPTY)
    check("whitespace only", c("a  b", "a b"), audit_tool.WHITESPACE_ONLY)
    check("case only", c("One Question", "one question"), audit_tool.CASE_ONLY)
    check("substantive", c("One question", "Two questions"), audit_tool.SUBSTANTIVE)


def test_classify_order_is_the_one_the_adr_states() -> None:
    print("classify_difference: first match wins, and the order is load-bearing")
    c = audit_tool.classify_difference
    # Both "the published side is empty" and "they differ only in whitespace"
    # are arguably true of ("", " "). Empty MUST win: a reader told
    # WHITESPACE-ONLY would conclude the store has the copy, and it has nothing.
    check("empty beats whitespace", c("", " x"), audit_tool.PUBLISHED_EMPTY)
    # Case AND whitespace differ -> WHITESPACE-ONLY must NOT claim it.
    check("case+whitespace is CASE-ONLY, not WHITESPACE-ONLY",
          c("One  Question", "one question"), audit_tool.CASE_ONLY)


def test_case_only_does_not_fold_the_turkish_dotted_i() -> None:
    print("classify_difference: the Turkish I caveat is PINNED, not silent")
    # str.casefold() is locale-independent and maps U+0130 to 'i' + U+0307, so
    # `Ikimiz`/`ikimiz` fold together but `Ikimiz` with the dot does NOT.
    # Deliberate: a Turkish-locale fold is wrong for a tool that also reads
    # en-US, and over-reporting is the safe direction when the field in question
    # is `name` and `deliver(force: true)` renames the live listing (ADR-032 D6).
    check(
        "the dotted capital is SUBSTANTIVE, not CASE-ONLY",
        audit_tool.classify_difference("\u0130kimiz", "ikimiz"),
        audit_tool.SUBSTANTIVE,
    )
    check(
        "an ASCII capital still folds",
        audit_tool.classify_difference("Ikimiz", "ikimiz"),
        audit_tool.CASE_ONLY,
    )


def test_whitespace_collapse_is_not_normalize() -> None:
    print("collapse_whitespace: a helper normalize() deliberately cannot be")
    # normalize() trims edges and folds CRLF and PRESERVES interior runs, which
    # is how a real copy change stays visible. Reusing it here would make every
    # interior-whitespace difference invisible instead of classified.
    check("interior run collapses", audit_tool.collapse_whitespace("a   b\n c"), "a b c")
    check_true(
        "and normalize does NOT do that",
        audit_tool.normalize("a   b") != audit_tool.collapse_whitespace("a   b"),
    )


def test_describe_counts_code_points_not_bytes_or_utf16() -> None:
    print("describe_difference: code points, matching store_metadata_lint")
    # `Gunde` with two Turkish diacritics is 12 bytes and 10 code points; a byte
    # count would make every Turkish field look longer than Apple thinks it is.
    text = "G\u00fcnde bir soru"
    described = audit_tool.describe_difference("x", text)
    check_true("names the committed code-point count", f"committed {len(text)}" in described)
    check_true("says code points out loud", "code point" in described)
    # An astral character is ONE code point and two UTF-16 code units. Dart's
    # String.length would say two; runes.length (what the lint uses) says one.
    check_true(
        "an emoji counts once, not twice",
        "committed 1 " in audit_tool.describe_difference("x", "\U0001f600"),
    )


def test_describe_names_the_first_difference() -> None:
    print("describe_difference: where the two texts part company")
    described = audit_tool.describe_difference("One question a day", "One question a week")
    check_true("offset is the common prefix length", "first difference at 15" in described)
    check_true("and it carries the verdict", audit_tool.SUBSTANTIVE in described)
    # A wholly different text parts at 0, which is the reader's cue that the
    # store is showing something else entirely rather than a small edit.
    check_true(
        "nothing in common parts at 0",
        "first difference at 0" in audit_tool.describe_difference("abc", "xyz"),
    )
    # ⚠️ The PREFIX case exercises the `for`/`else` branch, which the two cases
    # above never reach: `zip` stops at the shorter string, so the loop never
    # breaks and `shared` must fall back to the shorter length. An off-by-one
    # here would read as "they part company inside the shared text" when in fact
    # one is simply longer (built-diff review).
    check_true(
        "a strict prefix parts at the shorter length",
        "first difference at 3" in audit_tool.describe_difference("abc", "abcdef"),
    )
    check_true(
        "and in the other direction too",
        "first difference at 3" in audit_tool.describe_difference("abcdef", "abc"),
    )


def test_both_sides_empty_is_not_a_finding_at_all() -> None:
    print("audit: two empty sides AGREE — no finding, so nothing to classify")
    # marketing_url.txt is empty in both locales and Apple holds nothing for it;
    # that is the state today and it must stay silent (ADR-020 D5 rev 2).
    expected = {"tr": {"marketing_url.txt": "\n"}}
    check("no findings", audit_tool.audit(expected, {"tr": {"locale": "tr", "marketingUrl": ""}}), [])


def test_the_finding_line_carries_the_verdict() -> None:
    print("audit: every `differs` line says what KIND of difference")
    expected = expected_two_locales()
    actual = published(expected)
    actual["en-US"]["description"] = "Copy from a build nobody remembers"
    findings = audit_tool.audit(expected, actual)
    check("one finding", len(findings), 1)
    check_true("still names the field and file", "description differs" in findings[0])
    check_true("and now the verdict too", audit_tool.SUBSTANTIVE in findings[0])
    check_true("with both lengths", "code point" in findings[0])


def test_findings_carry_a_kind_field_not_a_word_in_prose() -> None:
    print("audit_findings: the classification is a FIELD (lesson 142)")
    # A status word that also appears in ordinary prose is not a status marker.
    # one_line() counts these, and counting them by grepping our own sentence is
    # exactly the fragility that lesson buys us out of.
    expected = expected_two_locales()
    actual = published({"en-US": dict(EN_FILES)})
    actual["en-US"]["description"] = "Something else entirely"
    detailed = audit_tool.audit_findings(expected, actual)
    kinds = sorted(f.kind for f in detailed)
    check("one missing locale and one substantive field", kinds,
          [audit_tool.NOT_PUBLISHED, audit_tool.SUBSTANTIVE])
    missing = [f for f in detailed if f.kind == audit_tool.NOT_PUBLISHED][0]
    check("the missing one names its locale", missing.locale, "tr")
    check("and has no field", missing.field, None)


def test_one_line_names_BOTH_halves() -> None:
    print("one_line: the notifier's whole view must not drop seven of eight")
    # The real 2026-09-02 shape: tr missing AND seven stale en-US fields. Before
    # ADR-070 D7.2 this returned "8 finding(s) - tr not published" and never
    # mentioned English at all, so the one channel ADR-047 D5 built to carry this
    # signal carried half of it.
    expected = expected_two_locales()
    actual = published({"en-US": dict(EN_FILES)})
    actual["en-US"]["description"] = "Something else entirely"
    actual["en-US"]["subtitle"] = "one question a day"   # CASE-ONLY vs the file
    detailed = audit_tool.audit_findings(expected, actual)
    line = audit_tool.one_line(detailed, expected, actual)

    check_true("names the missing locale", "tr not published" in line)
    check_true("AND says the rest are stale", "stale" in line)
    # ⚠️ Delimited, not a bare substring: `"1 substantive" in "11 substantive"`
    # is True, so the obvious assertion would pass on an inflated count. Writing
    # the test the way lesson 142 tells you to write the CODE was a real gap here,
    # found by the built-diff review.
    check_true("with the tally, counted exactly", "(1 substantive)" in line.lower()
               or ", 1 substantive" in line.lower() or "(1 substantive," in line.lower())
    check("and NOT an inflated one", "11 substantive" in line.lower(), False)
    check_true("naming the case-only one too", "1 case-only" in line.lower())
    check("still ONE line", "\n" in line, False)


def test_one_line_is_unchanged_when_only_one_kind_is_present() -> None:
    print("one_line: the two single-kind sentences still read as they did")
    expected = expected_two_locales()
    only_missing = audit_tool.audit_findings(expected, published({"en-US": dict(EN_FILES)}))
    check_true("missing only", "tr not published" in
               audit_tool.one_line(only_missing, expected, {}))
    stale_actual = published(expected)
    stale_actual["en-US"]["description"] = "Copy from a build nobody remembers"
    only_stale = audit_tool.audit_findings(expected, stale_actual)
    check_true("stale only", "stale" in audit_tool.one_line(only_stale, expected, stale_actual))
    check_true("and NOT the missing sentence",
               "not published" not in audit_tool.one_line(only_stale, expected, stale_actual))
    # The "one line" contract held on the both-halves path and was unpinned on
    # these two — recurring shape 5, a guard that guards one path (built-diff
    # review). The empty case is pinned too: it is the third return.
    for label, line in (
        ("missing-only", audit_tool.one_line(only_missing, expected, {})),
        ("stale-only", audit_tool.one_line(only_stale, expected, stale_actual)),
        ("no findings at all", audit_tool.one_line([], expected, {})),
    ):
        check(f"{label} is still ONE line", "\n" in line, False)


def test_report_names_the_version_it_audited() -> None:
    print("render: which App Store version, and in what state")
    # ADR-070 D7.3. The audit picks an editable version and then threw away which
    # one. That cost S095 a claim it could not check: the disclosure argument in
    # D7.4 rests on the listing being an unsubmitted draft, and the only evidence
    # was a docstring 17 days old. EDITABLE_STORE_STATES also holds
    # DEVELOPER_REJECTED, REJECTED, METADATA_REJECTED and INVALID_BINARY.
    expected = {"tr": {"description.txt": "Bir soru\n"}}
    version = {"id": "v1", "attributes": {"versionString": "1.0",
                                          "appStoreState": "PREPARE_FOR_SUBMISSION"}}
    report = audit_tool.render(expected, {"tr": {"locale": "tr", "description": "Bir soru"}},
                               [], version=version)
    check_true("names the version", "1.0" in report)
    check_true("and the state it was in", "PREPARE_FOR_SUBMISSION" in report)
    # Without one it must still render — the callers that pass no version are the
    # unit tests, and a report that crashed without it would be a worse tool.
    check_true("degrades without a version",
               "OK:" in audit_tool.render(expected, {"tr": {"locale": "tr",
                                                            "description": "Bir soru"}}, []))


def test_published_locales_reuses_a_version_it_is_given() -> None:
    print("published_locales: the caller may hand in the version it already read")
    # ⚠️ The decoy matters. Script the version LIST too, with a different id: a
    # fixture that omitted it would make the "ignore the given version" mutant die
    # by AscError instead of by the assertion below, and a mutant reddened by an
    # exception proves the crash, not the property (lesson 76). With the decoy
    # present the mutant runs to completion and only the two assertions catch it.
    seen = _fake_call([
        ("GET", "appStoreVersionLocalizations", {"data": [
            {"attributes": {"locale": "tr", "description": "Bir soru"}}]}),
        ("GET", "appStoreVersions", {"data": [
            {"id": "v-decoy",
             "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}}]}),
        ("GET", "appInfoLocalizations", {"data": []}),
        ("GET", "appInfos", {"data": [{"id": "ai", "attributes": {}}]}),
    ])
    version = {"id": "v-known", "attributes": {"appStoreState": "PREPARE_FOR_SUBMISSION"}}
    merged = audit_tool.published_locales("t", "app", version=version)
    check("still reports the locale", sorted(merged), ["tr"])
    # The whole point: no second round-trip for a version the caller already has.
    check("never asked for the version list",
          [q for _m, q, _b in seen if "appStoreVersions?" in q], [])
    # And it read the localizations of the version it was HANDED, not the decoy.
    check("localizations came from the given version",
          [q for _m, q, _b in seen if "appStoreVersionLocalizations" in q
           and "v-known" in q] != [], True)


def main() -> int:
    print("store_metadata_audit self-tests")
    test_everything_published()
    test_production_state_2026_08_16()
    test_missing_locale_is_reported_once()
    test_present_but_stale_is_a_finding()
    test_name_comes_from_app_info_not_the_version()
    test_absent_field_is_named_as_absent()
    test_trailing_newline_is_not_drift()
    test_unknown_txt_file_is_not_invented_drift()
    test_expected_locales_reads_the_repo()
    test_expected_locales_refuses_an_empty_tree()
    test_the_real_repo_tree_parses()
    test_editable_version_is_chosen_by_state()
    test_no_editable_version_is_could_not_measure()
    test_published_locales_merges_both_resources()
    test_app_info_absent_does_not_kill_the_read()
    test_api_error_is_exit_2_not_exit_1()
    test_main_reports_the_production_finding_and_writes_its_outputs()
    test_main_exit_0_when_everything_matches()
    # ADR-070 D7
    test_classify_the_five_verdicts()
    test_classify_order_is_the_one_the_adr_states()
    test_case_only_does_not_fold_the_turkish_dotted_i()
    test_whitespace_collapse_is_not_normalize()
    test_describe_counts_code_points_not_bytes_or_utf16()
    test_describe_names_the_first_difference()
    test_both_sides_empty_is_not_a_finding_at_all()
    test_the_finding_line_carries_the_verdict()
    test_findings_carry_a_kind_field_not_a_word_in_prose()
    test_one_line_names_BOTH_halves()
    test_one_line_is_unchanged_when_only_one_kind_is_present()
    test_report_names_the_version_it_audited()
    test_published_locales_reuses_a_version_it_is_given()

    if _failures:
        print(f"\n{len(_failures)} FAILED: {', '.join(_failures)}")
        return 1
    print("\nall store_metadata_audit self-tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
