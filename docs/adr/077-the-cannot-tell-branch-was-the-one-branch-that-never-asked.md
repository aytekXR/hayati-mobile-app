# ADR-077: The "cannot tell" branch was the one branch that never asked

- **Status:** Accepted. **A hole in ADR-076's fix, closed before anyone installs
  anything** — and two sentinels put in front of the surfaces that let it, and
  the two methods before it, ship unguarded.
- **Date:** 2026-09-13 (Session 102)
- **Deciders:** session agent. **Nothing deployed, no release dispatched, no
  build cut.** ⚠️ **Build 121 — on TestFlight now, awaiting the founder — does
  NOT carry D1.** See D4.
- **Related:** **ADR-076** (the fix this corrects — its Appendix A points here),
  **ADR-074** (the refusal callback, the other unpinned method), **ADR-044 D1**
  (the bounded capture that calls this six times), **ADR-042 D2** (the thin
  adapter and its *deliberately untested* trade), **ADR-018 D6** (the one
  platform channel), **ADR-055** (the watchdog that named the CI failure in D3),
  lessons **135**, **143**, **151**, **159**

## Context — reviewing a fix after it has shipped

ADR-076 landed on 2026-09-06 and went out as **build 121** the same day. Its
argument: nothing in this project had ever *asked* APNs for an address, because
the request came only from `firebase_messaging`, behind an initialisation
ordering this app does not control. Its remedy, **D2**, verbatim:

> **It fires from `isReadyForToken`, when the answer is "no address".**

The code it shipped did not do that on one of its paths. `isReadyForToken()`
reads `getAPNSToken()` inside a `try`, and the `catch` returned:

```dart
try {
  if (await _messaging.getAPNSToken() != null) return true;
} catch (_) {
  // Not "no" — "cannot tell". The caller retries either way, and a throw
  // here must never be louder than a null.
  return false;          // <-- and asked nobody
}
```

The nil path fell through to the new request. **The throw path returned before
reaching it.** So the branch whose own comment says *"Not 'no' — 'cannot tell'"*
— the state where *having no address* is most likely and asking for one is worth
most — was the only branch that skipped the ask.

⚠️ **And it is not a hypothetical shape in this app.** `getAPNSToken()` reaches
`[FIRMessaging messaging]`, a **default-app accessor**, and this app has no
`FirebaseApp` until Dart configures one from pure-Dart `FirebaseOptions`. That
is *the same root cause ADR-076 is about*, arriving as a throw instead of a nil.
The failure mode most likely to produce this throw is the one the fix was
written for — and the fix declined to act on it.

## Decision 1 — A throw is two answers, and only one of them is "no"

The `catch` is asked two different questions by two different readers, and the
honest answer differs:

| the question | who asks | answer on a throw |
|---|---|---|
| *are we ready to mint a token?* | the caller, via the returned `bool` | **no** — unchanged, `false`, and the bounded retry keeps its meaning |
| *do we have an address?* | the request below it | **cannot tell**, which for the purpose of *asking* is the same as **no** |

Conflating them is what produced the defect: one `return false` answered the
first question and silently answered the second one too.

The read now records into a local and both paths converge on the request:

```dart
var hasAddress = false;
try {
  hasAddress = await _messaging.getAPNSToken() != null;
} catch (_) { /* falls through */ }
if (hasAddress) return true;
unawaited(_askApnsToRegister());
return false;
```

**Every return value is unchanged on every path** — the nil path, the non-nil
path, the non-iOS path and the throw path all return exactly what they returned
before. The only difference is that the throw path now issues the request. The
cost is bounded by the same thing that bounds every other path:
`PushTokenSync.tokenCaptureAttempts` is **6**, so a phone whose `getAPNSToken()`
throws every time issues at most six `registerForRemoteNotifications` calls per
capture run, which Apple documents as idempotent (ADR-076 D1).

⚠️ **The local is `var`, and the comment names the analyzer's own diagnostic
rather than a paraphrase of it.** A `final` local written from both the `try`
and the `catch` is rejected as `assignment_to_final_local` — *"The final
variable 'hasAddress' can only be set once."* Measured here, in a four-line
file, rather than recalled: the first version of this comment said "definite
assignment analysis" and named no diagnostic, which is the shape of a claim
nobody can check (lesson **153**).

## Decision 2 — An unreachable branch gets a SOURCE SENTINEL, not a skipped test and not a refactor

D1 cannot be tested on this box, and that was established rather than assumed —
three independent barriers, each checked:

1. **The branch is behind `if (!Platform.isIOS) return true;`.** `Platform.isIOS`
   is `dart:io`'s `static final bool isIOS = (operatingSystem == "ios")`, read
   from the host OS. It is **not** `debugDefaultTargetPlatformOverride` (which
   moves Flutter's `TargetPlatform`, a different type for a different purpose),
   and `IOOverrides` covers `File`/`Directory`/`Socket`, not `Platform`. On
   Linux the branch is unreachable, full stop.
2. **The change is invisible above the port.** `PushTokenSource.isReadyForToken`
   returns `Future<bool>`; the throw path returned `false` before and returns
   `false` after. What changed is a fire-and-forget side effect the port does
   not expose — so no fake can observe it and no seam moves.
3. **The fake cannot produce the input.** `push_token_sync_test.dart` models
   `currentTokenThrows` for `currentToken()` and nothing for `isReadyForToken`,
   because the port never specified that state.

Two alternatives were considered and refused:

* **Widen the port so the behaviour is observable.** That moves a decision into
  the adapter layer ADR-042 D2 deliberately kept empty of decisions, to make one
  invisible branch testable. The seam would then exist for the test rather than
  for the design.
* **Write nothing, on ADR-042 D2's "deliberately untested" licence.** That
  licence is about an adapter *with no branches of its own*. This method now has
  four paths and an invariant — the ABSENCE of a `return` — that no reader can
  see and that already regressed once.

So: a sentinel over the source, asserting **the catch after `getAPNSToken()`
contains no `return` statement**, and that the call it falls through to is still
made. Same trade `signing_sentinel_test.dart` and
`device_privacy_channel_parity_test.dart` already make for surfaces `flutter
test` cannot reach; the new part is that the property is **control flow inside
one method** rather than a file's contents.

⚠️ **Mutation-checked in three directions, because a sentinel nobody has seen
fail is a claim** (standing lesson): restoring `return false;` in the catch
fails it; removing the `unawaited(_askApnsToRegister())` call fails it; deleting
the sentence that explains the fall-through fails it. **The third mutation is
the reason one assertion is written as it is** — it was first written as
`contains('_askApnsToRegister()')` scoped "up to the next `@override`", and the
private helper has no annotation, so its own *declaration* fell inside the
window and satisfied the assertion with the call site deleted. **The test was
green over the mutation until the mutation was actually run.**

### ⚠️ D2.1 — and the built-diff review found the sentinel green over the likeliest re-introduction

The design pass produced the sentinel; the **second** pass, over the built diff,
found a hole in it. Recorded here because the sentinel's whole value is that it
cannot be quietly wrong.

The `return` check was anchored: `^\s*return[\s;]`, matched line by line. The
anchor existed for a reason — the catch body is **all comments**, and its prose
says *"rather than returning"* and *"the early return made"*, which an unanchored
`\breturn\b` would match. But an anchored pattern **misses
`if (cond) return false;`** — and a single-line conditional return is this file's
own house style, used **three** times in it (`if (!Platform.isIOS) return true;`
and two more). So the guard was green over the most plausible way the bug comes
back.

The fix removes the reason for the anchor rather than working around it: the
extractor now walks to the **matching** brace while skipping `//` comments, and
keeps two strings — the body verbatim, and the body with comments stripped. The
`return` scan runs on the stripped text, unanchored.

⚠️ **That also closed a second hole nobody had noticed**: the first extractor
stopped at `source.indexOf('}', …)`, so a single `}` written inside one of the
catch's own comment sentences would have silently truncated the window every
assertion measures — green, over a fragment.

**Re-mutation-checked, four ways, and the fourth is the one that matters:**

| mutation into the catch | before | now |
|---|---|---|
| `return false;` | fails ✅ | fails ✅ |
| **`if (hasAddress) return false;`** | **PASSES ❌** | fails ✅ |
| `if (hasAddress) { return false; }` | **PASSES ❌** | fails ✅ |
| a `}` in a comment, then `return false;` | **PASSES ❌** | fails ✅ |

⚠️ **And the first attempt at that fourth mutation was itself broken** — a `\n`
inside a double-quoted shell argument stayed literal, so the whole insert landed
as one comment line and the test passed for the wrong reason. Caught by reading
the mutated file instead of the exit code. **Lesson 161 twice in one session.**

⚠️ **The refuting verifier got this one wrong, and that is worth recording.** It
returned **REFUTED**, on the grounds that the lines the finding cited as evidence
(`if (!Platform.isIOS) return true;` at the top of two methods) sit *outside* the
window the regex scans — which is true, and is about the finding's **evidence**,
not its **claim**. The claim was that a conditional return *inside* the catch
would evade the guard, and four minutes with the regex confirms it does. *A panel
is an input to judgement, not a substitute for measuring* (standing lesson).

## Decision 3 — The `integration-emulator` red on 3b0eaf3 is the known flake, and the evidence is not "it passed later"

ADR-076's own merge run (**34042187123**, `3b0eaf3`) failed:

```
##[error]integration_test/auth_emulator_test.dart SILENT for 600s (bound 600s)
```

and the three `main` runs after it **skipped** the job (docs-only paths, by
design), so `main`'s last full pipeline stood red and unexamined for six days.
The correlation was exact — green at `d7aca04` (ADR-074), green at `188025a`
(ADR-075), red at `3b0eaf3` (ADR-076) — and that is precisely the shape that
deserves suspicion rather than a shrug.

It is not a regression, and the load-bearing evidence is **not** that a later
run passed:

* **The code path is not reached.** `auth_emulator_test.dart` calls
  `initializeFirebase()` and constructs `FirebaseAuthRepository` directly. It
  never touches `PushTokenSync`, `FcmPushTokenSource` or `isReadyForToken`, so
  the channel method ADR-076 added is never invoked by the suite that hung.
* **The same signature has appeared on a diff with zero app code.** S088 hit
  `SILENT for 600s` on *this same suite*, with the same
  `Error waiting for a debug connection: The log reader failed unexpectedly`
  and the same `No tests ran`, on a diff of docs and Python only.
* **The hang is before the tests, not inside them.** The log shows
  `Xcode build done. 229.5s`, then 5,817 bytes of output and silence — the app
  never reported a single test.

⚠️ **ADR-055 did its job and should be read as the good news here.** The job
**FAILED with the suite named** instead of being **cancelled** at
`timeout-minutes` — which is the difference between a Slack message and silence,
and the whole point of that ADR.

**And then it was measured directly, which is better than either argument.**
`integration-emulator` is `main`-only, so a PR cannot run it — but the job's own
comment names the way round that, and it was used: `gh workflow run ci.yml --ref
<branch>` (`workflow_dispatch` is in its `if:`). Run **34751782953**, over
`8a28215` — which contains everything in `3b0eaf3` — came back

```
integration-emulator   success
ios-build-smoke        success
quality                success
```

⚠️ **That is containment, not a diagnosis, and the difference matters.** A pass
here is compatible with *"the flake did not happen this time"*, which is exactly
what a flake is. It is worth having because the alternative hypothesis — a
regression — predicts a **reproducible** failure over the same code, and this run
refutes that prediction. The path evidence above is what carries the verdict; this
is the cheap check that the verdict is not obviously wrong.

⚠️ **What this is NOT is a diagnosis of the flake.** `ci-debt #15` stays open and
the simulator hang is still undiagnosed. What is decided here is only that
ADR-076 did not cause it.

**What the failing job's own diagnostic block did record**, and it narrows the
hunt enough to be the next session's objective: at the moment the watchdog fired
the simulator was `(Booted)`, ports **8080 / 9099 / 5001 all ANSWERING**, and the
tool said `No tests ran.` beside *"Error waiting for a debug connection: **The
log reader failed unexpectedly**"*. Not the emulators, not a dead simulator, not
a slow runner: `flutter test` discovers the Dart VM service by **scraping the
simulator's system log**, and that reader failed — after which silence is
guaranteed, because the tests never start.

## Decision 4 — Build 121 carries the hole, and the founder is told that plainly

The founder is holding build 121 and an instruction to install it. D1 is **not**
in it. That is written into `operator-expected.md` rather than left for someone
to infer from a version number, and it is written without inflating it:

* **121 is still worth installing, and the instruction stands.** The hole only
  bites if `getAPNSToken()` actually *throws* on that phone; a nil — the common
  case, and the one production has shown twice — reaches the request in 121 just
  fine.
* **If 121's report still says `captureExhausted`, that result is no longer
  clean**, because one path in it could have skipped the ask. Build 122 is what
  makes that reading unambiguous.
* **No claim that this was the bug.** It is a hole in a candidate fix, closed
  before anyone installs anything, at the cost of a build rather than a round
  trip through a founder's phone.

## Decision 5 — The channel sentinel is completed in both directions, because it was green over an unpinned surface

Found on the way to D1, and the more serious of the two defects.

`device_privacy_channel_parity_test.dart` exists for exactly one failure mode,
in its own words: *"a renamed method … compiles perfectly and ships a **silently
dead feature behind a green pipeline**."* Its pinned list held **five** methods.
The channel has **seven**. The two it did not pin are the two newest:
`apnsRegistrationFailure` (ADR-074) and `ensureRemoteNotificationRegistration`
(ADR-076) — **including the one the entire push feature now rests on.**

A rename of `ensureRemoteNotificationRegistration` on either side would have
reproduced ADR-076's own bug — nobody asks APNs, no address, no error — with
every gate green. **Two consecutive sessions added a method to the one channel
and neither pinned it**, and the sentinel's silence read as coverage.

Three changes, all of them structural rather than another list to keep by hand:

1. Both methods added to the pin.
2. **The reverse direction, which did not exist.** The old test walked the list
   and proved each entry is on both sides — which says nothing about a method
   that is on both sides and *not in the list*. It now reads every `case "x"` out
   of the Swift handler and every `invokeMethod<…>('x')` out of the Dart client
   and requires both sets to be exactly the pin. **An unpinned method is now a
   red test**, which is the only version of this guard that maintains itself.
3. **The dartdoc's own count is gated.** The class comment opened *"It carries
   the seven native methods this layer needs"* and then listed **six** — the
   count and the list had drifted apart inside a single comment, and the missing
   bullet was ADR-076's method. The stated number, the pin's length and the
   number of bullets must now agree.

Mutation-checked in four directions: dropping a method from the pin, renaming
the Swift case, changing the dartdoc's number word, and deleting a bullet each
turn the file red.

## Consequences

**Positive**

- The state where asking APNs is worth most is no longer the state that skips
  the ask, and `isReadyForToken`'s return contract is untouched on every path.
- The two newest methods on the app's one platform channel are pinned, and a
  *future* unpinned method fails the build rather than waiting for a session to
  notice.
- `main`'s six-day-old unexamined red is examined, and attributed on path
  evidence.
- A doc claim and its documented count can no longer disagree inside the same
  comment without a red test.

**Negative / accepted trade-offs**

- **Still unverified against a device**, like everything in ADR-074/075/076.
  Format clean, analyze clean, the full suite green, `ios-build-smoke` compiled
  the Swift. The first real exercise is a build, and that is operator item 4.
- **A source sentinel is not an execution test.** It proves a statement is
  absent, not that the runtime behaves. It is the best available instrument on
  Linux for this branch, and D2 says so rather than implying otherwise.
- **It pins a sentence in a comment**, which will annoy someone rewording it.
  The invariant is the *absence* of a statement, and prose is the only thing
  that can tell the next reader why — `project-rules.md` #8 already makes that
  prose part of the implementation.
- **D5 widens a test from a hand-kept list to a regex over two files.** A future
  `switch` over strings elsewhere in `AppDelegate.swift` will trip it. That is
  the intended failure direction: it asks a human whether the new surface
  belongs on the pin.

## Erratum — ADR-076's test count

ADR-076's Consequences says *"Format, analyze and **78 tests** pass locally"*,
and its commit message says the same. **78 is not reproducible at that tree.**
Re-measured here, with the commands beside the numbers:

| command | count |
|---|---|
| `flutter test test/features/notifications/` | **69** (and **72** with this session's sentinel) |
| `flutter test test/features/notifications/ test/features/settings/` | **151** |
| `flutter test` | **1883** |

The folder ADR-076 changed was unchanged between `3b0eaf3` and this session's
first commit, which is why **69** is also what that commit's message reports —
correctly. Where 78 came from is not reconstructible, and it is recorded as an
erratum rather than quietly corrected: lesson **153** is that the command beside
a number must be the one that produced it, and here it was not.
