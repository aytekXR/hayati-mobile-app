#!/usr/bin/env python3
"""Did the store copy we committed actually get PUBLISHED? (#204)

WHY THIS EXISTS. `fastlane store_metadata (deliver per locale)` has failed
identically on every release since build 112 — nine of them, 112 through 119 —
and every one of those runs was green and Slack said nothing. The step is
`continue-on-error: true` and that is CORRECT (ADR-020 D8: the binary already
shipped in the step above, and store copy is native-review-gated). Lesson **69**:
*`continue-on-error` is not the bug; an UNREAD failure is.* It has already
produced a wrong instruction to the founder twice (lesson **91**).

WHAT IT REFUSES TO DO. It does not grep the log for
`Cannot add localization due to app name`. That is the same defect one level
down: it goes quiet the day Apple changes the message, and quiet reads as fine.
It also cannot work here for a second reason — `deliver` aborts inside
`verify_available_version_languages!`, i.e. BEFORE it uploads anything, so there
is no per-locale success line in any of the nine logs to key on. There is no
positive fixture to parse because there has never been a success.

SO IT ASKS THE STORE. Expected set = the directories in `fastlane/metadata/`.
Actual set = what App Store Connect actually holds on the editable version.
Absence of evidence is a FINDING (lesson **65**), and so is a locale that exists
but whose text does not match the file on disk — because a present-but-stale
locale is exactly what a presence-only check would call green.

That distinction is not hypothetical. Measured 2026-08-16 (read-only, via
`testflight-testers.yml -f store_status=true`):

    app store versions (newest first):
      1.0  state=PREPARE_FOR_SUBMISSION  platform=IOS <-- editable
          en-US: APP_IPHONE_67=6

**One locale.** `tr` is absent, and because deliver dies before the upload
phase, the `en-US` copy has never been refreshed either — so the honest verdict
is not "one of two locales is missing", it is "nothing has ever been published".

WHERE THE FIELDS LIVE (two different resources, and the split is the whole bug):

  appStoreVersionLocalizations   description, keywords, whatsNew,
                                 promotionalText, supportUrl, marketingUrl
  appInfoLocalizations           name, subtitle, privacyPolicyUrl

`name` is on the SECOND one, and `name` is what Apple refuses — so a tool that
only read version localizations would miss the actual failure.

EXIT CODES (the `rules_drift.py` taxonomy, used everywhere in this repo):

    0   every expected locale is published and matches the committed files
    1   FINDING — a locale is missing, or a published field differs from disk
    2   COULD NOT MEASURE — no credential, an API error, no editable version

It has NO VOTE on the release. release.yml runs it `continue-on-error` and
publishes the verdict as a job output; the notifier reads that output. Nothing
here can redden a build (ADR-020 D8, ADR-024 D3).
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import pathlib
import sys

_MODULE_PATH = pathlib.Path(__file__).with_name("testflight_testers.py")
_spec = importlib.util.spec_from_file_location("testflight_testers", _MODULE_PATH)
assert _spec is not None and _spec.loader is not None
tf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tf)

AscError = tf.AscError

EXIT_OK = 0
EXIT_FINDING = 1
EXIT_CANNOT_MEASURE = 2

DEFAULT_BUNDLE_ID = "com.beyondkaira.hayati"

# filename -> the App Store Connect attribute it publishes to.
#
# Split by RESOURCE, because they are two different endpoints and `name` — the
# one Apple actually refuses — is on the second.
VERSION_FIELDS = {
    "description.txt": "description",
    "keywords.txt": "keywords",
    "release_notes.txt": "whatsNew",
    "promotional_text.txt": "promotionalText",
    "support_url.txt": "supportUrl",
    "marketing_url.txt": "marketingUrl",
}
APP_INFO_FIELDS = {
    "name.txt": "name",
    "subtitle.txt": "subtitle",
    "privacy_url.txt": "privacyPolicyUrl",
}


def normalize(value: str | None) -> str:
    """Compare TEXT, not whitespace.

    Every file on disk ends in a newline and Apple's stored value does not, so a
    byte-exact comparison would report all twelve fields as drifted forever —
    the cries-wolf failure that gets an instrument ignored, which is the same
    outcome as not having one. Interior text is untouched: only the edges are
    trimmed, and CRLF is folded, so a real copy change is still a finding.
    """
    if value is None:
        return ""
    return value.replace("\r\n", "\n").strip()


def expected_locales(metadata_dir: pathlib.Path) -> dict[str, dict[str, str]]:
    """The committed copy: `{locale: {filename: text}}`.

    The EXPECTED set comes from the repository, never from Apple. A tool that
    derived what should exist from what does exist could not detect the one
    thing it is for (`tr` missing entirely) — that is the fixture-from-its-own-
    subject shape, recurring failure #4 in `session-lessons.md`.
    """
    if not metadata_dir.is_dir():
        raise AscError(f"{metadata_dir} is not a directory")
    locales: dict[str, dict[str, str]] = {}
    for child in sorted(metadata_dir.iterdir()):
        if not child.is_dir() or child.name.startswith("."):
            continue
        files = {
            path.name: path.read_text(encoding="utf-8")
            for path in sorted(child.iterdir())
            if path.is_file() and path.suffix == ".txt"
        }
        if files:
            locales[child.name] = files
    if not locales:
        raise AscError(f"{metadata_dir} contains no locale directories")
    return locales


def editable_version(token: str, app_id: str) -> dict:
    """The App Store version `deliver` writes to.

    No editable version is EXIT 2, not a finding: there is nothing for deliver to
    have published to, so "the copy did not land" would be an accusation the
    evidence does not support.
    """
    versions = tf.app_store_versions(token, app_id)
    for version in versions:
        state = (version.get("attributes") or {}).get("appStoreState")
        if state in tf.EDITABLE_STORE_STATES:
            return version
    states = ", ".join(
        sorted(
            {
                (v.get("attributes") or {}).get("appStoreState") or "UNKNOWN"
                for v in versions
            }
        )
    ) or "(no versions at all)"
    raise AscError(
        "no App Store version is in an editable state, so deliver had nothing "
        f"to write to. States seen: {states}"
    )


def app_info_localizations(token: str, app_id: str) -> dict[str, dict]:
    """`{locale: attributes}` for the EDITABLE app info.

    `appInfos` carries one row per review state; the editable one is where
    `name` / `subtitle` / `privacyPolicyUrl` are written. Falls back to the first
    row rather than failing, because an unrecognised state must not hide the
    locale set — the `EDITABLE_STORE_STATES` reasoning, one resource over.
    """
    infos = tf._call(token, "GET", f"/v1/apps/{app_id}/appInfos?limit=10").get(
        "data", []
    )
    if not infos:
        return {}
    chosen = next(
        (
            info
            for info in infos
            if ((info.get("attributes") or {}).get("appStoreState"))
            in tf.EDITABLE_STORE_STATES
        ),
        infos[0],
    )
    rows = tf._call(
        token,
        "GET",
        f"/v1/appInfos/{chosen['id']}/appInfoLocalizations?limit=50",
    ).get("data", [])
    return {
        (row.get("attributes") or {}).get("locale"): (row.get("attributes") or {})
        for row in rows
        if (row.get("attributes") or {}).get("locale")
    }


def published_locales(token: str, app_id: str) -> dict[str, dict]:
    """`{locale: merged attributes}` — both resources, one view per locale."""
    version = editable_version(token, app_id)
    merged: dict[str, dict] = {}
    for row in tf.version_localizations(token, version["id"]):
        attributes = row.get("attributes") or {}
        locale = attributes.get("locale")
        if locale:
            merged.setdefault(locale, {}).update(attributes)
    for locale, attributes in app_info_localizations(token, app_id).items():
        merged.setdefault(locale, {}).update(attributes)
    return merged


def audit(
    expected: dict[str, dict[str, str]], actual: dict[str, dict]
) -> list[str]:
    """The findings, in the order a human would want to read them.

    A MISSING LOCALE is reported once and its fields are not then enumerated:
    twelve "description differs" lines under a locale that does not exist is
    noise that buries the one sentence that matters.
    """
    findings: list[str] = []
    for locale in sorted(expected):
        if locale not in actual:
            findings.append(
                f"{locale}: NOT PUBLISHED — no localization exists on the "
                f"editable App Store version"
            )
            continue
        attributes = actual[locale]
        for filename, text in sorted(expected[locale].items()):
            field = VERSION_FIELDS.get(filename) or APP_INFO_FIELDS.get(filename)
            if field is None:
                # An unknown .txt is not a finding: fastlane's metadata directory
                # carries files this map does not own, and inventing a failure
                # for one would be the cries-wolf mistake.
                continue
            if field not in attributes:
                findings.append(
                    f"{locale}: {field} is ABSENT on the published localization "
                    f"(from {filename})"
                )
                continue
            if normalize(attributes.get(field)) != normalize(text):
                findings.append(
                    f"{locale}: {field} differs from {filename} — the committed "
                    f"copy is not what the store is showing"
                )
    return findings


def render(
    expected: dict[str, dict[str, str]],
    actual: dict[str, dict],
    findings: list[str],
) -> str:
    lines = [
        f"expected locales (fastlane/metadata): {', '.join(sorted(expected))}",
        f"published locales (App Store Connect): "
        f"{', '.join(sorted(actual)) if actual else '(none)'}",
        "",
    ]
    if not findings:
        # Say it OUT LOUD. A tool that only speaks when something is wrong is
        # indistinguishable from a tool that is not running — which is how nine
        # releases went green (lesson 65).
        lines.append("OK: every committed locale is published and matches.")
        return "\n".join(lines)
    lines.append(f"FINDING: {len(findings)} problem(s) with the published copy.")
    lines.extend(f"  - {finding}" for finding in findings)
    lines.append("")
    lines.append(
        "  The release itself is unaffected — the binary shipped, and this step "
        "has no vote\n  (ADR-020 D8). What is affected is the STORE LISTING, "
        "which is showing something\n  other than what this ref committed."
    )
    return "\n".join(lines)


def one_line(findings: list[str], expected: dict, actual: dict) -> str:
    """The Slack-sized verdict — one line, no newlines, no markup."""
    if not findings:
        return f"store metadata: all {len(expected)} locale(s) published and current"
    missing = [f.split(":", 1)[0] for f in findings if "NOT PUBLISHED" in f]
    if missing:
        return (
            f"store metadata: {len(findings)} finding(s) — "
            f"{', '.join(missing)} not published"
        )
    return f"store metadata: {len(findings)} finding(s) — published copy is stale"


def emit(path: str | None, text: str) -> None:
    """Append to a GitHub file-protocol path, if one was given."""
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(text + "\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata-dir", default="fastlane/metadata")
    parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    parser.add_argument(
        "--github-output",
        default=os.environ.get("GITHUB_OUTPUT"),
        help="write `store_metadata_audit=<one line>` here (a job output).",
    )
    parser.add_argument(
        "--summary",
        default=os.environ.get("GITHUB_STEP_SUMMARY"),
        help="append the full report here (the run's step summary).",
    )
    args = parser.parse_args(argv)

    try:
        expected = expected_locales(pathlib.Path(args.metadata_dir))
    except (AscError, OSError) as failure:
        print(f"COULD NOT MEASURE: {failure}", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    try:
        token = tf._token()
        app = tf.find_app(token, args.bundle_id)
        actual = published_locales(token, app["id"])
    except AscError as failure:
        print(f"COULD NOT MEASURE: {failure}", file=sys.stderr)
        emit(args.github_output, "store_metadata_audit=store metadata: could not measure")
        return EXIT_CANNOT_MEASURE
    except Exception as failure:  # noqa: BLE001 - exit 2 is the honest answer
        print(f"COULD NOT MEASURE: {type(failure).__name__}: {failure}", file=sys.stderr)
        emit(args.github_output, "store_metadata_audit=store metadata: could not measure")
        return EXIT_CANNOT_MEASURE

    findings = audit(expected, actual)
    report = render(expected, actual, findings)
    print(report)
    emit(args.summary, "### store metadata\n\n```\n" + report + "\n```")
    emit(args.github_output, "store_metadata_audit=" + one_line(findings, expected, actual))
    return EXIT_FINDING if findings else EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
