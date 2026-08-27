# ADR-064: the watcher that cannot rot, and the `viewer` role that cannot see billing

- **Status:** Proposed
- **Date:** 2026-08-28 (Session 088)
- **Deciders:** the session agent for the lane; **the founder** for the credential grant and for the billing account itself
- **Related:** **#263** (this one), **#219** (the first outage, and the residual list that named both causes of the second), **ADR-063** (the instrument, rebuilt so it can report *during* an outage rather than after it), **ADR-034 D4** (the cron that was rejected, and why), **ADR-024 D1/D2/D3** (`slack_notify.sh` is the single notifier, with **no vote** and **all policy in the script**), **ADR-047 / #204** (`EXTRA_FINDINGS` — the non-voting finding, built for a signal with no other reader), **ADR-041 D4/D6** (read-only by construction; MEASURED-or-visibly-SKIPPED), **ADR-048** (measure IAM against the API, not the documentation), operator items **9** and **2(e)(iii)–(iv)**

> **Review status.** Written and committed **before any code**
> (`session-context.md` §5 item 1, lesson **115**). Every number below was measured
> on 2026-08-28 with the commands recorded inline.

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
  different console page from project IAM, which is why the operator item must say
  so explicitly or it will be done in the wrong place and read as a gap.

## Decisions

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

**D3 — The credential is three narrow grants, and the ADR names the two that must
NOT be used.**

* `roles/logging.viewer` and `roles/cloudscheduler.viewer` **on both projects**;
* `roles/billing.viewer` **on billing account `012195-7EF76F-3A9083`** — a grant
  made on the billing account's own IAM page, not the project's;
* **NOT `roles/viewer`** — measured above: it cannot read the billing account, so
  the watcher would gap its most important fact while looking fully configured;
* **NOT `roles/billing.user`** — measured above: it can attach projects to billing
  accounts, and a watcher must not be able to cause what it reports (ADR-041 D4).

**D4 — `prod_pulse.py` grows a service-account credential path.**
`--from-firebase-cli` is `required=True` today, and its module docstring says the
service-account path was *"deliberately NOT wired here"* because `firebase.readonly`
cannot read Logging, Scheduler or Billing — **which is a statement about that role,
not about service accounts.** D3's three roles can. The docstring is corrected
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

## Consequences

* A closed billing account becomes a message in a channel instead of a thing
  somebody notices six days later.
* The founder's grant is **three roles in two places**, and the ADR names the two
  plausible-looking roles that would break it.
* **The lane ships unarmed**, like `rules-drift`, `deploy-rules` and
  `deploy-functions` before it. That is four unarmed lanes; the operator page should
  say so in one place rather than four.
* `EXTRA_FINDINGS` gains a second producer, which is the first evidence that it is a
  general mechanism rather than a one-off for #204.
