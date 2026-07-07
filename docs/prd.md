# Product Requirements Document — Hayati

**Version:** 1.0 · **Owner:** Founder · **Status:** Approved for MVP build (post-Gate 1)

## 1. Product vision

The private daily ritual for two. Hayati helps couples and spouses in Turkey, the GCC, and the Arabic-speaking world stay connected in five minutes a day — in their own language, respecting their own culture, without the cost or stigma of therapy.

**Positioning line:** *The app you use with your partner — never to find one.*

## 2. Goals & non-goals

**Goals:** (1) daily habit for both partners; (2) pairing as the activation event; (3) subscription revenue with GCC as margin engine; (4) content system that doubles as marketing supply.

**Non-goals:** matchmaking or any stranger interaction; therapy or clinical claims; public social feed; Western feature parity for its own sake.

## 3. Personas

- **P1 — Zeynep & Emre (Istanbul, 27 & 29, dating 2 yrs).** Secular, hyper-online, found us on TikTok. Want playfulness and "do you really know me" games. Price-sensitive; will pay ₺-tier or lifetime. Tone: casual, flirty allowed.
- **P2 — Noura & Fahad (Riyadh, 31 & 34, married 5 yrs, two kids).** Drifting into logistics-only communication. Therapy is unthinkable socially; a private app is face-saving. Pay iOS premium prices. Tone: warm, dignified; spice mode discovered later, appreciated, never advertised at them.
- **P3 — Aylin & Karim (Berlin/London diaspora, 26 & 30, engaged).** Bilingual, bridge two cultures, pay EU prices, share content — our best evangelists.

## 4. Core loop

Open (push: "Today's question is waiting — Fahad hasn't seen your answer yet") → answer today's question → **mutual reveal** (partner's answer unlocks only after you answer — the core mechanic; creates curiosity pressure on the lagging partner) → react/comment privately → streak seed added → occasional quiz/challenge → paywall touchpoints on depth.

## 5. Features

### P0 — MVP (build order in `implementation-plan.md`; scope fence in `mvp.md`)

- **F1 Onboarding & pairing.** Phone/Apple/Google auth. Relationship profile (status: dating/engaged/married; language; tone register: playful/respectful). Pairing via link or 6-digit code, optimized for WhatsApp. **Invited partner sees a live preview (today's question + partner's locked answer) before creating an account** — the reluctant-husband flow. Solo mode: 7 days of solo reflection questions with persistent invite nudges; app is honest that it's better together.
- **F2 Daily question + mutual reveal.** One question/day per couple, localized packs (TR ×2 registers, AR MSA-Gulf, EN), category-tagged (fun/deep/memories/future/gratitude). Timezone-correct rollover per couple. Reveal → private thread on that question.
- **F3 Couple streak.** Shared streak counted when *both* answer. Pomegranate-seed visual (see brandkit). One free "mercy day" (grace token) per week — retention insurance, culturally framed.
- **F4 Paywall & subscription.** RevenueCat. Free: daily question + streak. Premium (one purchase covers both partners): all packs, quizzes, AI coach, spice mode, timeline. Trial 7 days, annual-first presentation. Gift-your-partner purchase flow.
- **F5 AI Coach v0.** Chat with persona presets: Coach (communication help), Date Genie (locale-aware date ideas), Gift Genie (occasion-aware). Server-proxied LLM; 10 messages/day cap free-tier zero / premium capped; hard guardrails: not therapy disclaimer, crisis-language detector → localized redirect to professional help, no medical/legal advice, respects tone register.
- **F6 Privacy pack.** PIN/biometric app lock; **discreet mode** (alternate innocuous icon + neutral notification text); notification privacy defaults ON in AR locale. This is a headline feature, not a setting.
- **F7 Localization & RTL.** TR/AR/EN at launch; full RTL mirroring; Arabic typography first-class; per-locale store listings.

### P1 — v1.5 (post-Gate 3)

- **F8 Quizzes & challenges.** Love-language and "how well do you know each other" quizzes with **shareable result cards sized for WhatsApp Status and Instagram Stories** (identity-safe, no answer content leaked); 7/30-day couple challenges.
- **F9 Spice mode (18+).** Text-only intimacy prompts between spouses; opt-in by *both* partners; separate discretion layer; region-flaggable via Remote Config; drives 17+ store rating when enabled.
- **F10 Shared bucket list + memories timeline.** Private couple timeline (photos, milestones, Hijri+Gregorian anniversary tracking with reminders).
- **F11 Ramadan mode.** Seasonal pack (gratitude/spiritual/family questions), adjusted notification windows (post-iftar), Ramadan couple challenge. Ships before first post-launch Ramadan regardless of phase.

### P2 — v2 (see `roadmap.md`)

- **F12 Anonymous community polls.** "73% of couples argue about this too" — normalization without exposure. No profiles, no DMs, heavy moderation. This is the *only* extra-couple social surface, ever.
- **F13 Expert packs marketplace** (licensed counselors author packs; rev-share). **F14 B2B premarital program pilot.** **F15 Widgets & watch.**

## 6. Social layer — decision record

Evaluated: public profiles, communities, rankings, stranger matching, flirting, accountability partners, local groups. **Decision: the couple IS the network.** Extra-couple social surfaces are limited to (a) outbound share cards and (b) anonymous aggregate polls (F12). Rationale: trust and discretion are the purchase drivers for P2 (our margin persona); any stranger-interaction surface converts us from "marriage companion" to "suspicious app on my spouse's phone," destroys the GCC positioning, and invites moderation cost a solo founder cannot carry. Flirting exists exclusively *inside* the couple (F9). Virality is carried by content and invites, not by a feed.

## 7. Content system

Question packs are structured data (id, locale, register, category, depth-level, seasonal-window), authored natively per culture — **never machine-translated**; AI-assisted drafting allowed with mandatory native review (Gulf reviewer for AR packs). Bank targets at launch: 400 TR / 300 AR / 300 EN. The same bank feeds the marketing engine: every question is a potential TikTok slideshow — content ops and product content are one pipeline (see `agent-workflows.md`).

## 8. Non-functional requirements

Offline-tolerant (answers queue and sync); cold start <2s mid-range Android (TR device reality); full RTL; accessibility per brandkit; KVKK/PDPL data-subject rights (export + delete self-serve); relationship data encrypted at rest, never used for ads; analytics pseudonymous; AI inputs never retained beyond session context window budget.

## 9. Metrics

**North star: couples with ≥4 mutual-answer days per week ("connected couples").**
Activation: % signups paired ≤7d (Gate 2 ≥40%). Retention: D1/D7/D30 couple retention (D7 ≥25%). Revenue: install→trial ≥6%, trial→paid ≥30% (Gate 3), churn <10%/mo, GCC+diaspora revenue share ≥50% by month 12. Loop health: invites sent/signup, invite→pair conversion, share-card CTR.

## 10. Release criteria (MVP)

All P0 features pass acceptance tests in `test-suite.md`; RTL golden tests green; KVKK/PDPL delete+export verified; paywall verified with store sandbox in TR + SAR storefronts; crash-free sessions ≥99.5% in closed beta (20 couples, 2 weeks); Gate 2 instrumentation live from day one.
