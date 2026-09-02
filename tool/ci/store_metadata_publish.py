#!/usr/bin/env python3
"""Publish `fastlane/metadata/` PER LOCALE, so one locale Apple refuses stops
taking the others down with it. (#278, ADR-071)

WHY THIS EXISTS. `fastlane store_metadata` runs `deliver(force: true)`, and
`deliver` dies inside `verify_available_version_languages!` — BEFORE the upload
phase — because Apple refuses to create the `tr` localization under this app
name. One refused locale therefore aborts the run for EVERY locale, which is why
`fastlane/metadata/` has never been published at all (ADR-070 D2). Measured
2026-09-02: seven of nine `en-US` fields are EMPTY at Apple, not stale.

THE ORDER IS THE DESIGN (ADR-071 D2). The fields split across two resources:

  appStoreVersionLocalizations   description, keywords, whatsNew,
                                 promotionalText, supportUrl, marketingUrl
  appInfoLocalizations           name, subtitle, privacyPolicyUrl

`name` is on the second, and `name` is the field Apple refuses. So a locale is
published as a UNIT and `appInfoLocalizations` is attempted FIRST: when it is
refused, nothing has been written for that locale and every OTHER locale still
proceeds. Per-field isolation would leave a Turkish listing carrying a
description and no name — a state nobody here can observe or undo.

⚠️ ORDERING IS NOT A TRANSACTION. It covers the known refusal completely,
because nothing is written when it fires. The reverse — app info lands, the
version localization then fails — is possible, is not prevented, and is reported
naming BOTH halves (D2.2).

WHAT IT REFUSES TO DO:

  * **send an empty field** (D4). An empty file on disk is skipped, never written
    as a blank. Emptying a file is not how you delete store copy, and blanking a
    field the founder typed by hand is ADR-070 D7's `COMMITTED IS EMPTY` hazard.
  * **trust its own success messages** (D5). It reads both resources back and
    runs the auditor's own comparison over what it WROTE — a 2xx says the request
    was accepted, not that the listing now says what we sent.
  * **treat a typo as a no-op** (D6). No `--confirm` is a dry run; a WRONG
    `--confirm` is REFUSED, because answering a fumbled literal with a cheerful
    dry run tells someone who meant to publish that they did.
  * **print Apple's copy** (ADR-070 D7.4). This repository is public and the
    store's text is the founder's unpublished draft. The plan reports field
    COUNTS and names, never values.

EXIT CODES (ADR-041's taxonomy, ADR-047 D4; `grep -l 'could not measure'
tool/ci/*.py` lists the others):

    0   every expected locale is published and the read-back agrees
    1   FINDING — a locale was refused, a locale is half-written, or the
        read-back disagrees
    2   COULD NOT MEASURE — no credential, no editable version, or an API error
        BEFORE any write was attempted
    64  REFUSED — a `--confirm` was given and it was not the literal. Nothing
        was sent. Deliberately outside the taxonomy: it is a usage error, not a
        statement about the listing.

⚠️ 2 STOPS AT THE FIRST WRITE ATTEMPT. After that, an error — including the
version ceasing to be editable because someone submitted it mid-run — is a
FINDING, because the listing may now be in a state nobody chose. Calling that
"could not measure" would describe a CHANGED listing as an unobserved one.

⚠️ NOTHING IN THIS TOOL HAS EVER RUN AGAINST APPLE. The request shapes are the
JSON:API form this repo already uses for `betaGroups` (`testflight_testers.py`),
and ADR-071 D3 separates what is known from what is assumed — nobody here has
seen what the REST API returns for the name refusal, so the tool QUOTES what it
cannot parse. Its first real execution is its first real test.

Usage:
    python3 tool/ci/store_metadata_publish.py                    # dry run
    python3 tool/ci/store_metadata_publish.py --confirm PUBLISH  # writes
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import pathlib
import sys
from typing import Callable, NamedTuple

_AUDIT_PATH = pathlib.Path(__file__).with_name("store_metadata_audit.py")
_spec = importlib.util.spec_from_file_location("store_metadata_audit", _AUDIT_PATH)
assert _spec is not None and _spec.loader is not None
audit = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(audit)

# The field maps are IMPORTED, never restated. If `store_metadata_audit.py`'s
# split moves, this breaks loudly at import rather than drifting quietly — the
# intended failure direction (ADR-071 Consequences).
tf = audit.tf
AscError = audit.AscError
VERSION_FIELDS = audit.VERSION_FIELDS
APP_INFO_FIELDS = audit.APP_INFO_FIELDS
normalize = audit.normalize

EXIT_OK = 0
EXIT_FINDING = 1
EXIT_CANNOT_MEASURE = 2
EXIT_REFUSED = 64

CONFIRM_LITERAL = "PUBLISH"
MODE_DRY_RUN = "DRY_RUN"
MODE_WRITE = "WRITE"
MODE_REFUSED = "REFUSED"

VERSION_TYPE = "appStoreVersionLocalizations"
APP_INFO_TYPE = "appInfoLocalizations"

DEFAULT_BUNDLE_ID = "com.beyondkaira.hayati"


class Action(NamedTuple):
    """One request, fully resolved before anything is sent.

    `files` is what the read-back will expect back if this action succeeds — the
    committed filenames, not the attribute names, because `audit_findings` is
    keyed on files (ADR-071 D5.1).
    """

    locale: str
    resource: str
    verb: str
    path: str
    body: dict
    files: dict[str, str]


class Finding(NamedTuple):
    """A locale that did not fully publish. `partial` is a FIELD, not a word in
    the sentence — lesson 142, and `render` and the exit code both read it."""

    locale: str
    partial: bool
    detail: str


class Outcome(NamedTuple):
    planned: list[Action]
    written: list[Action]
    findings: list[Finding]


def resolve_mode(confirm: str | None) -> str:
    """Absence means "I am looking". A wrong literal means "I tried and fumbled".

    Those must not print the same thing. Revision 1 of ADR-071 made any wrong
    confirm a quiet dry run; the design review checked the precedent
    (`appid_capability_enable.py` returns REFUSED) and it was right.
    """
    if confirm is None or confirm == "":
        return MODE_DRY_RUN
    return MODE_WRITE if confirm == CONFIRM_LITERAL else MODE_REFUSED


def writable_fields(files: dict[str, str]) -> tuple[dict[str, str], dict[str, str]]:
    """`(app_info_attributes, version_attributes)` for one locale.

    An EMPTY committed value is dropped, not sent as `""` (ADR-071 D4). An
    unknown `.txt` is ignored the way the auditor ignores it — fastlane's
    metadata directory carries files these maps do not own, and inventing a write
    for one would be worse than inventing a finding.
    """
    info: dict[str, str] = {}
    version: dict[str, str] = {}
    for filename, text in sorted(files.items()):
        value = normalize(text)
        if not value:
            continue
        if filename in APP_INFO_FIELDS:
            info[APP_INFO_FIELDS[filename]] = value
        elif filename in VERSION_FIELDS:
            version[VERSION_FIELDS[filename]] = value
    return info, version


def _files_for(files: dict[str, str], fieldmap: dict[str, str]) -> dict[str, str]:
    return {
        name: text
        for name, text in files.items()
        if name in fieldmap and normalize(text)
    }


def _action(
    locale: str,
    resource: str,
    attributes: dict[str, str],
    files: dict[str, str],
    *,
    existing_id: str | None,
    parent_type: str,
    parent_key: str,
    parent_id: str,
) -> Action:
    """A PATCH by id, or a POST hung off its parent.

    ⚠️ The parent for an `appInfoLocalizations` create is the editable **appInfo**,
    not the app (ADR-071 D3). Revision 1 did not mention it and would have hung
    the create off the wrong resource.
    """
    if existing_id:
        return Action(
            locale=locale,
            resource=resource,
            verb="PATCH",
            path=f"/v1/{resource}/{existing_id}",
            body={"data": {"type": resource, "id": existing_id, "attributes": dict(attributes)}},
            files=files,
        )
    return Action(
        locale=locale,
        resource=resource,
        verb="POST",
        path=f"/v1/{resource}",
        body={
            "data": {
                "type": resource,
                "attributes": {"locale": locale, **attributes},
                "relationships": {parent_key: {"data": {"type": parent_type, "id": parent_id}}},
            }
        },
        files=files,
    )


def plan(
    expected: dict[str, dict[str, str]],
    *,
    version_id: str,
    app_info_id: str,
    existing_version: dict[str, str],
    existing_app_info: dict[str, str],
) -> list[Action]:
    """Every request, in the order it will be sent.

    Locales in sorted order for a stable report; **within a locale, app info
    first** (ADR-071 D2) — that ordering is the whole isolation strategy, so it
    lives here rather than in `execute`, where a later edit could reorder it
    without a test noticing.
    """
    actions: list[Action] = []
    for locale in sorted(expected):
        files = expected[locale]
        info_attributes, version_attributes = writable_fields(files)
        if info_attributes:
            actions.append(
                _action(
                    locale,
                    APP_INFO_TYPE,
                    info_attributes,
                    _files_for(files, APP_INFO_FIELDS),
                    existing_id=existing_app_info.get(locale),
                    parent_type="appInfos",
                    parent_key="appInfo",
                    parent_id=app_info_id,
                )
            )
        if version_attributes:
            actions.append(
                _action(
                    locale,
                    VERSION_TYPE,
                    version_attributes,
                    _files_for(files, VERSION_FIELDS),
                    existing_id=existing_version.get(locale),
                    parent_type="appStoreVersions",
                    parent_key="appStoreVersion",
                    parent_id=version_id,
                )
            )
    return actions


def execute(
    call: Callable[..., dict],
    actions: list[Action],
    *,
    dry_run: bool,
) -> Outcome:
    """Send the plan, one locale at a time, and never let one locale end another.

    ⚠️ A dry run sends NOTHING — not even a read. Everything it would need was
    resolved by `plan`, which is what makes the dry run a real exercise of this
    code rather than a stub (ADR-071 D6).
    """
    if dry_run:
        return Outcome(planned=list(actions), written=[], findings=[])

    written: list[Action] = []
    findings: list[Finding] = []
    by_locale: dict[str, list[Action]] = {}
    for action in actions:
        by_locale.setdefault(action.locale, []).append(action)

    for locale in sorted(by_locale):
        landed: list[str] = []
        for action in by_locale[locale]:
            try:
                call(action.verb, action.path, action.body)
            # ⚠️ `Exception`, not `AscError`. `tf._call` converts an HTTPError
            # into AscError and leaves URLError, socket.timeout and a malformed
            # JSON body to propagate raw — so catching only AscError would let a
            # DNS blip on one locale abort every remaining locale, which is
            # #278's own defect reintroduced one exception type over. Found by
            # the built-diff review with a three-locale reproduction.
            except Exception as failure:  # noqa: BLE001 - isolation is the point
                label = (
                    str(failure)
                    if isinstance(failure, AscError)
                    else f"{type(failure).__name__}: {failure}"
                )
                if landed:
                    # D2.2 — ordering is not a transaction. Name BOTH halves: a
                    # partial write reported as a locale-wide failure sends
                    # someone looking for a listing that is half there, and
                    # reported as a success it is the defect #278 is made of.
                    findings.append(
                        Finding(
                            locale=locale,
                            partial=True,
                            detail=(
                                f"PARTIAL — {', '.join(landed)} written, "
                                f"{action.resource} FAILED: {label}"
                            ),
                        )
                    )
                else:
                    findings.append(
                        Finding(
                            locale=locale,
                            partial=False,
                            detail=f"{action.resource} refused, nothing written: {label}",
                        )
                    )
                # The locale is a unit: stop here, and go on to the next locale.
                break
            written.append(action)
            landed.append(action.resource)

    return Outcome(planned=list(actions), written=written, findings=findings)


def read_back_expectation(outcome: Outcome) -> dict[str, dict[str, str]]:
    """What the read-back should find — built from what was WRITTEN, not from the
    committed tree.

    ⚠️ This is ADR-071 D5.1, the design review's one blocking finding. Passing
    the whole committed set to `audit_findings` would report `COMMITTED IS EMPTY`
    against a field D4 correctly declined to write, failing the read-back for a
    write that did everything right. The read-back asks exactly one question:
    *did what I wrote land?*

    The blind spot that creates — a field empty here and non-empty at Apple — is
    covered by `store_metadata_audit.py`, which reports it on every run. The two
    tools are deliberately not given the same job.
    """
    expectation: dict[str, dict[str, str]] = {}
    for action in outcome.written:
        expectation.setdefault(action.locale, {}).update(action.files)
    return expectation


def exit_code(*, refusals: int, read_back: int) -> int:
    """0 or 1. **2 cannot reach here, and that is the decision** (ADR-071 D7).

    Every path that could answer "could not measure" returns EXIT_CANNOT_MEASURE
    from `main` BEFORE the first write is attempted; after that, an error is a
    statement about the LISTING, not about our ability to see it. Revision 1 took
    a `wrote` flag here to say so and never read it — an argument that documents
    rather than computes reads as a bug, and the boundary belongs where it is
    actually enforced.
    """
    if refusals or read_back:
        return EXIT_FINDING
    return EXIT_OK


def render(outcome: Outcome, *, dry_run: bool) -> str:
    """The plan a human reads before authorising it (operator 6(b)).

    Field NAMES and COUNTS, never values: this runs in a public repository's
    Actions log, and while our own copy is already public there, printing it back
    turns a diagnostic into a publication channel (ADR-070 D7.4).
    """
    header = "DRY RUN — nothing was sent." if dry_run else "WROTE"
    lines = [f"store metadata publish: {header}", ""]
    if not outcome.planned:
        lines.append("nothing to publish: every committed field is empty.")
        return "\n".join(lines)

    lines.append(f"plan ({len(outcome.planned)} request(s)):")
    for action in outcome.planned:
        attributes = action.body["data"]["attributes"]
        names = ", ".join(sorted(k for k in attributes if k != "locale"))
        lines.append(
            f"  {action.locale}: {action.verb} {action.resource} "
            f"— {len(action.files)} field(s): {names}"
        )
    if not dry_run:
        lines.append("")
        lines.append(f"written: {len(outcome.written)} of {len(outcome.planned)} request(s)")
    if outcome.findings:
        lines.append("")
        lines.append(f"FINDING: {len(outcome.findings)} locale(s) did not fully publish.")
        for finding in outcome.findings:
            lines.append(f"  - {finding.locale}: {finding.detail}")
    return "\n".join(lines)


def emit(path: str | None, text: str) -> None:
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(text + "\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata-dir", default="fastlane/metadata")
    parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    parser.add_argument(
        "--confirm",
        default=None,
        help=(
            f"must be exactly {CONFIRM_LITERAL!r} to write. Omitted entirely = a "
            f"dry run; anything else = REFUSED, and nothing is sent."
        ),
    )
    parser.add_argument("--summary", default=os.environ.get("GITHUB_STEP_SUMMARY"))
    args = parser.parse_args(argv)

    mode = resolve_mode(args.confirm)
    if mode == MODE_REFUSED:
        print(
            f"REFUSED (nothing was sent): --confirm must be exactly "
            f"{CONFIRM_LITERAL!r}, and it was {args.confirm!r}. Omit it entirely "
            f"for a dry run.",
            file=sys.stderr,
        )
        return EXIT_REFUSED

    try:
        expected = audit.expected_locales(pathlib.Path(args.metadata_dir))
    except (AscError, OSError) as failure:
        print(f"COULD NOT MEASURE: {failure}", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    # Everything up to here is read-only, so an error is still EXIT 2.
    try:
        token = tf._token()
        app = tf.find_app(token, args.bundle_id)
        version = audit.editable_version(token, app["id"])
        app_info_id, existing_app_info = _app_info_state(token, app["id"])
        existing_version = {
            (row.get("attributes") or {}).get("locale"): row.get("id")
            for row in tf.version_localizations(token, version["id"])
            if (row.get("attributes") or {}).get("locale")
        }
    except AscError as failure:
        print(f"COULD NOT MEASURE: {failure}", file=sys.stderr)
        return EXIT_CANNOT_MEASURE
    except Exception as failure:  # noqa: BLE001 - exit 2 is the honest answer
        print(f"COULD NOT MEASURE: {type(failure).__name__}: {failure}", file=sys.stderr)
        return EXIT_CANNOT_MEASURE

    actions = plan(
        expected,
        version_id=version["id"],
        app_info_id=app_info_id,
        existing_version=existing_version,
        existing_app_info=existing_app_info,
    )

    def call(method: str, path: str, body: dict | None = None) -> dict:
        return tf._call(token, method, path, body)

    outcome = execute(call, actions, dry_run=(mode == MODE_DRY_RUN))
    report = render(outcome, dry_run=(mode == MODE_DRY_RUN))

    read_back_findings: list = []
    if mode == MODE_WRITE and outcome.written:
        # D5. A 2xx is not proof; Apple's state is. And this tool has never run
        # against Apple, so the read-back is what makes its first real execution
        # self-checking rather than self-reporting.
        try:
            actual = audit.published_locales(token, app["id"], version=version)
            read_back_findings = audit.audit_findings(read_back_expectation(outcome), actual)
        except AscError as failure:
            # ⚠️ NOT exit 2. Something has been written; the listing may be in a
            # state nobody chose, and calling that "could not measure" would
            # describe a changed listing as an unobserved one (D7).
            read_back_findings = [
                audit.Finding(
                    locale="(read-back)", field=None, filename=None,
                    kind=audit.NOT_PUBLISHED,
                    text=f"the read-back could not run AFTER writing: {failure}",
                )
            ]
        report += "\n\nread-back:\n" + (
            "  OK: everything written is present and matches."
            if not read_back_findings
            else "\n".join(f"  - {f.text}" for f in read_back_findings)
        )

    print(report)
    emit(args.summary, "### store metadata publish\n\n```\n" + report + "\n```")
    return exit_code(refusals=len(outcome.findings), read_back=len(read_back_findings))


def _app_info_state(token: str, app_id: str) -> tuple[str, dict[str, str]]:
    """`(editable appInfo id, {locale: localization id})`.

    The same selection `store_metadata_audit.app_info_localizations` makes, but
    it keeps the appInfo's own id — which a CREATE needs as its parent and which
    the audit had no reason to return.
    """
    infos = tf._call(token, "GET", f"/v1/apps/{app_id}/appInfos?limit=10").get("data", [])
    if not infos:
        raise AscError("the app has no appInfo, so there is nothing to write `name` to.")
    chosen = next(
        (
            info
            for info in infos
            if ((info.get("attributes") or {}).get("appStoreState")) in tf.EDITABLE_STORE_STATES
        ),
        infos[0],
    )
    rows = tf._call(
        token, "GET", f"/v1/appInfos/{chosen['id']}/appInfoLocalizations?limit=50"
    ).get("data", [])
    return chosen["id"], {
        (row.get("attributes") or {}).get("locale"): row.get("id")
        for row in rows
        if (row.get("attributes") or {}).get("locale")
    }


if __name__ == "__main__":
    sys.exit(main())
