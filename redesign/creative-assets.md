# Hayati — Creative Asset Inventory & Production Blueprint

The complete inventory of visual assets for the Hayati redesign and launch, executable without further questions. The brand direction document is law: palette hexes, taglines, and principles below are verbatim from it. Codebase constraints are binding — the invariant firewall (`docs/adr/025-uipro-refactor-scope-and-invariant-firewall.md`), the DV threat model (`docs/adr/018-device-privacy-layer.md`), and the golden matrix ({TR,AR,EN} × {LTR,RTL}). Two standing hard rules cover every asset here: **no photographic couples, no faces, no embracing figures on any AR-market marketing surface** (two-ness is always paired forms — two seeds, two branches, two lit windows), and **the privacy shield (`app/lib/features/privacy_lock/presentation/privacy_shield_cover.dart`) and app-switcher card stay brand-free flat Night forever**. Alert `#D96C5F`/`#B04A3E` never appears in marketing.

Palette shorthand used throughout (dark-mode hex / light-mode hex): Night `#231A33`/`#FAF3E8` (Paper), Night Raised `#2E2344`/`#FFFCF6`, Sand `#F3E7D7`/`#2A2138` (Plum Ink), Mist `#B9AFC6`/`#6B6178`, Veil `#453A5C`/`#E7DCCB`, Pomegranate `#C04A5A` (both modes), Pomegranate Deep `#8E3140` (both modes), Rose `#E38E99`/`#8E3140`, Moonlight `#FFF8F1` (both modes), Gold `#D9A441`/Brass `#866112`, Sage `#8FAE8B`/`#4E6B4A`, Clay `#B98A6E`/`#8A5F43`.

---

## 1. App icon concepts

Context: the shipped mark (`brandkit/brandkit/logo/hayati-mark.svg`) is conceptually right and executionally wrong — it occupies barely a third of the canvas and its twin rounded forms invite misreads (butterfly at best, anatomical at worst), fatal for a discretion-first brand. All four concepts are wordless: the "Hayati" trademark is unresolved (ADR-027), so the mark must survive a rename to İkimiz, Baynana, Mawadda, or Roohi.

### 1.1 Two Seeds, redrawn — RECOMMENDED, ship this

- **Composition:** Two pomegranate seeds inclining toward each other with a clear asymmetric kiss-point — the left seed slightly larger and lower, the right slightly smaller and higher, tips nearly touching at an off-center point about 58% up the canvas. Seed geometry is a slim teardrop with a defined tip (not a lobe): roughly 1:1.6 width:height, rounded base, 1.75-stroke-language curvature matching the icon set. Mark scaled to ~55% of canvas width, optically centered.
- **Palette:** Background is flat Night `#231A33` with an extremely subtle radial lift toward Night Raised `#2E2344` behind the kiss-point (the one sanctioned "glow," ≤8% delta — reads as depth, not gradient decoration). Left seed Pomegranate Deep `#8E3140`; right seed Pomegranate `#C04A5A` with a single Moonlight `#FFF8F1` specular crescent on its upper shoulder. No outlines, no gold.
- **Rationale:** Keeps continuity with every shipped asset; carries the streak metaphor (every mutual day, a seed); reads two-ness without bodies; stays quiet on a glanced-at home screen. The redraw fixes scale, silhouette ambiguity, and tip definition — the three actual failures.
- **Variants:** iOS 18 **dark** variant: identical (the icon is already dark — verify the system doesn't double-darken; if muddy, lift background to Night Raised `#2E2344`). iOS 18 **tinted** variant: seeds as a single Moonlight-alpha glyph on transparent, per Apple grayscale-template spec. Light contexts (marketing, web favicon): seeds on Paper `#FAF3E8`, left seed Pomegranate Deep, right Pomegranate — no Moonlight highlight (insufficient contrast on light). Android adaptive (M6.5): foreground = seeds at 40% of safe zone, background = flat Night; replaces `hayati-appicon-android-adaptive-*.png`.

### 1.2 The Whole Pomegranate — backup / umbrella mark

- **Composition:** A single round pomegranate, five-point calyx crown, a thin crescent cut on the lower right revealing exactly two seeds inside. Flat Nightbloom construction, fruit at ~60% canvas.
- **Palette:** Fruit Pomegranate `#C04A5A`, crescent interior Pomegranate Deep `#8E3140`, the two interior seeds Moonlight `#FFF8F1`, crown Clay `#B98A6E`, on Night `#231A33`.
- **Rationale:** Reads as fruit first, love second — the most glance-proof romantic option for phones checked by family; strongest umbrella mark if packs/quizzes become sub-brands (seeds of the same fruit).
- **Variants:** dark = as-is; tinted = fruit silhouette with crescent as negative space; light marketing = Plum Ink `#2A2138` line rendering on Paper.

### 1.3 The Unfold — A/B challenger

- **Composition:** An abstract folded note caught mid-opening: two soft-cornered panels lifting apart from a center fold, the gap glowing Sand `#F3E7D7` from within; the negative space between panels forms a subtle seed silhouette.
- **Palette:** Panels Night Raised `#2E2344` with Veil `#453A5C` edge hairlines, interior glow Sand `#F3E7D7` falling to Night `#231A33`.
- **Rationale:** Brands the product's core verb (the sealed answer, the mutual reveal) in the Linear/Stripe school of "icon = the interaction." Fully non-romantic at a glance — its superpower for discretion, its risk on the store shelf. Test against 1.1 in App Store product-page A/B once analytics exist.
- **Variants:** tinted = panels as outline glyph; light = Plum Ink panels on Paper with Pomegranate glow.

### 1.4 The Lit Lattice — v2 / AR-storefront refresh

- **Composition:** An eight-point star aperture (Seljuk/mashrabiya-derived) cut into a Night field, glowing warm from inside — a lit window seen from the street at night — with two tiny seed silhouettes just visible within the glow.
- **Palette:** Field Night `#231A33`, aperture glow Sand `#F3E7D7` warming to Gold `#D9A441` at the very center (the one sanctioned gold use in iconography), seeds Pomegranate Deep `#8E3140`.
- **Rationale:** Encodes the deepest brand truth — a warm private life glimpsed but not exposed — with unmistakable Anatolian/Arab fluency and zero Western-couple-app resemblance. Most premium and ownable; most abstract, so it needs the screenshots to explain. Hold for a v2 refresh or the AR storefront.

### 1.5 Discreet alternate icon — keep, do not "improve"

The shipped grey utility glyph (`brandkit/branding-assets/icons/hayati-appicon-discreet-1024.png`, wired via `app/ios/Runner/Assets.xcassets/AppIconDiscreet.appiconset`) is correct and honest. Redraw only for pixel hygiene at small sizes. It must never gain seeds, pomegranate tones, or any brand tell — its entire job is to not be this brand. Provide matching iOS 18 dark/tinted variants that stay equally anonymous.

---

## 2. Illustration system spec — "Nightbloom"

One drawing hand across the entire brand. Nightbloom is abstract duotone botanical over geometric lattice: pomegranate seeds, branches, blossoms, and crescent-cut fruit silhouettes as the recurring characters; behind them, low-opacity Ottoman/Seljuk and mashrabiya lattice fragments as atmosphere.

**Construction rules**

- **Layers:** 2–3 flat layers per piece, period. Foreground subject (filled shapes), midground secondary forms, background lattice texture.
- **Line & stroke:** Line-work matches the icon language — 1.75 stroke at 24dp scale, scaled proportionally (e.g., 7pt stroke at 96dp artwork). Rounded caps and joins everywhere; terminals echo Rubik's rounded terminals.
- **Fills:** Flat color only. The single sanctioned gradient in the entire system is Pomegranate `#C04A5A` → Pomegranate Deep `#8E3140`, used inside seeds and fruit shading. Nothing else blends.
- **Texture:** Lattice fragments at 4–8% opacity (Sand-on-Night in dark; Plum Ink-on-Paper in light). Lattice is cropped, partial, off-grid — a fragment drifting behind the subject, never a full symmetric medallion, never wallpaper.
- **Palette per piece:** Night + two accents maximum. Pomegranate/Clay dominant; Sage or Gold as the rare third (Gold only in celebration pieces). Light-mode inversion: Plum Ink `#2A2138` line-work on Paper `#FAF3E8`, same accent discipline.
- **Character treatment:** No people. Ever, in-app; and no faces/embracing figures on AR marketing. Two-ness is paired forms: two seeds, two branches inclining toward each other, two lit windows, two cups of tea, two panels unfolding. Objects may have warmth (a glow, an incline) but never eyes, limbs, or expressions.
- **Scale discipline:** In-app spot illustrations are small and quiet — 96–160dp, sitting above the headline in empty states. Hero pieces (sign-in, marketing) may fill wider fields but keep ≥40% empty Night around the subject. Restraint reads premium.

**What Nightbloom must never look like**

- Corporate-Memphis blob people, Alegria-style figures, or any "diverse flat humans" stock idiom.
- Gradient-mesh 3D blobs, glassmorphism, clay-render 3D, or AI-slop hyperdetail.
- Neon-dating visual language: no hearts as motifs, no flames, no lips, no ring emoji energy. (No flame imagery anywhere — and no nar/نار wordplay: "nar" is pomegranate in Turkish but *fire* in Arabic; the pun is off-limits, and Arabic copy says رمّان only.)
- Ornament pastiche: no full arabesque carpets, no Aladdin-esque orientalism, no crescent-and-star nationalism. The lattice is an echo, not a costume.
- Cute mascot styling (see §3), emoji as illustration, or Duolingo-grade saturation.

**Reference caliber:** Headspace's system discipline (one vocabulary, infinite scenes) without its characters; Calm's atmospheric restraint and dark-canvas warmth; Linear/Stripe editorial precision in geometry; Studio-quality Islamic geometric art references (real mashrabiya photography, Seljuk tile fragments) as the lattice source, redrawn — never traced clip-art.

**Deliverable set (masters, each in dark + light):** sign-in hero; onboarding preview trio (§4); empty-state suite (§5); the streak seed vessel (§6 — the hero brand object); celebration pieces (§6); invite card art (§9.3); paywall benefit vignettes (three: packs, coach, one-subscription-two-people — paired seeds under one branch); store screenshot backdrops (§9.1).

---

## 3. Mascot evaluation

**Recommendation: no mascot.** Firmly.

1. **A mascot is a third person in a two-person room.** The product thesis is "the couple IS the network" — no feed, no strangers, ever. An anthropomorphized character watching the ritual breaks the intimacy that is the product.
2. **Discretion is a feature.** A recognizable character on notifications or screens re-identifies the app to exactly the relative or metro-glancer the discreet icon and shield exist to defeat.
3. **Dignity for the margin persona.** Noura & Fahad (Riyadh, married, GCC prices) are choosing a face-saving alternative to therapy; a cartoon companion reads juvenile and undermines "warm, dignified, faith-compatible."
4. **Mascots monetize guilt.** The Duolingo playbook is passive-aggressive streak pressure; Hayati's principle is verbatim "Never guilt, always invite — streaks forgive (the mercy day), nudges welcome, the lagging partner is courted rather than shamed." A mascot's strongest lever is the one this brand forbids.

**The alternative that fills the mascot's job:** the **seed vessel** (§6.1) is the brand's persistent, ownable, emotionally-accruing object — it grows, it can be celebrated, it can appear in marketing — without ever being a character. It is Hayati's "mascot-shaped object": Calm has the mountain, Headspace has the dot, Hayati has the vessel of seeds two people filled together. All character-budget goes there.

---

## 4. Onboarding illustrations

The redesign adds a 3-screen ritual preview before sign-in (the store description at `fastlane/metadata/en-US/description.txt` already contains this pitch, localized) and re-stages the existing screens. One piece per step; all shipped in dark + light, all RTL-safe (see §10).

| Step | Screen / file | Subject & composition | Mood |
|---|---|---|---|
| 0. Preview 1 — "One question a day, for two." | new pre-auth pager | A single folded question card, closed, resting under a branch with one blossom; lattice fragment upper-start corner at 6%. Card Night Raised with Veil hairline; blossom Pomegranate. | Calm invitation — the ritual as a small, finite promise (five minutes, not another feed). |
| 0. Preview 2 — "Sealed until you both answer." | same pager | Two cards facing each other across a center gap, both closed; a faint Sand glow in the gap between them. One card tilted 4° toward the other. | Anticipation without tension — no peeking, no performing. |
| 0. Preview 3 — "What's between you stays between you." | same pager | The lattice-lock custom glyph (eight-point star aperture with a keyhole-negative seed) large, centered; behind it a barely-lit pair of windows in a night skyline reduced to three rectangles. | Quiet security — privacy expressed as care, never paranoia. Spotlights PIN/discreet icon for the GCC persona before sign-in. |
| 1. Sign-in hero | `app/lib/features/auth/presentation/sign_in_screen.dart` | Replace `Text(config.appName)` with the redrawn two-seed mark (56dp) above the wordmark, over a soft Nightbloom scene: two branches from opposite screen edges inclining toward each other, tips almost meeting behind the wordmark; lattice at 4% across the top third. Tagline beneath in Mist: "One question a day, for two." (TR: "Günde bir soru, ikiniz için." / AR: "سؤال واحد كل يوم، لكما.") | Arrival — warm, unhurried, candlelight not neon. The invitee's first impression finally sells something. |
| 2. Profile capture | `app/lib/features/profile/presentation/profile_capture_screen.dart` | Small spot (96dp) above "About you two": two seeds side by side on a single leaf. No scene — the form stays light. | Companionable; "we're asking about the two of you." |
| 3. Consent gate | `app/lib/features/legal/presentation/consent_gate_screen.dart` | **No illustration, no lattice** (legal surfaces stay bare — ui-ux §6.1: gravity is expressed through space). Copy is frozen (Class G). Permitted: Veil dividers to break the wall of text into scannable sections without rewording anything. | Sober, respectful register. |
| 4. Invite share | `app/lib/features/pairing/presentation/invite_share_screen.dart` | The invite-card art (§9.3) shown as a live preview above the code: a sealed card with the partner-facing message visible — the inviter sees exactly what the partner will receive. | Confidence — "this is what they'll see." |
| 5. Partner preview (invitee) | `app/lib/features/pairing/presentation/partner_preview_screen.dart` | A single card mid-unfold (the soft-unfold moment frozen as art), Sand glow spilling from the fold; inviter's name set above in H1. When the questionText preview hook lands (PRD F1 restoration), the art frames the real locked answer slot. | "Someone is waiting for you" — warm pull, zero pressure. |

---

## 5. Empty-state artwork

Every piece is a quiet 96–140dp Nightbloom spot above the existing (unchanged) copy. States that carry frozen or safety copy get stillness, not decoration.

| Screen & state | Source | Artwork |
|---|---|---|
| Paired home — no question yet ("Today's question is on its way…") | `app/lib/features/daily_question/presentation/paired_home_screen.dart` | The **"dawn branch"** piece (ui-ux's name for it): a closed bud on a branch against a crescent moon (crescent-cut fruit silhouette, not a religious crescent — asymmetric, fruit-stemmed). Night + Clay + Pomegranate bud. |
| Paired home — waiting for partner slot | `paired_home_screen.dart` partner slot | Replace the hourglass `Icons.hourglass_empty` with the custom "unfold" glyph half-open plus a small still seed beside it. No animation loop — waiting must feel patient, not nagging. |
| Paired home — partner slot locked ("unlocks when you answer") | same | Lattice-lock glyph, Clay, 32dp inline. Not an illustration scene — a glyph keeps the nudge light. |
| Solo home — day N of 7 | `app/lib/features/daily_question/presentation/solo_home_screen.dart` | The seven-seed progress row (canonical across ui-ux §6.3 and roadmap QW-9): N seeds filled Pomegranate, 7−N slots in Veil outline, drawn horizontally (mirrored in RTL), today's seed pulsing softly once on load. This is the missing progression visual; it doubles as the day counter and teaches the streak language before pairing. |
| Solo home — completed (day 8+) | same | The full seven-seed row beneath a branch bending toward an empty second branch entering from the far edge — the invitation embodied. Sage accents on the bloomed branch. |
| Partner preview — invitation unavailable / fetch error | `partner_preview_screen.dart` | The shared **"closed bud"** error spot (canonical error art, ui-ux §6.2): a closed bud on a short stem — patient and blame-free; no broken, torn, or detached metaphors (never imply the relationship failed). One drawing reused across all error states. |
| Couple-ended notice | `app/lib/features/data_rights/presentation/couple_ended_notice_screen.dart` | **Minimal by design:** a single seed resting on open ground, small, centered, Clay-toned. No pair imagery, no wilt, no drama. Copy is pinned and actor-unattributed; the art must be exactly as reticent. |
| Coach — empty transcript | `app/lib/features/coach/presentation/coach_screen.dart` | Two cushions and a low tea table rendered as three soft geometric forms, lattice at 4% behind. Warmth without a person — the coach has no face (see §3). |
| Coach — help card / paused panel | same | **No artwork.** Class G+★ surfaces; the help card's structural distinction from persona bubbles is test-pinned. Color and stillness only. |
| Pack selection — locked & "New packs are on the way." | `app/lib/features/entitlements/presentation/pack_selection_screen.dart` | A crate of pomegranates, one open showing seeds, rendered as three stacked rounded forms; Gold absent (gold belongs to the premium mark, not the pitch). |
| Paywall — store unavailable | `app/lib/features/entitlements/presentation/paywall_screen.dart` | The same "closed bud" error spot at glyph scale (ui-ux §6.4 — one error drawing, everywhere). Honest error states stay typographic-first. |
| Export screen | `app/lib/features/data_rights/presentation/export_screen.dart` | None. Raw JSON honesty is the design. |
| Lock screen | `app/lib/features/privacy_lock/presentation/lock_screen.dart` | **None, ever.** Class F: parity-only, no overlay-dependent widgets, keypad stays LTR — and no brand additions either, not even the seed mark: a locked Hayati should look like nothing worth asking about (ui-ux §6.6). Retint with tokens; nothing else. |

---

## 6. Success & celebration artwork and moments

### 6.1 The seed vessel — the brand's hero object

A low, wide glass-ceramic bowl (Anatolian çini silhouette, drawn in Nightbloom flat layers: Night Raised body, Veil rim hairline, Clay foot) that visibly holds one Pomegranate seed per mutual day. Lives on the paired home replacing the `Icons.favorite` + "4-day streak" text row. Seeds render individually up to 14, then as a rising fill level with a "34" tabular-figure count (Eastern Arabic numerals ٠١٢٣ when the AR setting lands). States: normal (seeds still), **streak-safe** after today's reveal (topmost seed with a Sage `#8FAE8B` glint), **at-risk** (vessel unchanged; a small Alert-colored dot on the day marker only — Alert colors the state, never the tone, and the vessel itself never threatens), **grace used** (see mercy day below).

### 6.2 The reveal — the product's one choreographed event

Artwork: the two answer cards redesigned as facing panels with a fold-line at their meeting edge, partner's card entering per §7.2. The moment both settle, a seed drops into the vessel. No confetti, no full-screen takeover — the celebration is the pair itself. Haptic (existing single `lightImpact`) kept.

### 6.3 Milestones — 7 / 30 / 100 seeds

Tap-to-skip overlay above Today (never a route, never blocking input — ui-ux §6.3), unlocked after the reveal settles: the vessel rendered larger with Gold `#D9A441` particle accents (≤1.2s motion, §7.5), caption verbatim from product-copy ("Seven seeds. A whole week of showing up for each other." — TR-playful may warm this; AR stays formal-warm). Gold appears here and on premium marks only — scarcity is the value. Each milestone card doubles as a **shareable image** (§9.3): identity-safe (no answers, no names unless the user opts in), WhatsApp-Status sized.

### 6.4 The mercy day (grace token)

Currently invisible pure server logic (`functions/src/streak/`). Give it a moment: when a missed day is bridged, the paired home shows a one-time inline card — a Sage `#8FAE8B` leaf laid over the gap between seeds in the vessel, copy invitational and verbatim from product-copy ("Life happened yesterday. A mercy day kept your streak whole."; native reviewers own final wording). Culturally-framed forgiveness, never "streak freeze" gamer language.

### 6.5 Pairing success

The moment `joinInvite` routes to the paired home: the two branches from the sign-in hero meet fully for the first time above the day's question, then settle into the home's ambient header. One-shot, then never repeats.

### 6.6 Premium welcome

Entitled paywall view keeps its Gold premium mark; add a single still vignette — two seeds under one Gold-tipped branch ("One subscription. Premium for both of you."). No shimmer, no ongoing animation on a settings-class surface.

---

## 7. Lottie/motion assets

Motion constitution: everything unfolds. Base verb is the shipped Soft Unfold (`app/lib/core/widgets/soft_unfold_reveal.dart`): 240ms easeOut, fade + 12dp rise, RTL-neutral. Hierarchy of intensity: daily reveal > milestone > pairing preview > everything else. Reduce-motion collapses every sequence to instant crossfade with haptic preserved. Lock, consent, legal, and deletion surfaces never animate beyond the base unfold. **Tooling split:** Rive for stateful objects (the vessel), Lottie for one-shot vector sequences, pure Flutter implicit animations for the base unfold (already shipped — do not re-implement in a runtime).

| # | Name | Trigger | Duration | Easing character | Frame-by-frame |
|---|---|---|---|---|---|
| 7.1 | `soft-unfold-enter` (Flutter, exists — extend) | Every screen/card/sheet entrance, replacing default Material transitions | 240ms | easeOut, no overshoot | 0ms: content at 0% opacity, +12dp below rest. 0–240ms: opacity to 100%, rise to rest. Nothing else moves. |
| 7.2 | `reveal-choreography` (Flutter sequence orchestrating 7.3) | Live waiting→revealed transition on paired home | ≤1200ms total | easeOut entries, gentle spring settle (overshoot ≤4dp) | Beat 1 (0–300ms): partner's card unfolds toward yours — enters from the partner-slot position with a subtle 3D fold flattening, translating toward your card. Beat 2 (300–650ms): both cards settle side-by-side as equals, 8dp gap, simultaneous 2dp settle. Beat 3 (650–1200ms): seed-drop (7.3). Haptic `lightImpact` fires at Beat 2 settle (kept from shipped code). Optional soft chime, off by default. |
| 7.3 | `seed-drop` (Rive state machine on the vessel) | Beat 3 of reveal; also fired on cold-open if a reveal happened while away (without beats 1–2) | 550ms | gravity fall (easeIn) then spring settle, overshoot ≤4dp | Seed appears 24dp above vessel rim at 0% opacity → 100% by 80ms; falls with slight acceleration; lands among existing seeds; neighboring 2–3 seeds displace 1–2dp and re-settle; count increments with a 120ms tabular-figure crossfade. |
| 7.4 | `vessel-states` (same Rive artboard) | Streak-safe glint after drop; at-risk dot; grace leaf | glint 400ms one-shot; others static | easeOut | Glint: Sage highlight sweeps the topmost seed once. At-risk and grace states are static poses in the state machine — no looping ambience, ever. |
| 7.5 | `milestone-gold` (Lottie) | Milestone card entrance at 7/30/100 seeds | ≤1200ms, skippable by tap, never blocks input | easeOut burst, particles decelerate to stillness | 0–150ms: card soft-unfolds. 150–900ms: 12–18 Gold `#D9A441` particles rise from the vessel rim like sparks from an ember — small, slow, dignified; no confetti physics. 900–1200ms: particles fade; Gold rim-light on the vessel remains as the still end-state. |
| 7.6 | `mercy-leaf` (Lottie) | First home view after a grace-bridged day | 600ms one-shot | easeOut | Sage leaf fades in above the seed gap, drifts down 8dp, settles across the gap. Still thereafter. |
| 7.7 | `pairing-preview-unfold` (Flutter, exists — restage) | Partner preview valid-invite entrance | 240ms base + 200ms | easeOut | Existing soft-unfold; add the card art opening 12° at the fold after settle, glow brightening 4%. |
| 7.8 | `branches-meet` (Lottie) | One-shot on first paired-home mount after `joinInvite` | 900ms | easeOut, no bounce | Two branches draw in from opposite screen edges (start/end aware — mirrors in RTL), tips meet center, one blossom opens at the join, then the whole settles to 60% opacity ambient header. Never replays. |
| 7.9 | `invite-sent-settle` (Flutter) | Return from share sheet on invite share screen | 300ms | easeOut | The invite-card preview tilts 2° and settles, code pulses once in Rose `#E38E99`. Confirms without a snackbar. |

Explicitly **not** built: looping backgrounds, idle bounces, pull-to-refresh novelties, animated tab bars, any lock-screen or shield motion (Class F), any consent/legal motion.

---

## 8. Background graphics, decorative elements & hero artwork

- **Lattice fragment library (6 masters):** eight-point star field, hexagonal mashrabiya grid, interlocking Seljuk knot band, girih strap fragment, blossom-diaper repeat, and a single large star aperture. Each delivered as a tileable SVG in Sand-alpha (dark) and Plum-Ink-alpha (light). Usage: 4–8% opacity, cropped and off-grid, at most one fragment per screen; approved surfaces are sign-in, onboarding pager, milestone cards, marketing. **Never** behind body text blocks, never on lock/consent/legal/delete surfaces — no exceptions (ui-ux §6.1: legal gravity is expressed through stillness).
- **Plum-tinted elevation, defined numerically (canonical values in ui-ux §9.3, repeated here):** shadow color `#160E22` (deep plum, never black) — cards y2 blur 8 at 28% (dark) / `#2A2138` at 8% (light); sheets/dialogs y6 blur 24 at 36% / 12%; milestone overlay y12 blur 40 at 44% / 16%. In dark mode pair with a 1dp Veil `#453A5C` top hairline (shadows barely read on Night — the hairline does the separating); light mode leans on Veil borders first, shadow second.
- **Corner blooms (4):** small branch-and-blossom pieces anchored to a start- or end-corner for marketing layouts and the milestone/share cards. Mirrored variants required (§10).
- **Divider ornament:** none in-app — Veil hairlines only (restraint reads premium). One marketing-only ornament: a three-seed ellipsis motif replacing "•••" in long-form layouts.
- **Hero artwork (masters):**
  1. *Sign-in hero* — §4 step 1.
  2. *Landing-page hero* — wide (2400×1350) Nightbloom scene: the paired home rendered as a floating device-free UI card pair mid-reveal, vessel beneath, branches arcing from both edges, lattice at 4%; headline space reserved start-side (mirrors for AR). Doubles as the Product Hunt gallery lead and X/Twitter header (replacing `brandkit/branding-assets/social/x-header-1500x500.png`).
  3. *Store screenshot backdrop set* — eight Paper `#FAF3E8` panels (the marketing canvas — Paper is canonical for store screenshots, per the direction) with a continuous Plum Ink branch-line flowing across the strip when viewed as a gallery (§9.1); the device mockups within stay Night.
  4. *Ramadan variant* — the same landing hero with the lattice swapped to the star-aperture fragment and a Gold crescent-cut fruit; prepared now, shipped with the Ramadan content moment (ADR-026 machinery exists).

---

## 9. Marketing visuals

Pre-launch reality check: G1 (60 TikTok slideshows — 30 TR / 30 AR across 6 fresh accounts per README; ≥3 posts >100K views per language from <5K-follower accounts) has never been run and needs zero app changes — the question-card template system below is therefore the **first** asset to production-harden. All AR marketing obeys the hard rules (no faces/couples/embracing figures; modest-romantic register). Name risk: keep wordmark presence light and seed-mark presence heavy on everything until the trademark clears.

### 9.1 App Store screenshots (per locale TR / EN now; AR directory to be created at `fastlane/metadata/ar-SA/` for Phase 3 — the GCC launch)

Eight slots (canonical storyboard and tri-locale captions live in marketing-strategy §4 — one source, zero drift), 6.9" (1320×2868) and 6.1" (1179×2556). Device mockups on Night sit over the Paper `#FAF3E8` marketing canvas with the continuous Plum Ink branch-line (§8). Captions set in Rubik 800 Latin / Rubik 700 Arabic, Plum Ink `#2A2138` on Paper; keep marketing display voice identical across scripts — Arabic never a lighter afterthought.

| Slot | Screen shown (captions per marketing-strategy §4) |
|---|---|
| 1 | Two-seeds mark + paired home, today's question in the Question style, vessel with 12 seeds — must communicate the whole product alone (most users never swipe) |
| 2 | Paired home, partner slot **locked**, lattice-lock glyph prominent |
| 3 | The reveal — both cards unfolded toward each other, mid-soft-unfold |
| 4 | Seed vessel with seeds + gold milestone moment |
| 5 | Lock screen + discreet icon toggle composite |
| 6 | AR paired home, full RTL, Arabic question (culture slide; AR set shows register depth instead) |
| 7 | Paywall entitled view — two phones, one badge |
| 8 | Partner preview — "{Name} invited you" + sealed answer card |

The TR set may use the playful register in captions; AR set stays formal-warm, authored by the Gulf reviewer, never machine-translated.

### 9.2 TikTok / Reels / Shorts — the G1 engine

- **Question-card slideshow template** (1080×1920, rebuild of `brandkit/branding-assets/social/tiktok-question-card-{tr,ar,en}-1080x1920.png`): Night field, lattice at 6%, question set in the marketing display voice (Rubik 800 Latin / 700 Arabic per the direction — one voice across TikTok cards, store, and app; the in-app Question style stays in-app), two-seed mark bottom-end small, no URL (pre-launch: the hook is the question, the CTA is "follow"). Built as a parameterized Figma component: question text + locale + register in, card out. The content pipeline (`content/packs/`) is the supply — every authored question is a card by design.
- **Slideshow arc template:** 5–7 cards per post — hook card ("Questions couples never ask each other" idiom, localized), 3–5 question cards escalating in depth (map to pack `depth` metadata), close card with the seed mark + "One question a day, for two."
- **Cover/thumbnail template** and a **caption-safe zone spec** (top 220px and bottom 320px kept clear of text).

### 9.3 WhatsApp & shareable cards (the dominant TR/GCC sharing surface)

- **Branded invite card** (1080×1920 Status + 1080×1350 feed + 1200×630 link preview for the `/i/<code>` landing — the same three variants ui-ux §6.2 specifies): **identity-safe by hard rule** (ui-ux §6.2, marketing §2 — it may be posted on a public Status): no names, no answers, no photos. Composition: the sealed-card art over Night, primary tagline in the sender's locale, invite code in a high-contrast Moonlight-on-Pomegranate pill (the code is the real path while links aren't tappable — make it screenshot-legible), seed mark small (wordmark light, trademark caution). The warmth — and the single licensed ❤️ — rides in the accompanying code-first text message (product-copy's rewrite), never on the card. Attached as an image alongside the message from `share_plus_invite_share_launcher.dart`.
- **Milestone share card** (§6.3): vessel + seed count + "Every day you answer together, a seed." Identity-safe by default — no names, no answers, ever, unless explicitly toggled on.
- **Quiz result card** (v1.5 spec, design now): two-column "you/them" paired-forms layout, results as seed clusters, zero text of actual answers.

### 9.4 Google Play feature graphic (M6.5, spec now)

1024×500 rebuild of `brandkit/branding-assets/social/feature-graphic-{tr,ar,en}-1024x500.png`: seed mark start-side, primary tagline end-side, branch-line connecting them; AR variant fully mirrored.

### 9.5 Product Hunt gallery

Launch-day set, matching marketing §6's gallery list one-for-one: (1) hero card — landing-hero crop with tagline + seeds, (2) the 20s preview video, (3) reveal choreography as a 10s capture GIF, (4) privacy trio (lock screen, discreet icon, shield — shown honestly as a blank card, which IS the story), (5) trilingual question card (the identity-work share bait), (6) "no per-person tax on being together" pricing card. The founder note in the radical-honesty voice ("We do not claim all of your data sits in Europe, because it does not." is the most Product-Hunt-native sentence this brand owns) leads the first comment, not the gallery.

### 9.6 Landing page (also unblocks universal links + store-required privacy/support URLs)

One page: hero (§8), three value-prop rows with Nightbloom spots (question/seal/privacy), store badge, AASA served for `hayati://` → https migration. Light mode (Paper) is canonical for web; the product screenshots within it stay dark — the contrast is the brand story.

### 9.7 Social profile kit

Avatar = redrawn seed mark on Night (all platforms); banner = landing hero crop; IG template refresh of `instagram-post-{tr,ar,en}-1080x1080.png` and `story-*-1080x1920.png` to the redrawn mark and Nightbloom system.

---

## 10. Production notes

**Masters & formats.** All illustration and icon masters in Figma with vector sources; export SVG (app/web), PDF (iOS asset catalogs where vector-appropriate), and PNG @1x/@2x/@3x for raster-only surfaces. App icon: 1024×1024 PNG master + iOS 18 dark and tinted variants in the asset catalog; discreet icon set stays a separate appiconset. Lottie as .json (target <60KB each, no raster layers, no expressions unsupported by lottie-flutter); the vessel as a single .riv artboard with one state machine (`seed_count` number input; `safe/at_risk/grace` state input). Marketing exports: PNG for store, MP4 (H.264, 1080×1920, 30fps) for motion posts.

**Dark/light discipline.** In-app is dark-only at MVP; every asset still ships a light Paper master now — marketing/web/store use light immediately, the future light theme inherits for free. Naming: `asset-name.dark.svg` / `asset-name.light.svg`; layer styles use token names, not hexes, synced against `brandkit/brandkit/tokens/hayati-tokens.json` and `app/lib/core/design_system/color_tokens.dart` (both drift-tested — Mist/Veil/Rose/Moonlight must land in both before assets reference them).

**RTL.** Every directional composition ships a mirrored variant: corner blooms, branch-line backdrops, the solo seven-seed progress row, `branches-meet`, feature graphics, screenshot strips, landing hero. Non-directional assets (vessel, seeds, lattice, icon mark) are drawn symmetric-safe and certified RTL-neutral. Phosphor migration note: directional UI glyphs (back/forward/send) ship as explicit mirrored pairs behind the direction-aware wrapper; the six-cell golden matrix and `tool/rtl_lint.dart` are the acceptance harness — every new asset placement regenerates goldens intentionally, never blind-accepted. Numeric keypad glyphs stay LTR-pinned (lock-screen sentinel).

**Cultural review gate.** Every asset carrying text routes through the native register owners (TR founder couple; Gulf-dialect AR reviewer) before export — including captions baked into images. AR marketing assets additionally checked against the hard rules (no figures/faces, modest-romantic, no Alert color, no "nar" wordplay).

**Repo placement.** Masters and exports land in `brandkit/branding-assets/` (marketing) and `app/assets/illustrations/`, `app/assets/motion/` (in-app, bundled via pubspec); the brand guidelines HTML (`brandkit/brandkit/hayati-brand-guidelines.html`) is updated with the Nightbloom, Moonlight/Mist/Veil/Rose, and motion sections so the kit stops being marketing-only.

**Tooling.** Figma (+ Tokens Studio synced to `hayati-tokens.json`) for all masters and templates; Rive editor for the vessel; LottieFiles/Bodymovin for one-shots; AI image tools (Midjourney/Ideogram) for **exploration and mood only** — every shipped vector is redrawn by hand to the 1.75-stroke spec, because AI output cannot hold a system across 30 assets and the lattice must come from real reference, not hallucinated arabesque.

**Generation prompt drafts (exploration only):**

1. *Icon exploration:* "Minimal flat app icon, two pomegranate seeds inclining toward each other, asymmetric near-touch, slim teardrop shapes with defined tips, deep plum night background #231A33, seeds in muted crimson #C04A5A and deep wine #8E3140, one warm off-white highlight, no outline, no text, no gradient background, Stripe/Linear-grade restraint — not cute, not a heart, not a butterfly."
2. *Nightbloom hero:* "Abstract duotone botanical illustration, two pomegranate branches entering from opposite edges inclining toward each other, flat 2-layer vector shapes, rounded 1.75-weight line terminals, deep plum night canvas #231A33, accents #C04A5A and #B98A6E only, faint 6%-opacity Seljuk geometric lattice fragment behind, large empty space, calm and dignified, no people, no faces, no gradients, no 3D."
3. *Seed vessel:* "Low wide ceramic bowl in Anatolian çini silhouette holding glossy pomegranate seeds, flat vector illustration, 3 layers max, plum night background #231A33, bowl in #2E2344 with thin #453A5C rim line, seeds #C04A5A shading to #8E3140, one seed mid-fall above the rim, warm quiet premium mood, no sparkle, no cartoon."
4. *Lit Lattice icon exploration:* "App icon, eight-point Seljuk star aperture cut into a dark plum field #231A33, warm light glowing through from inside, sand #F3E7D7 to soft gold #D9A441 at center, two tiny seed silhouettes inside the glow, a lit window at night, flat vector, premium, discreet, no text."
5. *TikTok card mood:* "Vertical 9:16 dark editorial card, deep plum #231A33, a single line of large bold rounded sans-serif text centered, faint geometric mashrabiya texture, one small pomegranate-seed pair mark bottom corner, candlelight-warm minimalism, Calm-app quality, no stock imagery, no hearts."

**Build priority (serves the gates):** 1) TikTok question-card template system (G1 runs pre-launch, zero app changes). 2) Redrawn app icon + sign-in hero (first-impression surfaces, G2's invitee funnel). 3) Invite card + partner-preview art (the reluctant-husband activation hinge). 4) Vessel + reveal choreography + milestones (retention core, D7). 5) Store screenshots + landing page (submission requirements). 6) Paywall vignettes (G3 — meaningful only once premium has real contents).
