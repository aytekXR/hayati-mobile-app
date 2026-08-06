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
