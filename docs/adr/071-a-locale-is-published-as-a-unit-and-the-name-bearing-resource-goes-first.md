# ADR-071: A locale is published as a unit, the resource Apple can refuse goes FIRST, and the dry run is the deliverable

- **Status:** Accepted — revision 2. **Revision 1 designed a tool that could not run**: it refused the tool a workflow, and the App Store Connect credential exists nowhere but GitHub secrets. The design review caught it. §Review record.
- **Date:** 2026-09-02 (Session 096)
- **Deciders:** session agent. **Nothing is published by this ADR.** It builds the mechanism; the permission is operator **6(b)** and **6(c)**, both open.
- **Related:** **ADR-070 D3** (which split this out and called it the recommended fix) and **D7** (whose classifier named the hazard D4 refuses to cause, and whose `COMMITTED IS EMPTY` verdict D5 has to reason about), **ADR-047 D3/D4/D6** (the two-resource split, the exit taxonomy, and the *"an unexercised instrument is the thing it is guarding against"* argument this ADR inherits), **ADR-020 D5 rev 2 / D8** (empty URLs are optional; all store copy is review-gated), **ADR-032 D6** (why a write to this listing is dangerous), **ADR-041 D5** (the typed-confirmation dispatch guard), **ADR-048** (measure → act → read back, and the read-back votes), **ADR-019** / `appid_capability_enable.py` (the wire-level confirm literal), issues **#278**, **#204**, lessons **65**, **77**, **78**, **103**, **133**, **150**

## Context

`fastlane store_metadata` runs `deliver(skip_binary_upload: true, force: true)`.
`deliver` dies inside `verify_available_version_languages!` — **before** the
upload phase — because Apple refuses to create the `tr` localization under this
app name. **One refused locale therefore aborts the run for every locale**, which
is why `fastlane/metadata/` has never been published at all (ADR-070 D2).

Re-measured today from merged `main` (run **33674000392**, exit 1):

```
audited App Store version: 1.0 state=PREPARE_FOR_SUBMISSION
  - en-US: description differs … — PUBLISHED IS EMPTY — published 0 vs committed 1454 code points
  … all seven the same …
  - tr: NOT PUBLISHED — no localization exists on the editable App Store version
```

**The listing is empty, not stale** (ADR-070 D1.1). `name` is the only field ever
set. That matters twice: a first write cannot destroy anything, and the
*"skip, never blank"* rule in **D4** is being written before the case it protects
can arise — the only time that is cheap.

### What this session cannot do, said before the decisions rather than after

`ruby`/`fastlane` are absent from this box; pointing this tool at production needs
operator **6(b)** (ADR-020 D8's store-copy review gate, never discharged) and a
dispatch needs **6(c)**. **Every decision below is exercised against fakes and
none against Apple.** That is a constraint that shapes D2, D3 and D6, and it is
why D5 exists.

⚠️ **And one thing this session verified about itself, because revision 1 got it
wrong:** there is **no App Store Connect credential on this machine** —
`~/.appstoreconnect` does not exist, no `AuthKey_*.p8` is anywhere on disk, and
`ASC_KEY_ID` is unset. The three `ASC_*` values live only in GitHub secrets
(`testflight-testers.yml`'s own header says so, and `architecture.md` §9 is the
rule). **A tool with no workflow therefore cannot run at all**, which is what
revision 1 designed and D1 now corrects.

## Decision 1 — A Python tool over the REST API, dispatched from a workflow, with the DRY RUN as the deliverable

ADR-070 D3 enumerated five options and recommended this one; only the conclusion
is repeated here.

What makes it right rather than convenient: **it is the only option this
repository can test.** `store_metadata_audit.py` already reads both resources
through a working credential path, `testflight_testers.py::_call` already takes a
method and a body, and `_fake_call` is a scripted responder the audit's own tests
use. A fastlane-side filter would first execute against the founder's live listing
under `deliver(force: true)`.

### 1.1 — Revision 1 said "no workflow at all". That was wrong, and the reason is worth keeping

Revision 1 argued that *a dispatchable workflow is a button, and a button whose
permission has not been given is a button someone presses*, and concluded the tool
should run "by hand where the credential lives".

**There is no such place.** The credential is a GitHub secret; a session cannot
export it, and no local `.p8` exists (Context). Revision 1 therefore designed
something with **no execution path whatsoever** — not a cautious tool, an inert
one. The reasoning had the shape of safety and the effect of futility, and it
survived until an outside reader checked where the credential actually lives.

**It also inverted what the dry run is for.** Operator 6(b) asks the founder
whether AI-drafted English copy may be published. The thing they need in order to
answer is *exactly what would be written* — which is the dry run. **A workflow is
not the risk to be avoided here; the dry run is the deliverable, and a workflow is
how it reaches the founder.**

**Decision: `publish-store-metadata.yml`, dispatch-only, with three guards.**

1. **Dry run is the default.** The workflow's write input defaults to off, and the
   tool's default is a plan.
2. **Writing requires a typed literal**, not a checkbox — the ADR-041 D5 shape
   (typing the project id) crossed with `appid_capability_enable.py`'s
   `--confirm ENABLE`. A boolean can be flipped by habit; a string has to be
   typed on purpose.
3. **No `push` trigger, ever.** Nothing merges its way into a store write.

*(Attribution corrected by the review: the phrase "dispatch-only or explicitly
gated, like `deploy-functions.yml`" is **`resume-prompt.md`'s acceptance criterion
6**, not ADR-070 D3. Revision 1 credited it to the ADR and then departed from it,
which made a departure from a session's own acceptance look like a departure from
a decision. It is neither now: the criterion is met.)*

**Screenshots are out of scope**, explicitly: `store_screenshots` is a separate
fastlane lane on purpose (`fastlane/README.md`, ADR-020 D8) because images and
copy have different readiness. This tool touches metadata only.

## Decision 2 — The unit of isolation is the LOCALE, and the name-bearing resource is attempted FIRST

This is the decision the issue is about, and the obvious version of it is wrong.

The obvious version is *"isolate per (locale, field) so nothing blocks anything"*.
The two resources are split by ADR-047 D3:

| resource | fields |
|---|---|
| `appStoreVersionLocalizations` | `description`, `keywords`, `whatsNew`, `promotionalText`, `supportUrl`, `marketingUrl` |
| `appInfoLocalizations` | **`name`**, `subtitle`, `privacyPolicyUrl` |

**`name` is on the second one, and `name` is the field Apple refuses.** Under
per-resource isolation a `tr` run would write the version localization and then
fail to create the app-info localization, leaving a Turkish localization carrying
a description and **no name**. Whether Apple renders that, rejects it at
submission, or ignores it is a vendor question this session cannot answer.

**Decision: a locale is published as a unit, and `appInfoLocalizations` is
attempted first.** If it is refused, the version localization for that locale is
**not attempted**, the locale is a finding, and every *other* locale proceeds.

### 2.1 — The alternatives, and why not

| alternative | why not |
|---|---|
| **per-(locale, field) isolation** | produces the named-less Turkish locale above |
| **rollback**: write, and on failure DELETE what landed | a compensating delete is itself a write that can fail, and it would be the only `DELETE` this repo issues to Apple — more blast radius than the case justifies, given ordering already covers the *known* failure |
| **probe before write**: ask Apple whether the name is acceptable | no validation endpoint is known to exist, and inventing one from a guess is the fixture-from-its-own-subject shape |
| **version-first, accept partial success** | lands `tr`'s description at the cost of the state above. Rejected — but see 2.2, because the reverse partial state is not fully excluded |

### 2.2 — Ordering is not a transaction, and revision 1 said it was

Revision 1 wrote that *"ordering does the work that a transaction would"*. **Both
verifiers refuted the finding against that sentence and the finding is applied
anyway** (lesson **107**): ordering covers exactly one failure — the refusal on
`appInfoLocalizations` — and covers it completely, because nothing has been
written when it fires. It does **not** make the run atomic.

The residual, which the review's completeness critic named and revision 1 did not:
**`appInfoLocalizations` succeeds and `appStoreVersionLocalizations` then fails.**
The locale now has a name and no description. That state is possible, it is not
prevented, and the honest handling is to **report it as a finding naming both
halves** — *"tr: app info written, version localization failed: <Apple's words>"*
— and exit 1. A partial write that reports as a whole success is the failure this
whole issue is made of.

**What D2 costs, plainly:** if `tr`'s name is refused, `tr`'s description does not
land either, even though it probably could have. **What it does not cost:**
`en-US` still publishes, which is the entire defect #278 exists to fix.

## Decision 3 — Create and update are different verbs, the appInfo ID is a prerequisite, and the refusal is quoted verbatim

`en-US` exists on the version and needs `PATCH`. `tr` does not exist and needs
`POST` — and `POST` is what Apple refuses, which is why the bug looks as it does.
A writer that only knew `PATCH` would report `tr` as *"could not find the
localization to update"* and never surface the real message, which is the one
diagnostic operator 6(a) needs.

⚠️ **Creating an `appInfoLocalization` needs the editable appInfo's id, not the
app's.** `store_metadata_audit.py::app_info_localizations` already resolves it
(`/v1/apps/{app_id}/appInfos` → pick the editable state → its localizations), and
the writer reuses that resolution rather than re-deriving it. Revision 1 did not
mention this and would have been written against the wrong parent.

**The refusal is captured and reported verbatim.** `_call` raises `AscError`
carrying the HTTP status and Apple's response body; that string is the finding.
ADR-047 D1's rule about never keying on Apple's wording governs *deciding*, not
*quoting for a human*.

⚠️ **What is assumed rather than known, separated out** (the review's vendor-shape
lens, and lesson **78**):

| known | assumed |
|---|---|
| `_call` performs POST/PATCH with a JSON body and surfaces the error body — the repo does this for `betaGroups` and friends, and `testflight_testers_test.py` carries raw ASC error JSON | that `appStoreVersionLocalizations` / `appInfoLocalizations` follow the same create-with-relationship, update-by-id pattern |
| Apple refuses the `tr` name — **through fastlane**; issue #204's quote is a `Spaceship::UnexpectedResponse`, a Ruby wrapper | what the REST API returns for that same refusal. **Nobody here has seen it** |

The tool is therefore written so that **an unrecognised error shape is still a
finding with Apple's bytes in it**, rather than something it tries to parse.

## Decision 4 — An empty committed field is SKIPPED, never sent

`marketing_url.txt` is empty in both locales and ADR-020 D5 rev 2 made it
optional. ADR-020's own review recorded that `deliver` skips absent and empty
values rather than uploading them, and this tool keeps that behaviour: **a field
whose committed file is empty is not written.**

The rule is not about `marketing_url`. It is about **`COMMITTED IS EMPTY`**
(ADR-070 D7), where the repository would blank a field the founder typed by hand.
Today the case has no instances because the listing is empty (Context).

⚠️ Consequence, recorded rather than implied: this tool **cannot clear a field**.
Emptying a file is not how you delete store copy, and D5.1 makes sure that gap is
visible rather than silent.

## Decision 5 — It reads back, and the read-back compares only what it MEANT to write

Straight from ADR-048: measure → act → **read back**, and the read-back votes.
After writing, the tool re-reads both resources and runs
`store_metadata_audit.audit_findings` over the result.

Two reasons, the second being the one that matters here:

1. Apple's write is not the proof; Apple's *state* is. A `204` says the request
   was accepted, not that the listing says what we sent.
2. **Nothing in this tool has ever run against Apple** (Context). The read-back is
   what makes its first real execution self-checking rather than self-reporting —
   a tool whose only evidence is its own success messages is the shape that let
   nine releases go green (lesson **65**).

### 5.1 — The reuse is not `audit_findings(expected_locales(...), actual)`, and revision 1 implied it was

**The design review's one blocking finding.** `audit_findings` compares **every**
committed file to Apple. D4 deliberately skips empty ones. So a straight reuse
would take a field the writer *correctly declined to write* and report it as a
**`COMMITTED IS EMPTY`** finding — failing the read-back, and exiting 1, for a
write that did everything it should have.

**Decision: the writer builds the `expected` map it passes to `audit_findings`
from the fields it actually attempted** — the committed set minus the empty ones,
minus any locale it skipped under D2. The read-back then asks exactly one
question: *did what I tried to write land?* Anything else is a different question
and belongs to the audit, which already asks it on every release.

⚠️ **And the gap that creates is stated rather than hidden.** A field that is
empty in the repo and non-empty at Apple is invisible to this tool's read-back by
construction. It is **not** invisible overall: `store_metadata_audit.py` reports
it as `COMMITTED IS EMPTY` every time it runs, which is what that verdict was
built for one ADR ago. **The writer's silence is covered by the auditor's
noise**, and the two tools are deliberately not given the same job.

## Decision 6 — Dry run by default; a wrong confirm is REFUSED, not a quiet dry run

Two gates guarding two different mistakes, and revision 1 conflated them.

* **No `--confirm` at all → a dry run.** Deliberate: the safe path is also the
  lazy path, and the plan is the deliverable (D1.1).
* **`--confirm` present but not the literal → REFUSED, and it is not a dry run.**
  Revision 1 said any wrong confirm was "not an error — it is a dry run". The
  review checked the precedent: `appid_capability_enable.py` returns
  `EXIT_REFUSED` with *"REFUSED (nothing was sent)"*. It is right and revision 1
  was wrong — **passing a wrong literal is evidence of intent to write**, and
  answering a typo with a cheerful dry run tells someone who meant to publish that
  they did. Absence means "I am looking"; a wrong value means "I tried and
  fumbled", and those must not print the same thing.

A wrong literal exits **64** — see D7. **The dry run is not a stub.** It resolves the app, reads both resources, works
out create-versus-update per locale, and prints the exact request set — every step
but the write. ADR-047 D6 applied one tool over: an instrument only exercisable by
the event it exists for is the thing it guards against, and here the dry run is
the *only* exercise available.

**No `--force`, no `--all`, no flag meaning four things** (ADR-048 on
`firebase deploy --force`). The locale set comes from `fastlane/metadata/` and
nowhere else (ADR-047 D1): a tool deriving what to publish from what is already
published could not publish the thing that is missing.

## Decision 7 — The exit taxonomy, and the line 2 stops at

The taxonomy ADR-041 set and ADR-047 D4 restated. `grep -l 'could not measure'
tool/ci/*.py` lists **eight** tools using it today; this is another — revision 1
said *"the fourth"*, which was simply wrong (lesson **133**).

| | |
|---|---|
| **0** | every expected locale is published and the read-back agrees |
| **1** | FINDING — a locale was refused, a locale is half-written (2.2), or the read-back disagrees |
| **2** | COULD NOT MEASURE — no credential, no editable version, or an API error **before any write was attempted** |
| **64** | REFUSED — a `--confirm` was given and it was not the literal. Nothing was sent |

**64 is deliberately OUTSIDE the taxonomy**, and it is the repo's existing
usage-error code (`adr_index_lint.dart`'s `exUsage`, `coverage_gate.dart`). A
fumbled literal is a statement about the *command*, not about the listing, and
giving it 1 would put it in the same bucket as *"Apple refused a locale"* —
which a reader would then have to disambiguate by reading prose. `appid_capability_enable.py`'s
precedent returns its own `EXIT_REFUSED` for the same reason; this reuses the
idea and not the number, because that tool's 1 is free and this tool's is not.

**A refusal is 1, not 2.** *"Apple said no"* is a measurement.

⚠️ **And 2 stops the moment the first write is attempted**, which revision 1 left
undefined and the review's critic caught. After a write, an API error — including
the version ceasing to be editable because the founder submitted it mid-run — is a
**finding**, because the listing may now be in a state nobody chose. Reporting
that as *"could not measure"* would describe a changed listing as an unobserved
one, which is the exact confusion ADR-063 built exit 2 to prevent.

## Implementation record

`tool/ci/store_metadata_publish.py` + `store_metadata_publish_test.py` (13 tests,
59 checks), registered in `ci.yml`'s `quality` job — an unregistered test is a
green run that proves nothing. The lane is
`.github/workflows/publish-store-metadata.yml`: `workflow_dispatch` only, no
`push` trigger, `confirm` an empty free-text box, `concurrency` with
`cancel-in-progress: false` because cancelling a run halfway through its locales
manufactures the D2.2 partial state on purpose.

**Mutation-checked: 13 mutants, 12 killed by a NAMED assertion.** Every decision
above has one pointed at it — the ordering (D2), a refusal ending the run, a
refusal continuing into its own locale's second resource, a partial reported as
a plain refusal (D2.2), empty fields being sent (D4), the read-back expecting the
*planned* rather than the *written* (D5.1), the create hung off the app instead
of the appInfo (D3), always-create-never-update (D3), a dry run writing (D6), a
wrong confirm quietly downgraded (D6), refusals not voting (D7), and `render`
dumping the committed values (ADR-070 D7.4).

⚠️ **Two flaws in the mutation set itself, found by running it and recorded
rather than quietly fixed:**

* the first ordering mutant **changed nothing semantically** — it swapped a
  condition rather than the order, and both conditions were true for the fixture,
  so it "survived" a test that would in fact have caught a real reordering. A
  mutant that applies and changes nothing prints the same green as a guard that
  works (lesson **109**).
* `refusal-aborts-everything` initially died **by an exception**, not by an
  assertion: mutating the `break` to a `raise` crashed the harness before any
  check ran. The test now catches an escaping exception and turns it into a named
  failure, so the property it advertises is the thing that catches the mutant
  (lesson **76**, and S095 hit the same shape twice).

**The one surviving mutant is recorded, not fixed:** reversing the *locale*
iteration order changes the report's order and nothing else. Locale isolation is
order-independent by construction, so a test pinning it would be pinning
presentation. `sorted()` stays for a stable report; nothing depends on it.

## Consequences

**Positive**

- The defect #278 names is fixed where it occurs: one refused locale no longer
  stops another from publishing.
- The `tr` refusal becomes a **verbatim diagnostic** for operator 6(a) instead of
  a Ruby backtrace inside a `continue-on-error` step.
- **The dry run answers operator 6(b)** — the founder can see exactly what would
  be published before deciding whether it may be.
- Everything but the HTTP verb is exercised on Linux against fakes.
- The `COMMITTED IS EMPTY` hazard ADR-070 D7 named is closed before it can fire,
  and the blind spot that creates is handed to the auditor rather than ignored.

**Negative / accepted trade-offs**

- **It has never run against Apple, and it ships that way.** D5 is a compensation,
  not a proof. Its first real execution is its first real test — said out loud,
  because ADR-047 spent seventeen days in exactly this position while reading as
  finished.
- **D2 costs `tr`'s description** when the name is refused. Chosen over a
  half-published locale nobody here can observe or undo — and 2.2 records that the
  *reverse* partial state is possible and merely reported, not prevented.
- **The REST refusal shape is unseen** (D3). The tool is built to quote what it
  cannot parse.
- **When Apple eventually accepts the Turkish name, this tool will simply
  succeed** where every prior run reported a finding, with nothing announcing the
  change. The auditor is where that would be noticed, and it already pins the
  locale set as a deliberate change-detector (ADR-047's last line). Recorded so
  the next reader does not expect an alarm here.
- A `PATCH` that 404s because a localization vanished between the read and the
  write is exit 1, not a retry-as-`POST`: the state changed under the tool, and
  guessing which verb it now wants is how a writer creates a duplicate.

## Review record

A pre-code design review ran against revision 1: **39 agents, 8 probes × 2
independent verifiers (a refuting skeptic and a governing-docs adjudicator), plus
a completeness critic.**

| | |
|---|---|
| `agents_error` | **0** |
| `agents_empty_result` | **0** — every lens found something; none was empty, considered or otherwise |
| raw findings | **15**, plus **7** from the critic |
| surviving | **10** | 
| refuted by both | **5** — one applied anyway (2.2) |

**The finding that mattered was structural, not textual:** revision 1's D1 refused
the tool a workflow, and the ASC credential exists nowhere else, so the design had
no execution path at all. It took an outside reader running `ls ~/.appstoreconnect`
to see it — the seventh consecutive session in which the worst error in an ADR was
caught by someone checking a claim against its source rather than by a lens reading
the prose.

Also applied: the blocking read-back semantics (5.1); the appInfo-id prerequisite
(D3); the confirm-literal behaviour, which contradicted the precedent it cited
(D6); the partial-locale residual (2.2); the exit-2 boundary (D7); the alternatives
table (2.1); screenshots declared out of scope (D1); and **two wrong claims of the
kind this repo keeps making** — *"the fourth tool to use the taxonomy"* (it is at
least the ninth; eight exist) and an acceptance criterion attributed to ADR-070 D3
when it came from `resume-prompt.md`.
