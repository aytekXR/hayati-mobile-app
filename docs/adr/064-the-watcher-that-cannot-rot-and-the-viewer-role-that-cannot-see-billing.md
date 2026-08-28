# ADR-064: the watcher that cannot rot, and the `viewer` role that cannot see billing

- **Status:** Proposed · **Revision 2, 2026-08-28** — the design review found a **blocking** gap in D2 (a stated goal with no mechanism), and re-measuring one of its *refutations* found the refutation was wrong on the fact it rested on, which **narrowed the credential**
- **Date:** 2026-08-28 (Session 088)
- **Deciders:** the session agent for the lane; **the founder** for the credential grant and for the billing account itself
- **Related:** **#263** (this one), **#219** (the first outage, and the residual list that named both causes of the second), **ADR-063** (the instrument, rebuilt so it can report *during* an outage rather than after it), **ADR-034 D4** (the cron that was rejected, and why), **ADR-024 D1/D2/D3** (`slack_notify.sh` is the single notifier, with **no vote** and **all policy in the script**), **ADR-047 / #204** (`EXTRA_FINDINGS` — the non-voting finding, built for a signal with no other reader), **ADR-041 D4/D6** (read-only by construction; MEASURED-or-visibly-SKIPPED), **ADR-048** (measure IAM against the API, not the documentation), operator items **9** and **2(e)(iii)–(iv)**

> **Review status.** Revision 1 was written and committed **before any code**
> (`session-context.md` §5 item 1, lesson **115**). **Revision 2 folds the design
> review**: 4 lenses × 2 independent verifiers, **`agents_error=0`,
> `agents_empty_result=0`**, 13 findings raised, **13 verified, 0 dropped
> unverified**, **5 surfaced**. Every number below was measured on 2026-08-28 with
> the commands recorded inline.

## Revision 2 — what the review changed, and the refutation that was wrong

**1. D2 stated a goal and never decided its mechanism (BLOCKING, both verifiers
high).** *"The lane does not vote"* is a property of how the **notifier** treats
`EXTRA_FINDINGS` — it is **not** a property of the **producer**. `prod_pulse.py`
exits **1** on a finding (ADR-063's taxonomy), which fails the step, fails the job,
and reddens the run: precisely the *"this change broke the build"* about a closed
credit card that D2 exists to prevent. ADR-047 decides **both** halves for
`store_metadata_audit` — `continue-on-error` on the step **and** the notifier's
no-vote — and slack_notify.sh's own comment says `EXTRA_FINDINGS` exists because
*"a step that is `continue-on-error: true` produces a SUCCESS job result, so
`NEEDS_JSON` is structurally blind to it."* **New D2b writes the mechanism down.**

**2. The cron interval was never specified** (raised by two independent lenses).
The refuters called it implementation discretion; the adjudicators cited lesson
**106** — *an ADR is the specification the next writer implements from, and
"implied" is discovered only by someone who already knows the answer.* The
adjudicators are right, and it is one number. **New D1a decides it.**

**3. Exit 2 had no mapping.** The lane was specified for *findings*; `prod_pulse`
also exits **2** for *could not measure*, and a revoked credential would produce
that on every run forever. **New D2c decides it.**

**4. The unarmed-lane count was wrong** — five, not four (`rules-drift`,
**`functions-drift`**, `deploy-rules`, `deploy-functions`, and this one). **Third
count I have gotten wrong in two sessions**; see the lesson filed with this ADR.

### 5. The security refutation was wrong on its own fact, and that changed D3

A lens raised *"`billing.viewer` exposes payment info the watcher does not need."*
Its refuter dismissed it: *"`billing.accounts.getPaymentInfo` is NOT included in
`roles/billing.viewer` — it is in `roles/billing.admin`."* **Measured against the
IAM API, that is false:**

| permission | `roles/billing.viewer` |
|---|---|
| `billing.accounts.getPaymentInfo` | **YES** |
| `billing.accounts.getSpendingInformation` | **YES** |
| `billing.credits.list` | **YES** |
| `billing.accounts.getIamPolicy` | **YES** |
| `billing.resourceAssociations.list` | **YES** — every project attached to the account |
| any write permission | **none** |

**This repository is PUBLIC.** A leaked service-account key holding
`roles/billing.viewer` on the founder's billing account would read payment-instrument
metadata, spending information, credits, the account's IAM policy, and the list of
**every project on that account** — including projects that have nothing to do with
this app. Revision 1 checked that role for *writes*, found none, and stopped. **The
question was never only "can it write."**

So **D3 is rewritten and the CI lane now asks for no billing permission at all** —
see below. The finding was real; the refutation was confident, specific, and wrong;
and the only reason it did not land is that the claim was re-measured rather than
taken on trust (lesson **123**, applied to a review agent instead of to a document).

## The one-sentence version

Production has now gone dark twice from the same cause, and the second time it
lasted six days — so this ADR adds the missing *reader*: a job that runs
`prod_pulse.py` and hands its finding to the notifier that already exists for
exactly this shape of signal. The interesting part is not the lane. It is that
**the obvious credential does not work and the obvious-looking safe one is a write
role**, and that **neither available trigger is sufficient alone.**

## Context — four measurements, and three of them changed the design

### 1. `prod_pulse.py` still reports the outage. Nothing reads it

```
$ python3 tool/ci/prod_pulse.py --from-firebase-cli                  # exit 1
  FINDING: the linked billing account is CLOSED. …
  FINDING: the last COMPLETED sweep was 56.9h ago (2026-08-25T15:00:11Z) …
  most recent refusal (2026-08-27T23:00:07Z): The request failed because billing
    is disabled for this project.
  COULD NOT MEASURE scheduler: …cloudscheduler… HTTP 403
```

ADR-063 made the instrument able to answer **during** the outage. It did nothing
about the fact that the only thing that ever asks it is a human at a terminal.

### 2. The notifier already has the exact mechanism — and it was built for this shape

`slack_notify.sh` carries `EXTRA_FINDINGS` (ADR-024 D1, added for #204). Read its
own comment, because it describes this signal without knowing about it:

> **THE NOTIFIER STILL HAS NO VOTE (D3).** A finding does not make `outcome`
> failure, does not redden anything, and does not change the exit code. It changes
> what the message SAYS — which is the entire remedy being asked for.

and, on why a finding escapes the noise policy:

> A FINDING is exempt, and that exemption is the point of #204: **it is precisely
> the signal that has no other reader, on a run that otherwise looks fine.**

A dead production backend on a green build **is** a signal with no other reader on
a run that looks fine. Today the only producer is `release.yml`'s store-metadata
audit; `ci.yml`'s `slack-notify` passes no `EXTRA_FINDINGS` at all.

### 3. Neither trigger is sufficient alone, and the numbers say so

**There is no cron anywhere in this repository.** ADR-034 D4 rejected one, and its
reason is still true: **GitHub disables scheduled workflows after 60 days without
repository activity** — so a cron meant to watch a quiet period dies during exactly
that period, *and looks like coverage while dead.*

But post-merge-on-`main` — the trigger `rules-drift` and `functions-drift` chose —
has a latency equal to the merge gap, and this incident measures it:

| | |
|---|---|
| outage began | **2026-08-22T02:00Z** |
| merges to `main` during the outage | **4** — 2026-08-26 (×2), 08-27, 08-28 |
| a post-merge watcher would have fired | **2026-08-26** — two days before a human found it, and **four days after it began** |

**Four days of blind window on a product whose whole feature is a daily
notification** is not a watcher, it is an autopsy. And a cron alone auto-disables.
So the choice between them is a false one.

### 4. The obvious credential is wrong, and the smaller one is a write role

Measured against the IAM API rather than the documentation (the ADR-048 rule, which
last time *refuted* the vendor docs). `prod_pulse` needs `billing.accounts.get`,
`logging.logEntries.list` and `cloudscheduler.jobs.list`:

| role | perms | carries |
|---|---|---|
| `roles/viewer` | 6064 | logging ✓, scheduler ✓, **billing ✗** |
| `roles/firebase.viewer` | 285 | logging ✓ only |
| `roles/logging.viewer` | 28 | logging ✓ |
| `roles/cloudscheduler.viewer` | 17 | scheduler ✓ |
| `roles/billing.viewer` | 62 | **billing ✓**, and **zero** write permissions |
| `roles/billing.user` | **6** | billing ✓ — **and `billing.resourceAssociations.create`** |

Two findings, both counterintuitive:

* **`roles/viewer` — 6064 permissions, the broadest read role Google ships — cannot
  read whether a billing account is open.** Granting it would produce a watcher that
  reports `COULD NOT MEASURE billing` on the single fact that matters, forever, and
  every other fact green. The most tempting grant is the one that silently blinds
  the instrument on its own subject.
* **`roles/billing.user` is smaller and is a WRITE role.** Its own description is
  *"Can associate projects with billing accounts"*, and it carries
  `billing.resourceAssociations.create` and `billing.accounts.redeemPromotion`.
  **Smaller is not safer.** A watcher whose subject is *"this project's billing
  account is closed"* must not hold the permission to **attach projects to billing
  accounts** — that is ADR-041 D4's rule (*the tool must never be able to cause the
  condition it reports*) reaching a place nobody had applied it.
* `billing.accounts.get` is granted **on the billing account, not the project** — a
  different console page from project IAM.

**Revision 2 adds the measurement revision 1 did not make**, and it changed the
answer: `roles/billing.viewer` is read-only **and** carries
`billing.accounts.getPaymentInfo`, `getSpendingInformation`, `credits.list`,
`getIamPolicy` and `resourceAssociations.list`. Checking a role for *writes* is not
checking it for *exposure*, and this repository is public. **D3 therefore asks for no
billing permission in CI at all** — the refusal reason the lane actually needs is in
Cloud Logging, in the platform's own words.

## Decisions

*(D1a, D2b, D2c and a rewritten D3 are revision 2.)*

**D1 — Two triggers, because each covers the other's failure.**
The lane runs **post-merge on `main`** *and* on a **cron**. Neither is sufficient:
post-merge had a **four-day** blind window in this very incident, and a cron
auto-disables after 60 days of repository inactivity. Together the failure modes are
complementary — the cron carries the cadence, and the post-merge run is the thing
that **cannot rot**, so if the cron is ever disabled the watcher degrades to
ADR-034 D4's rejected-but-honest fallback rather than to silence.

**ADR-034 D4 is not overturned.** Its finding — that a cron *alone*, watching a
quiet repo, is coverage-shaped nothing — stands and is restated here. What changes
is that a cron **backed by a trigger that cannot be disabled** no longer has that
failure mode, and D4 was deciding about a lone cron.

**D1a — The cron interval is every 6 hours (`0 */6 * * *`), and here is the
arithmetic.**
The sweep is hourly and `prod_pulse`'s own staleness threshold is **90 minutes**, so
any cadence under ~6h detects a dead loop within one product-day; 6h gives at most a
**6-hour** blind window against the **4-day** one measured for post-merge alone.
Four runs a day on a public repository costs nothing.

**On the noise this creates during an outage: it is intended.** Six days of outage
at this cadence is ~24 messages, and the review's own refutation of the
de-duplication finding is the reason that is acceptable — ADR-034's
*trained-to-ignore* concern was about an **unchanging, accepted** advisory backlog,
not an active production outage. **A wolf that keeps being reported is not
cry-wolf.** No de-duplication state is introduced, deliberately: ADR-012 D3 keeps
this system free of dedup state and the alternative is a store that must itself be
correct across runs.

**D2 — The lane produces a FINDING; it does not vote.**
Production being down is not caused by the commit that triggered the run. Reddening
`main` for it would report *"this change broke the build"* about a closed credit
card — ADR-034's cry-wolf shape, and the thing that gets a channel muted. The signal
goes through `EXTRA_FINDINGS`, which is non-voting **and exempt from the
noise-suppression policy** — the mechanism ADR-024 D1 already built for a signal
with no other reader on an otherwise-fine run.

*(This is where this ADR parts from ADR-041 D2, deliberately. Rules drift **votes**
because it is caused by our own omission and is fixed by our own action. A closed
billing account is neither.)*

**D2b — "Does not vote" is a MECHANISM, and it lives in two places, both written
down here.**
Revision 1 stated the goal and decided neither half. `prod_pulse.py` exits **1** on
a finding, and an exit 1 fails the step, the job and the run. So, following ADR-047
exactly:

1. **`continue-on-error: true` on the watcher step**, so a finding produces a
   SUCCESS job result and the run conclusion is untouched;
2. the finding text is captured to a **job output** and passed to `slack-notify` as
   `EXTRA_FINDINGS` — which is the *only* channel that crosses the
   `continue-on-error` boundary, because `NEEDS_JSON` is structurally blind to a
   step that was allowed to fail (slack_notify.sh says so in its own comment).

**The tool's exit code is NOT changed to 0.** ADR-063's taxonomy is a binding
invariant and the local operator path depends on it; the *lane* absorbs the exit
code, the *tool* keeps its meaning.

**D2c — Exit 2 is reported, and it is reported as a different sentence.**
`prod_pulse` exits **2** for *could not measure*. That must not be silent — a
revoked credential would otherwise leave a watcher that runs, passes, and watches
nothing — and it must not be worded as an outage, because it is not one. So:

| tool exit | lane behaviour |
|---|---|
| 0 | no finding; nothing is sent (the notifier's noise policy already handles a quiet green) |
| 1 | finding, prefixed **`production:`** — the FINDING lines verbatim |
| 2 | finding, prefixed **`production (unmeasurable):`** — naming what could not be read |

Both non-zero codes reach a human; only one of them claims production is down. This
keeps ADR-041's taxonomy intact at the tool boundary while giving the notifier the
two-way distinction it needs — *"I looked and it is broken"* versus *"I could not
look"*, which is the same sentence pair ADR-063 D2 wrote into `verdict()`.

**D3 — The CI lane gets `roles/logging.viewer`, and NO billing permission at all.**

*(Rewritten in revision 2. Revision 1 asked for `roles/billing.viewer` on the
billing account. That was the wrong ask, and this repository being **public** is why.)*

The lane needs to answer one question: **is the daily loop running, and if not,
why?** Both halves are in Cloud Logging:

* the **sweep-age** verdict reads `question_rollover: sweep complete` — the decisive
  fact, and the only one the tool's title is about;
* the **refusal reason** reads the sweep's own error stream, which carries
  *"The request failed because billing is disabled for this project"* **verbatim**.

So the cause is already legible with **no billing permission whatsoever**. What the
billing probes add is precision — *linked-but-closed* rather than *refused for a
billing reason* — and that precision is not worth putting payment metadata, spending
information, credits, the billing IAM policy and an inventory of every project on the
account behind a key in a public repository (measured above).

* **CI lane:** `roles/logging.viewer` on both projects. Optionally
  `roles/cloudscheduler.viewer` (17 permissions, read-only, no financial surface).
* **NOT `roles/billing.viewer`** — measured: it carries `getPaymentInfo`,
  `getSpendingInformation`, `credits.list`, `getIamPolicy` and
  `resourceAssociations.list`.
* **NOT `roles/viewer`** — measured: 6064 permissions and it *still* cannot read
  `billing.accounts.get`, so it would buy the blast radius without buying the fact.
* **NOT `roles/billing.user`** — measured: 6 permissions and it is a **write** role
  (`billing.resourceAssociations.create`); a watcher must not be able to attach
  projects to billing accounts (ADR-041 D4).
* **The billing-account read stays on the local `--from-firebase-cli` path**, where
  the founder's own credential already has it and no key is stored anywhere.

**And the degradation is honest by construction**, which is what makes this
acceptable rather than a compromise: under ADR-063 D2 an unreadable fact is a
**named gap**, so the CI report prints `COULD NOT MEASURE billing` beside its
finding, and **a gap can never produce a green**. The reduced credential cannot make
the lane quietly optimistic — it can only make it say less, out loud.

**If CI precision is ever wanted**, the narrow path is a **custom role carrying only
`billing.accounts.get`** — measured: `customRolesSupportLevel = SUPPORTED` on that
permission — never `billing.viewer`.

**D4 — `prod_pulse.py` grows a service-account credential path.**
`--from-firebase-cli` is `required=True` today, and its module docstring says the
service-account path was *"deliberately NOT wired here"* because `firebase.readonly`
cannot read Logging, Scheduler or Billing — **which is a statement about that role,
not about service accounts.** D3's roles can read Logging. The docstring is corrected
rather than left to mislead the next reader (ADR-063 D7: a comment may not carry a
measured fact that has moved).

**D5 — MEASURED or visibly SKIPPED, with no third outcome.**
The ADR-041 D6 pattern, because it exists for precisely this hazard: a job-level
`if:` cannot read `secrets`, and a job whose every step skipped reports **green**. A
credential preflight publishes a boolean; the watcher gates on it; the skip carries
a `::warning::` naming what is unguarded. **The lane ships UNARMED** until the
operator grant exists, and saying so is the point (`session-context.md` §2).

**D6 — This catches the SYMPTOM. Operator item 9 catches the CAUSE, and they are
not substitutes.**
A budget alert fires on the *card* days before a sweep goes stale, is Google-side,
and cannot be disabled by GitHub inactivity. This lane fires only once production is
already down. The operator page must not let item 9 be closed by this ADR shipping.

## Alternatives rejected

| | why not |
|---|---|
| Cron only | ADR-034 D4, re-verified: disabled after 60 days of repo inactivity, during exactly the quiet period it exists for, **and it looks like coverage while dead** |
| Post-merge only | Measured **four-day** blind window in this incident (outage 08-22, first merge 08-26) |
| Make the lane vote (redden `main`) | Reddens a build for a closed credit card. ADR-034's cry-wolf shape; a muted channel then swallows the `integration-emulator` red that ADR-024 exists for |
| `roles/viewer` for simplicity | **Measured: it cannot read `billing.accounts.get`.** The watcher would be permanently gapped on its most important fact while appearing correctly configured |
| `roles/billing.user` because it is smaller | **Measured: it is a write role** — `billing.resourceAssociations.create`. Smaller is not safer |
| Reuse `FIREBASE_RULES_VIEWER_SA` as-is | Its `firebase.readonly` scope is exactly what ADR-063's docstring says cannot read these APIs. The *identity* may be reused; the *roles* are new, and the billing one is granted somewhere else entirely |
| A GCP-side alerting policy instead | Correct, arguably better, and **not a session's to create** — it is console work on the founder's project, and it is item 9's neighbour. Named here rather than silently skipped |
| `roles/billing.viewer` in CI (revision 1's ask) | **Measured**: carries `getPaymentInfo`, `getSpendingInformation`, `credits.list`, `getIamPolicy` and an inventory of every project on the account. In a **public** repo that is the blast radius of one leaked key, bought for precision the log line already provides |
| A custom role with only `billing.accounts.get` | Sound, and **`customRolesSupportLevel = SUPPORTED`** was measured for it — but it is org-level console work for a fact the refusal log already carries. Kept as the named path *if* CI precision is ever wanted |
| Change `prod_pulse` to exit 0 on findings so the step passes | Breaks ADR-041's taxonomy at the tool boundary and silently changes what the local operator command means. **The lane absorbs the exit code (D2b); the tool keeps its meaning** |

## Consequences

* A closed billing account becomes a message in a channel instead of a thing
  somebody notices six days later.
* The founder's grant is **three roles in two places**, and the ADR names the two
  plausible-looking roles that would break it.
* **The lane ships unarmed**, like `rules-drift`, **`functions-drift`**,
  `deploy-rules` and `deploy-functions` before it. That is **five** unarmed lanes —
  revision 1 said four and forgot `functions-drift` — and the operator page should
  say so in one place rather than five.
* `EXTRA_FINDINGS` gains a second producer, which is the first evidence that it is a
  general mechanism rather than a one-off for #204.
