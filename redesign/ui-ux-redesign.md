# Hayati — UI/UX Redesign Blueprint

**Status:** Redesign direction v1 · Pre-launch · Companion to the brand direction, brandkit v1.1, marketing audit, and content strategy documents (all five share one source of truth for brand facts).
**Scope:** Every surface in the ADR-025 inventory (19 screens, 25 sub-widgets, 3 dialogs, 1 snackbar) plus proposed new surfaces.
**Governing constraint:** The ADR-025 invariant firewall. Class F surfaces (lock screen family) are parity-only. Class G copy (consent, legal, coach disclaimer/help/paused, delete/couple-ended sentences, sign-in footer) may be re-laid-out but never reworded without re-running its legal/safety gates. The privacy shield stays a brand-free Night surface, forever. Every redesigned screen regenerates the six-cell golden matrix ({TR, AR, EN} × {LTR, RTL}) intentionally and passes `tool/rtl_lint.dart`.

---

## 1. Product Understanding

**Vision** (docs/prd.md §1): "The private daily ritual for two. Hayati helps couples and spouses in Turkey, the GCC, and the Arabic-speaking world stay connected in five minutes a day — in their own language, respecting their own culture, without the cost or stigma of therapy."

**Positioning in one line:** the app you use with your partner — never to find one. Hayati is a marriage companion, warm and faith-compatible, that begins where matchmaking apps (Muzz, Soudfa, Oolfa) abandon their users: at the wedding. The couple IS the network — no feed, no strangers, ever. The primary tagline, used consistently across product and store: **"One question a day, for two." (TR: Günde bir soru, ikiniz için. / AR: سؤال واحد كل يوم، لكما.)** The enemy is drift — the slow slide into logistics-only marriage.

**Audience (personas, prd.md §3):**

| Persona | Who | What they need from design |
|---|---|---|
| P1 Zeynep & Emre | Istanbul, 27/29, dating, secular, hyper-online, found via TikTok | Playfulness, "do you really know me" energy, TR-playful register in the UI chrome, price sensitivity (lifetime tier) |
| P2 Noura & Fahad | Riyadh, 31/34, married 5 yrs, two kids, drifting | Dignity, discretion (family may check the phone), modest-romantic Gulf Arabic, face-saving alternative to therapy. **The margin persona — GCC carries revenue** |
| P3 Aylin & Karim | Berlin/London diaspora, 26/30, engaged, bilingual | Cultural fluency that Western apps lack; they evangelize; they pay EU prices |

A flagged assumption shapes the whole activation design: **the installing partner skews female**, so the invitee flow is optimized for "get a reluctant husband to tap one link" — the zero-signup partner preview exists for exactly this.

**Jobs-to-be-done:**

1. *"Keep us feeling like two people in love, in five minutes a day"* — the daily question ritual.
2. *"Let me say things I wouldn't say across the dinner table"* — sealed answers, mutual reveal, no performing.
3. *"Keep this between us"* — from family members who pick up phones, from algorithms, from outsiders. Privacy is a headline feature, not a settings checkbox.
4. *"Give me a dignified way to work on my marriage"* — never therapy-coded, never dating-coded.
5. *"Get my partner in with zero friction"* — the invite is the product's growth engine and Gate 2's hinge.

**Core loop:** open → read today's question → write your answer (sealed) → partner answers → **mutual reveal** (both answers unfold together) → a pomegranate seed joins the couple's shared streak → return tomorrow. Server-enforced fairness: neither answer is readable until both exist (`firestore.rules` `exists()` gate, mutation-tested). The reveal is the product; everything else exists to deliver couples to that moment daily.

**Validation gates the design must serve:** G1 content virality (TikTok slideshows; questions double as content assets), G2 activation (≥40% paired ≤7d, D7 couple retention ≥25% — the invitee flow and push notifications are the levers), G3 monetization (trial→paid ≥30% — the paywall and premium's perceived value are the levers). Pre-launch reality: engineering ~95%, operational proof 0%; first release target is the founder couple's devices.

---

## 2. Current UX Review

The honest summary: **Hayati today is a beautifully-engineered wireframe.** Token discipline is flawless (0 hardcoded TextStyles, 0 magic EdgeInsets), the invariant hygiene is genuinely world-class, the copy is the best asset in the product — and the visual identity does not exist. The brand lives entirely in `brandkit/` and has never once appeared inside the app.

### Navigation & information architecture

- The model is sound: hub-and-spoke from a single home, every event-driven navigation a pop, every push a user tap (the PrivacyGuard security argument depends on this inventory). Keep it.
- But the hub is invisible as a *place*. The **settings gear overlay** floating over both homes is the only persistent chrome — functional, unstyled, and it makes settings feel like a developer escape hatch rather than a designed surface.
- Coach and Packs are tiles inside the **Paired home** column with no visual differentiation from the ritual itself; premium features, empty states, and the emotional core all share one flat vertical stack.
- The deep-link surface is custom-scheme only (`hayati://invite/<code>`), which most WhatsApp clients refuse to linkify — the single largest structural hole in the activation funnel.

### Onboarding

- **Sign-in screen** sells nothing: `Text(config.appName)` in displaySmall over Night, three provider buttons, a legal footer. A reluctant husband tapping his wife's invite lands on a screen with no promise, no preview, no warmth. This is the highest-leverage redesign surface in the app.
- **Profile capture** is a form, not a welcome — three ChoiceChip groups titled "About you two," with the genuinely lovely first-person-dual labels ("Evliyiz," "متزوجان") buried in default chips. It collects no display name, which is why invite previews degrade to "Someone invited you" for phone sign-ups — a direct Gate 2 wound.
- **Consent gate** lands four dense legal paragraphs at the emotional peak of onboarding, between "About you two" and the invite. The copy is admirably honest and frozen (Class G); the *layout* is a wall.
- The invitee pays the worst toll: profile + consent + sign-in stand between "my wife invited me" and being paired — three screens of friction at the exact moment motivation is highest and patience lowest.
- Privacy — a headline differentiator for P2 — is invisible until someone spelunks into settings. There is no onboarding lock prompt.

### The core loop

- The **Paired home** reveal — "the product" per brandkit §9.3 — is a 240ms fade and one haptic. A card appears. No staging, no celebration, no shared-ness. The two answer cards are equal-weight rectangles indistinguishable from the settings list's raised tone.
- The streak is `Icons.favorite` + "4-day streak" text. The pomegranate-seed motif — the brand's conceptual spine — appears nowhere in the product. The weekly grace token ("mercy day") is pure server logic with zero UI.
- The reveal is terminal: no reaction, no comment (PRD F2's private thread unbuilt), no forward pull toward tomorrow. The loop ends flat.
- No push notifications can fire (no `firebase_messaging`, no APNs registration) — the ritual has no heartbeat. This is a product gap wearing a design costume: every "come back" moment we design is dead until the device half ships.

### Usability & accessibility

- Recorded contrast failures: Sand on Pomegranate button labels at 3.94:1 (below AA); Pomegranate as text on Night at 3.45:1, so links render Sand and are **visually indistinguishable from body text** — a real usability defect on the legal and paywall surfaces.
- Token gap #67: no muted-text or outline tokens, so **Settings** subtitles fall through to Material's desaturated grey and the app has no dividers anywhere — a cold, off-brand grey inside a warm plum product.
- Phone sign-in hints "+90 555 123 45 67" for every locale — a Riyadh user is shown a Turkish number format.
- Strengths to protect: 13.6:1 body text, six-cell golden matrix, dynamic type verified at 130%, RTL lint, LTR-pinned keypad, reduce-motion collapse, DV-aware flows. The accessibility *architecture* is excellent; the token set is what's incomplete.

### Visual hierarchy, spacing, typography

- Every screen is the same screen: a centered Column of Sand text and one FilledButton on Night; every card the same nightRaised rounded rectangle. A legal wall, a settings list, and the mutual reveal share one visual temperature.
- The daily question — the hero text of the entire product — renders in the same H1 style as screen titles. Nothing marks it as the day's event.
- Elevation is nonexistent; the brandkit's "subtle plum-tinted shadows" were never implemented. Separation relies on a single raised tone.
- Empty states are typographic only ("No question yet today" is a headline and a sentence) — illustration-shaped holes throughout.
- Gold restraint has slid into gold absence: two uses in the whole app.

### What is already right (do not churn)

The Rubik dual-script system, the 4pt spacing tokens, the stadium buttons, the calm blame-free error copy, the honest states ("Saved — you can edit until you both answer."), the safety-literate settings copy, and the entire invariant firewall. The ADR-025 arc built a correct skeleton. This redesign gives it a body.

---

## 3. Design Principles

The seven principles (verbatim from the brand direction), each with its product application:

1. **"Two people, one screen state — every surface answers 'what does my partner see right now?'; the couple, not the user, is the unit of design."** Application: the partner slot is never an afterthought card — it is the co-star of the Paired home. Every state names the partner's state honestly (locked / waiting / revealed). The streak vessel belongs to *us*, not *me*. The paywall pitch stays "One subscription. Premium for both of you."
2. **"Discretion is a feature — design every screen as if it's glanced at on the metro or picked up by a relative; dark canvas, quiet notifications, a shield that never shows the brand."** Application: Night stays the canonical in-app canvas; no screen shouts romance at arm's length — intimacy reads only at reading distance. The shield stays brand-free; the discreet icon stays honest; notification previews collapse to neutral text in discreet mode.
3. **"The reveal is the product — the daily mutual unfold gets the polish budget first: staging, seed, haptic, celebration; everything else stays calm so this moment can land."** Application: §6 gives the reveal a three-beat choreography and the seed vessel; every other surface is deliberately quieter so this contrast exists.
4. **"Culturally authored, not translated — TR and Gulf-AR are first languages of the brand, with native register owners approving copy, Arabic type set with equal presence, and romance kept modest and family-safe for the GCC."** Application: Arabic never renders lighter or smaller than Latin; the Question style has its own AR line-height (1.6); locale-aware phone hints; Eastern Arabic numerals as an AR setting; no faces or embracing figures anywhere in-app or in AR marketing.
5. **"Restraint reads premium — gold is scarce, motion is scarce, ornament is scarce; value is expressed through warmth and precision, not decoration."** Application: Gold appears only on premium marks, the Best value badge, and milestone particles. Lattice texture never exceeds 8% opacity. No looping ambience, no idle bounces, no confetti outside milestones.
6. **"Honesty is the interface — copy never promises more than the code delivers, states never lie, errors never blame; radical honesty is the trust engine of a privacy product."** Application: the redesign restyles honest copy; it never replaces honesty with marketing gloss. "Saved — you can edit until you both answer." survives every visual pass.
7. **"Never guilt, always invite — streaks forgive (the mercy day), nudges welcome, the lagging partner is courted rather than shamed; warmth without pressure is what makes a daily ritual survivable."** Application: streak-at-risk uses Alert as a state color, never as tone; the mercy day becomes a visible moment of grace (Sage, not red); the waiting state courts ("Your partner's answer unlocks when you answer."), never counts down.

---

## 4. Information Architecture & Navigation

### Decision: no tab bar

We evaluated a conventional 3–4 tab structure (Today / Us / Coach / Settings) and **rejected it**. Reasons: (a) a tab bar advertises feature surface area Hayati doesn't have and shouldn't pretend to — the ritual is the app; (b) tabs invite idle browsing, and this product's promise is *five minutes, then back to your life*; (c) the PrivacyGuard security argument rests on a strict navigation inventory ("every event-driven navigation is a pop, every push is a user tap") that a stateful tab controller complicates for zero user benefit; (d) discretion — a busy tabbed app looks like a social app over a shoulder; a single calm page does not.

### The model: one stage, two wings, sheets for the rest

```
BEFORE                                  AFTER
Sign-in ──► Onboarding ──► Home         Welcome (3-card ritual preview)
                            │              └─► Sign-in ─► Name ─► Profile ─► Consent
Home = flat Column                              │
 ├── (gear overlay) Settings            TODAY (the stage: Solo or Paired home)
 ├── Packs tile ─► Pack sel ─► Paywall   ├── header start: Us glyph ─► US (streak,
 └── Coach tile ─► Coach                 │        seed vessel, past reveals, solo history)
                                         ├── header end: gear ─► Settings (unchanged spoke)
                                         ├── inline: today's ritual (question→answer→reveal)
                                         ├── below the fold: Coach + Packs tiles
                                         ├── sheet: Pack selection ─► Paywall (push)
                                         └── overlay: milestone celebration
```

- **Today** is the single home (Solo or Paired variant, as now). It opens directly onto the question — no dashboard between the user and the ritual.
- **Us** is one new pushed screen (header start-side glyph: the seed vessel icon, RTL-mirrored position). It holds the streak vessel at full size, milestones, the mercy-day status, past reveals, and pre-pairing solo answers — finally honoring "your answers will be waiting."
- **Settings** stays a pushed spoke behind the header end-side gear, now a designed header element rather than a floating overlay. The state-independent reachability guarantee (settings/lock reachable even from error states) is preserved by keeping the header outside the state switch, exactly as `settings_gear_overlay.dart` does today.
- **Modal strategy, three tiers:** (1) *Sheets* (Night Raised, radius 24, drag handle) for transient, dismissible choices: pack selection, invite-card preview, reaction picker. (2) *Full pushed screens* for anything with legal or destructive gravity: consent, delete, legal documents, paywall (StoreKit needs the room). (3) *Dialogs* remain only for the three shipped confirms (PIN verify, biometric DV warning, delete/withdraw) — and **never on the lock screen** (Class F, sentinel-enforced: the recovery confirm stays inline widget state).
- **Overlays:** the milestone celebration is a tap-to-skip overlay above Today, never a route — it cannot trap navigation and respects the push/pop inventory.

### Deep-link surface

- Add **universal links**: `https://hayati.app/i/<code>` (requires domain + AASA — already an operator item; the same one-page domain hosts the store-required privacy/support URLs). The custom scheme `hayati://invite/<code>` remains as fallback. Chat apps linkify https; this converts the invite from "install, then type a code" to "tap."
- The web landing page for `/i/<code>` shows the inviter's name (from the existing zero-auth `invitePreview` endpoint) + App Store badge — the invite works even before install.
- Pending invites captured while locked continue to render offstage and reveal on unlock (shipped behavior in `app_links_deep_link_source.dart`; keep).

---

## 5. Redesigned User Flows

### 5.1 First-run onboarding (either partner)

| Step | Before | After | Why |
|---|---|---|---|
| 1 | Sign-in screen, zero pitch | **Welcome preview**: 3 swipeable cards (the ritual, the seal, the privacy) then Sign-in | The store description's pitch already exists, localized; onboarding finally uses it. A skippable 15-second sell before asking for anything |
| 2 | Provider buttons | Same providers, redesigned screen with Nightbloom hero | Auth logic untouched (credential seam) |
| 3 | — | **Name capture**: "What should we call you?" one field, one Continue | Fixes "Someone invited you" degradation; nicknames explicitly welcome — the answer is often an endearment (*hayatım*), which is itself on-brand |
| 4 | Profile capture form | Same three questions, restyled as a warm conversation | Content unchanged; presentation carries the first-person-dual charm |
| 5 | Consent wall | Same frozen copy, **re-laid-out**: each paragraph's first sentence bolded as its lead (verbatim, no new words), generous spacing, sticky consent CTA | Class G — not one word changes and none are added (even a summary chip would trigger the ADR-023 gate re-run, per product-copy); structure makes it readable rather than skimmed-and-resented |
| 6 | → Solo home | → Solo home, with a one-time **Privacy spotlight** card offering PIN setup ("You can do both later in Settings.") | PRD F6 headline feature surfaced at the moment trust is being formed; dismissible, never modal |

### 5.2 Pairing — inviter

1. Solo home nudge (now an illustrated card, not a text box) → **Invite share screen**.
2. New: the screen renders the **invite card** — a branded, identity-safe share image (two seeds, the code, "One question a day, for two.") — plus the code in large tabular figures with a **copy button**, a **QR code** for same-room pairing, and the expiry line.
3. Share → system share sheet carrying the code-first warm message (rewritten per product-copy: the code leads so the invite survives non-tappable scheme links; the single ❤️ closes the message, off the glanceable first line) + the https universal link + the card image.
4. Screen self-pops the moment `coupleId` lands (shipped behavior, kept).
*Why:* the only outbound artifact today is plain text with an unlinkable scheme URL. QR + copy + card + https attacks every drop-off in the chain. Idempotent code re-issue (shipped) means re-opening never breaks a sent invite.

### 5.3 Pairing — invitee (the activation event)

1. Taps the https link (or scans QR, or types the code — 31-char alphabet, kept).
2. **Partner preview**, pre-auth: "Aylin invited you" — now with the invite illustration and, once the endpoint grows its typed projection (single most Gate-2-relevant build item), **today's question + partner's sealed answer card**, lock closed: "Aylin has already answered today's question. Her answer unlocks when you write yours." This is the PRD F1 hook, restored.
3. Sign-in (same three buttons, inline on this screen) → name → profile → consent → the preview **re-mounts automatically** (pending code is keepAlive — shipped) → "Join {name}" (fallback "Accept invitation" when no name) → paired home, arriving directly on the sealed question.
4. Typed failures keep their honest copy; the stale-link dead-end gains one affordance: "Ask {name} to share a fresh code" opens the share sheet with a pre-written request message — the invitee can ping the inviter without leaving the app.
*Why:* the reluctant husband must see value *before* the three-screen toll, and the toll must end back at the exact thing he came for. Every change is presentation + one endpoint field; the join transaction is untouched.

### 5.4 The daily ritual (paired core loop)

1. Push notification (once the device half ships) or open → Today.
2. Question renders in the new **Question type style** (28/300) inside the **question card** with the date and pack chip. No-question-yet state gets the Nightbloom "dawn branch" illustration and the shipped honest copy.
3. Write → Save (server-acked, kept) → "Saved — you can edit until you both answer." The partner slot shows the **sealed card**: a folded-note visual with the lattice-lock glyph, not a grey rectangle.
4. Both answered → **the Reveal**: three-beat choreography (§11) — partner's card unfolds toward yours, both settle as a pair, one seed drops into the streak vessel. Haptic kept. ≤1.2s, reduce-motion collapses to crossfade + haptic.
5. New: **reaction row** under the partner's revealed answer — six curated reactions (❤️ 🥰 😂 🤲 🌹 plus one register-aware slot) + a one-line private reply. Both are couple-visible only, freeze with the day.
6. New: **come-back-tomorrow footer** — "Tomorrow's question arrives after midnight." with the vessel showing today's seed seated.
*Why:* the loop's payoff was a fade; now it is an event with a response channel (PRD F2 lite) and a forward pull. Server contracts unchanged; reactions are a new subcollection behind the same reveal gate.

### 5.5 Solo week (unpaired retention)

1. Day N of 7, now visualized as **seven seed slots** filling across the week — the streak motif introduced before pairing.
2. Answer → save (kept) → the day's seed settles.
3. Day 8+: the cliff becomes a ledge — the completed state offers the invite CTA *plus* a weekly solo reflection question (evergreen solo track, P1 content item), so the unpaired user always has a reason to return until the partner joins.
*Why:* the current day-8 dead-end offers nothing further, forever. Retention until pairing IS the funnel.

### 5.6 Purchase (premium for both)

1. Packs tile → **Pack selection sheet** (honest state kept until couple packs exist) → "See Premium" → **Paywall** (pushed).
2. Paywall gains: benefit vignettes (Nightbloom, one per value), a compact free-vs-premium table honoring "Your daily question and streak stay free, always.", the **TR lifetime card** ("Yours forever · Pay once. Both of you, for good." — product-copy) alongside annual/monthly, verbatim store prices (kept), trial banner (Sage), restore, legal links.
3. Purchase → StoreKit → durable processing banner (kept) → entitled view with the gold premium mark.
*Why:* the rail is shipped and correct; the presentation is a text column. G3 cannot pass on an IOU — this design assumes the content bank and live coach land first (§7 priorities).

### 5.7 Coach conversation (premium)

Flow unchanged (disclaimer gate → personas → send → crisis pre-scan → reply). Redesign is visual only: persona chips become **persona cards** with custom glyphs, the transcript gets proper bubble styling, the quota caption moves to a Mist pill, and the **crisis help card keeps its structurally distinct widget type** (test-pinned) with a calmer, more spacious layout. All Class G copy frozen. Ephemerality is disclosed up front in the empty state ("Conversations here aren't saved — they end when you close the app.") — honesty over surprise.

### 5.8 Privacy lock lifecycle

Setup moves earlier (the onboarding Privacy spotlight, §5.1) but remains optional and settings-reachable. The lock screen itself is **Class F parity-only**: same structure, retinted with tokens, keypad stays LTR, no Overlay widgets, inline recovery confirm kept. Cooldown copy untouched.

### 5.9 Data rights (export / delete / withdraw)

Flows unchanged; all sentences pinned (ADR-019 D7). Redesign is layout only: the delete screen's irreversibility block becomes a bordered Alert-toned callout so the gravity is visual as well as verbal; export gains a monospace JSON container with the copy action; the couple-ended notice gets the single-seed spot illustration (creative-assets §5): one seed resting on open ground, no pair imagery, no wilt — gentle, actor-free, non-blaming, per the DV decision (no push, no attribution — untouchable).

---

## 6. Screen-by-Screen Redesign

Conventions used below: all measurements in dp; "start/end" not "left/right" (RTL lint); light-mode values in §9's palette table apply automatically via the token layer; every screen ships with regenerated six-cell goldens.

### 6.1 Onboarding & auth

#### NEW — Welcome preview (pre-auth, 3 cards)

- **Purpose:** sell the ritual in 15 seconds before asking for anything; the only marketing surface inside the app.
- **Layout:** full-bleed Night. Top 55%: Nightbloom illustration per card (compositions per creative-assets §4). Middle: H1 + two lines of Body. Bottom: page dots (Veil, active Pomegranate), "Continue" FilledButton ("Get started" on card 3, per product-copy), "Sign in" skip TextButton in Rose (the skip affordance *is* sign-in).
- **Cards:** (1) *The ritual* — a closed question card resting under a blossoming branch; "One question a day, for two." (2) *The seal* — two sealed cards facing each other, a faint Sand glow in the gap; "No peeking, and no pressure to perform: just a moment that belongs to the two of you." (reusing the shipped store copy). (3) *The privacy* — the lattice-lock glyph over two lit windows; "What's between you stays between you." with one Caption line about PIN + discreet icon.
- **Motion:** cards enter with Soft Unfold; swipe parallax ≤8dp on the illustration layer. Skippable always; never shown again after first completion.
- **States:** none (static content, bundled).

#### Sign-in screen (`sign_in_screen.dart`, `provider_actions.dart`)

- **Purpose:** auth entry; also the landing for pre-auth invitees (who instead get the Partner preview).
- **Layout top-to-bottom:** Nightbloom hero (two branches from opposite edges inclining toward each other, ~30% of height, breathing room above — creative-assets §4); the redrawn two-seeds mark + wordmark (Display 32/800 — mark-first, since the name may change per ADR-027); tagline in Body Mist: "One question a day, for two."; then ProviderActions — Continue with Apple / Google as FilledButtons (Moonlight label on Pomegranate), Continue with phone as a Rose TextButton; the **frozen legal footer** verbatim (Class G) in Caption Mist with Rose links (finally distinguishable from body text).
- **Hierarchy:** illustration → mark → tagline → actions; the eye lands on the promise before the ask.
- **States:** error view keeps its structure with the Alert detail line in a Veil-bordered callout; spinner replaced by the seed-pulse progress indicator (§9).
- **Micro-interactions:** buttons press to Pomegranate Deep with a 120ms scale-to-0.98.

#### Phone sign-in (`phone_sign_in_screen.dart`)

- **Purpose:** OTP flow, unchanged mechanics.
- **Layout:** header "Continue with phone" (H1), Body explainer, phone field with a **locale-aware hint** (+90 for TR, +966 for AR-SA device regions, +44/+49 fallbacks) — fixes the Turkish-number-for-everyone defect; code entry becomes six individual digit boxes (Night Raised, Veil border, radius 16, tabular figures, **LTR-pinned digit order** like the keypad) with auto-advance; resend as a Rose TextButton with a Mist countdown.
- **States:** inline errors keep their calm copy ("That code didn't match. Try again.") in Alert with the field border tinting Alert. Known issue #15 (simulator crash) remains an engineering quarantine, not a design concern.
- **Motion:** step transitions use Soft Unfold; success self-pops (kept).

#### NEW — Name capture

- **Purpose:** collect a display name so invite previews never say "Someone invited you"; a brand moment disguised as a form field.
- **Layout:** H1 "What should we call you?" (product-copy canonical, with TR/AR register renderings); Caption in Mist: "Your partner will see this on your invitation."; single text field, placeholder "Your name or nickname"; Continue anchored bottom (per the ADR-025 slice-3 CTA-anchor pattern). Pre-filled from Auth displayName when present (Apple/Google), so most users just confirm.
- **States:** empty field disables Continue; no error states needed (any non-empty string is valid).

#### Profile capture (`profile_capture_screen.dart`)

- **Purpose:** relationship status, question language, TR-only tone register — content unchanged.
- **Layout:** H1 "About you two" kept; each ChoiceChip group gains an H2 lead-in line and breathing room (x4 between groups); chips restyle to Night Raised with a Veil border, selected = Pomegranate Deep fill with Moonlight label; the first-person-dual labels ("Sevgiliyiz / Nişanlıyız / Evliyiz", "نتواعد / مخطوبان / متزوجان") are now the visual stars — set in Body-emphasis. A small two-seeds glyph sits above the title: continuity from sign-in.
- **Hierarchy:** one question per visual band; Continue bottom-anchored (kept).
- **Micro-interaction:** chip selection gets a 120ms fill transition + selection haptic (light).

#### Consent gate (`consent_gate_screen.dart`) — Class G copy

- **Purpose:** KVKK/PDPL special-category consent before any reflective feature (ADR-023).
- **Layout (re-laid-out, zero rewording):** header "Before we begin" is *not* added — the frozen copy owns the words. Instead: the four paragraphs render in a scrollable region with generous 1.5/1.7 line-height, each paragraph's first sentence set in Body-emphasis as its lead (verbatim — progressive disclosure by weight, not by new words, matching product-copy), each paragraph separated by a Veil hairline; Privacy/Terms links in Rose; the 18+ statement and the consent CTA ("I consent and continue", FilledButton) sit in a **sticky bottom bar** on Night Raised with a top Veil hairline, so the action is always visible without scroll-hunting; the three escape TextButtons (sign out / export / delete remain reachable for decliners) sit under the CTA in Mist.
- **Hierarchy:** stillness by design — no illustration, no motion beyond the base unfold. Gravity is expressed through space (per the motion principles: legal surfaces do not animate).
- **States:** post-consent waits for the server-stamped consent to stream back (kept, no optimistic grant) — the waiting state shows the seed-pulse indicator with the Caption "Recording your consent…".

#### NEW — Privacy spotlight (one-time card on first home)

- **Purpose:** surface the headline privacy features (PIN, discreet icon) at the moment trust forms, without blocking.
- **Layout:** a dismissible Night Raised card atop Solo home, lattice-lock glyph in Clay, H2 "Keep Hayati between you two" (product-copy canonical), two Caption lines ("Add a 6-digit PIN so only you can open the app — and switch to a plain home-screen icon if you'd like. You can do both later in Settings."), row of two actions: "Set up my PIN" (Rose) / "Maybe later" (Mist — never "Skip"; no judgment).
- **Behavior:** shown once; "Set up my PIN" pushes the shipped PIN setup screen; never re-prompts (Settings remains the home of these controls). Never modal — Principle 7.

### 6.2 Pairing

#### Partner preview / join (`partner_preview_screen.dart`)

- **Purpose:** the invitee's activation moment; must sell in one glance.
- **Layout, valid-preview state:** invite illustration (a single card mid-unfold, Sand glow spilling from the fold — creative-assets §4) → H1 "**{Name} invited you**" (name in Pomegranate-accented emphasis — one of the few sanctioned accent-text uses, set in Body-emphasis weight so color is not the only signal) → the restored hook: today's question in the Question style inside a card, and beneath it the **sealed answer card** — folded-note visual, lattice-lock glyph, Caption "{Name} has already answered. Their answer unlocks when you write yours." → primary CTA ("Join {name}" post-auth, fallback "Accept invitation"; the three sign-in buttons pre-auth) → "Not now" in Mist.
- **Manual entry state:** "Have an invite code?" + an 8-slot code field (tabular, letter-spaced, auto-uppercase) + "See invitation".
- **Error states:** the six typed join failures keep their honest sentences, each in a Veil-bordered callout with an "Enter a different code" Rose action; the expired state adds "Ask {name} for a fresh code" (opens share sheet). Fetch-error and unavailable states get the "closed bud" spot illustration.
- **Motion:** the preview enters with Soft Unfold (kept — one of the two shipped animated moments, now consistent with the reveal language).
- **Dependency:** the question + sealed-answer hook requires growing the `invitePreview` typed projection (`functions/src/invites/`) — P0 in §7.

#### Invite share (`invite_share_screen.dart`)

- **Purpose:** creator side of pairing; produce an artifact worth sending.
- **Layout:** H1 "Invite your partner" → the **invite card preview** (branded, identity-safe: two seeds, the code, tagline — rendered as the actual shareable image) → the code in Display-size tabular figures with a **copy icon-button** (Phosphor `copy`, confirmation via the shipped snackbar pattern) → expiry Caption in Mist ("Expires 28 Jul 2026, 3:00 PM" format kept) → **QR code** (Sand modules on Night Raised card — scannable same-room pairing) → "Share invite" FilledButton → "Have a code?" cross-path in Rose.
- **Share payload:** the code-first warm message (product-copy rewrite — code before link, ❤️ at the close) + `https://hayati.app/i/<code>` + the card image.
- **States:** issuing (seed-pulse), issue-error (calm retry), and the shipped self-pop when the partner joins — now with a brief "Paired ✦" Sage confirmation beat before popping.

#### NEW — Invite card (shareable asset, rendered in-app)

- **Purpose:** the only outbound branded artifact; serves G1/G2 on WhatsApp Status, the dominant GCC/TR sharing surface.
- **Composition:** 1080×1920 (Status), 1080×1350 (feed), and 1200×630 (link preview) variants — the set creative-assets §9.3 produces; Night canvas, 4–6% lattice fragment, two seeds inclining, the code in Moonlight tabular type, primary tagline in the sender's locale. **Identity-safe:** no names, no answers, no photos — safe on a public Status. Wordmark small (trademark-pending caution); the seed mark carries the brand.

### 6.3 Home & the ritual

#### Solo home (`solo_home_screen.dart`)

- **Purpose:** 7-day solo ritual + persistent invite nudge; the unpaired fallback.
- **Layout:** header (Us glyph start / gear end — the Us screen shows solo seeds pre-pairing) → invite nudge card, now illustrated (small two-branches art, H2 "Hayati is better together", CTA "Invite your partner") → **seven seed slots** in a horizontal row (filled seeds Pomegranate, today pulsing softly once on load, empty slots Veil outline) replacing "Day 3 of 7" → the day's question in the **Question style (28/300)** → answer field (Night Raised, radius 16, grows with content) → "Save answer" → "Saved for today." Caption in Sage.
- **Completed state (day 8+):** "Your seven days are complete" over the full seven-seed row + the invite CTA + (P1) the weekly solo question slot.
- **Motion:** on save, the day's seed fills with a 240ms scale-settle — the streak language taught before pairing.
- **States:** loading (seed-pulse), save-error (calm inline Alert line, kept copy).

#### Paired home (`paired_home_screen.dart`) — the core loop

- **Purpose:** today's question, own answer, the mutual reveal, streak; the product's heart.
- **Layout top-to-bottom:**
  1. Header: Us glyph (start) with a tiny seed-count badge, date Caption centered in Mist, gear (end).
  2. **Streak strip:** the miniature seed vessel (custom glyph) + count in tabular figures + the mercy-day indicator when a grace token was spent this week (small Sage leaf glyph, Caption "Mercy day used — your streak is safe."). Replaces the Material heart. Tap → Us screen.
  3. **Question card:** Night Raised, radius 16, plum shadow level 1; pack chip (Caption, Mist) top-start; the question in Question style 28/300 — the hero text of the day, given its own literary voice; subtle 4% lattice watermark bottom-end corner.
  4. **Your answer:** the input field (or your saved answer as a card post-save) + Save; saved Caption kept verbatim.
  5. **Partner slot** (`partner_slot.dart` states): *locked* = the folded-note sealed card with the lattice-lock glyph and "Your partner's answer unlocks when you answer."; *waiting* = the same sealed card with the unfold glyph half-open and "Your side is done. {name}'s answer will unfold here." (product-copy); *revealed* = the reveal composition (below).
  6. Below the fold: Coach tile (premium; persona glyph, one-line pitch) and Packs tile (lock badge in Clay, kept) — restyled as quiet cards, visually subordinate to the ritual.
- **The reveal composition:** both answer cards as a pair — partner's card unfolds toward yours (§11 choreography), each carrying the author's name in Caption Mist; then the **reaction row** (six reactions + one-line reply, couple-visible only) under the partner card; then the seed-drop into the streak strip's vessel; then the come-back-tomorrow footer ("Tomorrow's question arrives after midnight.") in Mist.
- **Hierarchy:** question > answers > streak > everything; the coach/packs tiles use Mist labels and no accent color so they never compete with the ritual.
- **States:** *no-day-yet* — the "dawn branch" illustration + the shipped honest copy ("Today's question is on its way — it arrives shortly after your midnight."), streaming in live (kept); *pack-update* and *error* states keep their copy with the closed-bud spot illustration; *first mount after pairing* — the one-shot `branches-meet` header art (creative-assets §7.8) with the one-time "You two are in." banner (product-copy), never repeated; loading = seed-pulse.
- **Micro-interactions:** Save press haptic (selection); the single light haptic on the live waiting→revealed transition (kept, sacred); reaction tap = 150ms pop + selection haptic.

#### NEW — Us (streak & shared history)

- **Purpose:** the couple's shared place — the streak made visible, past reveals re-readable, solo history honored. Pure UI over shipped data (`couples/{id}` streak fields, days subcollection, `users/{uid}/soloAnswers`).
- **Layout:** hero: the **seed vessel** at full size — a hand-drawn Nightbloom glass bowl visibly holding N seeds (clustered naturally, not a grid), count in Display tabular figures, Caption "{N} days answered together"; milestone track beneath (7 / 30 / 100 markers, achieved ones in Gold — one of the sanctioned gold uses); **mercy-day status** (Sage leaf + "1 mercy day available this week" or "Used Tuesday — your streak is safe."); then a reverse-chronological list of past mutual days — each a compact card with date + question first-line, tapping opens the frozen pair of answers (read-only, per the post-reveal freeze rules); a final section "Your first seven days" shows the user's own pre-pairing solo answers (own-data only — partner solo answers never cross, matching the export posture).
- **Empty state (new couple):** the vessel empty with one Caption: "Your first seed arrives the first day you both answer."
- **Motion:** on entry after a reveal, the newest seed settles with the gentle spring; otherwise stillness.

#### NEW — Milestone celebration (overlay)

- **Purpose:** reward 7/30/100 seeds and mercy-day saves without gamified noise.
- **Composition:** tap-to-skip overlay above Today: the vessel centered, Gold particle drift (≤1.2s, ≤24 particles), H2 + one warm line per register, verbatim from product-copy ("Thirty seeds. This is a ritual now." / "Seven seeds. A whole week of showing up for each other." / register variants per the profile field), single "Continue" action. Never blocks input mid-animation; reduce-motion = static gold-ringed vessel card.
- **Mercy-day variant:** Sage, not Gold — "Life happened yesterday. A mercy day kept your streak whole." (product-copy canonical). Forgiveness framed as grace, not as a consumed resource (Principle 7; culturally resonant framing for both markets).

### 6.4 Premium

#### Pack selection (`pack_selection_screen.dart`, `premium_gate.dart`)

- **Purpose:** first premium-gated surface; honest until couple packs exist.
- **Presentation:** becomes a **sheet** (radius 24, drag handle). Unlocked: pack cards (title, question-count, category glyph, register badge for TR) in a vertical list; "Starter collection" + "New packs are on the way." honest state kept until W9 content lands. Locked: the lattice-lock glyph, H2 "Unlock every pack", the kept line "Premium opens every question pack — for both of you.", "See Premium" FilledButton.
- **Future-proofing:** the card template already carries the seasonal badge slot (Ramadan/Eid, ADR-026 windows) so seasonal packs need zero new UI.

#### Paywall (`paywall_screen.dart`)

- **Purpose:** convert with dignity; G3's stage.
- **Layout:** H1 "Hayati Premium" → pitch (kept verbatim: "One subscription. Premium for both of you.") → **three benefit vignettes** (Nightbloom minis: every-pack, the coach persona glyph, two-seeds = both-of-you) each with one Body line → **package cards**: Annual (pre-selected, Pomegranate border, Gold "Best value" badge — sanctioned gold use), Monthly, and **Lifetime (TR storefront only)**: "Yours forever · Pay once. Both of you, for good." honoring the TR one-time-purchase culture (feasibility §6 pricing: ₺2,499); verbatim store prices + "≈ ₺74,99/month" sub-labels (kept) in tabular figures → trial banner in Sage ("7 days free" from store-derived copy) → CTA "Start your free trial" (Moonlight on Pomegranate) → the free-tier reassurance kept verbatim: "Your daily question and streak stay free, always." → compact free/premium table (3 rows max) → Restore (Rose) + legal links (Rose).
- **States:** *store-unavailable* fail-closed state keeps its honest copy with the closed-bud illustration; *processing* keeps the durable banner ("Purchase received — unlocking for both of you…") now in Sage with the seed-pulse; *entitled* view: gold premium mark + "You're Premium" / "Premium is active for both of you." (kept).
- **Explicitly no:** fake social proof, countdown timers, decoy pricing theatrics — honesty is the interface, and the GCC persona reads pressure tactics as cheap.

### 6.5 Coach

#### Coach chat (`coach_screen.dart`) + disclaimer / help / paused sub-surfaces (Class G+★)

- **Purpose:** premium AI coach, three personas, safety spine intact.
- **Layout:** persona selector as three **cards** (custom glyphs: coach lantern, date spark, gift box; localized names kept — "Buluşma Perisi", "ملهم المواعيد") with fill = active state; transcript: user bubbles Night Raised end-aligned, persona bubbles with a 2dp Pomegranate start-edge accent, timestamps Mist; composer bottom-anchored with the quota pill above it (Mist, tabular: "7 messages left today"); per-persona drafts (fixing the shared-draft annoyance).
- **Empty state:** persona glyph + kept line "Ask anything — from a hard conversation to a date idea." + the ephemerality disclosure Caption.
- **Frozen surfaces, re-laid-out only:** the first-open disclaimer gate (full-screen, still, copy verbatim, "I understand" FilledButton); the **crisis help card** keeps its structurally distinct widget type (test-pinned) — full-width, Veil border, no persona styling, generous padding, copy verbatim ("We're here for you"); the **paused panel** replaces the composer verbatim ("This conversation is paused to keep you safe.") with "Start a new conversation" as the only action. No motion beyond the base unfold anywhere near the safety surfaces.
- **States:** provider-unavailable (today's reality) keeps its honest line; typed errors render as system lines in Mist, never as persona bubbles.

### 6.6 Settings & privacy

#### Settings (`settings_screen.dart`)

- **Purpose:** the control surface; the #67 unblock is the whole redesign here.
- **Layout:** grouped sections with H2 headers and Veil hairline dividers (finally possible): **Privacy** (App lock, Change PIN, biometric accelerator with its DV-warning flow kept, discreet icon toggle, discreet notifications toggle), **Your data** (Download my data, Privacy & Terms, Delete account & data), **Account** (Sign out). Subtitles in **Mist** (replacing Material grey); switches themed (track Veil → Pomegranate active, thumb Moonlight); chevrons Clay (kept role); destructive rows (Delete) in Alert text with a lattice-free trash glyph.
- **Copy:** every safety-literate sentence kept verbatim ("Anyone whose face or fingerprint is saved on this phone can unlock Hayati. Your PIN stays private to you.", "Shows a plain icon on your home screen. The app's name still appears under it.").
- **Hierarchy:** privacy first — it is the headline feature; the section order says so.

#### PIN setup (`pin_setup_screen.dart`) & PinKeypad

- **Layout:** prompt H2 ("Choose a 6-digit PIN" / "Enter your PIN again"), six dot slots (Veil outline → Sand filled), the shared **PinKeypad** restyled: 64dp circular targets, Night Raised fill, Sand digits in tabular figures, press = Pomegranate Deep flash 100ms — **TextDirection.ltr pinned** (kept; numeric pads never mirror).
- **States:** mismatch shakes the dot row 2×4dp (respecting reduce-motion: color flash only) with a calm retry line; save-failure keeps its never-lying copy ("The PIN couldn't be saved. The lock is still off.").

#### Lock screen (`lock_screen.dart`) — Class F, parity-only

- **Redesign scope: retint, nothing else.** Same structure: "Hayati is locked" (H2, Sand), "Enter your 6-digit PIN", dot echo, the LTR keypad, biometric CTA when armed, cooldown copy tiers verbatim ("Wrong PIN. 1 try left before a wait.", "Face ID changed on this phone — enter your PIN."), always-visible "Forgot PIN? Sign out" with the **inline** confirm panel (never a dialog — no Overlay-dependent widget may mount here, sentinel-enforced). No illustration, no brand flourish: a locked Hayati should look like nothing worth asking about. Restructuring requires a new ADR; this document does not propose one.

#### Privacy shield cover (`privacy_shield_cover.dart`) & PrivacyGuard (`privacy_guard.dart`)

- **Unchanged by decision.** The shield remains a plain `ColoredBox(ColorTokens.night)` — deliberately brand-free so the app-switcher card never re-identifies the app for the user who chose the discreet icon. The guard's lifecycle (Offstage+TickerMode lock, 60s grace, cold-start locked) is invisible infrastructure the navigation model in §4 was designed around. Any designer proposing a logo here has misunderstood the product.

### 6.7 Legal & data rights

#### Export screen (`export_screen.dart`)

- **Layout:** kept line "This is your data, as Hayati holds it. Copy it anywhere you like." → JSON in a monospace scroll container (Night Raised, Veil border, horizontal scroll within the card) → "Copy" FilledButton → the app's one snackbar ("Copied to your clipboard.", kept). Minimal by design; fine for launch.

#### Delete account (`delete_account_screen.dart`) + confirm

- **Layout:** the pinned sentences verbatim, restructured for gravity: "This can't be undone." as the H2; the scope sentences ("…both sides of every answer.", "Your partner will see that the shared space was closed, but not why.", "This does not cancel an App Store subscription.") in an Alert-bordered callout; export-first link in Rose above the destructive CTA; second step = PIN re-verify (lock on) or the destructive dialog (lock off), both kept; retry copy keeps "couldn't be confirmed" (never "failed"). No illustration — stillness.

#### Couple-ended notice (`couple_ended_notice_screen.dart`)

- **Layout:** the single-seed spot illustration — one seed resting on open ground, Clay-toned, no pair imagery (the art must be exactly as reticent as the pinned copy); pinned copy verbatim ("The shared space has been closed and its content permanently deleted.", "Your own private reflections are untouched and remain yours.", "You can pair again whenever you choose."); one Continue action → solo home. Shown once per event (kept); **no push notification of the ending** (ADR-019 D3, DV-aware — untouchable).

#### Legal hub (`legal_screen.dart`) + withdraw dialog; Legal document (`legal_document_screen.dart`)

- **Hub:** Privacy Policy / Terms tiles with Veil dividers; consent status line in Mist ("Consented on 25 Jul 2026, version 1." format kept); Withdraw consent in Alert text; the withdraw dialog's prospective-reading copy verbatim on Night Raised radius 24 (kept from ADR-025 slice 1).
- **Document:** the bundled TR/AR/EN renderer gains the reading typographic scale (Body 16 at 1.5/1.7, H2 section heads, Veil hairlines between sections) — dependency-free rendering kept, byte-sync from `docs/legal/` kept.

### 6.8 System & meta surfaces

#### Dialogs (3) + snackbar

- All keep the ADR-025 slice-1 floor (Night Raised, radius 24/16) and gain Veil hairline borders in light mode; destructive dialog CTAs in Alert; PinVerifyDialog uses the restyled keypad. Total dialog count stays at three — the modal budget is deliberately tiny.

#### System share sheet & share payloads

- Payload upgraded per §5.2: the code-first message (product-copy rewrite) + universal link + invite card image. The share sheet itself is OS-owned; we design only what rides in it.

#### Deep link surface

- `https://hayati.app/i/<code>` universal links + AASA (new) with `hayati://invite/<code>` fallback (kept); pending-invite capture-while-locked behavior kept.

#### Push notifications (device half — to be built)

- Copy templates exist server-side; design rules: notifications read like a considerate friend ("A new question is waiting for you two."), collapse to neutral text in discreet mode (kept, non-overridable AR default kept), **never carry question/answer text** (by construction, kept), quiet hours 22:00–08:00 (kept). New: a **pre-permission prompt** card on Today after the first save ("Want a gentle nudge when {name} answers?") so the iOS system dialog fires at a moment of demonstrated value — never on first launch.

#### App icons & switcher card

- Default icon: the redrawn Two Seeds (§10). Discreet alternate icon: kept as-is from brandkit (grey list glyph — correct and honest); switcher card stays the blank night shield. The honest label disclosure ("The app's name still appears under it.") stays.

#### Store listing (fastlane/metadata)

- Screenshot system (new): eight frames per locale on device mockups over the Paper `#FAF3E8` marketing canvas, per the marketing-strategy §4 storyboard (canonical) — (1) the question, (2) the sealed answer, (3) the reveal, (4) the seed vessel, (5) privacy (lock + discreet icon), (6) in your language/culture, (7) one subscription for two, (8) the invite/partner preview. No faces, no couples photography anywhere (GCC hard rule — also applied to TR/EN for one global system). AR metadata directory to be created (currently missing); subtitle kept ("Günde bir soru, ikiniz için" / "One question a day, for two"); privacy/support URLs filled by the new domain.

---

## 7. Missing Pages & Missing Features

Priorities: **P0** = blocks honest gate testing or the core promise; **P1** = the redesign's own body of work; **P2** = post-validation.

| # | Item | Type | Rationale | Priority |
|---|---|---|---|---|
| 1 | Push notifications, device half (`firebase_messaging`, APNs, token capture) | Feature | A daily ritual with no heartbeat retains no one; all server logic is shipped and tested | P0 |
| 2 | Analytics & gate instrumentation (privacy-posture-compatible, pseudonymous, no answer text in events) | Feature | G2/G3 are unfalsifiable today; PRD §10 requires it "from day one" | P0 |
| 3 | Question content bank (400 TR / 300 AR / 300 EN, native-reviewed) + couple `packConfig` writes | Content | Every couple currently gets 7 Turkish solo questions; the single biggest product gap; also G1's raw material | P0 |
| 4 | Universal links + one-page domain (AASA, `/i/<code>` landing, hosted privacy/support URLs) | Infra + page | Unlinkable invites throttle Gate 2; store submission needs the URLs anyway | P0 |
| 5 | Name capture screen | Screen | Kills "Someone invited you"; three days of work protecting the activation hook | P0 |
| 6 | Partner-preview question hook (grow `invitePreview` projection: question + sealed-answer presence) | Feature | The PRD's strongest activation hook, cut in M3; the endpoint was designed to grow exactly this | P0 |
| 7 | Reveal choreography + seed vessel + streak strip (pomegranate motif in-product) | Design build | "The reveal is the product" — currently a fade; pure UI over shipped server data | P1 |
| 8 | Us screen (streak, past reveals, solo-answer history) | Screen | Honors "your answers will be waiting"; gives the streak a home; zero new backend | P1 |
| 9 | Reaction row + one-line reply on the reveal | Feature | PRD F2 lite; closes the loop's flat ending; small write surface behind the existing reveal gate | P1 |
| 10 | Welcome preview (3 cards) + Privacy spotlight + notification pre-prompt | Screens | Onboarding currently sells nothing; privacy is invisible; permission asks are untimed | P1 |
| 11 | Invite card (branded share image) + QR + copy-code | Feature | The only outbound artifact is plain text; WhatsApp Status is the GCC/TR sharing surface | P1 |
| 12 | Milestone celebrations + mercy-day surface | Design build | Streak system works server-side with zero reward UI | P1 |
| 13 | Mist/Veil/Rose/Moonlight tokens into `color_tokens.dart` + brandkit JSON; motion values into tokens (#71); Phosphor migration (#63) | System | Closes every recorded §10 gap and both open design issues | P1 |
| 14 | Evergreen solo track (weekly question, day 8+) | Content + feature | Softens the solo cliff that starves the pairing funnel | P1 |
| 15 | TR lifetime tier card on paywall | Screen state | Priced in feasibility (₺2,499), no UI concept exists; TR one-time-purchase culture | P1 |
| 16 | Ramadan mode (tagged questions + notification-window setting; ADR-026 machinery shipped) | Content + feature | The owned annual moment; "Ramadan-before-Ramadan" roadmap rule | P2 (calendar-driven — promote if launch nears Ramadan) |
| 17 | Eastern Arabic numerals AR setting (٠١٢٣) | Feature | Brandkit §3 promise; scheduled, not aspirational | P2 |
| 18 | Quizzes + shareable result cards; referral rewards | Feature | v1.5 share loop; G1-adjacent | P2 |
| 19 | Spice mode (both-partner opt-in, region-flagged, 17+) ; bucket list & memories timeline | Feature | v1.5 per mvp.md OUT list; P2 discovers spice "later, never advertised at her" | P2 |
| 20 | Android enablement (M6.5) — incl. Android discreet icon via activity-alias | Platform | Turkey is Android-heavy; G2 stays directional until this ships | P2 (sequenced by roadmap) |

Items 1–4 are founder/operator-gated as much as design-gated (Blaze, domain, content review) — the redesign should not wait on them, but Gate 3 testing must.

---

## 8. Accessibility

**Contrast (the redesign's biggest accessibility win).** The new tokens close every recorded failure: Moonlight `#FFF8F1` on Pomegranate = 4.7:1 (was Sand at 3.94:1 — AA fail); Rose links at 6.8:1 on Night / Pomegranate Deep at 7.2:1 on Paper (links were previously indistinguishable from body text — now color *plus* weight, never color alone); Mist secondary text at 7.9:1 on Night / 5.3:1 on Paper; body text stays 13.6:1 (Sand on Night). Pomegranate is never body text in either mode (3.45:1 on Night). Gold is text-safe only as `#D9A441` on Night (7.4:1); light mode uses Brass `#866112` (5.1:1). Alert meets 4.94:1 on Night / 5.0:1 on Paper.

**Dynamic Type.** Verified at 100% and 130% via goldens (kept, extended to the new Question style — 28/300 must remain legible when scaled; below 130% it may not wrap-break the seal metaphor cards). Minimum body 14. Streak counts and timers use tabular figures so scaling never jitters layout.

**VoiceOver.** Reading order per screen is top-to-bottom semantic, with three special cases: (1) the reveal announces as one event — "Both answers revealed. {Partner}'s answer: …" — before the seed-drop is described ("One seed added. {N}-day streak."); the haptic accompanies the announcement; (2) the sealed card's semantic label states the contract explicitly ("Partner's answer, locked. Unlocks when you answer."); (3) the PIN keypad exposes digits as buttons with no announced sequence memory, and cooldown countdowns announce via polite live regions, not repeated interruptions. All icon-only buttons (gear, Us glyph, copy, reactions) carry labels. Decorative illustration and lattice texture are excluded from the semantics tree. TalkBack parity lands with Android at M6.5.

**Hit targets.** 48dp minimum everywhere (buttons already 48dp min-height; keypad keys 64dp; reaction chips padded to 48dp; the settings gear's tap target ≥48dp even though the glyph is 24dp).

**Reduced motion.** Every sequence collapses to an instant crossfade **with the haptic preserved** — the reveal must remain operable and feelable without animation (shipped policy, extended to the new choreography, milestones = static card, PIN shake = color flash).

**RTL.** All layout in logical start/end (lint-enforced, kept); the six-cell golden matrix regenerates intentionally per redesigned screen; Phosphor migration adds a direction-aware wrapper for the small directional glyph set (back/forward/send) shipped as mirrored pairs since Phosphor forfeits Material auto-mirroring; the numeric keypad and OTP digit boxes stay LTR-pinned; Arabic line-heights 1.7 body / 1.6 Question style applied per resolved locale (kept mechanism); illustrations are designed direction-neutral (paired forms incline toward center) so they need no mirrored variants.

**Cognition & safety.** One primary action per screen; frozen legal copy gains structure (bolded verbatim leads, spacing, hairlines — layout only, never new words) not simplification-by-deletion; cooldown and error copy never lies (kept verbatim); crisis surfaces stay structurally distinct and motion-free.

---

## 9. Visual Design System

### 9.1 Palette (canonical — identical across all five direction documents)

Dark (Night) is the canonical in-app theme; the Paper column serves marketing, web, store screenshots, and the future light theme.

| Token | Light (Paper) | Dark (Night) | Role |
|---|---|---|---|
| Night — canvas | `#FAF3E8` | `#231A33` | Primary background; dark is canonical in-app (evening is the couple's moment; discretion likes dark screens) |
| Night Raised | `#FFFCF6` | `#2E2344` | Cards, sheets, dialogs, inputs, answer cards; light mode pairs with a Veil hairline border |
| Sand / Plum Ink | `#2A2138` | `#F3E7D7` | All primary text; 13.7:1 / 13.6:1; never pure white/black |
| Mist (new) | `#6B6178` | `#B9AFC6` | Secondary text: subtitles, captions, timestamps; closes gap #67 |
| Veil (new) | `#E7DCCB` | `#453A5C` | Hairline dividers, borders, card edges; non-text decorative-boundary role |
| Pomegranate | `#C04A5A` | `#C04A5A` | Primary action fills, seeds, selected states; never body text; labeled in Moonlight |
| Pomegranate Deep | `#8E3140` | `#8E3140` | Pressed/selected states, gradient partner, seed shading; text-safe accent on Paper (7.2:1) |
| Rose (new) | `#8E3140` | `#E38E99` | Links, TextButtons, inline emphasis; color plus weight, never color alone |
| Moonlight (new) | `#FFF8F1` | `#FFF8F1` | Text/icons on Pomegranate fills (4.7:1) |
| Gold / Brass | `#866112` | `#D9A441` | Premium marks, Best value badge, milestone particles — celebration and premium only |
| Sage | `#4E6B4A` | `#8FAE8B` | Success, streak-safe, trial label, mercy-day |
| Clay | `#8A5F43` | `#B98A6E` | Secondary icons, chevrons, lock badge, lattice line-work |
| Alert | `#B04A3E` | `#D96C5F` | Errors and streak-at-risk only; never in marketing; colors the state, never the tone |

Implementation: extend `app/lib/core/design_system/color_tokens.dart` and `brandkit/brandkit/tokens/hayati-tokens.json` together (the drift test enforces parity); route the Material `surfaceContainer*` family through Night Raised as shipped in ADR-025 slice 1.

### 9.2 Typography

One family, two scripts, zero new fonts: **Rubik** (bundled 300/400/500/600/700/800 — add 300 and 800), Noto Sans / Noto Sans Arabic fallbacks. System surfaces the app doesn't render (push, OS dialogs, icon label) use SF Pro / SF Arabic — never fight the OS there.

| Style | Spec | Use |
|---|---|---|
| Display | 32 / 800 | Wordmark and hero only |
| **Question (new)** | 28 / 300 · lh 1.35 Latin / 1.6 Arabic | The daily question — the product's hero text; the light weight glows on Night |
| H1 | 24 / 700 | Screen titles |
| H2 | 20 / 600 | Section heads, card titles |
| Body-emphasis | 16 / 600 | Names, emphasized lines |
| Body | 16 / 400 · lh 1.5 Latin / 1.7 Arabic | Everything; Arabic needs air, applied per resolved locale |
| Caption | 13 / 400 · **Mist** | Timestamps, helpers, quotas — no longer Material grey |
| Button | 16 / 600 · **Moonlight** on fills | All CTAs |

Numerals: tabular figures for streak counts, codes, timers, prices; Eastern Arabic numerals (٠١٢٣) as an AR user setting (scheduled). Arabic display type carries equal optical weight to Latin in every lockup — never a lighter afterthought.

### 9.3 Spacing, radii, elevation

- **Spacing:** the shipped strict 4pt scale x1–x8 (4–32), screenGutter 20, cardPadding 16 — unchanged; the redesign adds no ad-hoc values (the 0-magic-numbers audit stands).
- **Radii:** card 16 · sheet/dialog 24 · stadium for buttons and chips — unchanged.
- **Elevation (new, closes the "plum-tinted shadows" debt) — defined numerically for the tokens JSON (#71):**
  - Level 0: none (inline surfaces).
  - Level 1 (cards): y2 blur8 `#160E22` at 28% (dark) / `#2A2138` at 8% (light).
  - Level 2 (sheets, dialogs): y6 blur24 `#160E22` at 36% / `#2A2138` at 12%.
  - Level 3 (milestone overlay): y12 blur40 `#160E22` at 44% / 16%.
  - Shadows are plum-tinted, never black; light mode leans on Veil borders first, shadow second.

### 9.4 Components

- **Buttons:** FilledButton — Pomegranate fill, Moonlight label, 48dp min, stadium; pressed = Pomegranate Deep + scale 0.98/120ms. TextButton — **Rose** label (the link fix), stadium. Destructive — Alert text, never a red fill (calm even when grave). Disabled — Night Raised fill, Mist label.
- **Cards:** Night Raised, radius 16, Level 1 shadow, Veil border in light mode. Variants: question card (lattice watermark 4%), sealed card (folded-note top edge + lattice-lock glyph), answer card (author Caption + body), tile (glyph + title + chevron in Clay).
- **Inputs:** Night Raised fill, radius 16, Veil border → 2dp Pomegranate focus border, label/hint in Mist, error border + line in Alert. OTP/PIN digit slots per §6.
- **Chips:** stadium; Night Raised + Veil border → selected Pomegranate Deep fill + Moonlight label; no checkmarks.
- **Gradients:** exactly one sanctioned pair — Pomegranate `#C04A5A` → Pomegranate Deep `#8E3140` — for seed shading and rare hero accents. No other gradients exist.
- **Icons:** **Phosphor rounded** (decision on #63), 24dp grid, 1.75 stroke, rounded caps/joins; outline = chrome/inactive, fill = active (fill is the only "on" signal besides color; color never the sole signal). Color roles: Sand/Ink neutral, Clay secondary, Pomegranate only for brand-meaningful glyphs, Gold only on premium marks. Five custom brand glyphs to the same spec: **the seed, the seed vessel, the unfold, the lattice-lock, the two-seeds mark**. Directional glyphs ship as mirrored pairs behind the direction-aware wrapper. Never mix families; never use emoji as UI icons.
- **Progress:** the **seed-pulse** — a single seed glyph breathing at 0.9→1.0 scale, 800ms loop — replaces the Material circular spinner as the app-wide loading indicator (the one sanctioned looping motion, because loading is not "ambience").
- **Illustration ("Nightbloom"):** abstract duotone botanical over 4–8% lattice fragments; 2–3 flat layers; per piece Night + two accents (Pomegranate/Clay dominant; Sage or Gold rare third); soft rounded forms matching Rubik's terminals and the 1.75 icon stroke — one drawing hand. Hard rules: no photographic couples, no faces, no embracing figures anywhere in-app or on AR marketing; two-ness only through paired forms (two seeds, two branches, two lit windows). Deliverable suite: sign-in hero, empty states (no-question-yet "dawn branch", waiting, solo complete, couple-ended "single seed", coach, closed-bud error), the seed vessel, invite card art, paywall vignettes. The shield and discreet icon stay illustration-free by ADR.
- **Component inventory (post-redesign):** FilledButton, TextButton, destructive text action, card ×4 variants, tile, input, OTP slot row, chip, sheet, dialog, snackbar, seed-pulse, streak strip, seed vessel, seven-seed row, reaction row, persona card, quota pill, callout (Veil/Alert), sticky CTA bar, header (Us glyph + gear), page dots, QR block, invite card renderer, milestone overlay, PinKeypad, SoftUnfoldReveal, PremiumGate, SettingsErrorLine, PrivacyShieldCover.

### 9.5 Design language summary

Candlelight, not neon. A deep plum night lit warmly from within: Sand text that glows rather than glares, one crimson accent that means *action* and *us*, gold so scarce it means *celebration*, and a botanical-geometric illustration voice that is Anatolian and Khaleeji without costume. Surfaces separate by warmth and hairlines, not by loud elevation. Everything unfolds; nothing bounces. The quietest screen in the category — until the nightly reveal, which is the loudest thing Hayati ever does, and it is 1.2 seconds long.

---

## 10. App Icon Concepts

All four render on the Night `#231A33` canvas with a subtle radial lift toward center (within the sanctioned gradient pair for seed shading only); no wordmark in any icon (trademark unresolved — the mark must survive a rename to İkimiz / Baynana / Mawadda / Roohi).

1. **Two Seeds, redrawn (recommended).** Two pomegranate seeds inclining toward each other — one Pomegranate Deep `#8E3140`, one Pomegranate `#C04A5A` with a Moonlight `#FFF8F1` highlight — redrawn with a clearer asymmetric kiss-point, slimmer teardrop geometry with a defined tip, scaled to ~55% of canvas (from today's ~third). Composition: the pair sits slightly below optical center, tips converging at a 12° incline, the gap between them a deliberate 1.75-stroke-width — the same breath as the icon system. *Rationale:* the concept is right (streak metaphor, two-ness, culturally bilingual); the execution fails at icon size — the current twin rounded forms invite misreads (butterfly at best, anatomical at worst), fatal for a discretion-first brand. A redraw keeps continuity with every shipped asset and stays wordless, which the discreet-conscious user quietly appreciates.
2. **The Whole Pomegranate.** A single round fruit with its five-point calyx crown in Clay, a thin crescent cut revealing exactly two seeds; flat Nightbloom style. Composition: fruit at 60% canvas, crown breaking the silhouette top-end, the crescent cut on the lower third so the two seeds read only at close look. *Rationale:* reads fruit-first, love-second — the most glance-proof romantic option for phones checked by family; a natural umbrella mark if packs/quizzes become sub-brands (seeds of the same fruit).
3. **The Unfold.** An abstract folded note caught mid-opening: two soft-cornered panels lifting apart, the gap glowing Sand from within; the negative space between panels forms a subtle seed silhouette. Composition: panels at 15° open, glow strongest at the fold line, panel corners matching the radius-16 card language. *Rationale:* brands the signature interaction (the sealed answer, the mutual reveal) rather than the metaphor — the Linear/Stripe school of "icon = the product's core verb." Completely non-romantic at a glance, which is either its superpower (discretion) or its weakness (warmth on the shelf); test against Two Seeds in a store-page A/B.
4. **The Lit Lattice.** An eight-point star aperture (Seljuk/mashrabiya-derived) on Night, glowing warm Sand-to-Gold from inside — a lit window seen from the street at night; two tiny seed silhouettes just visible within. Composition: aperture at 50% canvas, glow bleeding 2–3% beyond the star edges, seeds at 8% scale inside. *Rationale:* encodes the deepest brand truth — a warm private life glimpsed but not exposed — with unmistakable Anatolian/Arab fluency and zero Western-couple-app resemblance; the most premium and ownable, but abstract enough to need the screenshots to explain it. Suits a v2 refresh or the AR storefront more than global launch.

The discreet alternate icon (grey utility-list glyph) is out of scope for these concepts — it is correct precisely because it carries no brand.

---

## 11. Motion & Interaction Language

**One verb, felt not watched: everything in Hayati unfolds.** Ordinary UI never animates for its own sake — no looping ambience (seed-pulse loading excepted), no idle bounces, no confetti outside milestones. Hierarchy of intensity: daily reveal > milestone > pairing preview > everything else.

### Named tokens (to be added to `motion_tokens.dart` and the brandkit JSON, closing #71)

| Token | Value | Use |
|---|---|---|
| `unfoldSoft` | 240ms · easeOut · fade + 12dp rise, RTL-neutral | Universal enter: screens, cards, sheets — replaces default Material transitions |
| `unfoldReveal` | 300ms · easeOut · card unfolds toward its pair | Reveal beat 1 |
| `settlePair` | 180ms · easeOut | Reveal beat 2: both cards settle as a pair |
| `seedDrop` | 420ms · gentle spring, overshoot ≤4dp | Reveal beat 3: seed into the vessel; also solo-day seed fill |
| `pressTouch` | 120ms · easeOut · scale 0.98 | All button presses |
| `chipFill` | 120ms · easeOut | Chip/selection fills |
| `reactPop` | 150ms · easeOut · scale 1.0→1.15→1.0 | Reaction tap |
| `celebration` | ≤1200ms total · easeOut particles | Milestones only; tap-to-skip; never blocks input |
| `seedPulse` | 800ms loop · scale 0.9→1.0 | Loading indicator (the one sanctioned loop) |
| `shakeDeny` | 2 × 4dp · 200ms | PIN mismatch (reduce-motion: color flash) |

### Signature moments

1. **The Reveal (the only choreography budget):** partner's card `unfoldReveal` toward yours → `settlePair` → one `seedDrop` into the streak strip's vessel. Total ≤1.2s. Accompanied by the single light haptic on the live waiting→revealed transition (shipped, kept, sacred) and an optional soft chime, **off by default**.
2. **Milestones (7/30/100 seeds) & mercy day:** Gold (or Sage for mercy) particle restraint — ≤1.2s, ≤24 particles, tap-to-skip, never blocking.
3. **Pairing preview:** `unfoldSoft` entrance (shipped, kept) — the invitee's first taste of the reveal language.
4. **Stillness as gravity:** lock, consent, legal, deletion, and crisis surfaces never animate beyond the base unfold. The absence of motion is itself a register.

### Haptics

| Event | Haptic |
|---|---|
| Live reveal transition | Light impact (shipped — the app's one haptic today; remains the anchor) |
| Save answer / chip select / reaction | Selection tick |
| Milestone | Light impact ×1 (never a buzz sequence) |
| PIN deny | None added — the cooldown copy carries the message; the lock never "buzzes angrily" |

### Physics & budgets

easeOut for all entrances; gentle spring (overshoot ≤4dp) only for `seedDrop`; 60fps budget; motion never delays interactivity (cards are tappable mid-unfold). **Reduce-motion collapses every sequence to an instant crossfade with the haptic preserved** — the reveal must remain operable and feelable without animation.

---

*Acceptance for every screen above: regenerate the six-cell golden matrix intentionally, pass `tool/rtl_lint.dart` and the sentinel suites (lock-screen forbidden APIs, biometricOnly, token parity), route any Class G layout change past the copy-digest check unchanged, and clear native register review (TR founder couple, Gulf-dialect AR reviewer) for every new string before merge.*
