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
    "name.txt": "İkimiz\n",
    "subtitle.txt": "One question a day\n",
    "privacy_url.txt": "https://ikimiz.web.app/privacy\n",
}
TR_FILES = {
    "description.txt": "Her gün bir soru, iki kişiye.\n",
    "keywords.txt": "çift,ilişki\n",
    "name.txt": "İkimiz\n",
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

    findings = audit_tool.audit(expected, actual)

    check("exactly one finding", len(findings), 1)
    check_true("and it names tr", findings[0].startswith("tr: NOT PUBLISHED"))
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

    findings = audit_tool.audit(expected, actual)

    check("one finding", len(findings), 1)
    check_true("names the field and the file", "description differs" in findings[0])
    check_true(
        "the one-liner says stale, not missing",
        "stale" in audit_tool.one_line(findings, expected, actual),
    )


def test_name_comes_from_app_info_not_the_version() -> None:
    print("audit: `name` — the field Apple refuses — is compared at all")
    expected = {"tr": {"name.txt": "İkimiz\n"}}
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

    if _failures:
        print(f"\n{len(_failures)} FAILED: {', '.join(_failures)}")
        return 1
    print("\nall store_metadata_audit self-tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
