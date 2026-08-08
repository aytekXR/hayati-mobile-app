# Resume Prompt — Session 065

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Before starting, read the two companions:
> * **`session-context.md`** — toolchain, machine, review discipline, binding
>   invariants, and the never-without-asking list.
> * **`session-lessons.md`** — the institutional lessons, numbered to **90**. Cited
>   below by number.
>
> Re-derive the session number from `git log`; a session on another machine can consume it.

**Objective: answer #166 — is the deployed Functions code comparable to `main`, and if so, gate it.**

This is the check whose absence cost the entire push feature. S063 merged the
whole stack, every PR green, `integration-emulator` green, two builds shipped —
and production was running Functions from before #190, so the callables the app
invokes **did not exist**. Nothing in the repository could have said so
(lesson **86**). #166 has been open since 2026-08-01 saying exactly this.

**It is measurement-first and may honestly close as unanswerable** — read the
issue body, it sets that out. Acceptance 3 is a legitimate outcome: *"no sound
comparison exists, here is the evidence, closed."* An honest recorded gap beats
a check that mostly restates something else.

> **S064 found the first real lead, so do not start from zero.** The deployed
> functions carry a Firebase-stamped label:
>
> ```
> "labels":{"deployment-tool":"cli-firebase","deployment-callable":"true",
>           "firebase-functions-hash":"fb789b160cab7febc561eb7573a404e2367363cd"}
> ```
>
> Seen on 2026-08-08 in the **audit-log entries** returned by
> `firebase functions:log --project hayatiapp-prod --only registerPushToken`
> (the `CreateFunction` AuditLog records from the 2026-08-07 deploy — not in
> `functions:list` output, which does not show labels).
>
> That is candidate **1** in the issue body, and it is now *observed to exist*
> rather than hypothesised. **The open question is the one the issue already
> names: is it derivable from a checkout?** If the hash cannot be recomputed
> locally from `functions/`, it identifies a deploy but cannot answer "is this
> `main`" — which is candidate 2's weakness, and ADR-041 D1's objection applies
> (whatever writes the record is the thing whose omission is the bug).

### S064 got further than that. Four measurements, all read-only — start here

**1. There is a clean instrument; do not use the audit log.**
`firebase functions:list --project <p> --json` returns per-function
`hash`, `labels`, and `source.storageSource.generation`. No `gcloud`, no ADC, no
service account — the founder's local CLI login is enough.

**2. The hash is PER-FUNCTION, not per-deploy.** Prod carries **three** distinct
values across 13 functions: eleven share `fb789b16…` (the 2026-08-07 deploy),
while `coachProxy` (`3e869aa3…`) and `revenueCatWebhook` (`476a433c…`) differ.
Those two are exactly the functions that consume **secrets**, which is the
obvious hypothesis for why their hash differs from siblings built out of the same
source zip — **test it, do not assume it.** If secret *versions* participate in
the hash, a rotation changes the hash without changing a line of code, and a
checker built naively on it would report drift that is not drift.

**3. `firebase deploy --dry-run` exists (CLI 15.22.4) and is NOT read-only.** Its
own help says it "may still enable APIs on the target project", so pointing it at
prod is a **§7 ask**, not a free measurement. Exercised against **dev**, it dies
before reporting anything useful:

```
Error: Failed to validate secret versions:
- RC_WEBHOOK_TOKEN … not found or has no versions   (operator item 0(c))
```

So **the rehearsal environment cannot run the instrument until an existing
operator item is closed.** That is a finding for the issue, not a blocker for it.

**4. The cheap set-comparison already found real drift — on dev.** Prod deploys
all 13 exports in `functions/src/index.ts`. **Dev deploys 10.** Missing:
`registerPushToken`, `unregisterPushToken`, `revenueCatWebhook`.

> ⚠️ **That drift was left in place ON PURPOSE.** Dev is a session's to exercise
> and fixing it is one command — but it is the only live positive case available
> for the checker this session is meant to build, and a checker with nothing to
> detect is the vacuous-green shape this repo keeps paying for. **Build the
> check, watch it go red on dev, then deploy dev and watch it go green.** Note
> the dev deploy will need `--only functions:registerPushToken,functions:unregisterPushToken`
> to route around the missing secret in measurement 3.

---

## 1. Where things actually stand *(measured 2026-08-08 — re-measure, do not inherit)*

| | State |
|---|---|
| **Push, server side** | **DONE and RUNNING.** All 13 exports in `functions/src/index.ts` are deployed to prod, and all **three** per-sweep summary lines appear on every hourly pass (`sweep complete`, `daily-question sweep complete`, `at-risk sweep complete`). The missing third line was S063's whole diagnosis; it is present. |
| **Push, credentials** | **DONE.** The founder confirmed on 2026-08-08 that the APNs `.p8` is uploaded to **both** Firebase projects. `PUSH_NOTIFICATIONS` was ticked 2026-08-06. |
| **Push, device side** | **Still zero.** `registerPushToken` has **never been invoked by a device** (only `CreateFunction` audit entries), and `checked` is **0** on every `daily-question sweep complete`. Nobody has a token because nobody has opened a build and tapped Allow. |
| **How to check that WITHOUT asking the founder** | `firebase functions:log --project hayatiapp-prod --only registerPushToken` and the `checked` counter above. **Both move the moment a real device accepts the prompt** (lesson **90**). This replaced "ask them whether a push arrived", which blocked M3.4 for three sessions. |
| **Build 117** | **Live.** `processing=VALID`, `internal=IN_BETA_TESTING`, **`external=IN_BETA_TESTING`** (Apple approved the beta review), groups `founders, Friends`. Carries the icon AND the whole push slice. Delivery was **not inferred from the green release** — the assignment (`assigned build 117 to 'Friends'`) and the submission (`build 117: submitted for Beta App Review`) were each read out of the job log, then re-read from the API. Apple's own icon rendering was fetched and is the founder's mark. Build number is `100 + run_number` (ADR-032). |
| **App icon** | **SHIPPED.** All 20 rasters derive from the founder's master via `tool/ci/app_icons.py`; `--verify` runs in CI's `quality` job. `AppIconDiscreet` byte-identical. |
| **Deployed rules** | **Both projects match `main`** — `rules_drift.py --from-firebase-cli` exit **0** for prod AND dev on 2026-08-08. Dev had drifted since 2026-08-01 and was deployed this session (dev is a session's to exercise). The `fcmTokens` freeze is live in both. |
| **Screenshots** | en-US: 6 live. **`tr` absent, and NOT for the reason three prompts have said.** Apple refuses to create the `tr` localization — *"the app name is already being used by another app"* — on **every release since build 112**, silently, because the `deliver` step is `continue-on-error` by design (ADR-020 D8) and nobody read it. Filed as **#204**. It needs a founder *decision* (a different Turkish display name), not a click. |
| **`MATCH_BOOTSTRAP`** | Confirmed absent from `gh variable list` 2026-08-08. |

---

## 2. THE OBJECTIVE

Work the issue's four acceptance criteria in order. **Acceptance 1 is the
session** — 2 and 3 are the two possible outcomes of it.

### Acceptance 1 — measure, and say which questions the instrument can answer

For **both** projects: what is deployed, and is that answerable at all with a
credential CI could hold? Name plainly what the `firebase` CLI can and cannot
do. `gcloud` is **not installed** and there is **no ADC** — say so rather than
asserting Cloud Functions v2 admin API results you cannot obtain (candidate 3
may be unreachable from here for exactly that reason; that is a finding, not a
failure).

The concrete first experiment, given the lead above:

1. Read the label off a deployed function by a repeatable command (the audit-log
   path above works; find whether a cleaner one exists).
2. Try to recompute `firebase-functions-hash` from `functions/` in a checkout.
   If it is not derivable, candidate 1 collapses into candidate 2.
3. Re-run after a no-op redeploy to `hayatiapp-dev` and see whether the hash is
   stable for identical source — **a hash that changes per deploy cannot detect
   drift, and a hash that never changes cannot either.** Dev is a session's to
   exercise; prod is not.

### Acceptance 2 or 3 — build it, or close it with evidence

If a sound comparison exists, build it in `rules_drift.py`'s shape: fail-closed,
the exit-code taxonomy (**0** in sync / **1** drift / **2** could not measure),
either MEASURED or **visibly SKIPPED** with no third outcome (lesson **77**),
hermetic self-tests registered in `quality`, mutation-checked with each mutation
reddening a *named* assertion. `tool/ci/app_icons.py` + its test are this
session's worked example of that shape, including the sections-based harness
that reports which property moved when a mutation *raises*.

If no sound comparison exists, **close #166 with the evidence** and record the
two cheap partial checks that would each have caught S063's actual failure —
they are named in `past-prompts.md` S063 and both are now demonstrated:

* a **set comparison** of `firebase functions:list` against the exports in
  `functions/src/index.ts` (13 vs 13 today), and
* an **assertion over the sweep's own structured log** — the absence of
  `daily-question sweep complete` *was* the diagnosis.

Neither answers "is the deployed code identical to `main`". **Both would have
worked**, which is the argument for building one even if the exhaustive answer
is unreachable.

### Acceptance 4

ADR + `docs/architecture.md` §9 in the same diff (rule #8).

### ⚠️ Before touching anything

**Prod Functions deploys are on the never-without-asking list** (`session-context.md`
§7). Arming anything in CI needs the same operator secret as the rules half
(**2(e)(iii)**), which is still absent — so expect the lane to be *visibly
skipped*, by design, exactly like `rules-drift`.

---

## 3. Then, in priority order

**1 — Ask whether the founder installed 117 and tapped Allow, then MEASURE.**
Do not ask them what arrived; ask only whether they accepted the prompt, then
read `registerPushToken`'s log and the `checked` counter yourself. If a token was
captured and no push arrives at 08:00, that is a real bug and now a findable one.

**2 — #204, the `tr` localization.** Do **not** repeat the old instruction to
the founder ("just add the locale") — it was wrong and is corrected on the
operator page. Apple rejects the name. The non-founder half of #204 is real
engineering and is unblocked: **make a failed `deliver` visible** so a green
release cannot again mean "store metadata silently did not land" (ADR-024 D1:
all notifier policy lives in `slack_notify.sh`, and the notifier has no vote on
the build). Once the founder picks a name, `name.txt` + `release_lane_lint.dart`
+ ADR-032 move in one diff, then
`appstore-screenshots.yml -f upload=true -f locales=en-US,tr`.

**3 — The rest.** Re-derive from `gh issue list`. **#175** (10 of 14 raised cards
render flat) · **#174** (no `liveRegion` — the reveal is never announced) ·
**#137** · **#129/#121** · **#115** · **#41**.

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first. Token capture needs none of it; only background *delivery* does.
`signing_sentinel_test` reddens if it is added.

---

## 4. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **M3.4's last inch** | the founder's phone | One install + one permission tap. **The credential half is CLOSED** (APNs `.p8` confirmed 2026-08-08). Verification is no longer blocked — only the tap is. |
| **`tr` App Store version localization** | founder | Measured absent. Screenshots cannot upload into a locale that does not exist |
| **operator 2(d)** — Associated Domains | founder | Measured absent. Same portal page as the push tick |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Gates arming any deploy lane in CI |
| **operator 2(e)(iv) / #165** | founder | One read-only SA + `gh secret set`. Until then `rules-drift` is SKIPPED **by design** |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15**, **#136** | the device | On-device observation nobody has made |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 5. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main` run**
(`integration-emulator` is main-only) → `codegraph sync`.

**S059–S061 skipped this three times. S062, S063 and S064 all ran it. Keep the streak.**
