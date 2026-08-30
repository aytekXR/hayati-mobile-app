# ADR-067: the index that fell eighteen behind gets a lint, not another promise

- **Status:** Accepted — revision 1 (2026-08-30, Session 091), written and committed **before** the code
- **Date:** 2026-08-30 (Session 091)
- **Deciders:** session agent (a docs-consistency lint in the established `tool/*_lint.dart` family; no credential, no deploy, no runtime code)
- **Related:** **ADR-020 D6** (the store-metadata lint this one copies in shape and exit taxonomy), **ADR-025 D8** (a *declaration* is discipline, **not** a CI gate — the decision this one deliberately departs from, and why), **ADR-023** (`docs/legal/` ↔ `app/assets/legal/` byte-sync under a drift test — the precedent for a document-versus-filesystem check), **ADR-029** (numbers are claimed by the earliest-created record, so a renumbering can leave a gap), issue **#248**

> **Review status.** Written before the code (`session-context.md` §5 item 1,
> lesson **115**). The design pass has not run yet.

## Context — measured 2026-08-30

```
$ ls docs/adr/*.md | grep -oE '/[0-9]{3}' | tr -d '/' | sort -n | …
count: 66  min: 1  max: 66   gaps: none   duplicate numbers: none
$ … parse the index table of docs/adr/README.md …
index rows: 48    rows pointing at a missing file: none
files with NO row: ['049','050','051','052','053','054','055','056','057',
                    '058','059','060','061','062','063','064','065','066']
```

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

### Finding 3 — the index is load-bearing, and the last two sessions prove it

S089 leaned on ADR-012 D3, ADR-033, ADR-053, ADR-059 and ADR-063 D8. S090 leaned
on ADR-041, ADR-063 D2/D4 and ADR-064 D2b. **None of those five is in the
index.** Both sessions found them by knowing they existed. A session that does
not know re-derives the decision, and re-deriving a decision is how a repo ends
up with two of them — which is the failure ADR-029's renumbering note already
records happening once, for numbers rather than content.

### Finding 4 — numbers may legitimately have gaps, so contiguity is NOT the check

There are no gaps today, and a lint that asserted contiguity would pass. It would
also be **wrong**: ADR-029 records numbers being claimed by the earliest-created
record, with a renumbering when two sessions draft the same one — and a
renumbering abandons a number. Asserting `max == count` would turn a correct
renumbering into a red build and teach the next session to renumber *around* the
lint. The check is a **bijection between the files that exist and the rows that
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
  stop finding things — and this one's whole job is to notice an absence.

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
