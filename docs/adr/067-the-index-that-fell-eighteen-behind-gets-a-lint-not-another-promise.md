# ADR-067: the index that fell eighteen behind gets a lint, not another promise

- **Status:** Accepted — **revision 2** (2026-08-30, Session 091), after the design pass; still **before** the code
- **Date:** 2026-08-30 (Session 091)
- **Deciders:** session agent (a docs-consistency lint in the established `tool/*_lint.dart` family; no credential, no deploy, no runtime code)
- **Related:** **ADR-020 D6** (the store-metadata lint this one copies in shape and exit taxonomy), **ADR-025 D8** (a *declaration* is discipline, **not** a CI gate — the decision this one deliberately departs from, and why), **ADR-023** (`docs/legal/` ↔ `app/assets/legal/` byte-sync under a drift test — the precedent for a document-versus-filesystem check), **ADR-029** (numbers are claimed by the earliest-created record; its own renumbering **preserved** contiguity — see Finding 4, which revision 1 got backwards), issue **#248**

> **Review status.** Revision 1 was written and committed **before** the code
> (`session-context.md` §5 item 1, lesson **115**). **The design pass has now
> run** — 4 lenses × 2 independent verifiers + a completeness critic, **27 agents
> (including the 18 that drafted the index rows), 0 errored, 0 empty results, 0
> skipped**; **3 lenses considered-empty, 0 failed-empty**; 2 lens findings + 1
> critic finding, **all 3 surfaced, 0 refuted by both, 0 dropped unverified**.
>
> ⚠️ **The critic found revision 1 asserting something false in the direction
> that flattered its own argument**, which is the failure this repo cares about
> most. Finding 3 said *"none of those five is in the index"* — of the seven
> unique ADRs the last two sessions leaned on, **three (012, 033, 041) ARE
> indexed** and four are not. Re-measured before accepting it: `for n in 012 033
> 041 053 059 063 064; do grep -qE "^\| \[$n\]" docs/adr/README.md; done` →
> in, in, in, missing, missing, missing, missing. The argument survives on the
> four; the sentence did not.
>
> ⚠️ **And the governance lens found Finding 4's justification was false
> history.** Revision 1 said ADR-029's renumbering *"abandons a number"*. It did
> not: `ls docs/adr/028-*.md docs/adr/029-*.md` shows **both exist** — the
> collision partner merged as 028 and the renumbered record took 029, so
> contiguity was preserved. The design choice stands; the reason it was given did
> not.

## Context — measured 2026-08-30

```
$ ls docs/adr/*.md | grep -oE '/[0-9]{3}' | tr -d '/' | sort -n | …
count: 66  min: 1  max: 66   gaps: none   duplicate numbers: none
$ … parse the index table of docs/adr/README.md …
index rows: 48    rows pointing at a missing file: none
files with NO row: ['049','050','051','052','053','054','055','056','057',
                    '058','059','060','061','062','063','064','065','066']
```

*(Taken **before this record existed**. Once it lands the counts are 67 files and
19 unindexed — this ADR is the nineteenth, and it indexes itself along with the
other eighteen. Said out loud because a number in a document is a claim about a
moment, and this one's moment is stated: lesson **133**.)*

**Eighteen.** Not the "nine" in #248's title, not the "sixteen" of the S089
prompt, not the "seventeen" of the S090 one — each of those was true when
written and none was ever wrong in a way anyone noticed, which is the whole
problem.

### Finding 1 — the failure is one-directional, and that tells you what to build

Every one of the 48 rows points at a file that exists. **Nothing has ever gone
stale in the other direction.** The drift is entirely *files that arrived
without a row*, which is exactly what you would predict: writing an ADR is the
session's own work and it happens under deadline; updating a shared index is the
step after the work feels finished.

A guard therefore has to fail on **file-without-row**. It should also fail on
**row-without-file** — that has never happened, and asserting it costs one line
and forbids a dangling link forever — but the asymmetry is worth recording so a
later reader knows which half is load-bearing and which is insurance.

### Finding 2 — this has been "the cheap next task" for three sessions

It was priority 1 in the S089 prompt, priority 1 in the S090 prompt, and named
again as *"next, not now"* in between. Each deferral was individually correct: a
production outage and a lying instrument both outrank a documentation index.
**Three correct deferrals still produce an index nobody can trust**, and the
next session's reasoning will be the same as the last three.

**A process that depends on remembering, at the end, after the interesting part,
is not a process.** ADR-025 D8 decided the opposite for golden declarations —
*discipline, not a CI gate* — and that was right for a judgement call a machine
cannot make. This is not a judgement call. It is a set comparison.

### Finding 3 — the index is load-bearing, and the last two sessions half-prove it

S089 leaned on **ADR-012 D3, ADR-033, ADR-053, ADR-059** and **ADR-063 D8**;
S090 on **ADR-041**, **ADR-063 D2/D4** and **ADR-064 D2b** — seven unique
records. **Four of the seven are not in the index**, measured:

```
$ for n in 012 033 041 053 059 063 064; do
    printf "%s " $n; grep -qE "^\| \[$n\]" docs/adr/README.md && echo IN || echo MISSING; done
012 IN   033 IN   041 IN   053 MISSING   059 MISSING   063 MISSING   064 MISSING
```

⚠️ **Revision 1 said "none of those five is in the index", and that was false
twice over** — the count and the claim. The completeness critic caught it. It is
recorded here rather than quietly corrected because of *which direction* it was
wrong in: it overstated the evidence for the thing this ADR wanted to do. A
sentence that flatters its own argument is the one to re-measure first
(lesson **123**).

**The corrected version is still the argument.** Four decisions that two
consecutive sessions actually relied on are absent from the document whose job is
to say those decisions exist — and both sessions found them only by already
knowing. A session that does not know re-derives the decision, and re-deriving a
decision is how a repo ends up with two of them.

### Finding 4 — contiguity is not the check, and revision 1 gave a false reason for that

There are no gaps today (001–067, measured), and a lint asserting contiguity
would pass right now.

⚠️ **Revision 1 justified skipping it by claiming ADR-029's renumbering
"abandons a number". It does not.** `ls docs/adr/028-*.md docs/adr/029-*.md`
shows **both records exist**: the concurrent session's PR #95 merged as 028 and
the renumbered record became 029, so the collision *preserved* contiguity. The
governance lens caught it, and it matters because the sentence was offered as
recorded history rather than as a hypothesis.

**The decision is unchanged and here is the reason that survives measurement.**
Two of them:

1. **Contiguity is not a property the index needs.** The index answers *"has
   anyone decided this?"* A hole in the numbering harms nobody; an unindexed file
   harms every session looking for precedent. A guard should assert the property
   it exists for, not a neighbouring one that happens to be true — otherwise the
   first legitimate exception makes the guard the thing that is wrong.
2. **A gap is still reachable, just not by the path revision 1 named.** ADR-029's
   own rule — *the earlier-created number wins, renumber yours* — leaves a hole
   whenever the collision partner is **abandoned rather than merged**. That has
   not happened. It is a hypothesis, and it is now labelled as one.

So the check is a **bijection between the files that exist and the rows that
exist**, and nothing about the sequence.

## Decision 1 — a lint, in the family that already exists, not a new mechanism

`tool/adr_index_lint.dart` plus `tool/adr_index_lint_test.dart`, wired into the
`quality` job as the two steps every other lint in this repo uses (*self-tests*,
then *the lint*). It copies `store_metadata_lint.dart` deliberately:

* **pure `dart:io`, no package imports**, so it runs in `quality` before any
  `pub get` — the property that makes the existing lints cheap;
* **exit codes 0 / 1 / 64** (ADR-020 D6's taxonomy): clean, violations, and
  *usage or input error* — a missing `docs/adr/` directory is **64**, never 0,
  because "I could not check" must never read as green (ADR-041's rule, one
  instrument over);
* **its own self-tests**, because a lint with no test is a lint that can silently
  stop finding things — and this one's whole job is to notice an absence;
* **an entry in `docs/test-suite.md` §2**, naming the file, the bijection it
  asserts and what its self-tests cover. Every other lint in this family has one,
  and ADR-029's own review established the rule: *a guard recorded only in its
  own ADR is a guard the next session will not know to keep.* The design review
  raised this and one verifier refuted it as unmandated; the adjudicator was
  right that a consistent, load-bearing convention is not "unmandated" merely
  because no document spells it out (lesson **137**).

## Decision 2 — what it asserts, and what it deliberately does not

**Asserts:**

1. **Every `docs/adr/NNN-*.md` has exactly one row** in the index table. This is
   the failure that has happened eighteen times.
2. **Every row points at a file that exists**, by resolving the link target
   relative to `docs/adr/`. Insurance, per Finding 1.
3. **The row's number matches the file it links to** — a row reading `[051](…)`
   whose link resolves to `052-…md` is a copy-paste that reads correctly and
   sends the reader to the wrong decision.
4. **No number appears twice** in the index.
5. **Every row has exactly THREE cells.** ⚠️ **This assertion was not in revision
   2 — it was found while building the lint, because the shipped index already
   violated it.** Row 042 carries an unescaped `|` inside a code span
   (`` `{kind:'ok'|'profile-missing'}` ``), and GitHub-flavored markdown does
   **not** let a code span protect a pipe in a table: that row has been rendering
   with its summary truncated and *"Accepted"* pushed into a fourth column since
   it landed. **A row that silently loses its Status is the same class of defect
   as a row that is missing** — the reader gets a confident-looking table with a
   fact quietly removed. Escaping it (`\|`) is the fix, and the lint's own row
   for this ADR needed the same fix, because I wrote an unescaped pipe into the
   sentence describing the defect and the lint caught me.

**Does NOT assert:**

* **Contiguity** (Finding 4).
* **Anything about the summary text.** A row's value is a human judgement about
  what a decision *means*, and a lint that demanded a minimum length would be
  satisfied by eighteen sentences of padding — worse than eighteen absences,
  because padding looks like coverage. **The lint guards presence; a review
  guards meaning.** That division is the honest one and it is stated so no later
  session mistakes a green lint for a good index.
* **Status accuracy.** The index carries a Status column; whether a record is
  `Superseded (by-NNN)` is a fact about two documents' contents, and a wrong
  status is a content error of the class above.

## Decision 3 — the eighteen rows are written, not generated

They are summaries of what each decision *is*, in the voice the existing 48 rows
use — dense, specific, and about the decision rather than the file. **A generated
row (title + status) would satisfy the lint and defeat the point**, because the
titles are already visible in `ls`; the index exists to answer *"has anyone
decided this?"* without opening 66 files.

Each of the eighteen is checked against its own ADR before it lands. Where a
record's own Status line says something the index must carry — `Proposed`, or a
supersession, or *"closes #NNN"*, or *"ships unarmed"* — the row carries it,
because those are the parts a reader is looking for when they scan.

## Decision 4 — the lint votes, on every push

Not path-filtered to `docs/adr/**`. The failure mode is a **new file arriving
without a row**, and a path filter on the ADR directory would catch that — but
the same push almost always carries the code the ADR describes, so the filter
buys nothing and adds a way to be wrong. It is milliseconds of `dart:io` in a job
that already runs a dozen lints.

**It votes**, unlike ADR-025 D8's golden declaration, and Finding 2 is the whole
argument: a discipline that has been correctly deferred three times in a row is
not a discipline. There is no third-party asymmetry here (ADR-034's reason for
advisories being non-voting) — an unindexed ADR is our own omission, always
actionable, and fixable in the same push by the person who caused it.

## Consequences

* **The next session that writes an ADR cannot merge without indexing it**, which
  is the point and is also a small tax on every ADR-bearing PR. That tax is one
  row, paid by the person holding the context to write it well — as against
  eighteen rows paid later by someone who has to read eighteen documents first.
* **The index becomes usable for precedent-finding again**, which is what
  Finding 3 says both recent sessions needed and neither had.
* **A renumbering still works** (Finding 4), and a gap in the sequence stays a
  legal state.
* **The lint will eventually fail on a legitimately-in-flight PR** — an ADR
  committed before its code, which is this repo's own rule, is committed in the
  same push as its index row or the build is red. That is intended: the index row
  is part of writing the ADR, not part of finishing the feature.
* **A green lint does not mean a good index** (Decision 2), and the eighteen rows
  this session writes are reviewed as prose, not as a diff that compiles.

## Alternatives rejected

| | why not |
|---|---|
| **Generate the index from the files** | The rows are summaries, not metadata. Generation gives you `ls` with a link, and the index exists precisely because `ls` does not answer *"has anyone decided this?"* Decision 3. |
| **A declaration in the PR template, like ADR-025 D8's goldens** | That is the mechanism that produced eighteen misses. D8's reasoning holds for a judgement a machine cannot make; a set comparison is not one. |
| **Assert contiguity (`max == count`)** | Passes today and is wrong tomorrow: ADR-029 records renumbering, which legitimately abandons a number. It would teach sessions to renumber around the lint. Finding 4. |
| **Lint the summary text (min length, must mention the decision)** | Satisfiable with padding, and padding is worse than absence because it looks like coverage. The lint guards presence; the review guards meaning. |
| **Path-filter it to `docs/adr/**`** | Buys nothing — the ADR and its code ship together — and adds a way for the guard to be silently absent. Decision 4. |
| **Fix the eighteen and skip the guard** | Exactly what three previous sessions would have done, and the reason this ADR is numbered 067 instead of 049. |

## What the design pass changed

4 lenses × 2 verifiers + a completeness critic, run alongside the 18 agents that
drafted the index rows: **27 agents, 0 errored, 0 empty results, 0 skipped**;
**3 lenses considered-empty, 0 failed-empty**; 2 lens findings + 1 critic
finding, **all 3 surfaced, 0 refuted by both, 0 dropped unverified**.

| from | finding | what changed |
|---|---|---|
| **critic** (blocking) | Finding 3's *"none of those five is in the index"* — three of the seven are indexed, and there were seven not five | Finding 3 rewritten around the measured four, with the overstatement recorded rather than tidied away |
| lens *governance* (major) | Finding 4 cited ADR-029's renumbering as *"abandons a number"*; **028 and 029 both exist**, so it preserved contiguity | Finding 4 keeps the decision and replaces the reason with two that survive measurement — and labels the gap-is-reachable half as a hypothesis |
| lens *governance* (minor) | no `test-suite.md` entry specified, while every other lint in the family has one | added to D1 |

⚠️ **The minor finding was refuted by one verifier and upheld by the other**, and
the aggregation surfaced it because either is enough. The refuter's ground was
that no rule mandates a `test-suite.md` entry. That is lesson **137**'s exact
shape: a convention every sibling follows is not optional merely because it is
unwritten.

⚠️ **One number this pass reported about ITSELF was wrong, and it was mine.** The
harness reported *"1 lens failed-empty"*. No lens failed: the adversarial lens
wrote *"CONSIDERED-empty"* and its prose contained the word **blocked** —
describing a workflow this design blocks on purpose — and the classifier
substring-matched it. A status word that also occurs in ordinary prose is not a
status marker. Recorded as lesson **142**; the true distribution is 3
considered-empty, 0 failed-empty.

**What this pass could not check.** No lens ran `dart` (forbidden to sub-agents),
so nothing here verifies the lint compiles or that its self-tests pass — the
built-diff pass and the diff's own runs settle that. And no lens can check
whether the eighteen rows are *good*, which is Decision 2's stated division:
the lint guards presence, the review guards meaning.

## What the BUILT-DIFF pass changed, and the row I got wrong myself

4 lenses × 2 verifiers + a completeness critic + **19 agents each checking one
drafted row against its own ADR**: **28 agents, 0 errored, 0 empty results, 0
skipped**; 2 lenses considered-empty, **0 failed-empty**; 2 lens findings, both
real to both verifiers, 0 refuted; 0 critic findings. And **5 of 19 rows came
back not-accurate**, which is the number that matters, because Decision 2 says in
as many words that the lint cannot check this and a review must.

| from | finding | what changed |
|---|---|---|
| lens *lint-correctness* | `unescapedPipes` used a **single-character lookback**, so `\\|` — an escaped BACKSLASH followed by a real separator — read as an escaped pipe. The lint reported three cells where GFM renders four: green over a broken row | counts the backslash **run** now; even (including zero) means separator. Mutation-checked: reverting reddens the new named check |
| lens *lint-tests* (major) | the **duplicate-files** branch had no test at all — a mutant deleting it passed all 22 checks | a fixture with `001-a.md` and `001-b.md`; the mutant now reddens two named checks |
| row **049** | cited *"lesson 79"*, which **appears nowhere in ADR-049** (`grep -c 79` → 0) | replaced with what the ADR actually says: the 37-hour **#219** shape and the runtime link **ADR-042 D5** left unverified |
| row **050** | credited the *lint* with admitting its own limit; the ADR makes that statement, and deliberately places it in the ADR | reworded to say where the admission lives |
| row **066** | said the note survived *"in two places"*; ADR-066 says **one** of two copies survived | corrected |
| row **067** — **mine** | *"priority 1 in three consecutive session prompts"*; ADR-067's own Finding 2 says priority 1 in **two** prompts and *"next, not now"* in between | corrected in the row **and** in the lint's header comment, where I had written the same inflation |

⚠️ **Row 067 is the one worth keeping in the record.** I wrote it myself,
immediately after writing a Review-status box that criticises revision 1 for
overstating in its own favour — and then overstated in its own favour, in three
places (the row, the lint's header comment, and the commit message). Nothing
about knowing the failure mode prevented it. The only thing that caught it was an
agent reading the ADR and the row side by side.

**One row finding was REJECTED, and the reason is recorded rather than the
finding silently dropped** (lesson **135**): row **058** was called `overstated`
for describing `docs/legal/proposed/` and `legal_proposal_test.dart` in the
present tense, on the ground that ADR-058 calls them *"a SPECIFICATION of what
will be built"*. That was true when ADR-058 was written; both now exist
(`ls docs/legal/proposed/*.md` → 4 files; the test file is present, and S089 ran
it). The index describes the repo as it is, and the row's Status cell already
carries the not-landed fact the scanning reader needs.

**What this pass could not check.** Whether the other fourteen rows are *good* —
dense enough, pointed at the right thing — as opposed to merely true. That is
Decision 2's stated division and it stays a human judgement.
