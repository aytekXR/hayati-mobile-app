# Session Lessons

Institutional memory for this repo: the mistakes that were made, measured, and are
not to be made again. Extracted from `resume-prompt.md` on **2026-08-05**, where
they had accumulated to the point that the objective was hard to find.

**Rules for this file:**

* **Append only. Never renumber.** Other documents cite these by number — that is
  itself lesson **71**. A retired lesson gets struck through in place, not deleted.
* One lesson per entry, in the form *what happened → what to do differently*. A
  lesson with no incident behind it is a preference, not a lesson.
* Full narrative for each lives in the `past-prompts.md` entry for the session
  that learned it. This file is the index, deliberately compressed.
* Add here at session close, when the lesson is fresh — not later.

---

## The recurring shape

Almost every entry below is one of five failures. When you are about to trust
something, ask which of these you are standing in:

1. **A green signal that measured nothing** — a skipped job, an unregistered test,
   a vacuous assertion, an empty tool result read as a negative.
2. **A claim that outran its instrument** — "verified", "exercised end to end",
   "done", where only one layer was actually checked.
3. **An inherited premise nobody re-measured** — a fact that was true once, copied
   forward through handoffs, and executed as an instruction.
4. **A test whose fixture came from its own subject** — it cannot detect the drift
   it exists to detect.
5. **A guard that guards one language, one path, or one direction** — and is silent
   on the others.

---

## Numbered lessons

### Recent, in full

**150 — A verdict that is compatible with two very different worlds is not yet a measurement, and everyone will assume the wrong one.** *(S095, ADR-070 D1.1)*
`store_metadata_audit.py` reported *"en-US: description differs from
description.txt"* for seventeen days. **ADR-047 D2 read that as *"the English
listing is still whatever was typed by hand into App Store Connect"*, and ADR-070
repeated it through two revisions.** The first run of a classifier — the same
comparison, asked one question further — returned **`PUBLISHED IS EMPTY` for all
seven fields**: App Store Connect holds *nothing*, and only the app `name` was
ever set. "Differs" was true the whole time and was compatible with *"they have
rival copy"* and *"they have no copy"*, which are opposite facts with opposite
consequences: one made publishing a risk of overwriting the founder's work, the
other makes it free and reveals the listing is **not submittable**.
**Both documents guessed, in the same direction, and neither noticed it was
guessing** — because a comparison that returns a boolean feels like a measurement.
When a tool's verdict is a *category* (differs / mismatched / failed / changed),
ask what the distinct members of that category are and whether your conclusion
survives all of them. If it does not, you have not measured yet. And the cheap fix
is usually one more question to an instrument you already built: the classifier
cost an afternoon and overturned a claim two ADRs had carried.

**149 — A truncated run's success lines look exactly like a complete run's.** *(S095)*
Counting the checks in a test suite before and after a change: the "before" run
was executed against a copy of the files in a temp directory and printed **24**
`ok` lines. The real number is **41** — the suite calls
`expected_locales(pathlib.Path("fastlane/metadata"))`, a **CWD-relative** path, so
outside a full worktree it raises partway through and stops. Exit code 1 was right
there and was not read, because the *interesting* output was the count and the
count looked plausible. **This is lesson 65 one step over: not an empty result read
as a negative, but a PARTIAL result read as a total.** An empty result at least
looks empty. Two instruments now: **read the exit code of the run you are counting,
not just its output**, and **count in a place where the thing can actually
complete** — `git worktree add` settled this one in ten seconds.
⚠️ It was the *fourth* wrong count in one session; the other three were caught by a
review agent. Lesson **133** does not stop being true once you have quoted it, and
this session quoted it in the ADR's own Context table.

**148 — A guard cannot protect you from someone OBEYING the wrong instruction, because the instruction tells them to move the guard.** *(S095, ADR-070 D6.1)*
`session-context.md` §6's binding-invariants table said the App Store name is
pinned to **`İkimiz`**. It is `ikimiz`; ADR-035 lowercased it and left five copies
of the old value behind, one of them in that table. `release_lane_lint.dart` does
pin `name.txt` and does run on every PR — so a session that edited `name.txt` alone
would go red. **But the lint's own violation message says *"Change the pin in
`tool/release_lane_lint.dart` and every `name.txt` in one commit"*, which is
precisely what a session reconciling to the invariant would do next** — and then
the build is green and `deliver(force: true)` renames the founder's live listing.
The first draft of the ADR called this *"a live detonator"*; a review agent found
the lint and the claim was overstated. **The corrected version is the more useful
one:** a guard defends against the careless edit and is silent for the diligent one,
so *"a lint covers it"* is never a reason to leave a stale instruction standing.
Grade a stale fact by what a **conscientious** reader would do with it.

**147 — A refusal grounded in a rule that says "without asking" is not a refusal. It is a question nobody asked.** *(S095, ADR-070 D3.1)*
ADR-070 revision 1 declined to build the release-lane fix, on the ground that
`session-context.md` §7 *"forbids a session dispatching the release lane"* — and
conceded two paragraphs later that §7 is *"a list of things to ask about, not a
prohibition"*. **Both sentences were in the same document.** The review's refusal
lens called it blocking, correctly: arguing around a rule rather than through it,
in a session that was already handing the founder two other decisions and could
have added one line. Revision 2 asks (operator item 6(c)). The same pass killed the
other ground — ADR-029 D2 / ADR-032 D4's *no blind edits* precedent protects a path
that **demonstrably works**, and this lane has never worked once, so the precedent
had to be **distinguished** (the ADR-041 move) rather than borrowed.
**If your ADR declines to build something, point a lens at that decision
specifically** — nothing fails when a refusal is wrong; the work simply does not
happen.

**146 — A rebuilt dev box makes every credentialed instrument answer "could not measure", and the next session will read that as a reading.** *(S095)*
S095 opened by running the two probes its prompt mandated. Both returned **exit 2**
where S094 had measured **1**. Nothing had changed in production: the machine had
been rebuilt around 2026-08-31 and `flutter`, `dart`, `java`, `ruby` and the
`firebase` CLI were simply gone, along with `~/.config/configstore/` and the git
identity. **`session-context.md` §2 and §3 still asserted all of them, in runnable
form** — lesson **64**, a stale fact inside an instruction, in the one document a
session is told to trust about its own machine.
ADR-063's exit-2 state is what stopped this becoming a false production report, and
it is worth seeing that it earned its keep for a reason nobody designing it had in
mind. **Two habits:** open a session by measuring the toolchain
(`for c in node npm python3 java dart flutter ruby gh git; do command -v $c; done`),
and when an instrument's answer moves, **suspect the instrument before the
subject**. Note what is a session's and what is not: reinstalling an SDK is a
download; `firebase login` is interactive OAuth on the founder's identity, so it is
an operator item.

**145 — A resume prompt is a claim, and the ADR that owns the objective outranks it.** *(S093, ADR-060 D6 / ADR-069)*
S093's prompt named **#242** and asserted that emitting the three money events
into the existing port was unblocked — only *delivery to a vendor* being blocked.
**ADR-060 Decision 6 had already decided the opposite**, after a design pass and a
built-diff pass: *"there is no reason to build a server emitter before there is
somewhere for it to emit"*, and its condition was still unmet (no sink; #226 and
#247 open). The prompt was written by the previous session from the **issue title
and the priority list**, without opening the ADR that owns the objective. Nothing
in the prompt was checkable at a glance, and it read as authoritative because a
resume prompt is the one document a session is told to trust.
**Before planning, open the ADR the objective belongs to and read the decision
that governs it** — an issue records a problem; the ADR records whether we
already decided what to do about it, and *when*. ⚠️ And the corollary for the
session that WRITES the prompt: naming an objective is a claim about its state.
Check it against its ADR before handing it to the next session, or the next
session inherits your homework as an instruction.

**144 — A line number is a claim with a short half-life, and your own diff is what expires it.** *(S092, ADR-068)*
ADR-068 revision 1 cited `data-rights-core.ts:366` as evidence; that was the
docstring, not the code. Revision 2 corrected it to `:372` and `:460` — **and the
same commit added a 32-line note above `ExportProfile`, pushing them to `:404`
and `:492`.** The correction was stale in the act of being made, and the
built-diff review found it. **Cite a SYMBOL and the command that finds it**
(`grep -n projectConsent …`), not a coordinate: the symbol survives every edit
above it, and the reader gets a verification path instead of a number to
disbelieve. This is lesson **132**'s rule — *a comment that names the command
does not go stale* — pointed at evidence in a document rather than at a comment
in code. ⚠️ Note the shape: **the more careful you are about correcting a line
number, the more likely you are to correct it to another line number.**

**143 — Knowing a failure mode does not prevent you committing it, and only an outside reader catches it.** *(S091, ADR-067)*
ADR-067 revision 2 opens with a box criticising revision 1 for *"asserting
something false in the direction that flattered its own argument"*. In the same
session, writing the index row for that same ADR, I said the index had been
*"priority 1 in three consecutive session prompts"*. Its own Finding 2, twenty
lines above, says priority 1 in **two** prompts and *"next, not now"* in
between. I then wrote the same inflation into the lint's header comment and into
the commit message — **three places, all after documenting the failure mode, all
in my own favour.** Nothing about having just named the trap helped. What caught
it was an agent whose only job was to read the ADR and the row side by side and
ask whether one was true of the other. **Self-review does not catch
self-flattery**; the check has to come from something that has no stake in the
sentence. The corollary for review design: when a change produces claims *about*
its own subject, spend agents on comparing each claim to its source, not only on
lenses over the diff — 5 of 19 rows came back inaccurate, and no lens found any
of them.

**142 — A status word that also appears in ordinary prose is not a status marker.** *(S091)*
A review harness classified one lens as **FAILED-empty** — meaning blocked,
meaning its silence was worthless — when the lens had written *"CONSIDERED-empty"*
and then used the word **blocked** in a sentence describing a workflow the design
blocks on purpose. The classifier did `note.toUpperCase().indexOf('BLOCKED') >= 0`
over free prose. The reported distribution was wrong about the review's own
coverage, which is the one number a reader uses to decide how much the review is
worth. **Put the classification in its own field, or require the marker at the
START of the string** — the fix here was a schema that says *begin the note with
the single word CONSIDERED-EMPTY or FAILED-EMPTY and use those words nowhere
else*, plus `startsWith` instead of a substring search. Same family as lesson
**133**: a number an instrument reports about itself is still a claim.

**141 — A correction is finished when every COPY of it is gone, not when the thing it corrected is fixed.** *(S090, ADR-066)*
S089 found `prod_pulse` printing *"no billing account is linked"* beneath the
linked account's own id, could not fix the tool in that session's scope, and put
a note in `operator-expected.md` telling the founder to ignore that line. S090
fixed the tool and removed the note — **one of the two copies of it.** The second
sat in the same document's *Next Step* section (*"Trust item 1's wording, not
that line"*), so the file simultaneously said the tool was correct again and that
the founder should distrust it; the *Next Session Goal* section still named the
issue the same commit closed. The commit message asserted the removal in the
singular — *"loses the S089 note"* — which is how a `sed`-shaped edit reads when
you wrote the note once and it was rendered twice. **This is the failure mode
ADR-066's own Alternatives section had already named**: *"a document that corrects
a tool is a note that goes stale"*, written by the session that then left one.
**Grep for the note's own words before claiming it is gone** — the built-diff
review found this and it costs one command. Related: lesson **140** (grep for
what your change falsifies) — this is its mirror, greping for what your change
makes *redundant*.

**140 — The sentence a change makes false is usually in the translation files, not in the code.** *(S089, ADR-065 D6)*
ADR-065 D5 spends a page on the right argument: this session makes a sentence in
the privacy draft false, that is *"the same defect class, one session later"*, and
so the draft is corrected in the same diff. It then stopped, because the draft was
the surface someone had already thought about. The **app** carried two sentences
about the identical fact and both were falsified by the same commit:
`nameCaptureHelper` — *"Your partner will see this on your invitation"*, said at
the **collection point**, the one place the app explains what a name is for — and
`settingsNotificationPrivacySubtitle`, which describes the **control** that is now
the only thing between a partner-chosen string and a lock screen, while promising
to hide *"message content"* a notification has never carried. Neither is code;
both are values in `app_{en,tr,ar}.arb`. **The built-diff panel did not find them,
and one of its critics was pointed straight at the question** — *"does anything in
`app/` display, cache or assume the name-free copy?"* — and answered by reading
the Dart. **Add one step to the blast radius of any behaviour change: grep the ARB
files for what the product SAYS about the thing you changed.** A `git grep` for
the old promise costs seconds; the surface it protects is the one a user actually
reads.

**139 — A verifier that can name one outcome stops there, and rates the defect by the milder one.** *(S089, ADR-065 D3e)*
The adversarial lens **found** that unpaired surrogates pass `sanitizePushName`,
and filed it as *"Cosmetic (renders as replacement characters), not security"* —
so it never became a finding. That first outcome is real: a UTF-8 round trip turns
`'Ay\uD800lin'` into `Ay?lin`. It is also not the only one. The same string is not
well-formed (`isWellFormed()` is `false`), FCM may refuse the payload, and
`deliverPush` counts a refusal as `send-failed` — **the recipient gets nothing**,
which is the exact outcome D3c's length cap exists to prevent, reached through a
different door. The lens stopped at the first branch it could describe and rated
the whole finding by it. **When a defect has more than one downstream, a verdict
is only as good as the branch the verifier happened to follow** — so when a lens
reports "cosmetic", ask what the *other* consumer of that value does with it.
Related: lesson **135** (a refutation is a claim) — this is its quieter cousin,
where nothing was refuted, only under-rated, and an under-rated finding never
reaches the aggregation at all.

**138 — An empty grep is evidence of absence only if the pattern was right, and case is the usual way it is not.** *(S089, ADR-065)*
ADR-065 revision 1 stated as measured fact that `name_capture_screen.dart` has
**no `maxLength`**, and built a paragraph of threat model on it. The screen caps
input at **50** — `nameCaptureMaxLength`, applied through a
`LengthLimitingTextInputFormatter`. The evidence was
`grep -rn "maxLength" app/lib/features/profile/`, which returns **0 lines**;
`grep -rni` returns **2**. The constant is `nameCaptureMaxLength`, capital `L`,
so the pattern never could have matched, and **an empty result was read as an
absent fact.** This is lesson **110**'s floor pointed at a grep instead of a test:
a search that matched nothing and a search that found nothing look identical, and
the only difference is whether the pattern was capable of matching. It had a
downstream cost — the ADR set a server-side length cap of 48, *below* the client
bound it did not know existed, which would have silently discarded names the app
itself invites people to type. **Before asserting a negative from a grep, prove
the pattern can match something**: run it case-insensitively, or grep for a
substring you know is there. The completeness critic caught this; neither of the
finding's two verifiers was looking at it, because it was never a finding.

**137 — A verifier asked "is this MANDATED?" will refute every true finding that no rule happens to cover.** *(S089, ADR-065)*
ADR-065's design pass ran 5 lenses × 2 verifiers over 8 findings and surfaced
**zero** — both verifiers refuted all eight, every one at `confidence: high`.
The design was not clean. Six of the eight were true and were adopted, two after
I re-measured the underlying fact myself. The refutations show what happened:
almost all of them argue *"no governing document requires an ADR to specify
this"*, and two concede the fact outright — *"The finding's technical observation
is correct … However, this is NOT a design deficiency."* That is an answer to a
question about **ADR completeness standards**, not about whether the finding is
**true**. The adjudicator lens is *supposed* to ask that; the defect was that the
**skeptic** prompt (*"try to REFUTE it; default to real=false if you cannot
substantiate it"*) let it borrow the same frame, so the aggregation had no
verifier left asking *"is the claim true, and does it matter?"* — and
`surface if EITHER says real` is worthless when both are answering the same wrong
question. **A 100%-refuted verdict distribution is a signal about the question,
not about the design** — the same shape as §5 item 5's *"check `agents_empty_result`
before trusting a distribution"*, one level up: check what the verifier was ASKED
before trusting what it answered. Give the skeptic a truth question and the
adjudicator the rules question, and never let the aggregation overrule a fact you
measured yourself (lessons **123**, **135**).

**136 — A `/g` regex driven by `.test()` skips alternate matches, and the result reads exactly like a working filter.** *(S089, ADR-065)*
The first draft of ADR-065's control-character strip used one global regex and
called `.test()` per character. Fed
`"Aylin\n\nSecurity alert: verify at evil.example"` it returned
`"Aylin\nSecurity alert: verify at evil.example"` — **one newline removed, one
left in**. A regex with `/g` carries `lastIndex` across `.test()` calls, so every
second match is skipped. The output is the tell only if you look at it: a strip
that removes *some* of the thing it is aimed at looks like a strip that works,
and the case that survives is the second one, which a single-instance test never
has. The rule is mechanical — **`.test()` takes a NON-global regex; `/g` belongs
only to `.replace()`** — and the reason it is worth a number is that this one sat
in the middle of a security control: the whole point was that a display name
cannot put a second line on someone's lock screen, and the draft let it.

**135 — A review agent's refutation is a claim, and a confident one is still a claim.** *(S088, ADR-064)*
A design lens raised *"`roles/billing.viewer` exposes payment info the watcher does
not need."* Its paired refuter dismissed it with a specific, checkable sentence:
*"`billing.accounts.getPaymentInfo` is NOT included in `roles/billing.viewer` — it
is in `roles/billing.admin`. Google Cloud explicitly separates billing metadata
access from payment method access."* One IAM API call: **that role carries
`getPaymentInfo`**, plus `getSpendingInformation`, `credits.list`, `getIamPolicy`
and `resourceAssociations.list`. The finding was real, the refutation was wrong on
the single fact it rested on, and the aggregation rule — *surface if EITHER verifier
says real* — **cannot save you here**, because both verifiers can be wrong about the
same external fact and neither is measuring it. Lesson **123** says to measure a
load-bearing claim in an issue or a handoff document yourself; this is the same rule
one level up: **a verifier's reasoning is an input to be checked, not an output to be
trusted**, and the tell is the same — a *specific, checkable* assertion that nobody
in the loop actually ran. Re-measure the ones a decision rests on, especially when
they arrive as good news.

**134 — Checking a role for what it can WRITE is not checking it for what it can SEE.** *(S088, ADR-064)*
The first draft of the CI credential asked for `roles/billing.viewer`, having
verified it has **zero** write permissions — which is true, and was the wrong
question. This repository is **public**; a leaked key is a leaked key, so the
question is exposure, not mutation. Three measurements, all counterintuitive, none
of them guessable: `roles/viewer` — **6064 permissions, the broadest read role
Google ships** — cannot read `billing.accounts.get` at all, so the most tempting
grant blinds the instrument on its own subject while looking fully configured;
`roles/billing.user` is **6 permissions and a WRITE role** (*"Can associate projects
with billing accounts"*), so **smaller is not safer**; and `billing.viewer`'s 62
read permissions include the founder's payment metadata and an inventory of every
project on the account. The fix was not a narrower role but a **narrower question**:
the lane never needed billing at all, because the reason the loop stopped is in
Cloud Logging in the platform's own words. **When a credential looks expensive, ask
what the tool actually has to READ before shopping for a role** — and ADR-041 D4's
rule (*the tool must never be able to cause what it reports*) generalises further
than the drift checks it was written for: a watcher for a closed billing account
must not hold the permission to attach projects to billing accounts.

**133 — I get counts wrong, and each one was caught by a different accident.** *(S087/S088)*
Three numbers written next to correct work in two sessions: *"21 sites in 8 files"*
(measured: 24 across 9), *"eight merged client slices"* (measured: seven), *"four
unarmed lanes"* (measured: five). Every one was stated with the same confidence as
the measured facts beside it, which is lesson **111** — *a number typed next to
working code inherits the code's credibility* — recurring three times in the session
that cited it. What is new is the pattern in the *catches*: one was found by
re-deriving from the merged diff, one by a review finding that was **wrong in the
opposite direction**, and one by a review finding that was right. **No habit caught
any of them**, which is the actual defect. The rule that follows is mechanical, not
attentional: **a count in a document is a claim, so it carries the command that
produced it** — `git diff … | grep -c`, `git log --since=… -- <paths>` — and a count
with no reproducible derivation should be written as *"several"* rather than as a
number that will be quoted back as measured.

**132 — A comment that states a measured fact goes stale; a comment that names the command does not.** *(S087, ADR-063)*
Five separate comments across the notification feature told a reader the device
half could not work: *"Nothing overrides this yet"*, *"It is INERT until the
entitlement lands"*, *"There is deliberately no implementation of this yet"*,
*"correct and inert today"*, *"NOTHING writes this field yet"*. Every one was
false, most of them for twenty days. **The cruel part is that the repo already
knew**: `main_prod.dart:217` carries a ⚠️ recording that this exact sentence *"HAD
BEEN FALSE FOR NINE DAYS"* and naming it *"the fourth indistinguishable
explanation for silence"* — and that correction was applied to **one file of
six**. A warning about stale comments is itself a comment, and it propagates no
better than the thing it warns about. The failure is not that the facts changed;
it is that a comment **asserted** a fact with a shelf life. So the rule is
structural rather than diligent: a comment may not carry a measured fact about
build, device or portal state — **it names the instrument instead**
(`push_delivery_probe.py`, `appid-capabilities.yml`). A comment that names a
command cannot go stale, because it makes no claim. And no CI gate can replace
this: only grammar separates *"the entitlement is absent"* from *"the entitlement
was absent in August"*, a scan would need an allowlist (lesson **128**), and
"this cannot work yet" is the single most expensive sentence to leave lying
around — it reads as a reason to stop looking.

**131 — The convenient field next to the fact is not the fact.** *(S087, ADR-063)*
`prod_pulse.py` asked `projects/{p}/billingInfo` for `billingEnabled` and treated
it as "billing works". It means **the project is LINKED to an account**. Through
six days of a total outage it read `true` while the account behind it was
`"open": false` and Cloud Run refused every invocation with *"billing is disabled
for this project"*. The tool would have printed the reassuring `billing: enabled`
in the middle of the incident it was written for — and the regression test that
replays that incident passes `billing_enabled=False`, **an input the production
path could no longer produce**, so the file's most important fixture had quietly
become unreachable. Two tells, both cheap: the field was one hop *nearer* than
the authority (`billingAccounts/{id}.open`), and a **vendor boolean named after
your question is usually named after their schema**. Cousin of **125** — there,
prefer state we own to a field the vendor controls; here, when you must read the
vendor, read the one that is *true* rather than the one that is *close*.

**130 — Measure several facts in one `try` and you report none of them — and the probe that fails is usually a consequence of the fact you needed.** *(S087, ADR-063)*
`prod_pulse.py` was built after #219 to make a silent production outage
impossible to miss. It met the identical outage on 2026-08-22 and printed
`could not measure` (exit 2) for six days. Its `main()` ran three independent
measurements inside one `try`: `measure_billing` **succeeded**, `measure_job`
raised HTTP 403, `measure_last_sweep` never ran — so the first failure discarded a
fact already in hand and a fact not yet asked for, and the pure `verdict()`
function, carefully written to **accumulate** cause and consequence, was never
called. **The abort was not bad luck.** Cloud Scheduler returns 403 *because*
billing is off (*"This API method requires billing to be enabled"*), so the one
state the tool exists to detect is the one state that **guarantees** it cannot
report — lesson **114** with the control's blind spot aimed at its own subject.
Three rules came out of it, and the second is the one that generalises furthest:
probe each fact separately and turn a failure into a **named gap**; **a gap can
never contribute to a green** (findings → 1, else any gap → 2, else 0 — ADR-041's
*"never 0 without having compared"* applied to a multi-fact verdict); and **a gap
is not an absence** — `job_state=None` already meant *"I looked and there is no
job"*, so without suppressing the paired finding the fix would have printed
*"the sweep has no trigger"* about a scheduler it merely could not read, i.e.
invented a cause and been worse than the bug. Recurring shape **1**: an empty
tool result read as a negative — except here the tool produced the empty result
itself, while holding the answer.

**129 — A rewrite that keeps every test green can still delete an assertion.** *(S085, ADR-061)*
Converting the flag seam to typed keys meant rewriting `local_flag_store_test.dart`.
The rewrite replaced `expect(coachDisclaimerAckKey('u1'), 'coachDisclaimerAck.u1')`
with a pin on `AccountFlag.coachDisclaimerAck.prefix`, which reads like the same
assertion and is not: the enum pin proves the **vocabulary** is intact and says
nothing about which member a **builder** reaches for. The behavioural test could
not cover the gap — `coach_screen_test.dart` seeds and asserts with the same
function, recurring shape **4** — and the mutation check proved it: rewiring the
builder to the wrong member left that test **green**. The built-diff review found
it; the suite never could, because the suite was green before and after. **When a
test file is rewritten rather than edited, diff the OLD file's assertions against
the new one and name where each landed.** A dropped pin leaves no trace anywhere
else.

**128 — Put the classification in the type, and there is no inventory to keep.** *(S085, ADR-061)*
The first design guarded "every flag is classified account- or device-scoped"
with a source scan for `localFlagStoreProvider` whose file set had to match a
declared list. Four of the six key-builder files never name that identifier, so a
new flag in a new file consumed from an inventoried consumer was invisible to it —
the guard reproduced the very defect it was written for. Two closed enums and a
key type that a raw `String` cannot become deleted the scan **and** the list: a
flag that is not classified does not compile. **Before writing a source scan that
enumerates what code must declare, ask whether the compiler can be made to
enumerate it instead** — and if a hand-written list survives, remember it is a
fixture derived from its own subject (`funnel_event.dart` says so about itself).

**127 — Reason about the KEY, not about the flag.** *(S085, ADR-061)*
The resume prompt this session inherited — written by the previous session, from
ADR-057 D4's own recorded bound — said clearing the once-only markers on deletion
*"makes a later re-signup re-emit once-only events, a counting change traded for
a data-rights improvement"*, and framed that trade as the hard decision of the
session. **There was no trade.** The uid is already inside the key, so a
replacement account gets a different key and re-emits whether or not the old one
was cleared. The bound ADR-057 recorded is real for `analytics.install`, which has
no uid — and was carried forward to five keys that do. **A per-identity cache key
does not have the invalidation problem a global one has; check which you are
holding before pricing the trade.**

**126 — The file you are appending to often already has the precise word you are about to get wrong.** *(S084, ADR-060)*
An addendum to `architecture.md` §7 called the entitlement mirror's sole writer
"the webhook". §3 of the **same file** already reads: *"the deleteAccount cascade
is the second admin writer, but it only ever deletes the doc WHOLE — the webhook
stays the sole CONTENT writer."* The distinction had been drawn, deliberately,
and the new paragraph flattened it — while contradicting its own ADR's
*"exactly two writers"* three screens away. **Before writing a summary sentence
about a subsystem, grep the document for the subsystem's name and read what it
already says.** The cost of not doing it is not a wrong fact so much as two
documents that disagree, which is the state the reader cannot resolve.

**125 — A rule that reads a field the VENDOR controls is a rule that can go silently unmeasurable.** *(S084, ADR-060)*
A draft classified `churn` as *"an `EXPIRATION` whose `periodType` is a known
non-trial value"* — correct-looking, and dependent on RevenueCat sending
`period_type` on an expiry event. **Nobody here can ask RevenueCat**, the repo's
own standing lesson is that *only the vendor can refute a vendor API shape*, and
the test fixtures default that field, so a suite would agree with any assumption.
If the field is absent the rule matches nothing and **churn is never emitted at
all** — the failure is silence, not a wrong number, and silence is the failure
mode a funnel cannot detect from inside. The fix was to key the rule off state
**we** own (the previous lane), which was already being fetched for a different
rule. **When a classification can be written against our state or the vendor's,
prefer ours — and when it cannot, say out loud which vendor behaviour the metric
now depends on.**

**124 — A hand-rolled Unicode range is a guess with syntax; ask the engine for the property instead.** *(S083, ADR-059)*
A test needed "is this character strong-RTL", and got
`/[֐-ࣿיִ-﷿ﹰ-﻿]/u`. It reads like three sensible block ranges. It is not: the
Hebrew point in the middle is **two codepoints** (U+05D9 + U+05B4), so the class
parsed as `U+0590-U+08FF`, a stray `U+05D9`, and then **U+05B4–U+FDFF** — sixty-
three thousand codepoints, calling Devanagari, Thai, Hiragana and Han right-to-
left. Nothing catches it: the tests it guarded all passed, because the strings it
was shown were Arabic and Latin and it happened to answer those two correctly.
**A predicate that is wrong agrees with whatever it is given.** `\p{Script=…}`
says what is meant and cannot be mistyped into a range. This repo had already
paid for the same lesson at a larger size — **ADR-053 GENERATES the app-side
strong-bidi table** rather than letting anyone type one — and the reasoning did
not transfer to a five-character regex in a test file, because nobody thought of
a test file as a place where Unicode is hard.

**123 — Fix the SPECIFICATION before the feature reaches it; but say out loud that nothing is reachable yet.** *(S083, ADR-059)*
`partnerAnswered` has named copy in three languages, a `partnerName` parameter,
and unit tests for all of it. **No caller has ever passed a name** — `grep` finds
the parameter only in its own file and its own tests, and `git log -S` finds no
call site that ever supplied one. Issue #136 called the resulting bidi defect
*"latent"*, which is one step less remote than the truth, and an ADR written from
the issue inherited that severity and then claimed a user-visible benefit — *"a
user whose partner has an Arabic name stops receiving backwards notifications"* —
**that cannot exist, because no user receives a name at all.** Two useful halves.
First: fixing unwired code is often right, because the branch is one argument
from being reached and the measurement is far cheaper now than after it ships.
Second: **the severity sentence is a separate claim from the fix**, and inheriting
it from the issue is inheriting an unmeasured premise (recurring shape 3). Before
writing "latent", run the grep that tells you whether anything calls it.

**122 — A correction can introduce the very defect it corrects, one document over.** *(S083, correcting S082)*
S082 existed to remove a false sentence from the privacy policy — *"ikimiz does
not send push notifications today"*, true of the outcome and false of the system.
Its draft then told users *"a notification can show your partner's name"*, which
is false in the **other** direction: no caller supplies a name, so it cannot.
S082 measured the push system carefully and did not measure the one sentence it
was itself adding. **The check that catches this is not more care, it is the same
check applied to the new text**: for every capability sentence you *write*, ask
what would have to be true for it to be false, and go and run that. It cost the
next session one grep to find, and the draft had already merged.

**121 — A test's NAME is a claim; its assertion is the measurement, and nothing keeps them together.** *(S082, ADR-058)*
The cross-locale parity guard was named *"all three locales carry the same
sections, in the same order"*. It collected the three ordered heading lists —
and then asserted **only that the three lengths were equal**. Three documents
with entirely different sections in any order passed it. The name was quoted
verbatim into ADR-058 Decision 8 and again into `test-suite.md`, so **three
artefacts agreed with each other and none of them agreed with the code**, which
is why a design review reading the ADR could not catch it and only someone
reading the assertion could. The tell was visible in the code: a variable called
`counts` holding full lists, with everything but `.length` discarded one line
later. **When a guard's name promises more than its `expect` measures, the name
is the thing that gets believed** — it is what a later session greps for, and it
is what goes into the docs. Read the assertion, not the test name, and be
suspicious of any guard whose name is a sentence its body could not print.
*(And the rewrite failed immediately on correct input: Dart `List` has identity
equality, so a `Set` of three structurally identical lists has length 3. Running
it is what proved the fix; reading it would not have.)*

**120 — An absolute in a user-facing document is a claim about every platform, and the counter-example is usually already written down in this repo.** *(S082, ADR-058)*
The version-3 draft said the on-device analytics markers *"never leave the
device, and removing the app removes them."* Both halves are false wherever
device backup is on: Android Auto-Backup has been default-on since API 23 and
`AndroidManifest.xml` sets no exclusion. **The iOS half was already recorded
here**: ADR-018 stores the PIN in a Keychain record marked
`unlocked_this_device` *specifically* to stay **"out of iCloud and device
backups"** — a sentence that only makes sense if ordinary app storage is in
them. Two code comments and ADR-057 carry the same unqualified assumption, all
of them inherited from an iOS-only framing nobody re-measured (recurring shape
**3**). The failure is not the platform detail; it is that **an absolute was
written into the one document class where being wrong is expensive, by the very
ADR whose purpose was removing a false sentence from it.** Before writing "never"
or "always" about storage, grep the repo for the control that was designed
*around* the exception — it is usually there, and it is usually load-bearing for
something else.

**119 — A revision draft must be a MINIMAL delta, or the reviewer reviews a re-translation.** *(S082, ADR-058)*
The first hand-written Arabic v3 draft silently re-worded the intro paragraph and
rendered `## من يُشغّل تطبيق ikimiz` as `## من يُشغّل ikimiz`, dropping a word
from a heading the revision had no business touching. A structural test caught
the heading; **nothing would have caught the paragraph**. That matters more for a
legal document than for code: the founder's lawyer is paid to review a *change*,
and a draft that also re-translates unrelated prose buries the change inside
noise the reviewer must now re-approve line by line. The fix was to stop hand-
authoring it — the Arabic draft was **rebuilt programmatically from the shipped
file** by 14 content-anchored replacements, each asserted to match **exactly
once**, so an anchor that moved failed loudly instead of silently no-op'ing. The
same rule caught the reverse case one file over: the diff of the EN and TR drafts
against their shipped counterparts was read line by line, and every changed line
had to be an intended one. **For any derived document, prefer a scripted delta
with unique anchors over a rewrite, and read the diff against the source as an
acceptance step.**

**118 — A rule recorded in one feature's ADR does not generalise itself; the diff will walk into it once per call site.** *(S081, ADR-057)*
ADR-017 D8 exists precisely because `ref.read` on an autoDispose controller
**throws** once it is disposed — it is why `CoachSendController` captures the
transcript notifier *before* the await. S081 added an analytics emit to four
controllers and read the provider *after* the await at **all four**. Only the
coach path had a test exercising mid-flight disposal, so exactly one went red and
the other three were **latent, in code whose own `ref.mounted` guards concede the
disposal can happen**. The suite caught the one that was already covered; nothing
would have caught the three that were not. **When you add the same line to N call
sites, the question is not "does it work here" but "which invariant does the
neighbouring code already defend, and does my line defend it too".** The fix was
uniform (capture before the await everywhere) and cost one grep; finding it cost
a full suite run and a regression test written after the fact.

**117 — A behavioural test of a de-duplication key cannot see the key.** *(S081, ADR-057)*
The once-only funnel events are de-duplicated by strings persisted in
`SharedPreferences` — `analytics.signup.<uid>` and five siblings. Every one was
tested as *behaviour*: call twice, assert one emission. **That test passes
identically for `analytics.singup.<uid>`.** And because the keys persist **across
app updates**, a typo does not fail anywhere: it silently re-emits a once-only
event for every existing user, on the version that "fixes" it, and the funnel
shows a spike nobody can explain. Surfaced by the built-diff review, not by the
suite. **Where a value is a persisted contract rather than an implementation
detail, assert the VALUE — behaviour is blind to it by construction**, and the
`FORMAT_VERSION` pinning discipline (lesson 108) is the same rule one layer up.

**116 — When a threshold needs re-tuning twice, the INSTRUMENT is wrong, not the number.** *(S078/S079, ADR-055 D2 revised)*
The integration watchdog bounded each suite by wall-clock time. 960s was sized
against a 540s run; a later run took 640s, so it went to 1080s; **the very next
run took 936s.** Three sizings in one day, each against whatever the most recent
run happened to be, each looking reasonable in isolation. The tell was already
visible in the data: the auth suite spans **513–936s across four runs — a 1.82x
spread from runner speed alone**, which is wider than the ±55% stress factor the
bounds were being checked against. No wall-clock number can be tight enough to be
useful and loose enough to be safe when the quantity varies by more than the
margin you are defending. **Chasing it does not converge — which is precisely
#208's own criticism of raising `timeout-minutes`, arriving one level down and
made by the fix for it.** The right question was never "what number", it was
"what quantity": a wedge is defined by producing NOTHING, and a slow runner still
prints. Measured, the discriminator is overwhelming — healthy runs go quiet for
at most **299s** (the cold Xcode build), the incident for **2280s**, a **7.6x**
separation that is structurally stable rather than a lucky gap. The watchdog was
already computing and printing `silent for …s` in its heartbeat and simply was
not deciding on it. **A second re-tune is a signal to change the measurement, and
the right measurement is often one you are already displaying.**

**115 — A rule cited by number is a claim. Open it.** *(S079, found auditing S076-S078)*
Three ADRs, several commit messages, a numbered lesson and the handoff all said
*"`session-rules` §5.1 requires the ADR before the code."* **`session-rules.md`
has five sections and §5 is "Timebox".** There is no §5.1 in it and no ADR rule
anywhere in the file. The discipline is real — it is `session-context.md` §5
*Review discipline*, item 1 — and **ADR-048 already cited it correctly**, so the
right reference was sitting in the repo while three consecutive sessions copied
the wrong one from each other. Nothing catches this: the rule exists, the
practice was followed, every sentence reads as verified, and the only thing wrong
is the address — which is exactly what a later session follows when it goes
looking for the authority.

**Opening it cost one grep and immediately found a second thing.** §5 item **3**
requires *"Run the review twice: once on the design, once on the built diff."*
S076, S077 and S078 each ran **one** review, on the built diff. Three sessions
were half-following a procedure they were quoting by number. **Cite a rule only
after re-reading it in the session you cite it in** — and read the whole clause,
not the sentence you were looking for, because the parts you are not quoting are
the parts you have stopped doing.

**114 — A compensating control can be silent for exactly the failure it exists to catch.** *(S078, ADR-055)*
`integration-emulator` is main-only, and its own comment says so while naming the
thing that makes that safe: *"the compensation for its post-merge-only verdict
already exists and works: ADR-024's Slack notifier reports the run nobody is
watching."* It does not work for a timeout. `slack_notify.sh` deliberately sends
**nothing** when the outcome is `cancelled` — a superseded run is not an event,
and that policy is right — and **GitHub reports a timed-out job as `cancelled`**.
So the 38-minute hang was invisible twice over: no progress in the log, and no
notification afterwards. The control was not broken and the policy was not wrong;
**the platform spent one word on two unrelated things**, and the compensation
happened to sit on the wrong side of it. Two things follow. First, *"X compensates
for Y"* is a claim about a **failure mode**, not about X, and it has to be checked
against the specific way Y actually fails — this one had been asserted in a
comment for sessions without anyone asking which outcomes reach it. Second, when a
control cannot distinguish two cases, prefer changing **what you emit** over
teaching the control a distinction its inputs cannot carry: the fix here is a
watchdog that produces `failure` instead of `cancelled`, and the notifier needed
no change at all.

**113 — A review of a tree you are still editing spends its findings on the edit in progress.** *(S076, ADR-053)*
S076 launched the §5 build-diff review and then kept working — updating
`architecture.md`, `test-suite.md`, the lessons file — while the five lenses read
the repo. All three surfaced blockers reduced to *"the documentation is
uncommitted"*, which was true when read, false twenty minutes later, and never a
defect in the change. One was a flat false positive: a verifier reported
`resume-prompt.md` as never regenerated, and its own paired skeptic refuted it by
reading the diff. **The review's instrument was a moving target, so its findings
describe a moment rather than the change.** The existing rule is *rebase before
review — review the diff that will actually merge*; this is its other half:
**freeze the tree for the duration**. Commit or stash first, and if a review must
overlap with work, point it at a ref (`git diff origin/main...<sha>`) rather than
the working tree. Cousin of **107** — there the aggregation rule lost a real
finding, here the input lost the findings' subject.

**112 — A mutation described by its INTENT is a claim about a test that was never made.** *(S076, ADR-053)*
The third mutant for the bidi table was written as *"delete the ranges covering
`U+0800–U+08C9`, reintroducing `intl`'s exact gap"*, it deleted nine ranges, both
tests went red, and the sentence went into the ADR and the commit message. The
sentence was false. The generated table contains `0x07FE, 0x0815` — **one range
that spans `intl`'s class boundary**, because `U+07FE`–`U+07FF` (NKO) are inside
`intl`'s RTL class and `U+0800`–`U+0815` (Samaritan) are not, while Unicode gives
them all `R` and the coalescer emits them as one. A filter keyed on each range's
**start** skipped it, so **22 of the 150 code points stayed covered** and the gap
was never reproduced. The tests reddened anyway — their fixtures live in Arabic
Extended-A, which *was* removed — so nothing pushed back. **State a mutant by its
measured post-condition, not its intent**: here, *"0 strong-RTL code points remain
covered in `U+0800–U+08C9`"*, which is one assertion the harness can make and the
first version would have failed. Cousin of **109**: there the edit did not land,
here it landed somewhere smaller than the sentence claimed.

**111 — A number typed next to working code inherits the code's credibility.** *(S076, ADR-053)*
*"62,408 code points `intl` calls RTL are not strong-RTL"* appeared in a source
doc comment, in the generator's own docstring, and in the emitted file's header.
It was re-derived only because writing the ADR forced it: the real figure is
**322**, and 62,408 corresponds to **nothing measurable** — it was never a
measurement of anything, not even of the wrong thing. Alongside it, the same
drafting session wrote that the new table is *"a strict superset of `intl`'s RTL
class"* — **false by those same 322 code points** — into both the docstring and a
test assertion, where it would have forced a correct table to stay wrong. Both
survived because they sat beside code that compiled and tests that passed.
**§5.1's ADR-before-code is not ceremony**: an ADR written first has to state its
numbers while there is nothing green to lend them authority. This session
inverted the order and paid exactly that price, which is why the inversion is
recorded in ADR-053's own text rather than tidied away.

**110 — A scan whose glob matches nothing reports the same clean zero as a scan that passed.** *(S076, ADR-053)*
The W4 golden declaration rested on classifying every string in the app under the
old and new logic. The first run reported *"200 strings examined, 0 changes"* — a
believable, reassuring, useless result. Its ARB glob pointed at `app/lib/l10n/`
and the files are in `app/lib/core/l10n/arb/`, so it had examined **no localized
string at all**; the 200 were content-pack entries alone. The rerun asserts a
**floor on the corpus before believing the result** (`assert len(arbs)==3`,
`assert n_arb > 300`) and found 894 strings, still 0 changes — the same
conclusion, now actually measured. This is the *sentinel-of-the-sentinel* shape
ADR-052 built into `card_surface_sentinel_test.dart`, and it is needed in
throwaway probes for exactly the same reason: **a scan over an empty set is this
repo's most familiar green.** Assert the input is non-empty before trusting the
output, in one-off scripts as much as in committed tests.

**109 — A mutation run that applies nothing prints exactly the same green as a guard that works.** *(S071, ADR-049)*
The first mutation check of the vocabulary parity sentinel ran three mutants and
reported three passes. It had edited **nothing**: the runner did `cd app` before
calling a script that opened `firestore.rules` by relative path, so every edit
raised `FileNotFoundError` on stderr while the test that followed ran against the
**pristine** file and passed. Three greens, three of them meaningless, and the
traceback was two lines above them in the same output. **A mutation harness must
assert the anchor is present and the edit landed BEFORE running the test, and it
must use absolute paths** — a relative path in a harness that changes directory is
a silent no-op generator. This is lesson **74**'s cousin (an anchor that lands on
the wrong line tests nothing); here the anchor never landed at all, and the
failure mode was reassurance rather than error. Redone with absolute paths, all
three mutants were red.

**108 — When a mutant survives, the guard is not what is wrong — the test's NAME is.** *(S071, ADR-049)*
`_record` refuses to write the `unknown` state, and a test called *"never reports
unknown"* passed. Deleting the guard entirely **also** passed: both sites that emit
`unknown` already run with a null `_syncedUid`, so the uid check turns them away
first and the `unknown` check is unreachable. The guard is still worth keeping —
it is defence against an emit-while-signed-in that does not exist yet — but the
test was measuring the uid check while claiming to measure the vocabulary check,
which is this file's recurring shape 1 wearing a passing tick. **A surviving
mutant has three honest resolutions and "leave it" is not among them:** delete the
guard, make it reachable, or *rename the test to what it actually proves and
record in both the code and the test that the guard is unfalsifiable here*. The
third was taken. Do not restructure production code to make a test possible, and
do not leave a green tick that names a property nothing checks.

**107 — Both verifiers can refute a real finding, and the aggregation rule will not save you.** *(S070, #206)*
The built-diff review's `python` lens reported *"missing test: scoping TO an
unmeasurable function"*. The refuting skeptic said no; the governing-docs
adjudicator said no; §5.2's *surface-if-either-says-real* rule therefore dropped
it, and the synthesis never saw it. It was **real** — the suite asserted that an
out-of-scope `gcfv1` function does not abort a scoped run, but never that scoping
**to** one still exits 2, so an implementation skipping the guards for *every*
function whenever a scope was set would have passed. Building that exact mutant
took two minutes and it reddened three named assertions once the missing check
existed. **Aggregation reduces the set you read; it does not decide what is
true.** Read the raw findings list, and when a refutation is cheap to falsify —
a mutant you can write, a command you can run — falsify it instead of accepting
it. The two-verifier panel raises the floor; it is not a ceiling on your own
judgement.

**106 — "The design implies it" is not a specification, because the code is written from the words.** *(S070, ADR-048)*
ADR-048 D5 said `--only` narrows *"both verdicts"*, and separately rejected an
alternative because *"an out-of-scope exit 2 would abort a deploy that had
nothing to do with it"*. Both true, and between them a hole: ADR-043's three
exit-2 cases are raised while the listing is **parsed**, before any verdict
exists, so an implementation that parsed first and scoped second would abort a
subset deploy over an old `gcfv1` function nobody named — the very thing the
paragraph rejected. The skeptic argued the ADR already implied the right
behaviour. It did. **An ADR is the specification the next writer implements
from, and "implied" is discovered only by someone who already knows the answer.**
When a decision states an intent whose mechanism lives in code the ADR does not
otherwise touch, write the mechanism down as a rule — here, one sentence:
*outside the scope, recorded but never examined.*

**105 — A validator that checks an alphabet cannot see a character its alphabet never mentions.** *(S070, #206)*
`deploy-functions.yml` validated its function-list input against
`^[A-Za-z][A-Za-z0-9_]*(,…)*$` — closed, anchored, and it looks airtight. `grep`
matches **line by line**, so `$'a\nb'` passes on the strength of its first line;
`IFS=',' read` then consumes only that line, and `echo "names=$ONLY" >>
$GITHUB_OUTPUT` writes a second, keyless line the parser discards. The lane would
deploy `a`, read back `a`, and go **green** while `b` was requested and never
deployed. Reachable with one `gh workflow run -f only=$'a\nb'`. The pattern was
never wrong about characters — it was silent about **shape**. **Assert the shape
of an operator input (single line, bounded length) as well as its alphabet, and
reproduce the bypass in a shell before believing the pattern.** Anchors mean
different things to different matchers, and the one you are holding may be
matching a smaller unit than you think.

**104 — A confident wrong state is worse than the missing one it replaced.** *(S069, ADR-046)*
The whole point of ADR-046 was that four device-side notification failures were
indistinguishable, so `PushTokenSync` gained five named states. The first
implementation then emitted `awaitingDeviceToken` at the end of an exhausted
capture **unconditionally** — which labels a phone whose owner tapped *Don't
Allow* as *"allowed, just not finished registering yet"* and hands it a **Try
again** button that can never work. The loop genuinely cannot tell the two apart:
its own log line says so in one sentence (*"no APNs registration yet, OR
permission was declined"*). The fix is one call — ask the OS — and it also made
the settled state independent of ordering, because a concurrent `refresh()` that
had already written `denied` was being overwritten by the loop finishing a moment
later. **When you replace a silence with a label, check that the code can
actually distinguish what the label claims;** a guess with a confident name is
harder to doubt than the silence was.

**103 — There is no positive fixture when the thing has never once succeeded.** *(S069, #204, ADR-047)*
The plan for #204 was to parse `deliver`'s per-locale success lines out of the
nine release logs. There are none: deliver aborts inside
`verify_available_version_languages!`, which runs **before** the upload phase, so
every one of the nine logs contains only the failure. A parser written against a
guess at the success format would have been a test whose fixture came from its
own subject (recurring shape 4) — green forever, guarding nothing. **Before
designing a log parser, confirm the log contains the line you intend to key on.**
The instrument moved to asking App Store Connect what it actually holds, which
needs no fixture at all — and that read immediately found seven `en-US` fields
drifted, which the intended parser could never have seen.

**102 — A shared lock over two paths that must not block each other is a tidiness bug with teeth.** *(S069, ADR-046)*
Merging `PushTokenSync`'s prompt guard and its capture guard into one
`_attemptInFlight` looked like a simplification and would have shipped a device
that **never shows the permission dialog**: the boot capture runs for up to ~7.5s
(ADR-044 D2), the paired home mounts inside that window, and the shared lock
would have made `promptForPermissionAndRegister()` return early every cold start.
Two concurrent captures are merely wasteful; a skipped prompt is the entire
feature. The guards are back apart, with the reason written where the next person
will try to merge them again. **Before unifying two guards, ask what each one
would BLOCK, not what each one protects.**

**101 — "The absence of `gcloud`" is not "the absence of the credential."** *(S068)*
`session-context.md` stated for months that *"Cloud Scheduler and Eventarc state
cannot be verified from here"* because `gcloud` is not installed and there is no
ADC. Both halves of that premise were true and the conclusion was false: the
firebase CLI's stored refresh token carries the **`cloud-platform`** scope, and
`rules_drift.py` had *already shipped* the code to mint from it — so Cloud
Scheduler, Cloud Logging, Cloud Billing, Cloud Functions v2 and the Firestore REST
API were all readable the whole time, from a helper this repo wrote itself.
The cost was not theoretical: with no way to see Scheduler or request-level logs,
a 37-hour production outage went unnoticed and was then *mis-reported as healthy*.
**A capability was declared unreachable by reasoning about a missing tool rather
than by trying the credential that was already in hand.** When a document says
something cannot be measured, that is a claim to re-test, not a fact to inherit —
and the first thing to test is whatever credential the repo already uses.

**100 — An invocation ATTEMPT and a completed run are different events, and the log stream shows both.** *(S068, #219)*
`questionRollover` failed 38 consecutive hourly invocations — Cloud Run refused
each at the serving layer (`HTTP 500 "billing is disabled"`, latency 0s, container
never started) — while Cloud Scheduler stayed `ENABLED` and fired punctually. A
session read `firebase functions:log`, saw a line at every hour, and published
*"Your app is running. The hourly job fired all day."* Every one of those lines
was the **error**. Severity `E` and `I` differ by one character under the same
function name, and the sweep's own summary lines were simply absent.
**Health is the presence of the thing SUCCEEDING, never the absence of silence.**
Key any liveness claim on a record only the successful path can emit — here
`question_rollover: sweep complete`, which `runQuestionRollover` must return
before it is written. `tool/ci/prod_pulse.py` now does exactly that, and its test
replays this outage's signature (`ENABLED` + punctual + status 13 + no completed
sweep) as the fixture a naive "did it fire?" check cannot pass.

**99 — When you are blocked on a human, hunt the REST of the path instead of waiting.** *(S066)*
The push fix was merged and a build shipped; the only remaining step was the
founder installing it and tapping Allow, which no session can do. Waiting was the
obvious move. Instead the whole delivery chain was hunted adversarially for a
*second* defect that would still bite after the token landed — and there was one:
**no foreground presentation option, so a push arriving while the app was open
displayed nothing.** Harmless for the 08:00 sweep, fatal for "your partner
answered", which fires exactly when the recipient is in the app. Had it not been
found, the founder would have installed, tapped, seen silence, and reported the
feature still broken — costing another build and another day.
**A blocked goal is not an idle one.** Ask what the human's action will *unblock*,
then audit everything downstream of it while you wait. Four of the five lenses
found nothing, and that was worth knowing too: it converted "we think it works"
into "no blocker remains between a token and a lock screen."


**98 — A test that asserts the swallow is correct converts the bug into a specification.** *(S066)*
`push_token_sync_test.dart` contained *"a throwing token source never escapes"*:
set `currentToken` to throw, assert nothing is registered, green. That is
**exactly** what the defect was — iOS throws `apns-token-not-set` until APNs
answers, and the single capture attempt was issued in that window — so the test
locked the failure in and nothing could ever go red. Fail-open code is
especially prone to this: *"it did not crash"* is trivially satisfied by *"it did
nothing."* **When the code under test is allowed to swallow, the test must assert
what happens NEXT** — retried, recovered, surfaced — not merely that the swallow
was quiet.

**97 — A counter read at the wrong hour is not evidence, however many times you read it.** *(S066)*
Four sessions reported *"`checked: 0` on every hourly pass, so no phone has ever
handed over a token"* and told the founder one tap was all that stood in the way.
But `runDailyQuestion` opens with `if (hour !== DAILY_QUESTION_LOCAL_HOUR)
continue` — the pass evaluates only couples whose OWN local clock reads 8, so
`checked: 0` is the expected reading for 23 hours out of 24 regardless of tokens,
and the sampled hours were exactly those. At the couple's real 08:00 the same log
says `checked: 1, skippedNoToken: 2` and names both recipient uids — the opposite
story: the server works to the last inch. **Before quoting a counter, read the
code that increments it and ask what the sampling window has to be for the number
to mean anything.** A gated metric sampled outside its gate is not weak evidence;
it is no evidence, and it reads exactly like strong evidence.


**96 — A read-only review agent will happily run YOUR write-tool, and the revert is silent.** *(S065)*
`session-context.md` §5.8 already says *after every review workflow returns,
`git status` must be EMPTY before you commit.* This is how it actually bites.
The diff-review agents were told READ-ONLY and given no edit tools — but the
session's own **mutation harness** was sitting in the scratchpad, and it works by
writing a mutation into the source and restoring a snapshot in a `finally`. An
agent ran it as "a way to check the tests", and its restore **silently reverted a
source edit made after its snapshot**. Nothing errored; a later test run just
quietly disagreed with the file I thought was on disk, and one measurement taken
inside that window was wrong.
**Two rules.** A harness that mutates tracked files is a *write* tool: move it out
of reach (or make it operate on a copy) before any concurrent agent runs. And
**§5.8's check is not only for the moment the workflow returns** — a measurement
taken *while* a review is in flight is as suspect as a commit made after one.
Re-run tests, mutations and the live check after the workflow has actually
finished, and trust nothing sampled mid-flight.

**95 — A tool that reproduces a vendor's algorithm must re-verify the ALGORITHM, not just pin the version.** *(S065)*
`functions_drift.py` transcribes firebase-tools' hash derivation. A version pin
catches a major rewrite; it cannot catch the algorithm moving *inside* a range
you still accept — and that has happened before in this vendor. The silent
failure is worse than a stale pin: a tool computing confident nonsense and
calling production drifted. So it **re-greps four load-bearing shapes out of the
installed vendor source every run** and exits 2 if any has moved. `rules_drift.py`
already had the instinct (it reads the CLI's OAuth constants at runtime "so that
an upgrade produces a clear error instead of a silent 401"); generalise it.
**When you reimplement someone else's algorithm, the authority is their installed
source — check it at runtime, not at review time.**

**94 — When two exits both mean "bad", the report still has to say WHICH bad.** *(S065)*
The Functions drift check found production mismatching a clean checkout. The
tempting output is "DRIFT". The true output is one of two utterly different
things: *production is running the wrong code* (alarming) or *production is
running the right code, hand-deployed from a dirty tree* (housekeeping). Both are
exit 1. Computing a second digest purely to separate them cost about twenty lines
and is the difference between a usable gate and one whose red gets ignored on the
third occurrence. **A report that cannot name its own finding's cause is the next
reader's wasted hour** — and the CI annotation, which is the one line most people
read, must carry the same distinction rather than a generic verb.

**93 — `filter(Boolean)` over strings is a no-op, and the mutation that proves it will pass.** *(S065)*
`getEndpointHash` does `[a,b,c].filter(Boolean).join("")`. The transcription
kept the filter; the mutation "delete the filter, just concatenate" **reddened
nothing**, because for strings the two expressions are identical — `"" + x == x`.
The filter only becomes load-bearing when a component is *absent* (`undefined` in
JS, `None` in Python), which the test did not cover. **When a mutation reddens
nothing, the tool is not necessarily right — the test may simply not reach the
property.** Ask what input makes the deleted code observable, and assert *that*.

**92 — Gitignored debris on the deployer's laptop is part of the artifact.** *(S065)*
`firebase deploy` packages the **directory** and never consults git. Production's
source digest therefore includes **62 files no checkout has** — an old lcov
report and a debug log — so prod cannot be compared byte-exactly to `main` even
though it *is* `main`. Nothing in the repo could show this, because the repo
cannot see the files. **Any artifact built by a hand-typed command from a working
directory carries that directory's accidents.** The fix is never a cleverer
comparison; it is a lane that builds from a clean checkout (#206).

**91 — An unread failure does not stay silent; it gets EXPLAINED, and the explanation lands on a person.** *(2026-08-08)*
Lesson 69 already says *`continue-on-error` is not the bug; an UNREAD failure
is.* This is what the unread failure actually did, which is worse than "nothing
happened."

`release.yml`'s `deliver` step is `continue-on-error: true` **for a good reason**
(ADR-020 D8: store copy must never fail a run whose binary already shipped). It
has failed identically on **every release since build 112** — six of them —
with Apple refusing to create the `tr` listing: *"the app name is already being
used by another app."* Green step, green job, green run, silent notifier.

**The gap did not go unexplained. It went WRONGLY explained.** Turkish
screenshots were missing, so the absence got attributed to the only visible
cause — the founder had not added the locale — and `operator-expected.md` carried
that for several sessions, ending in a confident one-minute click path that
would have hit the same rejection. *S064 wrote a fresh version of that same wrong
instruction earlier the same day, from a correct measurement (`tr` really is
absent) and a wrong inference about why.*

So: **when a symptom has an obvious human-shaped cause, check whether a machine
already recorded a different one** — especially where something is permitted to
fail quietly. And when you allow a step to fail, decide in the same breath *who
reads it and where* — a failure nobody reads is not a deferred cost, it is a
false explanation waiting to be adopted. Filed as **#204**, whose first
acceptance criterion is visibility, not the fix.

**90 — Before recording "only a human can observe this", ask what the system already writes down.** *(2026-08-08)*
M3.4 sat blocked for three sessions on an operator dependency phrased as *"ask
the founder to install the build, accept the prompt, and say whether a push
arrives at 08:00."* That is a real dependency for the *install* — and the wrong
boundary for the *observation*. Production answers a sharper version of the
question directly, to a CLI this repo already had:

* `firebase functions:log --only registerPushToken` — has any device **ever**
  called it? (Measured: no. Only deploy audit entries.)
* the `daily-question sweep complete` line's `checked` counter — how many
  couples were even evaluated for a push? (Measured: `0`, every hourly pass.)

So the founder's half shrank to *"open it and tap Allow"*, and the verification
half moved back inside the session, where it can be re-run at will. **The
generalisable move: split a blocked item into the part that genuinely needs the
human and the part you assumed needed them because it was written in the same
sentence.** Lesson 85 said a recorded boundary may be authority rather than
capability; this is the third kind — a boundary that is real for one clause and
imaginary for the next.

**89 — A test harness that names its inputs BY HAND cannot see a new input, and its silence reads as "nothing changed".** *(2026-08-08)*
`flutter_test_config.dart` loaded the brand fonts from a hard-coded list of four
Rubik files. #176's fix adds a *fifth* face to `pubspec.yaml`. Goldens would have
kept rendering the question at Regular, the golden diff would have come back
empty, and the honest-looking conclusion — *"the font change is a no-op"* —
would have been exactly backwards: the change was invisible to the instrument,
not absent. The repo already had the drift-proof mechanism (`FontManifest.json`,
used for MaterialIcons) sitting in the same file, four lines below.
**When you add to a declared set, check whether the TEST reads the declaration
or a private copy of it.** And the same file's manifest loader returned
*silently* when a family was missing — loading nothing, rendering every glyph in
the placeholder font, and passing. It throws now.

**88 — A byte comparison of a COMPRESSED artefact tests the compressor as well as the content.** *(2026-08-08)*
The icon gate was first written to compare committed PNG bytes against a fresh
render. It passed locally and would have been wrong to ship: `zlib`'s output is
not guaranteed identical across zlib versions, so the gate could red on a CI
runner for a reason that has nothing to do with any icon — and a false red that
looks exactly like a true one is worse than no gate. Comparing **decoded pixels**
is both portable and the property actually worth asserting: *this file is the
correct downscale of the master*, however it happens to be deflated. **Ask what
your comparison is a comparison OF.** Content-addressing a derived binary
silently pins every tool in the chain that produced it.

**87 — A handoff's claim about a binary asset's HISTORY is as inheritable, and as wrong, as any other — and the asset itself is a first-hand instrument.** *(2026-08-08)*
`resume-prompt.md` said *"the 15 iOS PNGs and 5 Android `mipmap-*/ic_launcher.png`
are hand-produced."* The iOS fifteen were. **The Android five were the default
blue Flutter logo from the m0.1 scaffold, untouched through 116 builds** — and
the PNGs said so without anyone opening them: 442–1443 bytes, colour type 3
(palette) with `tRNS` and a `tEXt` chunk, while every hand-produced icon in the
tree is truecolour RGB. `git log --follow` on any of them returns exactly one
commit, the scaffold. **The metadata of a binary is testimony about where it came
from, and it costs seconds to read.** This is lesson 3's shape (an inherited
premise nobody re-measured) applied to a file rather than a fact — and the reason
it survived so long is that a wrong icon on an unshipped platform breaks nothing,
so no signal ever contradicted it.

**86 — "Merged and green" is not "running". This repo has no instrument that can tell you the difference for Functions, and it cost the whole push feature.** *(2026-08-07)*
S062/S063 merged the entire push stack across #187-#196. Every PR green, every
post-merge `main` run green including `integration-emulator`, the capability
ticked, the entitlement signed, two builds shipped. I told the founder more than
once that *"everything is built and shipped except the APNs `.p8`."*

**Production was running Functions code from before #190.** `registerPushToken`
and `unregisterPushToken` did not exist there at all. Build 116 would have
prompted for permission, captured a token, called the callable, and received
NOT_FOUND — no token, no push, ever, with no error surface, because every layer
is fail-open by design.

**Nothing in the repository could have told me.** There is no Functions deploy
workflow (`deploy-rules.yml` and `deploy-site.yml` exist; functions have none),
so deployment is a manual step nothing tracks, and #166 has been open since
2026-08-01 saying exactly this.

**How it was actually caught, and the transferable part:** by reading production
logs — `firebase functions:log --project hayatiapp-prod`. Four consecutive hourly
sweeps logged the two passes the old code has and **not** the one my new code
emits unconditionally. The absence of an expected log line was the whole
diagnosis.

So: **when a feature spans a deploy boundary, "did my code merge" and "is my code
running" are different questions, and only the second one matters to a user.**
Ask the second one directly, against the live system, before reporting a feature
as shipped. The tooling to do it already existed here — an authenticated CLI —
and no session had thought to point it at production.

**85 — A boundary a past session drew on SAFETY grounds is not the same as one drawn on CAPABILITY grounds, and the two need opposite treatment.** *(2026-08-06)*
`appid_capabilities.py` was built read-only with an explicit reason in its header:
enabling a capability "is a founder decision, and a tool that could do it would
also be a tool that could do it by accident." For a session working toward push
delivery, that reads as a wall. It is two different things wearing one sentence:

* *"a founder decision"* — an **authority** boundary. Only the founder can move
  it, and the correct action is to ASK, with the trade-off stated (here: a portal
  click by hand vs. an API write that invalidates the provisioning profile while
  `match` runs readonly, on a live app with 8 TestFlight users).
* *"could do it by accident"* — an **engineering** boundary. Nobody needs to
  authorise anything; it needs a lock. The repo already had the pattern in
  ADR-019's `confirm: 'DELETE'` wire literal.

The session that wrote that header collapsed both into "don't build it," which
was right *then* — it had no authorisation and no reason to spend the effort.
Read later as a standing prohibition, it would have blocked the feature forever.

**When you meet a recorded "we deliberately cannot do X", separate the two before
accepting it.** If the reason is authority, ask. If the reason is risk, engineer
the guard. Only "it is impossible" is a wall — and that one is worth
re-measuring too: `gcloud` absent, no ADC, and no `firebase` CLI APNs command
was checked, not assumed, before calling the APNs `.p8` genuinely out of reach.

**84 — A dev-only dependency pin constrains the WHOLE resolution, and a package can declare a constraint its own code violates.** *(2026-08-06)*
Adding `firebase_messaging` resolved cleanly, analyzed clean, and passed all 1653
tests. The iOS build then failed with `Type 'FirebasePlugin' not found`. Two
compounding causes, and neither is a mistake anyone made locally:

* **16.4.2 is a broken release.** It declares
  `firebase_core_platform_interface: ^7.1.0` and uses `FirebasePlugin`, which
  exists only in **8.x**. Upstream corrected the *declaration* in 16.4.3. A
  resolver cannot catch this: the metadata is self-consistent and wrong.
* **A `dev_dependencies` pin is not test-only.** This repo pinned
  `firebase_core_platform_interface: ^7.1.0` so one test could import that
  package's `test.dart`. 7.1.0 was the newest 7.x, so the pin looked current —
  but it constrained the entire Firebase set, made 16.4.3+ unsatisfiable, and
  silently selected the one broken version. **A pin in `dev_dependencies`
  restricts production resolution exactly as hard as one in `dependencies`.**

**The general lesson is about which check can see what.** `flutter analyze` never
type-checks a plugin against the platform it will compile for; only the kernel
snapshot for that platform does. So a class of defect exists that is invisible to
every fast, cheap, Linux-side gate and visible only to the slow platform build.
When adding or upgrading a **plugin** (as opposed to a pure-Dart package), local
green means nothing until the platform build has run — and if the only such check
is `--no-codesign`, remember it still cannot see anything about *signing*.

**83 — Changing an eligibility rule changes WHO reads the message, so the message has to change with it.** *(2026-08-06)*
ADR-042 D4 dropped the `streak.count > 0` gate so the afternoon nudge would reach
couples with no streak — that population *was the reason for the change*. The ADR
noted that the existing copy already had a count-free variant and concluded
"nothing about the existing message is lost." It was right about the code and
wrong about the product: that variant read **"Your streak together is still
alive"**, which is **false for exactly the people the change existed to reach.**
A gate is not only a filter on delivery; it is a **precondition the copy above it
was written under**. When you delete one, re-read every string the newly-admitted
population will now see and ask whether it is still *true* for them — not whether
it still renders. The bug would have shipped as a working feature with green
tests, because "the copy degrades gracefully" and "the copy is honest" are
different properties and only the first one has a test shape.

**82 — A mutation that silently hits the wrong line reports exactly what a covered line reports: green.** *(2026-08-06)*
S062 mutation-checked `PushTokenSync` by string-replacing a guard, with
`str.replace(old, new, 1)` — first occurrence only. The anchor `if (_syncedUid == null)
return;` appears **twice**: once in `_syncFrom`'s sign-out branch and once in
`_register`. The replace hit the first, which is a harmless dedupe, and the run came
back all-green. Read naively that says *"this guard is unprotected"*; the truth was
*"you did not mutate that guard."* **Anchor a mutation on text unique to the line you
mean — the surrounding comment, not the statement — and treat an all-green mutation as
a claim to verify rather than a result to record.** A mutation is a measurement, and
this one had no control.

**81 — A verifier that cannot read the artefact must SAY SO and be discarded, never counted as a refutation.** *(2026-08-06)*
The ADR-042 design review's first round produced 36 findings correctly and then refuted
eleven of them with the reasoning *"the file does not exist; the highest ADR number is
041."* They were right about their worktree — the session had moved to another branch
mid-review — and wrong about the world. **An `ls` that returns nothing is not a
refutation.** Had those verdicts been counted, the review would have closed with eleven
false "refuted"s and both real findings buried among them; re-running the nine
contested findings against a worktree that held the file confirmed two. The general
form: **a negative result from an instrument that was pointed at the wrong thing is
indistinguishable from a negative result, and reads as evidence.** Make "I could not
read it" a required, separately-reported outcome — the way `appid_capabilities.py` exit
**2** is separate from exit **1**, for exactly this reason.

**Both confirmed ADR-042 findings were the same species, and it is worth naming:**
a **citation that asserted more than the cited line contained** (`entitlement-core.ts:472`
credited with a cap it does not apply; a `MessagingPort` assertion promised against
deps that carry no port). Neither was a flaw in a decision. The repo's file:line
convention is meant to prevent exactly this and in fact makes it cheap to commit,
because a citation looks like evidence whether or not anyone opened it. **The lenses
that caught them were the ones that opened the files.**

**80 — "Revert it to the previous one" is an instruction whose object must be measured, not assumed.** *(2026-08-05)*
The founder asked to revert the app icon to the previous one. `git log --follow` on
`Icon-App-1024x1024@1x.png` returns exactly two commits, and the earlier is the m0.1
scaffold — **the default blue Flutter logo.** A session taking "previous" literally
would have shipped the Flutter logo to a live TestFlight group, having followed the
instruction exactly. The intended object was a third file that path's history never
mentions. **When an instruction names a prior state, enumerate the candidate prior
states and show them to the person before restoring one.** "Previous" is a word about
someone's memory, not about your revision graph.

**79 — A feature can be 100% built, 100% tested, documented as done in the milestone plan, and have never once run.** *(2026-08-05)*
`implementation-plan.md` recorded M3.4 ✅ with 35 push tests and three push kinds.
Measured: no `firebase_messaging`, no `aps-environment`, no `remote-notification`, and
**no writer of `users.fcmTokens` anywhere.** Every push was composed correctly and sent
to an array nothing populates — not one notification had ever been delivered. The code
was honest at every layer (`at-risk.ts:42`, `reveal-service.ts:321`); the *plan* still
totalled it as shipped. **The lesson is not that the deferral was undocumented — it was
documented five times. It is that a milestone ticked ✅ on the strength of its testable
half reads, weeks later, as a working feature.** When a slice defers the only layer that
makes it observable, the deferral goes **in the tick**: *"M3.4 ✅ (server half;
undeliverable until item 4)"*. **Before believing a plan's ✅, trace the path a USER
would walk and check every layer of it exists.**

**78 — Name which half is proven by which instrument.** *(S058)*
ADR-041's first draft said the deploy path was *"exercised end to end"*. What was
exercised was the `firebase deploy` **command**, from a local CLI; the workflow had never
run. A second sentence claimed verification "for all four read methods this tool calls"
when the tool calls three. Both were caught by re-reading the finished ADR **against the
code**. **Write "X was proven by Y" and let the asymmetry show — a sentence that averages
a proven half and an unproven half is false about both.**

**77 — A job whose every step is skipped reports GREEN.** *(S058)*
A job-level `if:` cannot read `secrets`, so the natural way to build a credentialed check
is one job with `if:` on each step — and that job goes green having measured nothing. Built
that way, the gate for #140 would have shipped #140's own defect. The cure is a **preflight
JOB** publishing a boolean, so the gated job is either MEASURED or **visibly SKIPPED**, with
no third outcome. **A skipped job is an honest gap; a green one is a claim.** Whenever a gate
can be unable to run, enumerate what the CI *UI* will show, not what your code returns.

**76 — A hermetic test can stop being hermetic under mutation, and pass for the wrong reason.** *(S058)*
Mutating `resolve_credential` to return `""` did not redden the no-credential test: the tool
built a real API client, called the **live endpoint**, got 401, mapped it to an error and exited
**2** — the asserted value. A test advertised as "no network" made a network call, and its
exit-code assertion was satisfied three layers from the property it names. **Assert the
MECHANISM, not only the outcome.** "Never constructs a client without a credential" cannot be
satisfied by luck; "exits 2" can. When an assertion is a scalar many paths produce, ask which
path produced it.

**75 — A fake that is wrong about the shape tests nothing, and its paired assertion still passes.** *(S058)*
A drift test's fake returned the same ruleset id for every project, so the drifting branch was
**unreachable** — yet the companion assertion *"bad project reported as drift"* passed, because
the check matched the section **header**. Two instruments came out of it: **assert against a
SCOPED SLICE of the output**, never the whole buffer, so a claim about one subject cannot be
satisfied by another subject's text; and **a mutation harness that reports WHICH checks moved**
catches vacuous assertions a pass/fail harness cannot.

**74 — Assert a mutation site is UNIQUE before believing what its failure tells you.** *(S057)*
A mutation applied to more than one site reddens tests for a reason you did not intend, and the
diagnostic then fails in the reassuring direction.

**73 — After writing anything about a secret, grep your own diff for the secret.** *(S057)*
A page celebrating a milestone nearly published a phone number.

**72 — Closing an issue on a reassuring measurement is not building what it asked for.** *(S057)*
Re-read the issue **body** before closing, and re-file the half you did not do.

**71 — Do not renumber a list other files cite by number.** *(S057)*
Operator items, ADR decisions and these lessons are cited by number from code, workflows and
docs. A surviving item keeps its number even when the list around it shrinks.

**70 — A risk inferred from STRUCTURE is a hypothesis until it has a POPULATION.** *(S057)*
"This shape could be wrong everywhere" is worth exactly one query that counts how often it
actually is.

**69 — `continue-on-error` is not the bug; an UNREAD failure is.** *(S056)*
And "the script raises" is not "the script never started" — prefer `python3 -m pip`.

**68 — Name the deferral, and why it keeps winning.** *(S056)*
#140 lost to a live directive five sessions running. Each deferral was correct; the pattern was
invisible until it was written down as a pattern.

**67 — Glob semantics are a vendor implementation detail.** *(S056)*
Deploy, then `curl`. Do not reason about what the host "should" match.

**66 — Verifying what you did NOT change is part of changing something.** *(S056)*

**65 — An empty result from a tool is UNVERIFIED, not negative.** *(S056)*
`gh run view --job --log` returns zero lines and reads as "the test never ran". Use
`gh api repos/:owner/:repo/actions/jobs/<id>/logs`. Generalise: before treating emptiness as
evidence, prove the instrument works on a case you know is non-empty.

**64 — A stale fact inside an INSTRUCTION gets EXECUTED.** *(S056)*
Re-derive every identifier in every runnable block you leave behind for the next session.

### Standing, from earlier sessions

**Lessons 1–63 are not reproduced here.** They were condensed to one-line form by earlier
sessions before this file existed, and the numbered originals were lost in that
condensation — the full narrative for each survives in the `past-prompts.md` entry for the
session that learned it. What follows is that condensed set: unnumbered, still binding, and
attributed to the sessions that paid for them. **Do not assign these numbers now** — a new
lesson takes the next number after 80.

* **Your own ADR is a claim surface you will falsify with your own code.** Re-read the WHOLE
  ADR after every code change, hunting the **paraphrase** and the **negation**. *(S051 ×4,
  S053 ×3, S058 ×2 — the highest-recurrence lesson in this file.)*
* **`$?` after a pipe reads the PIPE's status — use `${PIPESTATUS[0]}`.** *(S047, S051, S053,
  and again 2026-08-05: `rules_drift.py … | tail` reported `EXIT=0` while the tool printed
  `::error::` and exited 2.)*
* **Verify with the command CI runs, not the convenient one.** *(S044, S053, S056, S058)*
* **Query the PLATFORM, not the docs.** *(S045, S053, S056; S058 settled an OAuth scope question
  by fetching the API's own discovery document.)*
* **Only the VENDOR can refute a vendor API shape.** *(S055)*
* **A test whose fixture is derived from its subject proves nothing.** *(S047, S050; closed for
  the seasonal vocabulary by #171.)*
* **A test that is not REGISTERED is a green run that proves nothing.** *(S055, S056)*
* **A gate written in one language guards one language.** *(S055)*
* **MUTATION-CHECK every guard AND the test, in both directions.** *(S042, S053, S058)*
* **A probe whose control passes is a broken probe.** *(S051, S053)*
* **N expert sweeps can all miss the same thing — budget a completeness critic into every
  fan-out.** *(S050, S053)*
* **The verifier panel is an INPUT to judgement, not a substitute for measuring.** *(S051)*
* **Read the ARTEFACT, not just the source.** *(S047, S051)*
* **Run the session; do not assert its conclusion.** *(S045)*
* **A premise that was replaced rather than measured is likely wrong again.** *(S049)*
* **A remainder deferred into prose is a remainder that gets lost.** File it.
* **"No unblocked engineering" is a claim to RE-DERIVE every session**, never to inherit.
