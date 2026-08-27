# ADR-063: the loop stopped six days ago, and the instrument built to notice returned "could not measure"

- **Status:** Proposed
- **Date:** 2026-08-27 (Session 087) · **Revision 2, 2026-08-28** — the design review found a **blocking** hole in D2's exit rule, showed D2 could not be implemented against `verdict()`'s signature, and **refuted Finding 4's central claim**; all three are folded in below
- **Deciders:** the session agent for the instrument, the comments and the proof; **the founder** for the billing account — a closed account is a payment action on their Google identity and nothing here can reach it
- **Related:** **#219** (the *first* time this happened, 2026-08-09→11, and the reason `prod_pulse.py` exists), **ADR-041** (exit codes are a taxonomy: 0 / 1 finding / **2 could not measure**), **ADR-011** (the hourly sweep), **ADR-012 D3** (both push passes ride ONE couples read; the injectable `MessagingPort`), **ADR-042 D2/D3** (the token lifecycle and the hour the founder asked for), **ADR-044** (APNs readiness and the bounded capture), **ADR-045** (the hours re-pointed to **9** and **22**, and the quiet window moved to 23:00–08:00 so they could exist), **ADR-046** (the permission state is app state — and iOS gives **one** dialog per install), **ADR-049** (the device reports *why*, and a no-report is not a reason), **ADR-025 D8** (a declaration can be discipline rather than a CI gate), issues **#136**, **#253**

> **Review status.** Revision 1 was written and committed **before any code**
> (`session-context.md` §5 item 1, lesson **115**). **Revision 2 folds the design
> review**: 4 lenses × 2 independent verifiers, **`agents_error=0`,
> `agents_empty_result=0`**, 11 findings raised, **11 verified, 0 dropped
> unverified**, **3 surfaced**. Every number below was measured on 2026-08-27/28
> with the commands recorded inline; none is inherited.

## Revision 2 — what the review changed

**1. D2's exit rule had a hole in the dangerous direction (blocking).** As written
it said *exit 2 only when nothing could be measured; exit 1 if any fact was
measured and any is a finding* — which leaves **exit 0** covering *"some facts
measured, none of them a finding, and the decisive fact unmeasurable"*. Billing
healthy + scheduler ENABLED + Logging 403 would have printed **"the daily loop is
running"** while unable to see a six-day-stale sweep. ADR-041's rule is
**"never 0 without having compared"**, and this design would have. **D2 is
rewritten**: findings → 1, else **any gap → 2**, else 0.

**2. D2 could not be implemented against the function it delegates to (major).**
`verdict()` takes `last_sweep: datetime | None` and `job_state: str | None`, where
`None` already means *"I looked and found none"* — a **finding**. There is no value
to pass for *"I could not look"*. So D2's own sentence — that the two must be
different lines in the same report — was unimplementable, and worse: today's
scheduler 403 would have arrived as `job_state=None` and produced the **false
finding** *"no Cloud Scheduler job for questionRollover — the sweep has no
trigger"*. **D3 (new) makes gaps a first-class input that SUPPRESSES the paired
absence-finding.**

**3. Finding 4's central claim was wrong, and the review is right.** Revision 1
said the permission grant would be *"spent for nothing"* and was *"the only
resource in the chain that cannot be re-requested"*. Measured at
`push_token_sync.dart:237-258`: `_syncFrom` runs on **every** `AuthSignedIn`
transition — including a cold launch on a restored session, because `build()`
syncs the current state before it listens — and calls `_captureAndRegister()`
unconditionally. **iOS keeps the grant; the app re-attempts registration by itself
on the next launch.** So doing ② first does not destroy anything. Finding 4 is
rewritten to the argument that survives, which is a different and weaker one.

## The one-sentence version

The 09:00 daily question has not been silent because no phone registered a token.
It has been silent because **the sweep that composes it has not completed since
2026-08-22T02:00Z** — the project's billing account is **closed** — and the
instrument built after the last identical outage answered **"could not measure"**,
because the API it asks second returns 403 *for the very reason* it exists to detect.

## Context — five things answer "why is push silent?", and one of them is honest

### 1. The device probe — honest, and it is not the whole answer

```
$ python3 tool/ci/push_delivery_probe.py --from-firebase-cli        # exit 1
hayatiapp-prod: 0/4 account(s) have registered a device
  6RNddHbXZ3RsOu6Ur05Zt4dANte2: no report
  CIWIARSsxoVDCArCZ9oFtMgIVGb2: no report
  ZCBj6HqSE2hVI5gW5FiQbMDRNS53: no report
  lvny6fJrOUQxz9jHKgjoc7G6vgG2: no report
```

It then says, correctly, that a no-report is **not distinguishable** from "no build
carrying the diagnostic ever ran here" (lesson **65**). That is the honest one. It
reports the device half, it is right about the device half, and the device half is
not where the loop is broken.

### 2. The instrument built for exactly this — and what it said

```
$ python3 tool/ci/prod_pulse.py --from-firebase-cli                  # exit 2
could not measure: https://cloudscheduler.googleapis.com/v1/projects/hayatiapp-prod/locations/europe-west1/jobs returned HTTP 403
```

`prod_pulse.py` exists because of **#219**: between 2026-08-09T18:00Z and
2026-08-11T07:19Z the sweep did not run once, Cloud Run refused all 38 invocations
with *"billing is disabled for this project"*, and `operator-expected.md` reported
*"Your app is running"* the whole time. Its docstring says it is here to make that
mistake impossible.

**It has now met the identical outage and returned "could not measure."**

### 3. The truth, measured by hand with the same credential

| measurement | result |
|---|---|
| `cloudbilling…/billingAccounts/012195-7EF76F-3A9083` | **`"open": false`** — the account ("Firebase Payment", TRY) is **CLOSED** |
| `cloudbilling…/projects/hayatiapp-prod/billingInfo` | **`"billingEnabled": true`** — the project is still **LINKED**, so the project-level flag reads healthy |
| the Cloud Scheduler 403 body | *"This API method requires billing to be enabled."* — the 403 **is a billing symptom**, not a permissions problem |
| `questionRollover` Cloud Run error stream | *"The request failed because billing is disabled for this project."* — **every hour since 2026-08-22T02:00:01Z** |
| last `question_rollover: sweep complete` | **2026-08-25T15:00:11Z** (`assigned:1`) — a single one-hour recovery; before it, **2026-08-22T01:00:06Z** |
| `projects/hayatiapp-dev/billingInfo` | linked to the **same closed account** — dev is dead too |

**The production daily loop has been dead for ~5 days and 20 hours.** No day doc is
created at local midnight. So even a phone holding a valid token would receive
nothing at 09:00: `runDailyQuestion` would read a missing day doc, count
`skippedNoDay`, and send zero pushes. **Every link downstream of the sweep is
irrelevant while this is true.**

### 4. Five comments tell a reader the device half cannot work yet. All five are false

| file | claim | since |
|---|---|---|
| `push_token_source_provider.dart:9` | *"**Nothing overrides this yet**, and that is the design"* | both entrypoints override it |
| `main_dev.dart:228` | *"It is **INERT** until the entitlement lands. `aps-environment` is **absent**"* | the entitlement landed **2026-08-07** |
| `push_token_source.dart:9` | *"There is deliberately **no implementation** of this yet"* | `FcmPushTokenSource` exists and is wired |
| `fcm_push_token_source.dart:29` | *"correct and **inert today**, and becomes live the moment the entitlement lands"* | it is live |
| `recipients.ts:46` | *"**NOTHING writes this field yet** — app-side capture is … deferred to the on-device slice"* | `push-token-service.ts:59` writes `fcmTokens` |

`main_prod.dart:217` already carries a ⚠️ recording that this exact sentence *"HAD
BEEN FALSE FOR NINE DAYS"* and calling it *"the fourth indistinguishable
explanation for silence"*. **The correction was applied to one file of six.** It
has now been false in the other five for twenty days, and it is the sentence that
tells a session to stop looking.

A second, larger family says the wrong hour: **24 comment hunks across 9 files**
(counted from the merged diff, not estimated — see D9). `payload-policy.ts`,
`question-rollover.ts`, `daily-question.ts`, `sweep-push.ts`, `at-risk.ts`,
`messaging_bootstrap.dart`, `daily-question.test.ts`, `at-risk.test.ts` and
`payload-policy.test.ts` still describe the announcement as **hour 8** and the nudge
as **hour 16**. ADR-045 re-pointed the constants to **9** and **22** and moved the
quiet window with them; the constants moved and the prose did not. `sweep-push.ts:43` states the load-bearing claim **backwards** — it
says the quiet guard matters most for the daily-question pass "which fires at hour 8,
the first legal hour", when since ADR-045 that role belongs to the **22:00 nudge**
sitting against the 23:00 edge, exactly as `at-risk.ts` says 35 lines later.

### 5. The emulator suite proves the 09:00 path — and asserts only who, never what

`question-rollover-handler.test.ts` drives the real handler at hour 9 with two
seeded tokens and asserts `port.sent.map(m => m.token).sort()`.
`daily-question.test.ts` asserts summary counts and tokens. Neither ever reads
`title` or `body`. The payload identity is proven only in `payload-policy.test.ts`,
at the pure-function level — **where the question text is not in scope**.
`runDailyQuestion` is the one place that reads the day doc holding `questionId`, and
nothing there asserts that what leaves is the `dailyQuestion` copy and carries no
question. Swap the kind literal to `'reveal'` and the whole suite stays green.

## Finding 1 — `prod_pulse.py` throws away facts it has already measured

```python
try:
    api     = GoogleApi(token_from_firebase_cli())
    billing = measure_billing(api, args.project)          # today: SUCCEEDED (True)
    state, status = measure_job(api, args.project, ...)   # today: RAISED (403)
    last, summary = measure_last_sweep(...)               # today: NEVER RAN
except MeasurementError as exc:
    print(f"could not measure: {exc}", file=sys.stderr)
    return EXIT_CANNOT_MEASURE
```

Three **independent** measurements share one `try`. The first failure discards every
fact already in hand and every fact not yet asked for. `verdict()` is written to
**accumulate** — its own docstring says findings accumulate "because the second is the
consequence and the first is the cause, and a report that prints only the consequence
sends the reader to the wrong place" — and `main()` never reaches it.

The sweep-age read that never ran is the one that produces the correct answer:
55 hours stale, over a 90-minute threshold, **exit 1**.

**And the abort is not bad luck.** Cloud Scheduler 403s *because billing is off*. So
the single state this tool exists to detect is the single state that **guarantees** it
returns "could not measure". A health check whose blind spot is its subject.

## Finding 2 — it reads the wrong billing fact, and the outage test asserts on an input it can no longer produce

`measure_billing` returns `billingInfo.billingEnabled` — whether the project is
**linked** to an account. Today that is `true` while the account behind it is closed
and Cloud Run refuses every request. Had `measure_job` not thrown first, the tool
would have printed **`billing: enabled`** as a reassuring note, in the middle of the
incident it was written for.

That also strands the most important test in `prod_pulse_test.py`.
`test_the_actual_outage` replays the #219 signature with `billing_enabled=False` — an
input the production path **cannot compute for this failure mode**. The pure function
is well tested; every test in the file targets it; **nothing tests `main()`**, and
`main()` is where both defects live.

## Finding 3 — it reads the absence and never the reason

The docstring is explicit that an invocation attempt and a completed sweep appear
under the same function name "one letter apart (`I` vs `E`)" — and then keys the
verdict solely on the `I`. The `E` line carries the reason **verbatim**. A verdict
that reports "no sweep completed" without "because billing is disabled" sends the
reader to the scheduler, which is also where its own 403 points.

## Finding 4 — the operator instruction is inverted; the cost is a false conclusion, not a lost capability

*(Revision 2. Revision 1 claimed the permission grant would be destroyed. The
design review refuted that, and the refutation holds — see below.)*

`operator-expected.md` currently reads: *"one action unblocks everything: **①
Dispatch the release lane** so a current build reaches TestFlight, install it, open
the app, and accept the notification prompt."* Two of its supporting sentences are
false today: item 1 says *"the server has composed and attempted pushes on schedule
since 2026-08-11"*, and §9 — the section about the **billing** watchdog — says
*"Billing itself is **fine** (restored 2026-08-11, verified)."*

**What revision 1 got wrong.** It said the grant would be *"spent for nothing"*.
Measured instead:

* `_syncFrom` (`push_token_sync.dart:237-258`) fires on **every** `AuthSignedIn`
  transition, and the class docstring records why it also fires on a **cold launch**
  — `build()` syncs the value already present before it starts listening, precisely
  so a warm start is not skipped. It ends in `unawaited(_captureAndRegister())`.
* iOS keeps the permission answer. So once billing returns, **the next time the
  founder opens the app the token is captured and registered with no further
  action from them.**

The grant is therefore **deferred, not destroyed**, and D1 does not rest on
irreversibility.

**What is actually wrong with the order.** Doing ② first cannot produce the thing
the founder asked for, and will produce a confident wrong answer instead:

1. The sweep has completed **zero** times in six days, so no day doc exists at local
   midnight and **no 09:00 push can be composed** for any couple, token or not.
2. `registerPushToken` is a Cloud Run function in the same project whose serving
   layer is refusing every invocation *by project*, so the registration call is
   expected to be refused too. *(Inferred from the `questionRollover` evidence and
   the refusal's own project-wide wording — **not** separately measured, because
   measuring it means invoking a production write endpoint.)*
3. So the founder installs, grants, waits for 09:00, receives nothing, and the probe
   still reports **0 of 4 registered**. The reasonable conclusion — *"push is still
   broken"* — would be **wrong**, and it is the **fifth** indistinguishable silence
   in a row (ADR-046's count, plus this one).

The instruction is not wrong about the build. It is wrong about the **order**, and
order is the entire content of an operator instruction with two steps.

## Decisions

*(D2 and D3 are revision 2. Revision 1's D2 conflated the exit rule with the
gap-plumbing and got the exit rule wrong; the review's two instrument findings
split it into the rule and the mechanism, which is how it should have been written.)*

**D1 — Billing first, build second; the order is the decision.**
`operator-expected.md` carries **① restore billing** and **② cut the build**, in
that order, each stating what it unblocks. ② performed first cannot deliver a 09:00
question and will read as *"push is still broken"* (Finding 4). The instruction also
says what happens if ② was **already** done: nothing is lost — reopen the app after
① and it registers itself (`_syncFrom` → `_captureAndRegister` on every launch).
Neither step is a session's.

**D2 — The exit rule: a fact that could not be measured can never contribute to a
green.**

| condition | exit |
|---|---|
| any measured **finding** | **1** — findings win; the report also names every gap |
| no finding, but **any** fact unmeasurable | **2** — *could not measure*; a green needs a full look |
| every fact measured, none a finding | **0** |

This is ADR-041's *"never 0 without having compared"* applied to a multi-fact
verdict. Revision 1's rule left exit **0** covering *"nothing found, and the
decisive fact unmeasured"* — billing healthy + scheduler ENABLED + Logging 403
would have printed **"the daily loop is running"** over a six-day-dead sweep. That
is the one output this tool exists to never produce.

Today's run under D2: the billing account is closed → a **finding** → **exit 1**,
with the scheduler 403 printed as a named gap on its own line.

**D3 — A gap is a first-class input to `verdict()`, and it SUPPRESSES the absence
finding it pairs with.**
`verdict()` cannot express a gap today: `job_state=None` means *"looked, no job"*
(a finding) and `last_sweep=None` means *"looked, none in the window"* (a finding).
There is no value for *"could not look"*. So it grows an explicit
`gaps: dict[str, str]` — fact name → the reason it could not be measured — and for
every fact named there, the paired absence-finding is **not** raised; a
`COULD NOT MEASURE <fact>: <why>` line is emitted instead.

Without this the fix would have made things **worse**: today's scheduler 403 would
arrive as `job_state=None` and print the flatly false finding *"no Cloud Scheduler
job for questionRollover — the sweep has no trigger."*

**D4 — The authoritative billing fact is the ACCOUNT's `open`, not the project's
`billingEnabled`.**
Healthy means **linked AND open**. Report both. **Linked-but-closed is its own
named finding** — it is a real state, it is the state we are in, and the
project-level flag reads green throughout it. A project that is not linked at all
has no account to ask about; that is the pre-existing `billingEnabled:false`
finding, unchanged. If the account document itself is unreadable, that is a **gap**
under D3, not an assumption in either direction.

**D5 — The refusal reason is read from the function's own error stream and printed
next to the absence.** One more Logging query, on a filter the tool already builds.
The reason is reported as *the most recent refusal, with its timestamp*, so a
reader can see whether it predates or follows the last completed sweep rather than
having to trust it as current.

**D6 — The default lookback widens from 48h to 168h.**
Measured today: the last completed sweep was **~55h** old, so at the shipped
default the tool can only say *"none in the searched window"* — true, and unable to
date the outage. At 168h it reports **when the loop stopped**, which is the fact an
operator instruction is built from. The `--max-age-minutes` threshold that decides
the verdict is untouched; only the search window moves.

**D7 — The five "this cannot work yet" comments are corrected, and the standing rule
is: a comment may not carry a measured fact about build, device or portal state — it
names the command that measures it.**
Discipline, not a CI gate (the ADR-025 D8 precedent, cited for the *pattern*).
Only grammar separates a false present-tense claim from legitimate history, and
grammar is not scannable; a scan would need an allowlist, which is the inventory
lesson **128** warns about. What replaces the gate is that each corrected comment
now **points at the instrument** (`push_delivery_probe.py`,
`appid-capabilities.yml`) instead of restating its last answer — *a comment that
names a command cannot go stale, because it makes no claim.*

*(Revision 2: the count is **five**, not four. `recipients.ts:46` — the reader the
sweep uses to find a recipient's tokens — says **"NOTHING writes this field yet"**,
and `push-token-service.ts:59` has written it since the callable shipped.)*

**D8 — The hour-9 proof asserts the payload, not only the recipient.**
`runDailyQuestion` is the one seam where the question is in scope. A test pins that
the port receives, per recipient, the **`dailyQuestion`** copy in that recipient's
language, and that **neither `title` nor `body` carries the question id**.
Mutation-checked: flipping the kind literal must redden it, and the existing suite
must stay green — which is the measurement that shows the gap was real.

**D9 — The hour-8/hour-16 family is corrected in one pass: 24 hunks across 9 files.**

*(Revision 2 said "21 sites in 8 files". **That was an estimate carried from the
pre-edit grep, and it was wrong** — the review's lens 4 challenged the count and
both verifiers refuted the challenge, correctly, because the error ran **under**
rather than over. The number here is counted from the merged diff:
`git diff origin/main...HEAD -U0` over the notification and rollover sources plus
`messaging_bootstrap.dart`, counting hunks whose removed lines name an hour.
Lesson **111** — a number typed next to working code inherits the code's
credibility — met inside the document that cites it.)*
Historical narrative ("re-pointed from the 8 of ADR-042 D3") stays and is valuable;
present-tense claims are corrected. Two of them are worse than stale:

* `sweep-push.ts:43-44` states the load-bearing claim **backwards** — the quiet
  guard is said to matter most for the daily-question pass "which fires at hour 8,
  the first legal hour", when since ADR-045 that role belongs to the **22:00 nudge**
  against the 23:00 edge, exactly as `at-risk.ts` says. It also names the window as
  22:00–08:00; it is 23:00–08:00.
* `at-risk.test.ts:113/128/133` — the `describe` says *"hour-16 gate"*, the `it`
  says *"fires ONLY for the bucket at couple-local hour 16"*, and an inline comment
  says *"New York is 13:00"*, while the fixture 12 lines above correctly reads
  **22:00** and **15:00** and the first assertion inside is
  `expect(AT_RISK_LOCAL_HOUR).toBe(22)`. **The names and the assertions disagree
  inside one file** — lesson **121** exactly, and the name is what a later session
  greps for.

## Alternatives rejected

| | why not |
|---|---|
| `prod_pulse` exits **1** on any `MeasurementError` | Collapses *"could not look"* into *"broken"*, which `test_exit_codes_are_distinct` and ADR-041 both forbid, and which sends the founder to the wrong place — the failure #219's report already made once |
| Keep exit **2** whenever any probe fails (i.e. leave `main()` alone) | That is today's behaviour, and today it threw away a measured **closed billing account** because a *downstream consequence of that same closure* returned 403. A tool that reports nothing when one of four probes fails is a tool that reports nothing during an outage |
| Let a gap fall through as `None` and reuse the existing absence-findings | Would print *"no Cloud Scheduler job — the sweep has no trigger"* for a scheduler the tool merely could not read. **Worse than the bug**: a false cause, stated confidently (D3) |
| A CI gate for stale comments | Needs an allowlist to tell history from claim (lesson **128**); grammar is not scannable. D5 removes the *claim* instead of gating it |
| Cut the build now, fix billing after | Spends the one-shot iOS dialog against a dead backend (Finding 4) |
| The session restores billing | A closed billing account is a payment instrument on the founder's Google identity. Not reachable, and not a session's to reach |
| Add a scheduled watcher for the sweep now | Correct and **out of this session's scope**. `slack_notify.sh` is the single notifier (ADR-024 D1) and has no signal for *"prod is dead"*; `prod_pulse` is local-credential by design. **Filed as #263** rather than improvised, with the credential and cron-decay decisions named |

## Consequences

* The founder receives **two** steps with a stated order, instead of one step that
  would have been spent for nothing.
* `prod_pulse.py` becomes able to report the state it was written for — and the
  regression test for that state stops asserting on an unreachable input.
* A session opening the push files is no longer told four times that the feature
  cannot work yet.
* The 09:00 payload is proven where the question text is actually in scope.
* **Still uncovered, and now named:** nothing *watches* production between manual
  runs of a local-credential tool. The account closed on 2026-08-22 and nothing
  noticed for six days — the second time in nineteen days. **#219's own residual
  list already said this**, twice, and both items were left open:
  *"Budget alert (operator item 2(a)) is still unset — the one control that would
  have caught the cause rather than the symptom"* and *"`prod_pulse` is a
  local/manual instrument… A cron that calls it and notifies would close the
  detection gap properly; that needs a credential decision."* **The residuals of
  the last incident are the cause of this one.** Filed as **#263**, and item 9 in
  `operator-expected.md` is promoted rather than restated.
