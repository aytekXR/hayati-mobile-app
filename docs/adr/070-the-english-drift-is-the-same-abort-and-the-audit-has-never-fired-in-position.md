# ADR-070: The English drift is not a second defect — it is the same abort, and the audit built to see it has never fired in the position it was built for

- **Status:** Accepted — revision 2 (the design review found twelve real defects in revision 1; §Review record)
- **Date:** 2026-09-02 (Session 095)
- **Deciders:** session agent. **Two founder decisions are named below and neither is taken here** — the Turkish display name (unchanged since #204 was filed) and, separated out for the first time, whether never-reviewed English store copy may be published at all. A third thing is **asked** rather than decided: one authorization, per `session-context.md` §7.
- **Related:** **ADR-047** (the instrument this re-measures — its D2 finding is confirmed unchanged 17 days on), **ADR-020 D5/D8** (the empty-URL ratchet and the store-copy review gate; both are described wrongly in the repo today — D6), **ADR-032 D6** (the store name, and why a drifted `name.txt` is dangerous), **ADR-035** (which moved that name to lowercase and left four prose copies behind), **ADR-029 D2 / ADR-032 D4** (the *no blind edits* bound — **distinguished, not borrowed**, in D3), **ADR-041** (the exit taxonomy, and the precedent for refusing to transfer a precedent), issue **#204**, new issue **#278**, lessons **64**, **65**, **69**, **71**, **78**, **103**, **107**, **133**, **141**

## Context

`resume-prompt.md` handed S095 #204 with three questions and an instruction to
establish which half of it is a session's before designing anything: **is the
audit armed and running · does the release lane still hide the failure · is
`en-US`'s seven-field disagreement a separate, unblocked defect.** Lesson **145**
says to open the ADR that owns the objective first. ADR-047 owns it, and it
turns out to have answered less than the prompt assumed and more than it claimed.

### What was measured, and with what

Every number below carries the command that produced it (lesson **133**). All
were run on **2026-09-02**.

| claim | instrument | result |
|---|---|---|
| the store listing | `gh workflow run testflight-testers.yml -f store_metadata_audit=true` → run **33661830831** | **exit 1**, 8 findings |
| production liveness | `python3 tool/ci/prod_pulse.py --from-firebase-cli` | **exit 2** — could not measure |
| push registration | `python3 tool/ci/push_delivery_probe.py --from-firebase-cli` | **exit 2** — could not measure |
| last release run | `gh run list --workflow release.yml` | **2026-08-09T15:00:26Z** (run 31319947579) |
| when the audit landed | `git log -S store_metadata_audit -- .github/workflows/release.yml` | **482f92f4, 2026-08-16** |
| the notifier's channel | `gh secret list` | five secrets; **no `SLACK_WEBHOOK_URL`** |
| repository visibility | `gh repo view --json visibility` | **PUBLIC** |

⚠️ **The two probes answered `2`, not `1`, and the difference is not about
production.** S094 measured `1` on both. They answer `2` here because
`~/.config/configstore/firebase-tools.json` does not exist — the firebase CLI is
no longer installed on this box, along with `flutter`, `dart`, `java` and
`ruby`. That is an **instrument outage, not a production reading**, and ADR-063
built the exit-2 state precisely so the two could not be confused. It is carried
into `operator-expected.md` and `session-context.md` rather than into this
decision; nothing below rests on it — except **D3**, where it is one input among
several rather than, as revision 1 had it, the whole argument.

## Decision 1 — Re-measure rather than inherit, and record that nothing moved

Run 33661830831, in full:

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

**The same eight fields as ADR-047 D2's 2026-08-16 reading.** Two fields still
agree and are still not findings: `name` and `marketingUrl`. That `name` agrees
is load-bearing evidence in **D6**.

Nothing moved because nothing could have: no release has run since 2026-08-09,
and a release is the only thing that writes this listing.

## Decision 2 — The `en-US` disagreement is NOT a separate defect. It is the same abort, and "fix en-US" is not a task that exists

The prompt asked whether the seven-field English mismatch is *"a separate,
unblocked defect"*. **It is neither.**

`deliver` dies inside `verify_available_version_languages!`, which runs **before**
the upload phase — ADR-047 quotes the backtrace from the release logs
(`upload_metadata.rb:575` from `:103`). One refused locale therefore aborts the
run **for every locale**, so nothing has ever been written to this listing by the
lane. The English listing is not *drifted*; it is **the copy that was typed by
hand into App Store Connect, never once overwritten**.

⚠️ **Naming the instrument** (lesson **78**): that backtrace is ADR-047's
measurement, read from the release logs of builds 112–119. This session did
**not** re-derive it, and could not — `ruby` and `fastlane` are absent from this
box. What this session measured independently is the *consequence*: the audit's
own output, which shows all seven en-US fields differing **plus** `tr` absent,
i.e. exactly the shape "no locale was ever written" predicts, and not the shape
"en-US published once and then drifted" would produce. That is corroboration, not
proof, and it is written as corroboration.

The competing history was checked and does not survive: `fastlane/README.md` and
ADR-032 D5 record that before S047 the lane aborted *even earlier*, at
`ensure_release_credentials!`, so **store metadata was never once delivered** on
that path either. Two sequential abort sites, no successful publication between
them.

**What follows, and it is the answer the prompt wanted:**

* There is nothing wrong *in* `fastlane/metadata/en-US/`. No file needs editing.
* There is no engineering task called "fix the English listing". The only thing
  that publishes English copy is a `deliver` run that gets past locale
  verification.
* Therefore #204 has **one** engineering cause and **two** founder-owned
  consequences — which is D4.

## Decision 3 — The decoupling fix is DEFERRED to its own slice and an authorization is ASKED FOR. It is not refused on §7, and the no-blind-edits precedent is distinguished rather than borrowed

The fix follows straight from D2: make `store_metadata` publish the locales it
*can* publish, so one refused locale stops taking the other down with it.
**This session does not build it.** Revision 1 called that a refusal and rested it
on two grounds that the design review broke; both are corrected here rather than
quietly restated.

### 3.1 — What revision 1 got wrong

**`session-context.md` §7 does not forbid this.** Its heading is *"Things a
session must never do **without asking**"*, and revision 1 used it as a
prohibition while conceding in its own next paragraph that it is not one. That is
arguing around a rule rather than through it. **The correction is to ask.** The
founder is already being handed D4; a third line costs them one more sentence, and
it is now **operator item 6(c)**: *authorize one release-lane dispatch, or
decline it.* A refusal that never asked was the weakest part of revision 1.

**The no-blind-edits precedent does not transfer as written.** ADR-029 D2 and
ADR-032 D4 both protected a path that **demonstrably worked** — ADR-032 D4's own
words are *"The lane demonstrably works **with** the step… the cost of being wrong
is a broken release the founder cannot debug"*. The `store_metadata` lane does
**not** work and never has (D2). The risk calculus is therefore different in the
direction that matters: **a failed decoupling attempt leaves a lane that has never
published still not publishing** — the status quo — whereas a failed signing edit
breaks a lane that ships binaries. ADR-041 set the precedent for saying this out
loud rather than assuming transfer, when it refused to carry ADR-034's asymmetry
into its own case. The bound still has *some* force here — the failure mode is a
`deliver(force: true)` write to a live listing, not merely a red job — but it is
**one input, not the argument**.

### 3.2 — The options, all of them, and what happens to each

| # | option | disposition |
|---|---|---|
| 1 | filter locales inside the fastlane lane (stage a metadata dir, point `deliver(metadata_path:)` at it) | **not now** — first execution would be against the live listing; see 3.1's residual risk |
| 2 | `deliver`'s `run_precheck_before_submit` | **rejected on inspection** — `precheck` inspects metadata against App Store guidelines. It does not create localizations, so it cannot exercise `verify_available_version_languages!`, which is the code path that aborts. The `store_screenshots` lane already sets it `false` and says why |
| 3 | run fastlane in a container on this box | **not available** — `ruby`, `bundler` and `fastlane` are absent, and installing a toolchain to exercise one lane is a slice of its own |
| 4 | a per-locale writer over the App Store Connect REST API | **the recommended fix, filed as #278.** The resources are already mapped and already read by `store_metadata_audit.py` (ADR-047 D3), so it is testable on Linux with the fakes that file already has |
| 5 | ask the founder to authorize one dispatch | **done** — operator item 6(c) |

**Two verifiers refuted the claim that option 4 is "downstream of D4(b)", and they
were right**: building a writer and pointing it at production are separate
decisions, and the first needs no permission. Revision 1's sequencing argument is
withdrawn. What remains is the honest reason, which is smaller and is a rule
rather than a risk: **`session-rules.md` §5 — one coherent objective per session,
and an objective that overflows gets sliced rather than stretched.** A metadata
writer with its own fakes, its own mutation checks and its own outward-facing
failure modes is not a corner of this session. It is **#278**, filed so it is not
a remainder deferred into prose.

## Decision 4 — There are TWO founder decisions, they are separable, and `operator-expected.md` currently presents one

Operator item 6 says the Turkish listing needs a display name that is not taken.
It mentions the English mismatch as a fact and asks nothing about it.

| | decision | who | blocked by the other? | decidable when |
|---|---|---|---|---|
| **(a)** | a Turkish App Store display name Apple will accept | founder | no | now |
| **(b)** | may the committed English copy be **published at all** | founder | no | **after D7's report is put in front of them** |
| **(c)** | authorize one release-lane dispatch to exercise a fix | founder | no | now |

**(b) has been invisible because (a) has been failing in front of it**, and it is
**askable today** — but revision 1 called it *"decidable today"*, which contradicts
the ADR's own admission that nobody knows which side of the drift is better.
⚠️ Both verifiers refuted that finding; **it is applied anyway.** Lesson **107** is
that both verifiers can refute a real finding and the aggregation rule will not
save you, and on re-reading, the two sentences plainly disagree. (b) becomes
decidable when someone runs
`gh workflow run testflight-testers.yml -f store_metadata_audit=true` and shows
the founder the report — which is why D7 exists, and the chain is stated so a
reader can check it.

### 4.1 — Which document governs the English gate, because two disagree

The review found a contradiction revision 1 had walked past:

* `fastlane/README.md` §*Native review: PENDING* — *"Every store string in **both
  locales** is AI-drafted and awaits native review"*, listing `name`, `subtitle`,
  `description`, `keywords`, `promotional_text`, `release_notes` for **en-US and
  tr**. ADR-020 **D8** is the decision behind it: *all* store copy.
* `docs/operator-expected.md` item 8 — *"**Native TR/AR review** of every
  user-visible string"*. English is absent.

**They are about different things, and the resolution is not that one is wrong.**
Operator item 8 is about **in-app strings in the languages that need a native
speaker** — Turkish and Arabic; English needs no *native* reviewer here. ADR-020
D8 is about **store copy**, and its concern is not nativeness but that the copy is
**AI-drafted and has never been read by a human who owns the product**. The
English store copy sits under the second and under **no line of the operator
checklist at all**.

So D4(b) is not the discharge of an existing operator item; it is the discovery
that the item was never written. **It is written now**, as operator item 6(b),
and the wording deliberately says *review*, not *native review* — the two are
different gates and collapsing them is how this got lost.

## Decision 5 — The audit is ARMED and has NEVER FIRED IN POSITION. Say so, rather than inherit ADR-047's confidence

The prompt asked whether the audit is *"armed and running"*. **Armed. Not
running.**

* The step exists in `release.yml`, publishes a job output, and the notifier reads
  it as `EXTRA_FINDINGS` — all verified by reading, all true.
* It landed in **482f92f4 on 2026-08-16**. The last release ran **2026-08-09**.
  **`release.yml` has not executed once since the step was added**, so ADR-047's
  remedy has never run in the event it was built for.
* **It has executed exactly twice, ever**, both through the ADR-047 D6 side door:
  run **31949645300** (2026-08-16, the run ADR-047 D2 cites) and run
  **33661830831** (this session). Revision 1 said three. ⚠️ The neighbouring
  dispatch **31947442886** (2026-08-16 12:34) does **not** carry the step at all —
  its step list runs 1–5 then jumps to the `Post` steps — so it was a different
  input on the same workflow.
  *How that was settled matters* (lesson **65**): `gh run view <id> --log` returns
  **zero lines** for both August runs and 250 for this session's, and a zero-line
  log reads exactly like "the step never ran". The control proves the instrument
  works and the emptiness is expiry, not absence; the count was then taken from
  `gh run view --json jobs` step lists, which are still served.
* Its terminal channel is unarmed: `gh secret list` shows five secrets and
  **`SLACK_WEBHOOK_URL` is not among them**. The `⚠️ CI passed, with findings`
  headline that ADR-047 D5 built — the entire remedy for *"nine releases went green
  and Slack said nothing"* — would today reach no Slack channel. **It is not
  invisible**: the audit writes `GITHUB_STEP_SUMMARY` unconditionally and that
  needs no secret. Unpushed, not unreadable.

None of that is a defect in ADR-047; the instrument does what it says. It is a
correction to how much has been *proven*: ADR-047 D6 argued that an unexercised
instrument is the thing it is guarding against, and then the instrument spent 17
days exercised only through the door built to compensate for that. **The claim "a
green release can no longer mean the copy silently did not land" is true by
construction and untested in the event.**

*One small correction to ADR-047's Context, recorded rather than tidied away:* the
ADR listed *"the step had no `id`"* as constraint 1, and the step now has one
(`deliver_store_metadata`). Nothing reads it —
`grep -rn deliver_store_metadata .github/ tool/ fastlane/` returns the definition
and nothing else. The remedy that shipped was the audit's job output, not the step
outcome. The `id` is a live affordance and is harmless; it is **not** evidence
that constraint 1 was addressed, and this record says so because a future reader
counting remedies would otherwise count two.

## Decision 6 — Four prose copies say the store name is `İkimiz`. It is `ikimiz`, and one of the four is in the binding-invariants table

Found by reading D1's output: **`name` is not among the eight findings**, so App
Store Connect's `en-US` name matches `fastlane/metadata/en-US/name.txt` under a
comparison that folds whitespace and **not** case (`store_metadata_audit.py`'s
`normalize`, which calls only `.replace("\r\n", "\n").strip()`). The file is six
bytes, `69 6b 69 6d 69 7a` — `ikimiz`, lowercase.

Measured against that:

| where | says | actual |
|---|---|---|
| `docs/session-context.md` §6, ADR-032 row | *"`fastlane/metadata/*/name.txt` is pinned to **İkimiz**"* | `release_lane_lint.dart`'s `pinnedStoreName` is `'ikimiz'` |
| `fastlane/README.md` §Founder-owned naming | *"**App Store name** is **`İkimiz`**"* | the live listing holds `ikimiz` (D1) |
| `fastlane/README.md` §Founder-owned naming | *"**`CFBundleDisplayName`** is **`İkimiz`**"* | `app/ios/Runner/Info.plist` is `ikimiz` |
| `docs/implementation-plan.md` M6.3 supersession note | *"The store name is now **İkimiz**"* | as above — **found by the review, not by this session** |

**ADR-032 D6 and ADR-035 are both innocent** — D6 recorded the founder choosing
`İkimiz`, and ADR-035 then renamed the app to lowercase `ikimiz` on purpose,
moving the files, the lint pin, the plist and the listing. What ADR-035 did not
move is these four sentences. Lesson **141**: a correction is finished when every
*copy* of it is gone, and revision 1 found three of four while quoting that lesson.

### 6.1 — What the danger actually is, corrected

Revision 1 called this *"lesson 64 with a live detonator"*. **That was
overstated, and the correction is the interesting part.**

`tool/release_lane_lint.dart`'s `checkStoreName` compares every `name.txt` against
`pinnedStoreName` and runs on every PR (`ci.yml`) and in `release.yml`. **A
session that edited `name.txt` alone would be stopped by a red build.** The
detonator is defused for the careless edit.

It is not defused for the **diligent** one. The lint's own violation message reads
*"Change the pin in `tool/release_lane_lint.dart` and every `name.txt` in one
commit (ADR-032 D6)"* — which is exactly what a session reconciling to
`session-context.md` §6's invariant would then do. Change both, and the lint goes
green, and `deliver(force: true)` renames the founder's live listing on the next
release. **A guard cannot protect against someone obeying the wrong instruction,
because the instruction tells them to move the guard too.** That is the precise
claim, and it is narrower and more useful than revision 1's.

All four copies are corrected in the same commit as this ADR.
**`docs/adr/README.md`'s row for ADR-020 and ADR-032's own body are left alone**:
they are records of what was decided then, and ADR-035 supersedes them. Only
documents speaking in the **present tense about the current state** are changed.

### 6.2 — Two stale sentences in the same section of `fastlane/README.md`

* It documents the lint as
  `dart tool/store_metadata_lint.dart --allow-empty-urls tr en-US`. **CI has not
  passed that flag since `6d1f7368` (2026-07-28)**: `ci.yml` and `release.yml`
  both run it bare. (`git log -S allow-empty-urls -- .github/workflows/ci.yml`
  returns exactly two commits: `43bc52fe` added the flag, `6d1f7368` removed it.)
* Its §*URLs ship empty* says *"`privacy_url.txt` and `support_url.txt` are EMPTY
  in both locales"*. They hold `https://ikimiz.beyondkaira.com/privacy` and
  `https://ikimiz.beyondkaira.com/` in both locales — filled in that **same
  commit** `6d1f7368`. Only `marketing_url.txt` is still empty, and ADR-020 rev 2
  made that one optional on purpose.

⚠️ **One review finding is declined here, with its reason** (`d6-1-drive-by`, and
both verifiers also refuted it): the two bullets are not two corrections. ADR-020
D5's ratchet *is* the `--allow-empty-urls` flag, and it was pulled in the same
commit that filled the URLs; the flag sentence and the empty-URL sentence went
stale together, as one fact. Splitting one of them into a separate issue would
file half a correction. `privacyPolicyUrl` and `supportUrl` are also two of D1's
seven English findings, so this section is stale about two of the exact fields
#204 is about.

## Decision 7 — The audit will report WHAT KIND of difference it found and WHAT VERSION it read, and will not print the store's text to do either

D4 asks the founder a question — *may the English copy be published* — that the
instrument cannot currently help with. `description differs from description.txt`
is true and is not decision-grade: it does not distinguish a trailing-punctuation
edit from a wholly different paragraph, and it says nothing about which side is
longer.

### 7.1 — The classification

Each differing field gains a verdict, two lengths, and the offset of the first
difference. Checked in order, first match wins:

| verdict | means |
|---|---|
| `PUBLISHED IS EMPTY` | the store holds nothing for a field the repo fills |
| `COMMITTED IS EMPTY` | the reverse — a release would **erase** a field the founder filled |
| `WHITESPACE-ONLY` | equal once every whitespace run collapses to one space |
| `CASE-ONLY` | equal once case-folded as well |
| `SUBSTANTIVE` | none of the above |

The two empty cases are split rather than folded into *"one side is empty"*
because they point in opposite directions, and under `deliver(force: true)` that
is the difference between a fix and a regression.

⚠️ **`WHITESPACE-ONLY` needs a helper `normalize()` cannot supply**, and that is
worth naming because reusing `normalize()` here would be the obvious wrong move:
it trims edges and folds CRLF **and deliberately preserves interior whitespace**,
which is how a real copy change stays visible. The classifier gets its own
collapse, and `normalize()` is left alone.

Lengths are **code points**, matching `store_metadata_lint.dart`, which counts
`content.runes.length` — a byte count would make every Turkish field look longer
than Apple thinks it is, and Dart's `String.length` (UTF-16 code units) would do
the same to emoji. Verified by reading the lint, not assumed from the convention.

⚠️ **`CASE-ONLY` carries a stated caveat rather than a silent one.** It uses
Python's locale-independent `str.casefold()`, which maps `İ` (U+0130) to `i` +
U+0307 and therefore does **not** fold `İkimiz`/`ikimiz` together. That is
deliberate — a Turkish-locale fold would be wrong for a tool that also reads
`en-US` — and it means a name difference of exactly the kind D6 is about reports
as `SUBSTANTIVE`. For this tool's purpose that is the safe direction: it
over-reports rather than dismissing a live-listing rename as a casing nit.

### 7.2 — The one-line verdict stops dropping most of the findings

`one_line()` is what crosses the job boundary into the notifier (ADR-047 D5), and
on today's real data it is **wrong by omission**: with 8 findings — one missing
locale and seven stale fields — it returns *"8 finding(s) — tr not published"* and
never mentions English at all. The reader of the one channel ADR-047 built to
carry this signal would learn that Turkish is missing and nothing else.

It now names both halves and tallies the classification, still on one line and
still free of newlines. The words `not published` and `stale` are kept, because
the existing self-tests assert on them and because they are the right words.

### 7.3 — The audited version is named in the report

The audit selects an editable App Store version and then discards which one it
found. That cost this session a claim it could not check: D7's disclosure
argument below rests on the listing being an **unsubmitted draft**, and the only
evidence for that is `store_metadata_audit.py`'s own docstring recording
`appStoreState=PREPARE_FOR_SUBMISSION` on **2026-08-16**. `EDITABLE_STORE_STATES`
also contains `DEVELOPER_REJECTED`, `REJECTED` and `METADATA_REJECTED`, so exit 1
today is consistent with several states, and this session **did not re-measure
it**. The report now prints the version string and `appStoreState` it audited —
one line, no credential, no extra request — so the next reader does not inherit a
17-day-old premise the way this one did.

### 7.4 — What it deliberately does NOT do: print the published text

The obvious richer output is a diff of both sides. **Refused.** This repository is
**public** (`gh repo view` → `visibility=PUBLIC`), the audit's output lands in a
public Actions log and step summary, and the store's copy belongs to a version
that is not on sale. The committed side is already public in this repo; the
published side is not, and publishing it as a side effect of a diagnostic is not
this tool's decision to make.

**The bound is stated rather than overstated:** a length and a first-difference
offset *are* a small disclosure about that text, and 7.3 is the reason the
premise itself is now measured rather than assumed. They are accepted as
proportionate; *"no information about the published copy leaves this tool"* would
be a false claim and is not made. A founder who wants the text has App Store
Connect, where it already is.

## Consequences

**Positive**

- #204's remaining question is answered rather than re-inherited: the English
  drift is not a second defect (D2), so the issue has one cause and two owners.
- A founder decision that was invisible behind another one is named, and the gate
  behind it turns out never to have had a line in the operator checklist (D4.1).
  It has one now.
- The instrument gains the two things it was missing for that decision: what kind
  of difference, and what it was looking at (D7).
- A stale invariant is removed from the one table sessions are told is binding,
  with an accurate account of what it could actually cause (D6).
- The deferral in D3 is recorded **as a slice with an issue number** rather than
  as a refusal, and the authorization it needs is **asked for** rather than
  assumed unavailable.

**Negative / accepted trade-offs**

- **Nothing about the listing changes, and cannot.** Both halves of #204 remain
  founder-owned; #204 stays open. This ADR moves it from *"one blocked decision"*
  to *"two decisions and one authorization, none of them blocked by Apple"*.
- **D7 is built without its consumer.** The classification will next be seen on a
  manual dispatch, and in position only on the founder's next release. It is a
  better report of a state that is not changing — worth building because it is the
  input D4(b) is waiting on, and worth saying plainly that it changes nothing on
  its own.
- **The Dart and shell halves of this session's verification ran only in CI**, not
  locally: the toolchain is gone from this box and only a standalone Dart SDK was
  restored, enough for the three `dart:io` lints and nothing else. The Python half
  ran here. Which instrument proved which half is stated in `past-prompts.md`
  rather than averaged (lesson **78**).
- D6 corrects four documents and deliberately leaves the historical ones
  disagreeing with them. A reader who greps `İkimiz` will still find hits in
  `docs/adr/` and `redesign/`; those are records of their own moment, and editing
  history so a grep comes back clean is worse.

## Review record

A pre-code design review ran against revision 1: **45 agents, 12 probes × 2
independent verifiers per finding (a refuting skeptic and a governing-docs
adjudicator), plus a completeness critic.**

| | |
|---|---|
| `agents_error` | **0** |
| `agents_empty_result` | **2**, both **CONSIDERED-empty** — `claim-measurement` and `claim-d2-causation` examined their sources and found nothing wrong |
| `failed_empty` | **0** |
| raw findings | **16** |
| surviving (either verifier said REAL) | **12** — all applied |
| refuted by both | **4** — two of them applied anyway, below |

Weighted toward claim-vs-source checking rather than lenses over the prose,
because the five sessions before this one each shipped an ADR whose worst error
was a claim that flattered its own argument, and every one was caught by an
outside reader comparing a claim to its source. That held here: the two most
serious findings were a **superlative** (*"the first movement on #204 in eleven
sessions that does not require Apple to accept a name"* — false; ADR-047 was
exactly that, and the sentence is deleted) and an **overstatement** (D6.1's
"detonator", which the store-name lint already defuses for the careless case).

**Two findings that BOTH verifiers refuted are applied anyway** (lesson **107**):
`decidable-without-input` (D4 — the ADR did contradict itself) and
`no-whitespace-collapse-helper` (D7.1 — `normalize()` really cannot serve). One
refuted finding is **declined with its reason** in D6.2 rather than silently
dropped. The completeness critic's single finding — *D7 is specified, not built* —
is answered by building it in the same PR, which is the sequence
`session-context.md` §5 prescribes: ADR first, code second, both in one change.
