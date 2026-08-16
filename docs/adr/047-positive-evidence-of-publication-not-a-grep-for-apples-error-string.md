# ADR-047: `deliver` has failed on nine consecutive releases with Slack silent — the fix is positive evidence of publication, not a grep for Apple's error string

- **Status:** Accepted
- **Date:** 2026-08-16 (Session 069)
- **Deciders:** session agent (this is the engineering half of #204; the Turkish *name* remains a founder decision and is untouched here)
- **Related:** **ADR-020 D8** (`continue-on-error` on the deliver step is CORRECT and stays), **ADR-024 D1/D3** (one tested notifier, all policy in the script, no vote on the build), **ADR-032 D5** (the lane split this audits), **ADR-041** (the exit taxonomy borrowed wholesale), issue **#204**, lessons **65**, **69**, **91**

## Context

`fastlane store_metadata (deliver per locale)` has failed identically on **every
release since build 112** — nine of them, 112 through 119. Every one of those
runs was green, and Slack said nothing every time.

The step already fails loudly *inside itself*: an `##[error]` and forty lines of
Ruby backtrace are right there in the log. What hides it is that
`continue-on-error: true` makes the step's **conclusion** success, the job green,
and the run green. **`continue-on-error` is right here** (ADR-020 D8: the binary
already shipped in the step above, and store copy is native-review-gated). Lesson
**69** is the whole point: *`continue-on-error` is not the bug; an UNREAD failure
is.* It has already produced a wrong instruction to the founder twice (lesson
**91**).

Three facts constrain any fix:

1. **The step had no `id`**, so `steps.<id>.outcome` — which *is* `failure` even
   under `continue-on-error` — had no name to be reached by.
2. **`slack_notify.sh` derives everything from `toJson(needs)`**, i.e. JOB
   results. A step-level non-blocking failure is *structurally* invisible to it.
3. **ADR-024 D1 is binding**: all notifier policy lives in that one tested
   script, and the notifier has no vote on the build. So the fix cannot be a
   bespoke Slack call from inside the release job, and cannot make the step fail.

## Decision 1 — Assert PUBLICATION, and never grep Apple's message

The obvious instrument is a step that greps the log for
`Cannot add localization due to app name`. **Rejected.** That is the same defect
one level down: it goes quiet the day Apple changes the wording, and quiet reads
as fine — the exact substitution that produced this issue.

It also cannot work here, for a reason that only shows up once you read the
logs. `deliver` dies inside `verify_available_version_languages!`, which runs
**before** the upload phase:

```
deliver/lib/deliver/upload_metadata.rb:575:in `block in verify_available_version_languages!'
deliver/lib/deliver/upload_metadata.rb:103:in `upload'
```

So there is no per-locale success line to key on in any of the nine logs, because
**there has never been a success.** A log parser has no positive fixture to be
written against, and one written against a guess at the format is a test whose
fixture came from its own subject (recurring failure #4).

**Decision: ask App Store Connect what it actually holds.**

* expected set — the directories in `fastlane/metadata/`, i.e. the repository;
* actual set — `appStoreVersionLocalizations` + `appInfoLocalizations` on the
  editable App Store version.

Absence of evidence is a **finding** (lesson 65). The expected set comes from the
repo and never from Apple, because a tool that derived what *should* exist from
what *does* exist could not detect the one thing it is for.

## Decision 2 — Presence is not enough; the TEXT is compared

A presence-only check would have read `en-US` as green. It is not, and this is
the finding the ADR did not expect to make.

Measured 2026-08-16, against the live App Store Connect listing
(`testflight-testers.yml -f store_metadata_audit=true`, run 31949645300):

```
expected locales (fastlane/metadata): en-US, tr
published locales (App Store Connect): en-US

FINDING: 8 problem(s) with the published copy.
  - en-US: description differs from description.txt
  - en-US: keywords differs from keywords.txt
  - en-US: privacyPolicyUrl differs from privacy_url.txt
  - en-US: promotionalText differs from promotional_text.txt
  - en-US: whatsNew differs from release_notes.txt
  - en-US: subtitle differs from subtitle.txt
  - en-US: supportUrl differs from support_url.txt
  - tr: NOT PUBLISHED — no localization exists on the editable App Store version
```

**The honest headline is not "the Turkish localization is missing".** It is that
`fastlane/metadata/` has *never been published at all* — because deliver aborts
before the upload phase, the English listing is still whatever was typed by hand
into App Store Connect, and seven of its nine fields disagree with this ref.
`name` and `marketingUrl` match, which is the only reason the drift was
survivable this long.

That is a materially different fact from the one #204 was filed with, and it was
reachable only because the comparison went past presence.

## Decision 3 — Two resources, because `name` lives on the second one

`description`, `keywords`, `whatsNew`, `promotionalText`, `supportUrl` and
`marketingUrl` are `appStoreVersionLocalizations`. **`name`, `subtitle` and
`privacyPolicyUrl` are `appInfoLocalizations`** — a different endpoint entirely.

`name` is the field Apple actually refuses. A tool that read only version
localizations would have missed the cause of the failure it was written for.

## Decision 4 — The repo's exit taxonomy, and no vote

Straight from `rules_drift.py` (ADR-041), because a fourth dialect of "what does
non-zero mean" is how these get misread:

| | |
|---|---|
| **0** | every expected locale is published and matches |
| **1** | FINDING — a locale is missing, or a published field differs |
| **2** | COULD NOT MEASURE — no credential, an API error, no editable version |

**2 is not 1.** "I could not read App Store Connect" and "the copy did not land"
are different sentences, and collapsing them would hand the founder a
measured-sounding lie. No editable version is likewise exit 2, not a finding:
there is nothing deliver could have written to, so "it failed to publish" is an
accusation the evidence does not support.

The step runs `if: always()` (the only interesting case is the one where the step
above failed) and `continue-on-error: true`. **It has no vote.** A store-copy
finding must never redden a release whose binary shipped.

## Decision 5 — The verdict crosses the job boundary as an OUTPUT, and the notifier policy stays in the script

`sign-upload` gains one output; `slack-notify` reads it as `EXTRA_FINDINGS`. That
is the only channel that crosses the step→job boundary `toJson(needs)` cannot.

Everything the notifier then *does* with it lives in `slack_notify.sh` and is
covered by `slack_notify_test.sh` (ADR-024 D1 — the policy is in tested code, not
in a YAML `if:` the self-test cannot see):

* a finding qualifies the headline to **`⚠️ CI passed, with findings`** — never a
  bare `✅ CI passed`, which is the sentence nine releases sent;
* a finding is **exempt from the PR noise policy**, because it is precisely the
  signal with no other reader on a run that otherwise looks fine — and the
  exemption is narrow: a clean PR is still silent;
* a red run stays red and carries the finding as well;
* the lines are `slack_escape`d like every other free-text field;
* whitespace-only is *none* — an unset job output interpolates to a blank string,
  and an empty `Findings:` header on every release is how a reader learns to skip
  it.

Five mutations were applied to those five properties; all five reddened a named
assertion.

## Decision 6 — It is dispatchable, because otherwise it could never be exercised

`session-context.md` §7 forbids a session dispatching the release lane. Without a
second entry point, the instrument could only ever run in the event it exists to
watch — and an unexercised instrument is the thing it is guarding against.

So `testflight-testers.yml` gains a read-only `store_metadata_audit` input, and
this ADR's Decision 2 measurement was taken through it. **The tool has been run
against the real App Store Connect, not only against its own fixtures.**

## Consequences

**What this does not do.** It does not fix the publication. `tr` still cannot be
created while Apple refuses the app name (a founder decision — a different
Turkish display name), and the `en-US` drift will persist until a release runs
with a deliver that gets past `verify_available_version_languages!`. This ADR
makes the failure legible; the copy decision stays where it belongs.

**Nothing here can redden a release.** Exit 1 is the expected answer today, and
the run stays green — by construction in two independent places
(`continue-on-error` on the step, and the notifier's no-vote guarantee).

**One deliberate change-detector.** `store_metadata_audit_test.py` pins the
locale set to exactly `en-US, tr` against the real `fastlane/metadata/` tree. A
third locale appearing without anyone deciding to publish it should stop and be
read — the ADR-032 mold, applied to store copy.
