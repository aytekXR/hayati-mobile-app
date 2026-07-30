# ADR-038 — Test Information and Beta App Review are writable, so a session writes them

- **Status:** accepted (Session 055) — design-reviewed before the code, revised by that review
- **Supersedes:** nothing. Extends **ADR-037** (auto-assignment) and reuses **ADR-032**'s credential shape.
- **Related:** ADR-021 (release lane), ADR-024 (a gate with no vote), ADR-034 (never redden for a
  third party's schedule), ADR-036 (the domain the store listing points at).

## Context — the measurement that opens this

Session 054 shipped auto-assignment: every release build now attaches itself to the external
**Friends** group. It also wrote down, honestly, that this delivers nothing on its own — an
external tester receives an install only after Apple's **Beta App Review** passes, and review
cannot start until the **Test Information** page is filled in.

`tool/ci/testflight_testers.py` says of those gaps: *"every gap here is founder-owned copy that no
session can write for them."* Measured against the live app on 2026-07-28 (dispatch
`testflight-testers.yml --status`, run 30391917460):

```
app: ikimiz (com.beyondkaira.hayati) id=6794737016
beta groups:  'founders' (internal)  'arkadaslar' (external)  'Friends' (external)
builds:       110 VALID (2026-07-27)  109 VALID  3 VALID  2 VALID  1 VALID
beta app review readiness (external testers need this):
  MISSING - Test Information: review contact email is empty
  MISSING - Test Information: review contact first name is empty
  MISSING - Test Information: review contact last name is empty
  MISSING - Test Information: review contact phone is empty
```

Two things in that output change the picture the tool's comment assumes.

1. **The beta description and feedback email are NOT missing.** `review_readiness()` checks
   `betaAppLocalizations` for an empty description and an empty feedback email and reported
   neither, so both already exist. What is missing is exactly the four
   `betaAppReviewDetail` contact fields — and *none of them is copy*. They are a name, an email
   and a phone number.
2. **A VALID, unexpired build already exists** (110, the one carrying the real icon). The
   product is not waiting on a build. It is waiting on four form fields.

So the sentence in the tool is half right and the half it gets wrong is the expensive half. The
**facts** are founder-owned — a session cannot know the founder's phone number. The **writing** is
not: `betaAppReviewDetails` is a PATCHable resource on an API this repo already authenticates
against with credentials CI already holds. Leaving it as "go and click in App Store Connect" keeps a
human in a loop that exists only because nobody wired the last 20 lines.

## The decision

### D1 — The four contact fields are written by the tool, from **secrets**, never from dispatch inputs

`testflight-testers.yml` gains no `review_contact` text input. **This repository is public.**
`workflow_dispatch` inputs are recorded in run metadata and rendered in the Actions UI, which means
a dispatch input carrying the founder's personal mobile number publishes it — permanently, to
anyone, including after the run is deleted from view. That is not a hypothetical: the operator doc
would have told the founder to type it into a box.

The contact therefore arrives as four `release`-environment secrets:

```
ASC_REVIEW_CONTACT_FIRST_NAME
ASC_REVIEW_CONTACT_LAST_NAME
ASC_REVIEW_CONTACT_EMAIL
ASC_REVIEW_CONTACT_PHONE
```

`release` environment rather than repository scope, to match `ASC_KEY_ID`/`ASC_ISSUER_ID` (ADR-021's
REL-2 lesson) — only a job that declares `environment: release` resolves them, and both lanes that
need them already do.

**The tool never prints a value.** It prints the field name and one of `set` / `unchanged` /
`missing`. GitHub's own masking is a backstop, not the design: a secret that is never echoed cannot
be un-masked by a formatting accident.

**And that guarantee gets a TEST, not a promise** — the S020 rule, which the design review caught
this ADR asserting without. ADR-024 already holds the precedent: `slack_notify_test.sh` carries an
`assert_no_leak` sentinel for exactly this class. `testflight_testers_test.py` now runs the contact
write with four distinct sentinel values (one per field, so a leak names *which* field escaped) and
fails if any of them appears in the returned line — on the set path, the unchanged path, the
dry-run path, the create path, and in the failure text of a partial credential set. A mutant that
formats one value into the summary is killed by three checks.

### D2 — Writing the contact is a separate, explicit flag; it is NOT a side effect of assignment

`--set-review-contact` does the PATCH. Without it, `--assign-latest-build` behaves exactly as it
does today. The reason is the same one ADR-037 gave for keeping tester *creation* dispatch-only:
these are writes against the founder's live App Store Connect account, and the blast radius of "a
merge changed my review contact details" is not zero. The release lane may pass it (D4), because a
release is already an intentional act.

Fails **closed** and names the missing secret NAMES if any of the four are absent — the same shape
as `_token()`'s credential gate. A partial contact is worse than none: Apple accepts three of four
and the page still reads as incomplete, so the readiness check would keep failing for a reason the
log had already claimed to fix.

### D3 — Submitting for Beta App Review is dispatch-only, gated on readiness, and idempotent **without depending on a status code nobody here has measured**

`--submit-for-review` POSTs `betaAppReviewSubmissions` for the newest VALID build. Four guards:

- **It refuses if `review_readiness()` returns any gap.** Submitting an incomplete app to Apple
  earns a rejection that is recorded against the app and costs a round trip. Fail closed, name the
  gaps, exit non-zero.
- **It is never implied.** Submission is outward-facing — it puts the founder's app in front of an
  Apple reviewer. ADR-037 made assignment automatic on release because assignment is internal
  bookkeeping; review submission is not, and the asymmetry is deliberate.
- **Duplicate protection is a STATE READ, not an error code.** The first draft of this ADR said
  "Apple returns a conflict for a duplicate submission." The design review found 409 and 422 both
  reported in the wild and neither measured here, so that sentence was a guess wearing the clothes
  of a fact. It is replaced by reading `externalBuildState` *before* posting: a build already
  `WAITING_FOR_BETA_REVIEW` / `IN_BETA_REVIEW` / `READY_FOR_BETA_TESTING` / `BETA_APPROVED` is a
  no-op that says so. The error-shaped path survives only as a **backstop for the race**, and it
  demands **both** an error family (409 *or* 422) **and** a phrase — because either half alone
  would swallow an unrelated failure or miss the real one.
- **Export compliance is named, not discovered.** `MISSING_EXPORT_COMPLIANCE` and
  `IN_EXPORT_COMPLIANCE_REVIEW` make a submission certain to fail, for a reason that is one
  question in App Store Connect. The tool refuses and says which.

### D4 — The release lane passes `--set-review-contact`, and still does not submit

`release.yml`'s existing assignment step gains `--set-review-contact`. A release is an intentional
act by the founder, the secrets are already resolved in that job, and the whole point is that a
build should never sit blocked on a form. It does **not** gain `--submit-for-review`: see D3.

**And the contact write is NON-FATAL, which is the load-bearing half of D4.** Wiring D4 exposed a
defect in D2 that no reviewer saw because it did not exist until the two were combined: with the
flag passed on *every* release and `read_review_contact()` failing closed, a founder who has not yet
set the four secrets would abort the step **before the build assignment** — silently repealing
ADR-037's guarantee that every release build reaches the Friends group, while `continue-on-error`
kept the release green. The write now reports, continues, and still exits non-zero. A dedicated test
drives `main()` with the secrets unset and asserts the assignment POST still happens.

> **⚠️ Correction — 2026-07-30 (Session 056): D4 named the right failure and the wrong layer.**
>
> The paragraph above predicts, precisely, *"silently repealing ADR-037's guarantee that every
> release build reaches the Friends group, while `continue-on-error` kept the release green."* That
> is exactly what happened on the first release after these ADRs shipped (build 112, run
> `30502948416`) — **and not for any of the reasons defended against here.** The step never reached
> `read_review_contact()`, never reached the assignment POST, and never ran a line of
> `testflight_testers.py`: it died on `import jwt`, because `sign-upload` had no
> `actions/setup-python` and bare `pip` installed into a different interpreter than `python3`.
>
> So the non-fatal write and its dedicated test were both correct and both irrelevant. **The
> hardening was one layer too high.** Every guard here assumed the tool RUNS; nothing established
> that its dependencies were importable, and the hermetic test could not — it imports `jwt` from the
> dev box's own environment, which is precisely the S055 warning about a fake that agrees with your
> assumption, one level down in the stack.
>
> Fixed in `release.yml` (pinned interpreter + an explicit `import jwt, cryptography` assertion
> before the 25-minute Apple wait). **The transferable rule: when you harden a step against its
> failure modes, enumerate the ones BELOW your abstraction too — "the script raises" and "the script
> never started" are different failures, and only the first one has a test.**

### D7 — `--dry-run` covers both new writes, and says which

The review found dry-run semantics unstated for the two new operations — a gap that matters because
the workflow's `dry_run` input **defaults to true**, so the first thing anyone dispatching this will
do is exercise exactly that path. `--set-review-contact` prints `WOULD SET <fields>` and issues no
PATCH; `--submit-for-review` prints `WOULD submit` and issues no POST. Both directions are pinned by
tests, and a mutant that drops either guard is killed.

### D5 — The honest signal is `externalBuildState`, `--status` must print it, and the enum is **open**

Everything above is inputs. The **output** — the only thing that answers "can my friends install
it?" — is `buildBetaDetail.externalBuildState` on the assigned build. `PROCESSING`,
`READY_FOR_BETA_TESTING`, `IN_BETA_REVIEW`, `WAITING_FOR_BETA_REVIEW`, `BETA_REJECTED` and the two
export-compliance states are different worlds, and today the tool prints none of them; it prints
`processingState`, which is about Apple's *encoder*, not Apple's *reviewer*. A build can be `VALID`
forever and never reach a tester.

**The state is printed VERBATIM and never mapped through a closed enum.** The review's second
finding here was that the list above is not exhaustive — Apple has more states than five and has
added to them over time. A tool that switch-cases on a fixed list would read a state it did not know
as "not submitted" and submit a second time. So only two small sets are named in code, both for
reasons that fail *safe*: the four states that mean "already through the gate" (skip), and the two
export-compliance states that mean "certain to fail" (refuse). Everything else prints as itself and
is treated as not-yet-submitted, because the POST is itself the second guard.

This repo has now met the same defect three times — rules that were merged but never deployed
(#140), a `PROCESSING` build that would have reported a successful attach (ADR-037), and the
`store_metadata` case (S047). Each was a green claim about an input standing in for an unmeasured
output. `--status` prints `externalBuildState` and `internalBuildState` per build, and the
group membership of each build, so the claim and the fact are side by side.

### D6 — No vote, no schedule (ADR-024 / ADR-034 hold)

Nothing here gates a build. `testflight-testers.yml` stays `workflow_dispatch`. Apple's review queue
is a third party's schedule; a check that reddens `main` because a reviewer has not got to it yet is
the cries-wolf shape ADR-034 rejected. The release lane's assignment step remains non-blocking.

## What this deliberately does not do

- **It does not write the beta description or feedback email.** They are already set, and unlike a
  phone number they *are* copy — the founder's voice, in the founder's languages. A session
  overwriting them with an AI draft would be exactly the "helpful" write nobody asked for.
- **It does not touch the `arkadaslar` group.** A second external group exists alongside `Friends`,
  predating ADR-037. Consolidating them means deciding which real people belong where, and possibly
  emailing them again. That is a founder call, filed rather than guessed.
- **It does not deploy anything to `hayatiapp-prod`.**

## What the design review changed, recorded because the changes are the value

Five lenses × two verifiers, plus a completeness critic (38 agents, 0 errors; the critic's empty
finding list was checked against its transcript — 43 tool calls, real work, and it independently
found that `list_builds` does not fetch `buildBetaDetail`). Sixteen raw findings, five survived, one
was dropped to the per-lens cap and logged.

| Finding | What it changed |
|---|---|
| D1's no-leak guarantee had no mechanism | The sentinel test above (D1) |
| "Apple returns a conflict" was unmeasured | D3 rewritten around a state read; the error path demands two conditions |
| The state enum is not five values | D5: printed verbatim, only fail-safe subsets named in code |
| `--dry-run` unspecified for the new writes | D7, with both directions tested |
| ADR-038 missing from the index | Added to `docs/adr/README.md` |
| *(dropped to the cap, and true)* the `applinks:` entitlement blocks the NEXT release build | Not this ADR's to fix — recorded in `operator-expected.md`, and the reason build **110** is the one to ship |

## Consequences

- Four new secrets the founder sets once; after that, no human types a form field to unblock a
  release. The four facts remain founder-owned, which is correct — they are facts about the founder.
- One outward-facing action (`--submit-for-review`) stays behind a deliberate dispatch, with a
  readiness precondition that makes an avoidable rejection impossible.
- `--status` stops reporting only the encoder's opinion of a build and starts reporting the
  reviewer's.
