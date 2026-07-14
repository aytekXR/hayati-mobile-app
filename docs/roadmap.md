# Roadmap — Hayati

Gates from `feasibility-report.md` §10 govern phase transitions. Dates are relative to project start (T0); calendar note: **plan v1.5 so Ramadan mode ships ≥3 weeks before the next Ramadan**, whatever phase we're in.

> **De-gating note (ADR-007, 2026-07-08):** the build (Phases 1+ engineering, M1→M6) proceeds immediately and independently of Phase 0 — gates are decision instruments for marketing/spend/launch posture, no longer build blockers. Phase 0 content ops are optional/founder-driven. First release target is the founder couple's own devices (personal-use-first). Phase timing below reads as sequence, not calendar commitments.

## Phase 0 — Validation (T0 → T0+3w) · *optional / founder-driven since ADR-007 (was: gate for build investment)*

- Content ops infra: 6 fresh TikTok accounts (3 TR / 3 AR), tracking spreadsheet (account, hook, format, views, likes, comments, comment-intent), 2 UGC creators contracted (TR + Gulf-dialect), AI slideshow pipeline.
- Produce & post 60 slideshows (30 TR / 30 AR): couple-question hooks, "answer this with your partner" formats, reaction formats.
- Parallel (allowed): M0 repo scaffold + CI (see `implementation-plan.md`).
- **Exit = Gate 1:** ≥3 posts >100K views from <5K-follower accounts per language. Both fail → NO GO (archive learnings, stop). One fails → re-scope single-market, revise `feasibility-report.md`.

## Phase 1 — MVP build (T0+3w → T0+9w)

- Milestones M1–M6 (`implementation-plan.md`); content bank authoring (400 TR / 300 AR / 300 EN) runs alongside build; closed beta with 20 recruited couples in final week via iOS TestFlight; App Store assets TR/EN (Play assets deferred to the Android enablement follow-on, M6.5).
- Content ops continue at reduced cadence — accounts must be warm at launch.
- **Exit:** MVP release criteria in `prd.md` §10 met.

## Phase 2 — Turkey soft launch (T0+9w → T0+13w)

- Ship to the **iOS App Store** TR storefront (Android follows post-validation — see the Android enablement follow-on (M6.5) below and ADR-006); content ops to full cadence (≥5 posts/day/language, winning hooks doubled); weekly funnel review against Gate 2; activation iteration only (pairing flow, notification copy, preview screen) — feature freeze otherwise.
- **Exit = Gate 2:** paired ≥40% ≤7d; D7 couple retention ≥25%. *(iOS-first caveat, ADR-006: this first Gate 2 read is the TR iOS cohort only — a minority platform in Android-heavy Turkey — so treat it as directional; the fuller read arrives once the Android enablement follow-on (M6.5) ships.)*

## Phase 3 — Monetize (T0+13w → T0+17w)

- Paywall experiments (price points, annual framing, gift flow prominence) via RevenueCat experiments; TR lifetime tier test; first cohort LTV read.
- **Exit = Gate 3:** trial→paid ≥30%; install→paid ≥2%. Passing unlocks spend, the Android enablement follow-on (M6.5), and GCC.

## Android enablement & Play release (M6.5) — follow-on (after Gate 3 · iOS MVP validated)

- Per iOS-first (ADR-006; detailed as **M6.5** in `implementation-plan.md`): Android release hardening (Play internal → production track, TR Play storefront + assets), RevenueCat/Play-billing parity, and Android-specific QA (deep-link cold start, discreet icon, push, RTL). Same Flutter codebase — platform hardening, not new product scope, so it stays cheap.
- Un-blinds the Android-heavy TR market and lets the fuller TR cohort confirm the iOS-only Gate 2/3 reads (see the Phase 2 Gate 2 caveat). May run in parallel with Phase 4 (GCC is iOS-heavy), so it does not delay the Phase 4 window.

## Phase 4 — Arabic launch & GCC push (T0+17w → T0+26w)

- AR store listings (KSA, UAE, KW, QA, BH, OM + EG for volume); Gulf creator UGC scale-up; SAR/AED premium pricing live; diaspora targeting (DE/UK/FR/US Arabic+Turkish communities); RTL polish pass from beta feedback; Apple Search Ads *only if* Gate-3 economics support it.
- KPI: GCC+diaspora ≥35% of new MRR by end of phase (path to the 50% month-12 target).

## UI/UX refactor with UI/UX Pro Max ("uipro") — founder directive 2026-07-14

The founder installed the **UI/UX Pro Max** skill tooling (`uipro` CLI v2.11.0,
npm `ui-ux-pro-max-cli`, global on the dev box) and directed that the app's
whole UI/UX be refactored through it. Recorded as a roadmap unit, honestly
scoped:

- **What:** a full UI/UX pass over every app surface, driven by the UI/UX Pro
  Max skill (the first refactor session runs `uipro init` in the repo to
  install the project-level skill — it is not project-installed yet — then
  works surface-by-surface).
- **Binding constraints (from the standing project record):** (1) **brandkit
  v1.0 stays the visual constitution** — the skill proposes, the brandkit's
  tokens/assets decide; the refactor is expressed through brandkit tokens, it
  does not replace them. (2) The **security surfaces keep their invariants**:
  the lock screen's no-dialog/no-Overlay constraint (ADR-018 D3), the privacy
  shield, the consent screen (whose copy is a guarantee surface, ADR-023) —
  any refactor touching them re-runs the relevant invariant audits in the
  same diff. (3) Copy under the **native-review gate** (operator item 1) is
  not reworded by a refactor session without flagging it back into that gate.
  (4) Goldens ×3 locales + RTL remain the acceptance harness — every
  refactored screen regenerates them intentionally, never blind-accepts.
- **Sequencing:** needs its own scoping ADR (surface inventory, skill-output →
  brandkit mapping, session slicing) before any pixels move; sized as a
  multi-session arc. It enters the next-session queue behind the standing
  preemptions (item 6 → M5.3; Blaze → first deploy; Gate 3 → M6.5) and ahead
  of the AI-chosen backlog (e.g. seasonal windows #29) — the founder can
  re-order it to the front by saying so.

## v1.5 (months 6–9)

Quizzes + WhatsApp/IG share cards → Spice mode (18+, both-partner opt-in, region flags) → Bucket list + memories timeline (Hijri+Gregorian dates) → **Ramadan mode** (calendar-driven priority) → referral rewards → break-even checkpoint (~500–550 paying couples; if trending short, cut content spend before cutting price).

## v2 (months 10–15)

Anonymous community polls (the only extra-couple surface — see `prd.md` §6) → expert question-pack marketplace pilot (2–3 licensed TR/AR counselors, rev-share) → B2B premarital pilot (one GCC family-program or TR municipality conversation) → widgets/watch → dialect packs (Egyptian, Levantine) → evaluate web companion.

## Standing decision points

- **Month 6:** TR-only economics honest check — if GCC hypothesis is failing, decide: TR-volume/ads-assisted model vs. diaspora-first pivot.
- **Month 12:** lifestyle-business vs. raise decision, driven by GCC ARPU data, not mood.
