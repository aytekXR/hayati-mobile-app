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
from collections import Counter
from typing import NamedTuple

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


# The classification vocabulary (ADR-070 D7.1). CLOSED, and each verdict is a
# FIELD on a Finding rather than a word inside the sentence — `one_line` counts
# these, and counting them by grepping our own prose is the fragility lesson
# **142** exists to buy us out of.
NOT_PUBLISHED = "NOT PUBLISHED"
ABSENT = "ABSENT"
PUBLISHED_EMPTY = "PUBLISHED IS EMPTY"
COMMITTED_EMPTY = "COMMITTED IS EMPTY"
WHITESPACE_ONLY = "WHITESPACE-ONLY"
CASE_ONLY = "CASE-ONLY"
SUBSTANTIVE = "SUBSTANTIVE"


class Finding(NamedTuple):
    """One problem, with its classification beside the sentence, not inside it."""

    locale: str
    field: str | None
    filename: str | None
    kind: str
    text: str


def collapse_whitespace(value: str) -> str:
    """Every whitespace run to a single space — a helper `normalize` cannot be.

    `normalize` trims the edges and folds CRLF and **deliberately preserves
    interior runs**, because that is how a real copy change stays visible. Reusing
    it here would make every interior-whitespace difference invisible instead of
    classified, so the two stay separate on purpose.
    """
    return " ".join(value.split())


def classify_difference(published: str | None, committed: str) -> str:
    """WHAT KIND of difference, for a pair already known to differ.

    First match wins and the order is load-bearing. The two empty cases come
    first and are kept APART: `PUBLISHED IS EMPTY` is copy waiting to land, while
    `COMMITTED IS EMPTY` is a release that would **erase** a field the founder
    typed — and under `deliver(force: true)` that is the difference between a fix
    and a regression, not a nuance.

    ⚠️ `CASE_ONLY` uses `str.casefold()`, which is locale-INDEPENDENT and maps
    `İ` (U+0130) to `i` + U+0307, so `İkimiz` and `ikimiz` do NOT fold together.
    Deliberate: a Turkish-locale fold would be wrong for a tool that also reads
    `en-US`, and this over-reports rather than dismissing a live-listing rename
    (ADR-032 D6) as a casing nit. Pinned by a self-test so it cannot drift.
    """
    left = normalize(published)
    right = normalize(committed)
    if not left:
        return PUBLISHED_EMPTY
    if not right:
        return COMMITTED_EMPTY
    flat_left = collapse_whitespace(left)
    flat_right = collapse_whitespace(right)
    if flat_left == flat_right:
        return WHITESPACE_ONLY
    if flat_left.casefold() == flat_right.casefold():
        return CASE_ONLY
    return SUBSTANTIVE


def describe_difference(published: str | None, committed: str) -> str:
    """The verdict, both lengths, and where the two texts part company.

    Lengths are **code points**, matching `tool/store_metadata_lint.dart`, which
    counts `content.runes.length` — verified by reading it. A byte count would
    make every Turkish field look longer than Apple thinks it is, and a UTF-16
    count (Dart's bare `String.length`) would do the same to an emoji.

    The offset is the common-prefix length of the NORMALIZED strings, i.e. of the
    values actually compared. `first difference at 0` is the reader's cue that
    the store is showing something else entirely rather than carrying a small
    edit — which is exactly the question ADR-070 D4(b) asks the founder.
    """
    left = normalize(published)
    right = normalize(committed)
    shared = 0
    for shared, (a, b) in enumerate(zip(left, right)):
        if a != b:
            break
    else:
        shared = min(len(left), len(right))
    return (
        f"{classify_difference(published, committed)} — published {len(left)} vs "
        f"committed {len(right)} code points, first difference at {shared}"
    )


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


def published_locales(
    token: str, app_id: str, version: dict | None = None
) -> dict[str, dict]:
    """`{locale: merged attributes}` — both resources, one view per locale.

    `version` lets the caller hand in the editable version it already read, so
    the report can NAME which one it audited (ADR-070 D7.3) without a second
    round-trip. Omitted, it reads the version itself, which is what the unit
    tests do.
    """
    version = version or editable_version(token, app_id)
    merged: dict[str, dict] = {}
    for row in tf.version_localizations(token, version["id"]):
        attributes = row.get("attributes") or {}
        locale = attributes.get("locale")
        if locale:
            merged.setdefault(locale, {}).update(attributes)
    for locale, attributes in app_info_localizations(token, app_id).items():
        merged.setdefault(locale, {}).update(attributes)
    return merged


def audit_findings(
    expected: dict[str, dict[str, str]], actual: dict[str, dict]
) -> list[Finding]:
    """The findings, in the order a human would want to read them.

    A MISSING LOCALE is reported once and its fields are not then enumerated:
    twelve "description differs" lines under a locale that does not exist is
    noise that buries the one sentence that matters.

    Each finding carries its `kind` as a FIELD (ADR-070 D7.1). `one_line` tallies
    those, and a tally taken by grepping this function's own sentences would be a
    status word read out of prose — lesson **142**, which this repo has already
    paid for once in a review harness.
    """
    findings: list[Finding] = []
    for locale in sorted(expected):
        if locale not in actual:
            findings.append(
                Finding(
                    locale=locale,
                    field=None,
                    filename=None,
                    kind=NOT_PUBLISHED,
                    text=(
                        f"{locale}: NOT PUBLISHED — no localization exists on "
                        f"the editable App Store version"
                    ),
                )
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
                    Finding(
                        locale=locale,
                        field=field,
                        filename=filename,
                        kind=ABSENT,
                        text=(
                            f"{locale}: {field} is ABSENT on the published "
                            f"localization (from {filename})"
                        ),
                    )
                )
                continue
            published = attributes.get(field)
            if normalize(published) != normalize(text):
                findings.append(
                    Finding(
                        locale=locale,
                        field=field,
                        filename=filename,
                        kind=classify_difference(published, text),
                        text=(
                            f"{locale}: {field} differs from {filename} — "
                            f"{describe_difference(published, text)}"
                        ),
                    )
                )
    return findings


def audit(
    expected: dict[str, dict[str, str]], actual: dict[str, dict]
) -> list[str]:
    """`audit_findings` as the sentences it prints. Kept because the report and
    several self-tests want the text and nothing else."""
    return [finding.text for finding in audit_findings(expected, actual)]


def render(
    expected: dict[str, dict[str, str]],
    actual: dict[str, dict],
    findings: list,
    version: dict | None = None,
) -> str:
    """The full report.

    `version` names WHICH App Store version was audited and what state it was in
    (ADR-070 D7.3). The audit selected one and then discarded it, which cost S095
    a claim it could not check: `tf.EDITABLE_STORE_STATES` holds five states
    (`PREPARE_FOR_SUBMISSION`, `DEVELOPER_REJECTED`, `REJECTED`,
    `METADATA_REJECTED`, `INVALID_BINARY`), so exit 1 is consistent with any of
    them, and "the listing is an unsubmitted draft" was inherited from a
    docstring rather than measured. It is optional so the unit tests, which have
    no version to hand, still render.
    """
    lines = [
        f"expected locales (fastlane/metadata): {', '.join(sorted(expected))}",
        f"published locales (App Store Connect): "
        f"{', '.join(sorted(actual)) if actual else '(none)'}",
    ]
    if version:
        attributes = version.get("attributes") or {}
        lines.append(
            f"audited App Store version: "
            f"{attributes.get('versionString') or '(unnamed)'} "
            f"state={attributes.get('appStoreState') or 'UNKNOWN'}"
        )
    lines.append("")
    if not findings:
        # Say it OUT LOUD. A tool that only speaks when something is wrong is
        # indistinguishable from a tool that is not running — which is how nine
        # releases went green (lesson 65).
        lines.append("OK: every committed locale is published and matches.")
        return "\n".join(lines)
    lines.append(f"FINDING: {len(findings)} problem(s) with the published copy.")
    lines.extend(f"  - {getattr(f, 'text', f)}" for f in findings)
    lines.append("")
    lines.append(
        "  The release itself is unaffected — the binary shipped, and this step "
        "has no vote\n  (ADR-020 D8). What is affected is the STORE LISTING, "
        "which is showing something\n  other than what this ref committed."
    )
    return "\n".join(lines)


def one_line(findings: list[Finding], expected: dict, actual: dict) -> str:
    """The Slack-sized verdict — one line, no newlines, no markup.

    ⚠️ It used to drop most of the findings. On the real 2026-09-02 shape — `tr`
    missing AND seven stale `en-US` fields — it returned
    *"8 finding(s) — tr not published"* and never mentioned English at all, so the
    one channel ADR-047 D5 built to carry this signal across the job boundary
    carried half of it. It now names both halves and tallies the classification
    (ADR-070 D7.2), still on one line.
    """
    if not findings:
        return f"store metadata: all {len(expected)} locale(s) published and current"
    missing = sorted({f.locale for f in findings if f.kind == NOT_PUBLISHED})
    stale = [f for f in findings if f.kind != NOT_PUBLISHED]
    parts: list[str] = []
    if missing:
        parts.append(f"{', '.join(missing)} not published")
    if stale:
        tally = ", ".join(
            f"{count} {kind.lower()}"
            for kind, count in sorted(Counter(f.kind for f in stale).items())
        )
        parts.append(f"{len(stale)} stale ({tally})")
    return f"store metadata: {len(findings)} finding(s) — {'; '.join(parts)}"


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

    version: dict | None = None
    try:
        token = tf._token()
        app = tf.find_app(token, args.bundle_id)
        # Read the editable version ONCE and hand it to both consumers, so the
        # report can name what it audited (ADR-070 D7.3) at no extra request.
        version = editable_version(token, app["id"])
        actual = published_locales(token, app["id"], version=version)
    except AscError as failure:
        print(f"COULD NOT MEASURE: {failure}", file=sys.stderr)
        emit(args.github_output, "store_metadata_audit=store metadata: could not measure")
        return EXIT_CANNOT_MEASURE
    except Exception as failure:  # noqa: BLE001 - exit 2 is the honest answer
        print(f"COULD NOT MEASURE: {type(failure).__name__}: {failure}", file=sys.stderr)
        emit(args.github_output, "store_metadata_audit=store metadata: could not measure")
        return EXIT_CANNOT_MEASURE

    findings = audit_findings(expected, actual)
    report = render(expected, actual, findings, version=version)
    print(report)
    emit(args.summary, "### store metadata\n\n```\n" + report + "\n```")
    emit(args.github_output, "store_metadata_audit=" + one_line(findings, expected, actual))
    return EXIT_FINDING if findings else EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
