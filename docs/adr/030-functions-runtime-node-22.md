# ADR-030: The Functions runtime moves to Node 22 — before the first prod deploy, and the ICU re-verification is the actual deliverable

- **Status:** Accepted
- **Date:** 2026-07-26 (Session 043)
- **Deciders:** session agent (no founder input needed — dated infrastructure debt with a forced deadline, no product or cost decision attached)
- **Related:** issue **#96** (this ADR closes it), ADR-026 (the seasonal-window ICU availability guard — **the reason this upgrade is verifiable at all**), ADR-011 (the hourly rollover whose runtime this is), ADR-021 (the CI pin discipline this touches), ADR-019 (the cascade suites most exposed to a runtime semantics change), `docs/architecture.md` §2/§9, issue **#107** (the `firebase-admin` pin this deliberately does not touch)

## Context

Every `firebase deploy` since S040 has printed:

> ⚠ functions: Runtime Node.js 20 was deprecated on 2026-04-30 and will be decommissioned on **2026-10-30**, after which you will not be able to deploy without upgrading.

Read from firebase-tools' own lifecycle table (`lib/deploy/functions/runtimes/supported/types.js`) rather than from memory:

| Runtime | Status | Deprecated | **Decommissioned** |
|---|---|---|---|
| `nodejs18` | deprecated | 2025-04-30 | 2025-10-30 |
| `nodejs20` | GA | 2026-04-30 *(past)* | **2026-10-30** |
| `nodejs22` | GA | 2027-04-30 | **2028-10-31** |
| `nodejs24` | GA | 2028-04-30 | **2028-10-31** |

Two things follow, and the second is the one a future session will get wrong:

1. This is **dated, not stylistic**. After 2026-10-30 deploys fail outright — including whatever emergency fix is needed that day.
2. It sits **on the path to the first prod deploy**, which is why S040 recorded that the natural time to fix it is *before* prod is stood up, never after. Standing prod up on a runtime with a known end date would be choosing to do this twice.

## Decision 1 — Target **Node 22**, not Node 24, and the reason is the table above

`nodejs22` and `nodejs24` **share the same decommission date (2028-10-31)**. Node 24 buys exactly one thing: the deprecation *warning* starts a year later (2028-04-30 rather than 2027-04-30). It buys **no additional runway** — the next forced upgrade lands on the same day either way.

So the choice is between a quieter 2027 and a more conservative runtime, and this project's infrastructure posture is conservative. Node 22 also wins on two practical grounds:

- **It is locally validatable.** The dev box has Node **22.23.1** available via nvm, so the whole suite ran on the *exact target major* rather than being pushed to CI and hoped for. A runtime upgrade validated only in CI is a runtime upgrade nobody has actually run.
- **The toolchain is mature there** — `@types/node@22.x` is long-settled, and `firebase-functions@7.2.5` (`engines: >=18.0.0`) and `firebase-admin@13.10.0` (`engines: >=18`) both already permit it, so no dependency is forced along.

Recorded explicitly so it is not re-litigated: **choosing 24 later gains nothing but a quieter year, and the next upgrade is due before 2028-10-31 regardless.**

## Decision 2 — The deliverable is the **ICU re-verification**, not the version string

Bumping `engines.node` is three characters. The reason this needed a session is ADR-026: the seasonal-window feature computes Hijri dates through ICU's `islamic-umalqura` calendar, and **`Intl` resolves an unsupported calendar to `gregory` SILENTLY**. A runtime upgrade is *precisely* the event that can move ICU data or availability underneath the product — which is why ADR-026 built an availability guard and a 19-row date fixture in the first place.

So the upgrade is only as good as what those fixtures report. Verified on Node 22 (v22.23.1), each run **deliberately and read**, not inferred from a green suite:

- **Availability:** `new Intl.DateTimeFormat('en-u-ca-islamic-umalqura', …).resolvedOptions().calendar` → **`islamic-umalqura`** (not `gregory`). Full ICU, **ICU 78**, `small-icu: false`. A real date confirms it numerically rather than by name: `2026-03-20` → **`10/1/1447 AH`**, which is a Hijri date, not a Gregorian one wearing a Hijri label.
- **`seasonal-window.test.ts` — 48 tests pass**, which is the 19 Umm al-Qura date rows *and* the silent-Gregorian degradation test. That second one matters here specifically: it installs the failure mode by spying on `Intl.DateTimeFormat.prototype.resolvedOptions`, so a runtime that made that property non-configurable would break the test's *mechanism*. Re-checked; still configurable on 22.

  > *Rev 2 (review finding): the previous sentence said such a runtime would **"silently disarm the test"**. That is wrong, and wrong in the alarming direction — `vi.spyOn` calls `Object.defineProperty`, which **throws a `TypeError` on a non-configurable property**, so the test would fail **loudly** with an installation error rather than pass while testing nothing. The correction matters because the two failure modes call for opposite responses: a loud install error is self-announcing, whereas a silent disarm is the thing this project actually fears. Verified by reading vitest's spy source, not assumed.*
- **`day-key-parity.test.ts` — 20 tests pass** (the TS half of the byte-pinned TS↔Dart agreement), and the Dart half (`couple_day_key_test.dart`, 24 tests) passes too. The fixture is shared, so a runtime that changed date arithmetic would break the pin from one side.
- **Whole suite on Node 22: 963 tests / 49 files pass**, coverage **percentages unchanged** at 97.75% statements / 93.61% branches (rev 2: the first draft said *"byte-identical"*, which V8 does not guarantee across majors and which nothing checked — the percentages are what the gates read and what was actually compared), with the emulator reporting `✔ functions: Using node@22 from host`.

- **The runtime bump moved `tzdata`, not just Node — and that is the bigger date risk, missed by the first draft and found by the review.** Measured on both local binaries: **ICU is identical (78.2) on Node 20 and Node 22**; what changed is the **timezone database, 2025c → 2026a**. A verified behavioural consequence: at the Istanbul midnight boundary (`2026-02-17T21:00:00Z`), `formatToParts` with `hour12: false` returns hour **`"24"` on Node 20 and `"00"` on Node 22**. That specific divergence is **harmless here, verified rather than assumed**: `day-key.ts` requests only `year`/`month`/`day` parts (its own header says *"no hour"*), so no hour value reaches a day key. But the general point stands — **a tzdata revision can change UTC offsets, and a day key is a function of offsets.** The `day-key-parity.json` fixture is exactly the guard for that, which is why running it deliberately was worth doing rather than trusting the aggregate suite. **Honest bound:** the fixture pins the zones it pins; a couple in a zone whose rules changed in 2026a and which the fixture does not cover is not covered by this verification either.

The test comments now record the re-verification **and why it was necessary**, so the next runtime bump inherits the reasoning rather than the conclusion.

## Decision 3 — Scope: the runtime and its type definitions. **Nothing else, on purpose.**

Changed: `functions/package.json` `engines.node` 20 → 22 and `@types/node` `^20.19.43` → `^22.20.1` (with the lockfile), and the **three** `actions/setup-node` pins — two in `ci.yml`, one in `release.yml` — moved in the same diff, because a CI leg testing on a different major than the deployed runtime is a gap that reports green.

**Deliberately NOT changed, each recorded rather than silently skipped:**

- **`firebase-admin` stays `^13`, and its stated reason is now void.** `architecture.md` said the pin existed because *"v14 requires Node ≥22"* — a constraint this upgrade lifts. The **reason** is corrected in the same diff (a stale justification is worse than none); the **upgrade** is issue **#107**. Bundling a dependency major into a runtime bump would turn one verifiable change into two entangled ones, and v14's exposure is exactly the surface ADR-019's resumable cascade leans on hardest.
- **`firebase-functions` stays v7**, though the deploy also warns it is outdated. Same reasoning, same issue.
- **`hayatiapp-prod` is not deployed.** Dev first; prod follows a session that has watched dev behave on the new runtime.

## Decision 4 — Every surface that *named* Node 20 is corrected, not just the ones that enforce it

`grep` for the old runtime across the repo before declaring the bump done — this project's standing addendum, earned twice in S041/S042 and **not fully learned even here: the first sweep missed two surfaces, and the review found them** (see the rev note at the end). Of everything that *named* Node 20, only **three places enforced it** — `functions/package.json` `engines` (Decision 3) and the `setup-node` pins in `ci.yml` and `release.yml`. Everything else below was a description that would have quietly misled the next reader:

`ci.yml` and `release.yml` step comments · `functions/src/invites/join-service.ts` (`Intl.supportedValuesOf` described as "a Node 20 runtime built-in" — it is Node 18+, so the claim was both stale and imprecise) · both `seasonal-window.test.ts` comments · `architecture.md` §2 · `implementation-plan.md` · `operator-expected.md` (the live-functions table **and** the dated ⚠ item, now closed) · `ADR-021`'s pinned-versions list.

`docs/past-prompts.md` is deliberately untouched — prior entries are immutable history (project-rules #2), and history is allowed to record what was true then.

## Consequences

**Positive:**

- A dated failure with a hard deadline is closed **five months early**, and off the critical path of the first prod deploy rather than on it.
- **ADR-026's guard earned itself a second time.** It was built to catch a silent Gregorian fallback in production; here it served as the acceptance test for a runtime migration. That is a guard paying for itself in a way its author did not have to anticipate — worth noting when the next "is this fixture worth it?" question comes up.
- The runtime now matches a Node major the dev box can actually run, so the next person to touch Functions locally is testing what deploys.

**Negative / accepted trade-offs:**

- **Node 22 will itself warn from 2027-04-30 and die 2028-10-31.** This is a lease, not a fix, and Node 24 would not have extended it.
- **The deployed runtime is verified by the emulator and one real deploy, not by a long production soak.** Mitigated by the one thing that *is* a production signal: the hourly rollover's own `seasonalCalendarUnavailable` line, read from the new runtime after deploying (see Acceptance).
- Two dependency majors are now unblocked but undone (#107). Recorded, not hidden.

## Acceptance

1. `engines.node` is `22`, `@types/node` is `^22.x`, and **zero** `node-version: '20'` pins remain in `.github/workflows/`.
2. On Node 22: eslint clean, both `tsc` projects clean, build clean, **963 tests pass**, coverage ≥ the 80 hard / 85 target gates.
3. The ICU availability check and the seasonal-window + day-key-parity fixtures **run explicitly and their results written down** (Decision 2) — not inferred from a whole-suite green.
4. **The ten deployable functions** redeployed to `hayatiapp-dev` on `nodejs22`, each `ACTIVE`, and the deploy no longer printing the Node 20 decommission warning.

   **Use the named-exclusion command — `--only functions` would fail.** `revenueCatWebhook` declares `secrets: ['RC_WEBHOOK_TOKEN']` and that secret does not exist, so a blanket deploy dies on it and can leave a **split-runtime backend**, some functions on 22 and some on 20. S040 established the pattern (a `--dry-run` first, then naming the ten); this ADR repeats it:

   ```sh
   firebase deploy --project hayatiapp-dev --only \
     "functions:createInvite,functions:joinInvite,functions:invitePreview,\
      functions:coachProxy,functions:deleteAccount,functions:exportData,\
      functions:recordConsent,functions:updateNotificationPrivacy,\
      functions:questionRollover,functions:answerReveal"
   ```

   **And re-verify the two things a redeploy can silently move** (neither is implied by `ACTIVE`): the Cloud Scheduler job `firebase-schedule-questionRollover-europe-west1` is **ENABLED** at `0 * * * *` UTC (ADR-011), and `answerReveal`'s Eventarc trigger still reports **`RETRY_POLICY_RETRY`** (ADR-012). A runtime bump touches every function, so this is the run where they are most likely to move.

   **Result (2026-07-26 04:54Z):** all ten `ACTIVE` on `nodejs22`; **the decommission warning is gone**; the Scheduler job `ENABLED`, `0 * * * *`, `Etc/UTC`; `answerReveal` `retryPolicy: RETRY_POLICY_RETRY` on trigger `answerreveal-484370` with its document filter intact.

5. **The decisive production signal:** the next scheduled `questionRollover` sweep on the new runtime logs `seasonalCalendarUnavailable: false`. If it logs `true`, ICU on the deployed Node 22 image lacks Umm al-Qura, the guard has fired for real, and seasonal content would be permanently unreachable — the correct response is to roll back, not to ship it.

   **What rollback actually means, since "roll it back" is easy to write and worth pinning:** revert `engines.node` to `20` and `@types/node` to `^20.x`, regenerate the lockfile, and re-run the named-exclusion deploy above. It is a redeploy, not a Cloud Run revision rollback — reverting to a prior revision would restore the old *container* but leave `package.json` claiming 22, so the next deploy would undo it. **This option expires on 2026-10-30**, after which `nodejs20` is decommissioned and there is nothing to roll back to; the forward fix would then be Node 24.

   **Result (2026-07-26 05:00:02Z, the first sweep on the new runtime):** `{"message":"question_rollover: sweep complete","seasonalCalendarUnavailable":false,"failed":0,"buckets":0,…}` — **`false` from the deployed Node 22 image.** The guard ADR-026 built to catch a silent Gregorian fallback served as the acceptance test for a runtime migration, and passed.

## Review record (Session 043 — one combined pass, and it earned itself)

**Shape:** a single combined pass over the built diff rather than the usual design-then-diff pair. Proportionate by the S031 precedent: the design here *is* the diff (a runtime constant, three CI pins, and a set of claims), so a design-only pass would have reviewed the same text twice. 4 lenses (completeness, runtime semantics, ADR-self-claims, risk/rollback) × 2 verifiers. **11 findings, all real.**

The three that changed the substance:

1. **The `tzdata` bump was missed entirely.** The ADR framed the risk as *ICU*, and checked ICU carefully — but **ICU is identical on both local Nodes (78.2)**; what actually moved is the **timezone database, 2025c → 2026a**. The lens found it by running both Node binaries and diffing the output, which is the only way it could have been found. It is harmless *here* (verified: `day-key.ts` reads no hour part), but a tzdata revision changes UTC offsets and a day key is a function of offsets — so the `day-key-parity` fixture, not the ICU check, is the guard that mattered, and the honest bound is that it covers the zones it pins. **The lesson generalises past this ADR: "a runtime upgrade" is at least three upgrades — the JS engine, ICU, and tzdata — and they move independently.**

2. **"A non-configurable `resolvedOptions` would silently disarm the test" was false, and false in the alarming direction.** `vi.spyOn` calls `Object.defineProperty`, which **throws** on a non-configurable property — the test would fail *loudly*. The lens verified this by reading vitest's spy source. Corrected, because the two failure modes call for opposite responses and this project's whole anti-vacuity posture depends on telling them apart.

3. **Two Node-20 surfaces survived the sweep — including `ADR-026`'s own line 88**, the ADR this entire bump is about, which still read *"Node 20 (the pinned Functions runtime)"*. The seasonal-window **fixture header** was the other. This is the *"grep the whole repo before declaring a claim corrected"* addendum failing on the very session that has been invoking it, for the third time in three sessions. Both fixed; the arithmetic in Decision 4 ("seven surfaces / three enforced") was corrected in the same pass.

The rest were precision fixes to this ADR's own claims: the safe deploy command and the split-runtime hazard now written down rather than merely practised; what rollback concretely requires **and that the option expires 2026-10-30**; the Scheduler/Eventarc re-verification promoted from something the session happened to do into something Acceptance requires; *"coverage byte-identical"* replaced with the percentages actually compared; and Acceptance items 4 and 5 given their real, dated results instead of past-tense assertions about work a diff cannot evidence.
