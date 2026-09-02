# ADR-072: A dry run that exits "published" is a false green — the plan reports what would CHANGE, and amends ADR-071 D7

- **Status:** Accepted — **and its implementation is deliberately deferred to #281.** The design review's two loudest findings were not about this document's reasoning but about its *place*: S097's objective was to run the dry run and put the plan in front of the founder, and writing a code change instead was **substituting the easy half for the assigned half**. The plan is now in `operator-expected.md` 6(b); the code is a filed issue
- **Date:** 2026-09-02 (Session 097)
- **Deciders:** session agent. **Still nothing is published** — operator **6(c)** is untouched and **6(b) now carries the plan** this run produced, which was the session's actual deliverable.
- **Related:** **ADR-071 D6/D7** (amended here — the dry run and the exit taxonomy), **ADR-047 D4** and **ADR-041** (the taxonomy both tools share), **ADR-070 D7** (the classifier this reuses to decide what "would change" means), **ADR-063** (exit 2 as a distinct state, and why a green that measured nothing is the failure this repo keeps paying for), issues **#278**, **#204**, lessons **65**, **77**, **133**, **150**

## Context

ADR-071 built `publish-store-metadata.yml` and said, in three places, that the
tool had never run against Apple and that its first real execution would be its
first real test. Session 097 ran it — `confirm` blank, so a dry run, writing
nothing — and it worked on first contact:

```
store metadata publish: DRY RUN — nothing was sent.
plan (4 request(s)):
  en-US: PATCH appInfoLocalizations — 3 field(s): name, privacyPolicyUrl, subtitle
  en-US: PATCH appStoreVersionLocalizations — 5 field(s): description, keywords, promotionalText, supportUrl, whatsNew
  tr: POST appInfoLocalizations — 3 field(s): name, privacyPolicyUrl, subtitle
  tr: POST appStoreVersionLocalizations — 5 field(s): description, keywords, promotionalText, supportUrl, whatsNew
store_metadata_publish exit=0  (0 published · 1 finding · 2 could not measure · 64 refused)
```

**Four of ADR-071's decisions are confirmed against reality by that output**, and
they are worth naming because they were assumptions when they were written:

* the credential path resolves the app, the editable version, the appInfo id and
  the existing localizations (D1, D3);
* **`en-US` is a `PATCH` and `tr` is a `POST`** — exactly the split D3 predicted,
  and independent confirmation that `en-US` localizations *exist* while holding
  nothing (ADR-070 D1.1) and `tr` does not exist at all;
* **`marketing_url` appears in neither plan.** Eight fields, not nine — D4's
  skip-empty rule, working against real data;
* `tr`'s app-info request is planned **before** its version request (D2).

## The defect it exposed, which is in the last line

**`exit=0`, and the run's own echo glosses 0 as `published`.**

Nothing was published. Nothing could have been: it was a dry run. Seventy-one
minutes earlier `store_metadata_audit.py` had exited **1** on the *same listing
state* (run 33674000392, 19:33Z; this one 20:44Z) because seven `en-US` fields
are empty and `tr` is absent — and nothing wrote to the listing in between, both
runs being read-only.

**Two tools, one listing state, opposite verdicts** — and the one that says
"fine" is the one that did nothing. That is recurring shape **1** in
`session-lessons.md`: *a green signal that measured nothing.* It is the shape
ADR-063 rebuilt `prod_pulse` around, the shape ADR-047 was written to end for
store copy, and it arrived in a tool written by the session that had just quoted
both.

⚠️ **It is not merely cosmetic.** The exit code is this tool's product; a lane
that consumed it would read "published" from a run that sent nothing, which is
precisely the sentence nine green releases sent.

## Decision 1 — `plan` marks which actions would CHANGE something, and reuses the auditor to decide

`plan` currently emits a write for every non-empty committed field, whether or not
Apple already holds that exact value. So a plan is non-empty on a *perfectly
published* listing, and "the plan is non-empty" cannot mean "there is work to do".

**Decision: every `Action` carries the subset of its fields that would actually
change**, computed with `store_metadata_audit.normalize`. No second comparison is
written: the auditor's normalisation is the one definition of "differs" in this
repo (ADR-047), and a second dialect is how two tools start disagreeing — which
is the defect this ADR exists to fix.

⚠️ **The data is not available today, and revision 1 said it was.** `main` reads
both resources and then **throws the attributes away**, keeping only
`{locale: id}` — `existing_version` and `_app_info_state` both do it, because ids
are all a *writer* needs. So *"computed against what the read already fetched"*
was false: there is nothing to compare against. The implementation must either
preserve those attributes or call `audit.published_locales`, which already merges
both resources into exactly the shape `audit_findings` wants. **The second is
cleaner and is what #281 should do** — the dry run stays read-only either way.
Caught by a review agent reading the extraction code rather than the prose.

**The write itself still sends every field, not only the changed ones**, and that
is deliberate. The publisher's job is *make it so*: if Apple silently drifts back,
re-sending the whole locale heals it, and a partial PATCH built from a comparison
would make the write depend on the comparison being right. **The comparison
decides what the report SAYS and what the exit code MEANS; it does not decide what
is sent.** Reporting and enforcing are different jobs and this ADR keeps them
apart.

## Decision 2 — A dry run's exit code answers "is the listing already what we committed?"

Amending **ADR-071 D7**, which defined the codes for a *write* and left a dry run
falling through to `EXIT_OK`.

⚠️ **This is an EXTENSION filling a gap, not the ADR-069 shape**, and the review
was right to press on it: ADR-069 amended ADR-061 D5 because D5's *premise* had
died. Nothing in D7 became false — **D7 simply never said what a dry run should
exit**, and the fall-through answered a question nobody had asked. Naming it an
"amendment" without that distinction would borrow ADR-069's authority for a much
smaller move.

| | a dry run means |
|---|---|
| **0** | nothing would change — the listing already carries every committed field |
| **1** | **FINDING** — `n` field(s) would change, or a locale does not exist yet |
| **2** | could not measure (unchanged: no credential, no editable version) |

**A dry run can no longer exit 0 while the listing is empty**, and the publisher
now agrees with the auditor about the listing they both read. That agreement is
the property worth having: **two instruments over one subject must not be able to
return opposite verdicts**, and if they do, one of them is lying to whoever reads
it next.

⚠️ **What this does NOT change: a WRITE that succeeds still exits 0**, and the
write path is untouched — it keeps deciding from the post-write read-back.

Revision 1 called that *"one rule, not two branches"*. **The semantics are one
rule — exit 1 when the listing differs from what we committed — but the
implementation is two, and saying otherwise would have sent an implementer
looking for a shared code path that should not exist.** They differ in *when*
they compare: a dry run compares **before** the attempt, a write compares
**after**. Same question, two moments, and the moment is the whole reason the
write path needs a read-back at all (ADR-071 D5).

## Decision 3 — The echo line stops calling 0 "published"

`publish-store-metadata.yml` prints
`(0 published · 1 finding · 2 could not measure · 64 refused)`. On a dry run the
word **published** is false about every branch of it. The gloss becomes
`0 nothing to do · 1 finding · 2 could not measure · 64 refused`, which is true of
both modes.

Small, and it is the half of the defect a reader actually sees: the exit code is
read by machines and the gloss beside it is read by the founder.

### 3.1 — And the step must stop VOTING, or the lane goes permanently red

The workflow runs `code=$?` then `exit "$code"`. Under D2 a dry run over today's
listing exits **1**, so **every dry run would fail its step and redden the run** —
until someone publishes, which is a founder decision that may never come.

**That is the cries-wolf failure with its sign flipped.** ADR-047's whole Context
is nine runs that were green and said nothing; a lane that is red on every run
says nothing just as reliably, and faster, because a human learns to skip it.

**Decision: the publish step gets `continue-on-error: true` and the lane has NO
VOTE** — the ADR-047 D4 shape, one workflow over, for the same reason. The verdict
travels in the report and the gloss; the run's colour stops pretending to carry
it. **A finding is a finding and a red build is a demand**, and this tool is only
ever entitled to the first.

## Consequences

**Positive**

- The two store-metadata tools can no longer disagree about the same listing.
- The design is reviewed **before** anyone writes it, and inherits three
  corrections it would otherwise have been written wrong against.
- The dry run's verdict now carries information: **1 means there is copy to
  publish**, which is exactly the state operator 6(b) is being asked about.
- The report gains the number the founder actually needs — *how much would
  change* — without printing a byte of Apple's own text (ADR-070 D7.4 stands).
- ADR-071's *"its first real execution is its first real test"* is discharged, and
  the test found something.

**Negative / accepted trade-offs**

- **A dry run over an unpublished listing now exits 1, i.e. non-zero, forever
  until someone publishes.** That is intended — it is a finding — but a future
  lane consuming this must not treat non-zero as broken. The workflow's own gloss
  says so, and the tool has no vote on anything else.
- **The comparison is now load-bearing for the exit code** and was previously
  load-bearing for nothing. If `normalize` is wrong, the publisher is wrong in the
  same direction as the auditor — a shared failure, which is the price of having
  one definition instead of two, and the trade this ADR takes deliberately.
- The write still sends unchanged fields. Idempotent, slightly wasteful, and the
  alternative couples the write to the comparison.
- **Nothing here is built.** #281 carries it. This ADR is a reviewed design and a
  record of what the tool's first real execution found — which was the session's
  actual job (ADR-071 said the first run would be the first test; it was).

## Implementation record (added when #281 was built)

`tool/ci/store_metadata_publish.py` + **11 new self-tests (14 → 25, all
registered; 62 → 96 checks)**. **Mutation-checked: 21 mutants, 20 killed by a
NAMED assertion**; the one survivor is recorded, not fixed — locale iteration
order is presentational.

**Verified against Apple**, which is the point of the exercise: run
`33686025994`, dispatched from the branch, `confirm` blank —

```
  en-US: PATCH appInfoLocalizations — 3 field(s), 2 would change: name, privacyPolicyUrl, subtitle
  ...
15 field(s) would change — the listing does not yet carry what this ref committed.
store_metadata_publish exit=1 (0 nothing to do · 1 finding · 2 could not measure · 64 refused)
```

**exit 1, and the run is green** — the publisher and the auditor now agree about
the listing, and the lane no longer votes. ⚠️ And `en-US`'s app-info row reads
**2 of 3 would change**: the third is `name`, the one field the store already
carries, which is exactly what ADR-070 D6 inferred from the auditor's silence
about it. **Two instruments, independently, on live data.**

### 3.2 — What the build found, and it was this ADR's own shape again

**Making the step `continue-on-error` means EVERY exit is a green job** — and
`REFUSED` (64) and `COULD NOT MEASURE` (2) both returned *before* the summary was
written. A green job with an empty summary is *"nothing happened"* to anyone
glancing at it: **the fix for one false signal introduced two more.** Every exit
now writes a summary, pinned by tests and two mutants.

⚠️ **And D2's *"the write path is untouched"* is about the exit-code rule, not
about the lane.** `continue-on-error` masks a **failed write** too, which the
review's completeness critic was right to name. That is accepted and is now said
out loud: **this lane has no vote in either mode** — ADR-047 D4's rule is that a
store-copy finding must never redden a build, and it does not become a different
rule because the tool wrote something. What makes it safe is 3.2's other half:
the verdict is in the summary on **every** path, so nothing depends on the colour.

## Review record

**14 agents, 4 probes × 2 verifiers + a completeness critic.** `agents_error`
**0**; `agents_empty_result` **0**; **8 findings**, 6 REAL / 10 REFUTED across the
verifier votes.

⚠️ **The most important finding was not about the reasoning; it was about the
scope.** `resume-prompt.md` gave S097 one objective — *run the dry run and put the
plan in front of the founder so operator 6(b) becomes answerable* — and this
document was the session answering an easier question it had just discovered.
Both blocking findings said so, and they were right: **the plan is the deliverable
and a defect found on the way to it does not replace it.** `session-rules.md` §2
already says where such a defect goes: `gh issue create`, not into the diff.

The three technical corrections above (the attributes `main` discards, the
permanently-red lane, and *"one rule, not two branches"*) are folded in so #281
starts from a design that is right rather than one that reads well.
