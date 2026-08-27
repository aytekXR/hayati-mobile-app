# ADR-063: the loop stopped six days ago, and the instrument built to notice returned "could not measure"

- **Status:** Proposed
- **Date:** 2026-08-27 (Session 087)
- **Deciders:** the session agent for the instrument, the comments and the proof; **the founder** for the billing account — a closed account is a payment action on their Google identity and nothing here can reach it
- **Related:** **#219** (the *first* time this happened, 2026-08-09→11, and the reason `prod_pulse.py` exists), **ADR-041** (exit codes are a taxonomy: 0 / 1 finding / **2 could not measure**), **ADR-011** (the hourly sweep), **ADR-012 D3** (both push passes ride ONE couples read; the injectable `MessagingPort`), **ADR-042 D2/D3** (the token lifecycle and the hour the founder asked for), **ADR-044** (APNs readiness and the bounded capture), **ADR-045** (the hours re-pointed to **9** and **22**, and the quiet window moved to 23:00–08:00 so they could exist), **ADR-046** (the permission state is app state — and iOS gives **one** dialog per install), **ADR-049** (the device reports *why*, and a no-report is not a reason), **ADR-025 D8** (a declaration can be discipline rather than a CI gate), issues **#136**, **#253**

> **Review status.** Written and committed **before any code**
> (`session-context.md` §5 item 1, lesson **115**). Every number below was
> measured on 2026-08-27 with commands recorded inline; none is inherited.

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

### 4. Four comments tell a reader the device half cannot work yet. All four are false

| file | claim | since |
|---|---|---|
| `push_token_source_provider.dart:9` | *"**Nothing overrides this yet**, and that is the design"* | both entrypoints override it |
| `main_dev.dart:228` | *"It is **INERT** until the entitlement lands. `aps-environment` is **absent**"* | the entitlement landed **2026-08-07** |
| `push_token_source.dart:9` | *"There is deliberately **no implementation** of this yet"* | `FcmPushTokenSource` exists and is wired |
| `fcm_push_token_source.dart:29` | *"correct and **inert today**, and becomes live the moment the entitlement lands"* | it is live |

`main_prod.dart:217` already carries a ⚠️ recording that this exact sentence *"HAD
BEEN FALSE FOR NINE DAYS"* and calling it *"the fourth indistinguishable
explanation for silence"*. **The correction was applied to one file of five.** It
has now been false in the other four for twenty days, and it is the sentence that
tells a session to stop looking.

A second, larger family says the wrong hour: **17 sites** across
`payload-policy.ts`, `question-rollover.ts`, `daily-question.ts`, `sweep-push.ts`,
`at-risk.ts`, `messaging_bootstrap.dart` and `daily-question.test.ts` still describe
the announcement as **hour 8** and the nudge as **hour 16**. ADR-045 re-pointed them
to **9** and **22** and moved the quiet window with them; the constants moved and the
prose did not. `sweep-push.ts:43` states the load-bearing claim **backwards** — it
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

## Finding 4 — the operator instruction is inverted, and inverting it is not recoverable

`operator-expected.md` currently reads: *"one action unblocks everything: **①
Dispatch the release lane** so a current build reaches TestFlight, install it, open
the app, and accept the notification prompt."*

Performed today, that spends the **one notification dialog iOS gives per install**
(ADR-046) against a backend that has completed **zero** sweeps in six days. The
founder would grant permission, wait for 09:00, receive nothing, and have
manufactured a **fifth** indistinguishable silence — with the only resource in the
chain that cannot be re-requested already spent. Recovery is the Settings app, which
the app has a row for, but the diagnostic value of the grant is gone.

The instruction is not wrong about the build. It is wrong about the **order**, and
order is the whole content of an operator instruction with two steps.

## Decisions

**D1 — Billing first, build second; the order is the decision.**
`operator-expected.md` carries **① restore billing** and **② cut the build**, in that
order, each with what it unblocks and why it cannot move: ② spends an unrepeatable
resource, ① is what makes spending it worth anything. Neither step is a session's.

**D2 — Each fact is measured independently; an unmeasurable one is a NAMED GAP in the
report, never a discarded run.**
`verdict()` already accumulates; `main()` must stop preventing it. Exit **2** is
reserved for *nothing could be measured at all* (no credential, or every probe
failed). If **any** fact was measured and **any** of them is a finding, the exit is
**1**. The taxonomy (ADR-041) keeps its meaning: *"I could not look at the scheduler"*
and *"I looked and it is broken"* remain different **lines in the same report**,
which is what they always should have been — they were only ever collapsed into
different **runs**.

**D3 — The authoritative billing fact is the ACCOUNT's `open`, not the project's
`billingEnabled`.**
Healthy means **linked AND open**. Report both; **linked-but-closed is its own named
finding**, because it is a real state, it is the state we are in, and the
project-level flag reads green throughout it. Where the project is not linked at all
there is no account to ask about, and that is the pre-existing `billingEnabled:false`
finding, unchanged.

**D4 — The refusal reason is read from the function's own error stream and printed
next to the absence.** One more Logging query, on a filter the tool already knows how
to build.

**D5 — The four "this cannot work yet" comments are corrected, and the standing rule
is: a comment may not carry a measured fact about build, device or portal state — it
names the command that measures it.**
Discipline, not a CI gate (the ADR-025 D8 precedent). Only grammar separates a false
present-tense claim from legitimate history, and grammar is not scannable; a scan
would need an allowlist, which is the inventory lesson **128** warns about. What
replaces the gate is that each corrected comment now **points at the instrument**
(`push_delivery_probe.py`, `appid-capabilities.yml`) instead of restating its last
answer — a comment that names a command cannot go stale, because it makes no claim.

**D6 — The hour-9 proof asserts the payload, not only the recipient.**
`runDailyQuestion` is the one seam where the question is in scope. A test pins that
the port receives, per recipient, the **`dailyQuestion`** copy in that recipient's
language, and that **neither `title` nor `body` carries the question id or its text**.
Mutation-checked: flipping the kind literal must redden it.

**D7 — The hour-8/hour-16 family is corrected in one pass.** Historical narrative
("re-pointed from the 8 of ADR-042 D3") stays and is valuable; present-tense claims
are corrected. `sweep-push.ts`'s reversed load-bearing claim is rewritten to name the
22:00 nudge.

## Alternatives rejected

| | why not |
|---|---|
| `prod_pulse` exits **1** on any `MeasurementError` | Collapses *"could not look"* into *"broken"*, which `test_exit_codes_are_distinct` and ADR-041 both forbid, and which sends the founder to the wrong place — the failure #219's report already made once |
| A CI gate for stale comments | Needs an allowlist to tell history from claim (lesson **128**); grammar is not scannable. D5 removes the *claim* instead of gating it |
| Cut the build now, fix billing after | Spends the one-shot iOS dialog against a dead backend (Finding 4) |
| The session restores billing | A closed billing account is a payment instrument on the founder's Google identity. Not reachable, and not a session's to reach |
| Add a scheduled watcher for the sweep now | Correct and **out of this session's scope**. `slack_notify.sh` is the single notifier (ADR-024 D1) and has no signal for *"prod is dead"*; `prod_pulse` is local-credential by design. **Filed as an issue** rather than improvised |

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
  noticed for six days — the second time in nineteen. Filed.
