# Hayati Redesign — Design & Implementation Roadmap

Hayati today is a beautifully-engineered wireframe: excellent token discipline, invariant hygiene, and honest copy, with almost no visual identity in the product. This roadmap sequences the redesign so the brand direction (pomegranate motif, Nightbloom illustration, staged reveal, new tokens) lands inside the app in impact order — governed by the three validation gates (G1 content virality, G2 activation, G3 monetization) and the ADR-025 invariant firewall. Every task cites real repo paths; a designer/engineer pair should be able to execute without further questions.

---

## How to read this roadmap

**Scoring model.** Each task carries Effort and Impact; we sequence by impact-per-unit-effort, then by technical dependency.

| Dimension | Values | Definition |
| --- | --- | --- |
| Effort | **S** ≤1 day · **M** 1–5 days · **L** 1+ week | Design + implementation + regenerating the six-cell golden matrix ({TR,AR,EN}×{LTR,RTL}) for touched screens |
| Impact | **High** directly moves a validation gate (G1/G2/G3) or the core-loop emotional payoff · **Med** supports a gate or closes a recorded quality gap · **Low** hygiene | Grounded in README gate criteria and PRD §10 funnel |

**Non-negotiable ground rules (apply to every task below):**

1. **Invariant firewall (docs/adr/025-uipro-refactor-scope-and-invariant-firewall.md).** Class F surfaces (`app/lib/features/privacy_lock/presentation/lock_screen.dart`, `privacy_shield_cover.dart`) are parity-only: no Overlay widgets, keypad stays LTR, shield stays brand-free Night forever. Class G copy (consent, legal, coach disclaimer/help/paused, delete/couple-ended, sign-in footer) may be re-laid-out but never reworded without re-running its legal/safety gate.
2. **Goldens are acceptance.** Every visual change regenerates its golden matrix *deliberately* (never blind-accept) and passes `tool/rtl_lint.dart` (logical start/end only).
3. **Every new string** ships through native register owners (TR founder couple, Gulf-dialect AR reviewer — operator item 1) before merge. AR stays modest-romantic and family-safe; the lagging partner is never guilt-tripped.
4. **Trademark caution (ADR-027).** "Hayati" is provisional; invest in the seed mark, keep wordmark investment light until the trademark clears.
5. **DV threat model is load-bearing.** No task may add a push on couple-ended, actor attribution, or brand marks to the shield/switcher.

Brand facts (hex values, taglines, principles) are quoted verbatim from the shared brand direction; the four sibling documents (see [Cross-document dependencies](#cross-document-dependencies)) use the same values.

---

## Quick wins (≤1 day each)

These ten tasks are the highest leverage-per-hour in the repo. QW-1 must land first — it unblocks four of the others.

| ID | Task | Where in code | Effort | Impact |
| --- | --- | --- | --- | --- |
| QW-1 | Close the token gaps: Mist, Veil, Moonlight, Rose | `app/lib/core/design_system/color_tokens.dart`, `hayati_theme.dart`, `brandkit/brandkit/tokens/hayati-tokens.json`, drift test | S | High |
| QW-2 | Settings de-grey: Mist subtitles, Veil dividers | `app/lib/features/settings/presentation/settings_screen.dart` | S | Med |
| QW-3 | "Question" type style 28/300 for the daily question | `app/lib/core/design_system/typography_tokens.dart`, `app/pubspec` font bundle, `paired_home_screen.dart`, `solo_home_screen.dart` | S | High |
| QW-4 | Seed glyph replaces the Material heart in the streak row | `app/lib/features/daily_question/presentation/paired_home_screen.dart`, new glyph in `app/lib/core/widgets/` | S | High |
| QW-5 | Sign-in hero: seed mark + primary tagline | `app/lib/features/auth/presentation/sign_in_screen.dart` | S | High |
| QW-6 | Display-name capture step in onboarding | new `name_capture_screen.dart` in `app/lib/features/profile/presentation/` + routing in `onboarding_gate.dart` | S | High |
| QW-7 | Copy-code button on invite share | `app/lib/features/pairing/presentation/invite_share_screen.dart` | S | Med |
| QW-8 | Locale-aware phone number hint | `app/lib/features/auth/presentation/phone_sign_in_screen.dart` | S | Low |
| QW-9 | Solo-week seed-dot progress row | `app/lib/features/daily_question/presentation/solo_home_screen.dart` | S | Med |
| QW-10 | Soft-unfold page transitions + motion tokens into JSON (#71) | `app/lib/core/design_system/hayati_theme.dart`, `motion_tokens.dart`, `brandkit/brandkit/tokens/hayati-tokens.json` | S | Med |

**QW-1 — Close the token gaps.** Add four tokens, dark/light pairs verbatim from the direction: **Mist** `#B9AFC6` (dark) / `#6B6178` (light) for muted secondary text; **Veil** `#453A5C` / `#E7DCCB` for hairline dividers and outlines; **Moonlight** `#FFF8F1` (both modes) for text/icons on Pomegranate fills; **Rose** `#E38E99` (dark) / `#8E3140` (light) for links and TextButtons. Why: this closes recorded gap #67 (Material grey leaks through settings), fixes the AA failure on button labels (Sand-on-Pomegranate was 3.94:1; Moonlight is 4.7:1), and makes links distinguishable from body text for the first time (Rose is 6.8:1 on Night). Wire into `hayati_theme.dart`: FilledButton foreground → Moonlight, TextButton foreground → Rose (color plus weight, never color alone), InputDecoration hint → Mist. Mirror into the brandkit tokens JSON so the drift test passes intentionally, and update `docs/frontend-brandkit.md` §10 to mark the gaps closed.

**QW-3 — Question style.** The daily question is the product's hero text and currently shares H1 with screen titles. New style: Rubik 28/300, line-height 1.35 Latin / 1.6 Arabic (add weights 300 and 800 to the bundled set). The light weight glows on Night and gives the question a literary voice distinct from chrome.

**QW-4 — Seed glyph.** The brand's central motif appears nowhere in-app; the streak is `Icons.favorite` + text. Ship one custom-drawn seed glyph (24dp grid, 1.75 stroke, per the icon spec) in Pomegranate `#C04A5A`, with tabular figures for the count. This is the cheapest possible delivery of "every day you answer together, a seed" and previews the full vessel (M-3).

**QW-5 — Sign-in hero.** Replace `Text(config.appName)` with the seed mark asset (from `brandkit/brandkit/logo/`, redrawn later in L-5) plus the primary tagline: **"One question a day, for two." (TR: "Günde bir soru, ikiniz için." / AR: "سؤال واحد كل يوم، لكما.")**. The Class G legal footer is untouched. A first-time invitee currently lands on a screen that sells nothing; this is the single highest-leverage square inch in the app.

**QW-6 — Display-name capture.** Add a one-field name-capture step between sign-in and profile capture (per ui-ux §6.1 and product-copy: "What should we call you?" — nicknames welcome, Continue disabled only while empty), pre-filled from the Auth displayName for Apple/Google sign-ins so most users just confirm. Phone sign-ups currently have no name, so the invite preview degrades to "Someone invited you" — directly weakening the reluctant-husband activation moment. One warm field fixes it.

**QW-7 / QW-8 / QW-9.** Copy-code affordance (the custom-scheme link isn't tappable in WhatsApp, so manual code entry is the real path — make the 8-char code one-tap copyable). Phone hint follows device region (a Gulf user currently sees `+90 555 123 45 67`). Solo home gets a 7-seed progress row so "Day 3 of 7" becomes visible progression feeding the pairing nudge.

**QW-10 — Unfold everywhere.** Replace default Material page transitions with the shipped Soft Unfold (240ms easeOut, fade + 12dp rise, RTL-neutral) via `pageTransitionsTheme`; reduce-motion collapses to instant. Write motion values into `hayati-tokens.json`, closing #71. One verb, felt not watched.

---

## High-impact medium efforts (1–5 days)

| ID | Task | Where in code | Effort | Impact |
| --- | --- | --- | --- | --- |
| M-1 | Analytics foundation (funnel events) | `app/lib/core/analytics/` (exists, empty), event calls in auth/pairing/daily_question/entitlements features | M | High |
| M-2 | Reveal choreography v1 (three-beat sequence) | `app/lib/core/widgets/soft_unfold_reveal.dart`, `paired_home_screen.dart`, `motion_tokens.dart` | M | High |
| M-3 | Streak seed vessel + milestones + mercy day | new `app/lib/core/widgets/seed_vessel.dart`, `paired_home_screen.dart`, reads `functions/src/streak/` data | M | High |
| M-4 | Partner-preview question hook | `functions/src/invites/`, `partner_preview_screen.dart`, `state/invite_preview_controller.dart` | M | High |
| M-5 | Onboarding that sells (2–3 pre-auth panes) | new panes ahead of `sign_in_screen.dart`, routed in `app/lib/app.dart` | M | High |
| M-6 | Privacy spotlight card on first home | `app/lib/features/daily_question/presentation/solo_home_screen.dart` (one-time card), reuse `settings/presentation/pin_setup_screen.dart` | S–M | High |
| M-7 | Branded invite card for the share sheet | `app/lib/features/pairing/data/share_plus_invite_share_launcher.dart`, art from `brandkit/branding-assets/social/` | M | High |
| M-8 | Nightbloom empty-state suite (5 states) | `paired_home_screen.dart`, `solo_home_screen.dart`, `couple_ended_notice_screen.dart`, `coach_screen.dart` | M | Med |
| M-9 | Phosphor migration + direction-aware icon wrapper (#63) | ~28 `Icons.*` call sites; new wrapper in `app/lib/core/widgets/` | M | Med |
| M-10 | Paywall as a sales page | `app/lib/features/entitlements/presentation/paywall_screen.dart` | M | Med |

**M-1 — Analytics first.** `app/lib/core/analytics/` exists and is empty; the app has zero instrumentation despite PRD §10 requiring "Gate 2 instrumentation live from day one." Implement the already-enumerated funnel (architecture §7): `install → signup → invite_sent → paired → q_answered → reveal_viewed → trial → paid`, pseudonymous, **no answer text or uid in events** (the privacy promises in the consent copy constrain vendor choice — the events must fit "no advertising or tracking"). This must land before the redesign phases so every subsequent change is measurable. Without it, G2 and G3 are unfalsifiable.

**M-2 — The reveal becomes an event.** "The reveal is the product" — today it is a 240ms fade. Ship the three-beat staged sequence from the motion direction: partner's card unfolds toward yours (~300ms) → both settle as a pair → one seed drops into the streak vessel with a small spring settle (no overshoot >4dp), capped at 1.2s, keeping the single light haptic. Reduce-motion collapses to an instant crossfade with the haptic preserved. This is the only choreography budget in the app; everything else stays calm so this moment can land.

**M-3 — Seed vessel.** The hero illustration object: a vessel that visibly holds seeds as mutual days accumulate, replacing "4-day streak" text. Milestones at 7/30/100 seeds earn Gold `#D9A441` particle restraint (≤1.2s, skippable, never blocking input). Surface the grace token as a culturally framed **"mercy day"** in Sage `#8FAE8B` — the server logic (`functions/src/streak/`) already computes all of this; the entire feature is display-only UI over shipped data.

**M-4 — Partner-preview question hook.** The PRD's strongest activation hook was cut: the zero-auth `invitePreview` shows only the inviter's name. Grow the endpoint's typed projection (designed for exactly this) to `{status, creatorDisplayName, questionText, hasLockedAnswer}` and render on `partner_preview_screen.dart`: today's question, plus the partner's answer as a sealed card — "Aylin has answered. Her answer unlocks when you write yours." Update the field-surface test intentionally. This is the single most Gate-2-relevant missing piece; the reluctant husband must see value *before* creating an account.

**M-5 — Onboarding that sells.** 2–3 swipeable panes before sign-in: (1) the ritual — one question a day, sealed until you both answer; (2) the culture — your language, your register, halal-appropriate; (3) privacy — PIN, discreet icon, "What's between you stays between you." The pitch copy already exists, written and localized, in `fastlane/metadata/tr/` and `fastlane/metadata/en-US/`; the copywriter adapts it. Nightbloom art per pane (paired forms only — two seeds, two branches; never bodies or faces).

**M-6 — Privacy spotlight.** Privacy is a headline feature (PRD F6) for the GCC persona yet PIN setup is buried in settings. Surface a one-time dismissible card on the first home after consent (never modal, never a blocking pane — ui-ux §6.1, product-copy "Keep Hayati between you two"), offering PIN + discreet icon setup and reusing the shipped `pin_setup_screen.dart` flow untouched. Tone: care, never paranoia; keep the DV warning + PIN gate on biometric enablement exactly as is.

**M-7 — Branded invite card.** The only outbound artifact today is plain text. Ship an identity-safe share image (seed motif on Night `#231A33`, tagline, code) attached via `share_plus` — WhatsApp Status is the dominant TR/GCC sharing surface. Identity-safe means: no answer content, nothing that outs the recipient as a user; the card sells the ritual, not the couple.

**M-10 — Paywall.** Keep the honest structure; add benefit vignettes (Nightbloom), a free-vs-premium comparison rooted in the kept promise "Your daily question and streak stay free, always.", and a TR lifetime-tier card concept (one-time-purchase culture; priced in `docs/feasibility-report.md` §6 — no UI concept exists). Gold stays scarce: the "Best value" badge and premium mark remain its only uses. Commercial reality is blocked on operator item 0, but the UI should be ready the day RevenueCat exists.

---

## Long-term bets (1+ week)

| ID | Task | Where in code | Effort | Impact |
| --- | --- | --- | --- | --- |
| L-1 | Push notifications, device half | add `firebase_messaging`, APNs registration, token write; server half shipped in `functions/src/notifications/` | L | High |
| L-2 | Question content bank + couple packs | `content/packs/`, `content/schema/question-pack.schema.json`, `functions/src/rollover/`, `pack_selection_screen.dart` | L | High |
| L-3 | Reveal thread v1 (emoji reactions) | `paired_home_screen.dart`, `state/partner_slot.dart`, new function + `firestore.rules` | L | High |
| L-4 | Universal links + one-page domain | AASA hosting, `app/lib/features/pairing/data/app_links_deep_link_source.dart`, `fastlane/metadata/` URL fields | L | High |
| L-5 | App icon redraw + store identity system | `brandkit/brandkit/logo/`, `app/ios/Runner/Assets.xcassets/`, `fastlane/metadata/` (add `ar-SA/`) | L | High |
| L-6 | Ramadan mode | ~30 tagged questions in `content/packs/` (windows machinery shipped, ADR-026), notification window config | L | Med |
| L-7 | Solo evergreen + solo-history surface | `solo_home_screen.dart`, new history surface post-pairing | M–L | Med |

**L-1 — Push is the heartbeat.** All composition logic (quiet hours 22:00–08:00, discreet-mode neutral text, no-content payloads) is built and emulator-proven; `users.fcmTokens` is simply never written. Until this lands, nothing calls the couple back — fatal for a daily ritual. Design work: notification copy per register (considerate friend, collapses to neutral in discreet mode), pre-permission priming screen. Largest functional gap in the product; schedule before any paid acquisition.

**L-2 — Content is product AND marketing.** Today every couple gets 7 recycled Turkish solo questions (`DEFAULT_PACK_ID = 'solo_tr'`). The launch target is 400 TR / 300 AR / 300 EN with category/depth/register metadata; couple packs and `packConfig` writes don't exist, so premium currently sells an IOU. Critically, the question bank and the G1 TikTok slideshows are one pipeline by design — every authored question doubles as a content asset, and the 60-slideshow G1 test can run *pre-launch with zero app changes*. Authoring must be native-first (culturally authored, not translated), TR dual-register, Gulf-AR modest-romantic.

**L-3 — The loop must not end flat.** Post-reveal is terminal; PRD F2's private thread is parked. Ship the smallest lovable version: emoji reactions on the partner's revealed card (a fixed, register-appropriate set — warm, not neon-dating), server-validated, rendered as a small Pomegranate-accented chip. Full comment threads wait for v1.5.

**L-4 — Universal links.** Custom scheme `hayati://invite/<code>` isn't linkified by WhatsApp, kneecapping the invite funnel. A one-page domain unlocks: tappable https invites with AASA, hosted privacy/support URLs (a store-submission requirement — the fields ship empty today), and an invite fallback page that routes to the App Store. Cheap engineering, big activation delta.

**L-5 — Icon and store identity.** Execute **"Two Seeds, redrawn"**: two pomegranate seeds inclining toward each other — one Pomegranate Deep `#8E3140`, one Pomegranate `#C04A5A` with the Moonlight highlight — clearer asymmetric kiss-point, sharper seed geometry, scaled to ~55% of canvas. The current mark misreads at icon size (butterfly at best) — fatal for a discretion-first brand. The seed mark must carry the brand through a possible rename (İkimiz / Baynana / Mawadda / Roohi are vetted). Same push: Arabic store metadata directory (none exists — create `ar-SA/`), the eight-slot screenshot system on the Paper `#FAF3E8` marketing canvas (marketing §4 storyboard), discreet alternate icon refresh. Test Two Seeds vs. The Unfold via App Store product-page optimization once live.

**L-6 — Ramadan before Ramadan.** The Hijri window machinery shipped early (ADR-026); zero tagged questions exist. ~30 TR/AR Ramadan/Eid questions plus an adjusted notification window makes Hayati the only couples app with a real Ramadan mode — the owned annual moment. Note the recorded Umm al-Qura ±1-day caveat in copy tone (never claim certainty about moon sighting).

**L-7 — Solo evergreen.** The day-8 cliff offers unpaired users nothing, forever. Extend solo into an evergreen track with periodic invite moments, and build the promised-but-missing solo-history surface post-pairing ("your answers will be waiting" is currently a promise no screen keeps — an honesty bug by the brand's own standard).

---

## Recommended implementation order

| Phase | Contents | Duration (1 designer + 1 engineer) | What it unblocks |
| --- | --- | --- | --- |
| **0 — Instrument & baseline** | M-1 analytics; capture current golden matrix + funnel baseline | ~3 days | Every later change becomes measurable; G2/G3 become falsifiable |
| **1 — Tokens & foundation** | QW-1, QW-2, QW-3, QW-10; start M-9 (Phosphor + 5 custom glyphs) | ~1 week | All screen work builds on complete tokens; one deliberate golden regeneration instead of many; AA compliance |
| **2 — Core loop & brand-in-product** | QW-4, QW-9, M-2 reveal, M-3 seed vessel, M-8 empty states | ~2 weeks | "The reveal is the product" becomes true; store screenshots can show real UI; the brand finally has a body in-app |
| **3 — Activation funnel** | QW-5, QW-6, QW-7, QW-8, M-4 preview hook, M-5 onboarding, M-6 privacy spotlight, M-7 invite card | ~2 weeks | The full G2 test (invite → preview → paired) at design strength; TestFlight-ready onboarding |
| **4 — Retention & monetization rails** | L-1 push, L-4 universal links, M-10 paywall | ~2 weeks | The ritual gets its heartbeat; G3 UI ready the day RevenueCat + packs exist |
| **5 — Content & identity bets** | L-2 content bank (feeds G1 immediately), L-5 icon/store system, L-3 reactions, L-6 Ramadan, L-7 solo evergreen | ~4+ weeks, rolling; content authoring parallelizable from Phase 1 | Honest G3 (premium has real contents), G1 at scale, launch-grade store presence |

**Total: roughly 10–12 weeks** to a launch-credible product, with content authoring (L-2) and the G1 slideshow test running in parallel from week 1 — G1 needs no app changes and its verdict should shape Phase 5 investment. Sequencing logic: measure first (Phase 0), because a redesign you can't measure is decoration; foundation before screens (Phase 1), so goldens regenerate once; emotion before funnel (Phase 2 before 3), because the activation flow must have something worth activating into; rails before content (Phase 4 before 5 completes), because push + analytics make every content drop measurable. Operator items (Blaze, RevenueCat, LLM key, APNs enrollment, native copy review) gate Phases 4–5 and should be chased from day one.

---

## Cross-document dependencies

This roadmap is the sequencing layer; four sibling documents in `redesign/` specify the work. Where they conflict, the shared brand direction block is the source of truth; brand facts (hex, taglines, names) are identical across all five by construction.

| Roadmap items | Specifying document | What it must contain |
| --- | --- | --- |
| QW-1, QW-4, M-3, M-9, L-5 | **Visual system & assets** (`redesign/creative-assets.md` + `redesign/ui-ux-redesign.md` §9–10) | Final token table (Mist/Veil/Moonlight/Rose dark+light values — ui-ux §9.1), seed glyph + 4 other custom glyph drawings to the 24dp/1.75 spec, "Two Seeds, redrawn" icon construction, Nightbloom illustration rules (no faces/embracing figures on AR surfaces), gold-restraint and alert-never-marketing rules |
| QW-3, QW-9, QW-10, M-2, M-5, M-8, M-10, L-7 | **UI redesign spec** (`redesign/ui-ux-redesign.md`) | Screen-by-screen redlines for all 48 ADR-025 surfaces, the reveal storyboard (three beats, timings, reduce-motion behavior), seed vessel states (0/1/7/30/100 seeds, mercy day, at-risk), empty-state art briefs, paywall layout with lifetime card |
| QW-5, QW-6, M-4, M-5, M-6, M-7, L-1, L-3, L-6 | **Product copy** (`redesign/product-copy.md`) | All new strings ×3 languages ×registers (tagline placement, onboarding panes, milestone/mercy-day lines, sealed-answer preview line, reaction labels, push copy incl. discreet variants), the frozen-family inventory (what may not be reworded), native-review routing |
| M-7, L-2, L-4, L-5, L-6 | **Marketing & growth plan** (`redesign/marketing-strategy.md`) | G1 test design (60 slideshows — 30 TR / 30 AR per README — ≥3 posts >100K views per language from <5K-follower accounts), question-bank-as-content pipeline, Paper `#FAF3E8` screenshot/store system, AR metadata plan, WhatsApp Status card specs, icon A/B via product-page optimization |

Internal dependency chain: **QW-1 → everything visual** (no screen work before tokens exist); **QW-6 → M-4** (a named preview needs names); **M-1 → all measurement claims below**; **M-9 glyphs → QW-4/M-3** (the seed drawing comes from the brand doc); **L-2 → M-10 honesty** (the paywall may not oversell packs that don't exist — honesty is the interface); **L-4 → M-7** (the invite card should carry a tappable https link, not `hayati://`).

---

## Measurement

Analytics (M-1) is the prerequisite for everything in this table; until it lands, checks run on the founder-couple dogfood build and TestFlight cohorts. *(S047: the parenthetical here used to read "operational proof is currently 0% — nothing deployed"; both backends are deployed and TestFlight builds ship from CI. Analytics remains the real prerequisite.)*

| Change | Primary metric | How to check |
| --- | --- | --- |
| M-5 onboarding + QW-5 hero | signup / install | Funnel events; target visible lift vs. Phase 0 baseline before spend |
| QW-6 + M-4 preview hook + M-7 invite card + QW-7 | **G2: ≥40% of signups paired ≤7 days** | `invite_sent → preview_viewed → paired` conversion; compare named-preview vs. "Someone invited you" cohorts |
| M-2 reveal + M-3 vessel + L-3 reactions | **D7 couple retention ≥25%**; north-star "connected couples" (≥4 mutual days/week) | `reveal_viewed` repeat rate, mutual-day counts from `functions/src/streak/` data mirrored into events |
| L-1 push | Next-day return after reveal; streak survival | Notification-tap → `q_answered` same-day; streak-at-risk saves |
| M-10 paywall + L-2 packs | **G3: trial→paid ≥30%, install→paid ≥2%** (4+ paywall weeks) | RevenueCat dashboard + `trial`/`paid` events; cannot honestly run until packs + coach are real — do not soft-launch spend before that |
| L-2 content + slideshows | **G1: ≥3 posts >100K views per language (TR and AR), from <5K-follower accounts** across 60 slideshows (30 TR / 30 AR, README verbatim) | TikTok analytics; runnable pre-launch, zero app dependency |
| L-4 universal links | Invite-link tap-through vs. manual code entry share | Deep-link source attribution on `paired` events |
| L-5 icon redraw | Store conversion (product-page views → installs) | App Store product-page optimization A/B: Two Seeds vs. The Unfold |
| QW-1/2/3, M-8, M-9 (craft layer) | No single metric — acceptance is qualitative | Deliberate golden review ×6 cells, `tool/rtl_lint.dart` pass, contrast audit ≥4.5:1 text (Moonlight 4.7:1, Rose 6.8:1, Mist 7.9:1 on Night), dynamic type at 130% |
| M-6 privacy spotlight | PIN adoption rate; GCC persona retention | `lock_enabled` event by market; watch that prompting does not dent onboarding completion (skippable by design) |

Two standing measurement rules: **no answer text or uid ever enters an event** (the consent copy's factual claims must stay true — this constrains vendor choice to a pseudonymous posture), and every metric is read per language cohort — a TR win that is an AR loss is a loss for the moat.
