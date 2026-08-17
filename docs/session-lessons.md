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
