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
- **`seasonal-window.test.ts` — 48 tests pass**, which is the 19 Umm al-Qura date rows *and* the silent-Gregorian degradation test. That second one matters here specifically: it works by making `resolvedOptions` writable+configurable to install the failure mode, and a runtime that changed that property's descriptor would **silently disarm the test**. Re-checked; still configurable on 22.
- **`day-key-parity.test.ts` — 20 tests pass** (the TS half of the byte-pinned TS↔Dart agreement), and the Dart half (`couple_day_key_test.dart`, 24 tests) passes too. The fixture is shared, so a runtime that changed date arithmetic would break the pin from one side.
- **Whole suite on Node 22: 963 tests / 49 files pass**, coverage byte-identical to Node 20 (97.75% statements, 93.61% branches), with the emulator reporting `✔ functions: Using node@22 from host`.

The test comments now record the re-verification **and why it was necessary**, so the next runtime bump inherits the reasoning rather than the conclusion.

## Decision 3 — Scope: the runtime and its type definitions. **Nothing else, on purpose.**

Changed: `functions/package.json` `engines.node` 20 → 22 and `@types/node` `^20.19.43` → `^22.20.1` (with the lockfile), and the **three** `actions/setup-node` pins — two in `ci.yml`, one in `release.yml` — moved in the same diff, because a CI leg testing on a different major than the deployed runtime is a gap that reports green.

**Deliberately NOT changed, each recorded rather than silently skipped:**

- **`firebase-admin` stays `^13`, and its stated reason is now void.** `architecture.md` said the pin existed because *"v14 requires Node ≥22"* — a constraint this upgrade lifts. The **reason** is corrected in the same diff (a stale justification is worse than none); the **upgrade** is issue **#107**. Bundling a dependency major into a runtime bump would turn one verifiable change into two entangled ones, and v14's exposure is exactly the surface ADR-019's resumable cascade leans on hardest.
- **`firebase-functions` stays v7**, though the deploy also warns it is outdated. Same reasoning, same issue.
- **`hayatiapp-prod` is not deployed.** Dev first; prod follows a session that has watched dev behave on the new runtime.

## Decision 4 — Every surface that *named* Node 20 is corrected, not just the ones that enforce it

`grep` for the old runtime across the repo before declaring the bump done — this project's standing addendum, earned twice in S041/S042. Seven surfaces named Node 20 and only three of them enforced anything:

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
4. `coachProxy`… and in fact all eleven-minus-one deployed functions redeployed to `hayatiapp-dev` on `nodejs22`, each reporting `ACTIVE`, and **the deploy no longer prints the Node 20 decommission warning**.
5. **The decisive production signal:** the next scheduled `questionRollover` sweep on the new runtime logs `seasonalCalendarUnavailable: false`. If it logs `true`, ICU on the deployed Node 22 image lacks Umm al-Qura, the guard has fired for real, and the correct response is to roll the runtime back — not to ship seasonal content that can never appear.
