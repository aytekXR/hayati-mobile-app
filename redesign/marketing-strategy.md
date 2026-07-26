# Hayati — Go-to-Market & Growth Strategy

**Status:** Pre-launch blueprint. Every activity below is sequenced against the three validation gates in `README.md` — G1 (content virality), G2 (activation), G3 (monetization). Nothing in this plan spends money before G1 evidence exists, and nothing claims a feature the code does not ship. Brand facts (name, taglines, colors, principles) are taken verbatim from the brand direction and must not drift from the four sibling redesign documents.

**Hard prerequisites this plan assumes (call them out to the founder, again):**

1. **Analytics before any spend.** The app has zero instrumentation (no `firebase_analytics`, no Mixpanel). G2/G3 are unfalsifiable today. The funnel `install → signup → invite_sent → paired → q_answered → reveal_viewed → trial → paid` from `docs/architecture.md` §7 must be live before the first paid impression, pseudonymous, with no answer text in events.
2. **A domain.** One page unlocks four blocked things at once: universal links (tappable WhatsApp invites — today's `hayati://invite/<code>` scheme is dead text in chat apps), the AASA file, hosted privacy/support URLs (a store-submission requirement — `fastlane/metadata/*/privacy_url.txt` ships empty), and the landing page in §5.
3. **Native review.** All TR/AR copy is AI-drafted, review-pending (operator item 1). No AR asset ships publicly before the Gulf-dialect reviewer signs off. A single Arabic misstep converts "marriage companion" into "suspicious app on my spouse's phone."
4. **Trademark caution.** "Hayati" has a vape-brand collision and the mark search is pending (ADR-027). All launch assets lead with the two-seeds mark and the tagline, not the wordmark. Vetted fallbacks: İkimiz, Baynana, Mawadda, Roohi.

---

## 1. Positioning & competitive frame

**One-sentence position (canonical, use everywhere):**
For married and committed couples in Turkey, the Gulf, and the diaspora, Hayati is the private daily ritual for two — one question a day, each answer sealed until both have written theirs, in your own language and inside your own culture.

**Category we create:** *the private couple ritual.* We refuse the two adjacent categories:

| Frame | Who owns it | Why we refuse it |
|---|---|---|
| Dating / matchmaking | Muzz, Soudfa, Oolfa | They abandon users at the wedding. Positioning line: **"Hayati begins where Muzz ends."** Being mistaken for dating is fatal in the GCC — every asset must read married-coded. |
| Western couple apps | Paired (8M downloads), Flame, Agapé | They translate; we author. No native TR/Gulf-AR content, no discreet icon, no PIN-by-default thinking, per-person pricing. Our wedge: cultural authorship + radical privacy + **one subscription for both of you**. |
| Therapy / self-help | Lasting, BetterHelp | "Therapy is unthinkable socially" for P2. Hayati is a companion, not a clinic — warm, dignified, faith-compatible. Never use clinical vocabulary in marketing. |

**The enemy is not an app.** The enemy is *drift* — the slow slide into logistics-only marriage ("who picks up the kids"). Every campaign attacks drift, not competitors by name. Competitor comparison lives only in App Store keyword strategy and press FAQ, never in creative.

**Three proof points that carry every message (all shipped in code):**
1. **Sealed until you both answer** — the mutual reveal is server-enforced (`firestore.rules` `exists()` gate), not a UI trick. No peeking is a *fact*, not a promise.
2. **Private by design** — PIN + Face ID lock, discreet home-screen icon, quiet notifications, no feed, no strangers, ever (`app/lib/features/privacy_lock/`, `app/lib/features/settings/`).
3. **One subscription, both of you** — couple-scoped entitlements (ADR-015) attack Paired's most-complained-about per-person pricing.

**Defensive positioning rule:** if Paired localizes into Turkish/Arabic (recorded risk), our answer is depth, not speed alone — natively authored questions, Ramadan/Eid windows (ADR-026 machinery already shipped), register-aware tone, and the DV-aware privacy layer no translation pass can copy.

---

## 2. Target audience & personas

The installing partner skews female (feasibility §1) — **the buyer is usually her; the activation battle is him.** Every channel plan below optimizes for two conversions: (a) she installs, (b) he taps one link. The zero-signup partner preview (`partner_preview_screen.dart`) exists for exactly (b).

### P1 — Zeynep & Emre (Istanbul, 27/29, dating 2 years)
Secular, hyper-online, price-sensitive, playful. She finds us on TikTok; he joins because she asks over WhatsApp.
- **Channels:** TikTok TR (40.2M adult users — the G1 engine), Instagram Reels/Stories, couple-meme accounts, TR podcast ads later (İlişki/psikoloji podcasts), App Store search "sevgiliye sorular".
- **Message:** playful "do you really know me?" energy; ₺ lifetime tier matters (one-time-purchase culture — a UI concept the paywall still needs).
- **Caveat:** Turkey is Android-heavy and we are iOS-first (ADR-006). Treat TR results as directional until M6.5; do not scale TR paid spend before Android.

### P2 — Noura & Fahad (Riyadh, 31/34, married 5 years, two kids) — **the margin persona**
Drifting into logistics. Therapy is socially unthinkable; a private app is face-saving. iOS-heavy, high ARPU — **GCC must carry revenue** (≥50% of revenue by month 12 per feasibility).
- **Channels:** TikTok + Snapchat KSA (Snapchat is disproportionately strong in Saudi — add it to the G1 test matrix), Instagram, WhatsApp Status shares (the dominant Gulf sharing surface), Khaleeji family/marriage podcast sponsorships, App Store AR search.
- **Message:** dignified, modest-romantic, family-safe. Lead with privacy (PIN, discreet icon, "no algorithm ever sees your answers") and the ritual. Never neon-dating, never saccharine, no photographic couples/faces/embracing figures on any AR surface (hard brand rule).
- **Creator strategy:** married Khaleeji women creators speaking to women; never "couple influencers" performing intimacy on camera.

### P3 — Aylin & Karim (Berlin/London diaspora, 26/30, engaged, bilingual)
Pay EU prices, best evangelists, bridge both cultures.
- **Channels:** Instagram/TikTok diaspora creators (TR-German, Arab-British), Reddit (r/relationships adjacent, r/turkey, r/arabs — organic founder participation only), Product Hunt + EN tech press (this is the *only* persona PH reaches), EN App Store search.
- **Message:** "in your own language and culture, even far from home." Bilingual assets (EN headline, TR/AR question on the card) perform identity work — share-bait by design.

### P4 (secondary) — The Reluctant Husband (the invitee, all markets)
Not an acquisition target; an activation target. He experiences exactly three surfaces: the WhatsApp message, the partner preview, and the first reveal.
- **Channel:** the invite itself. Invest in it like an ad unit: branded invite card image for the share sheet (identity-safe, abstract Nightbloom art, no answer content), universal link, and — the single highest-leverage product ask from marketing — **restore the PRD F1 preview hook**: show today's question + the partner's sealed answer on the zero-auth preview. "Your wife already answered today's question. Answer yours to read hers" is the best ad we will ever write, and the endpoint's typed projection was designed to grow exactly this.

---

## 3. Brand messaging house

**Primary tagline (verbatim, everywhere):**
> One question a day, for two. (TR: Günde bir soru, ikiniz için. / AR: سؤال واحد كل يوم، لكما.)

**Alternate taglines (verbatim, by use):**
| Line | Use |
|---|---|
| The app you use with your partner — never to find one. | Category disambiguation: store description close, press boilerplate, PH, FAQ. |
| Five minutes a day, together. (TR: Günde beş dakika, birlikte.) | Time-cost objection handling: ads, onboarding, App Store promo text. |
| Life is more beautiful together. (AR: حياتي أجمل معًا) | AR-market warmth line: AR store listing, Eid campaigns. |
| What's between you stays between you. | Privacy campaigns, P2 creative, settings/lock marketing. |
| Every day you answer together, a seed. | Streak/motif line: product, social captions, streak-share cards. |
| Still getting to know each other. | P2 campaign line for long-married couples. |

**Value props (verbatim from direction; the six pillars of all copy):**
1. One question a day — a five-minute ritual that keeps you close, not another app demanding your attention
2. Sealed until you both answer — no peeking, no performing, no copying your partner's homework; the mutual reveal makes every answer honest
3. Yours in your own language and culture — questions authored natively in Turkish and Gulf Arabic (not translated), romance kept halal-appropriate, Ramadan and Eid woven in
4. Private by design — PIN and Face ID lock, a discreet home-screen icon, quiet notifications; what's between you two stays between you two, from family, from outsiders, from algorithms
5. One subscription, both of you — a single purchase unlocks Premium for the couple; no per-person tax on being together
6. A companion for marriage, not a matchmaker — no feed, no strangers, ever; Hayati begins where the wedding apps end

**Elevator pitch (30 seconds):**
"Hayati is a private daily ritual for couples in Turkey, the Gulf, and the diaspora. Every day you both get one question. You each answer alone — your partner's answer stays sealed until you've written yours — then both unfold together, and a pomegranate seed is added to a streak you grow as a couple. It's in your own language, written for your culture, locked behind your PIN, and one subscription covers you both. It's the app you use with your partner — never to find one."

**Tone rules (binding for every marketer and every asset):**
- Warm second person; a confidant, not a coach. Candlelight, not neon.
- Registers: TR informal-warm ("sen"), Gulf-AR formal-warm, modest-romantic, family-safe; EN neutral-warm. Legal/safety surfaces always respectful register.
- Radical honesty is the trust engine: never claim more than the code delivers. No "AI-powered insights," no fabricated testimonials, no inflated counts — ever.
- Never guilt, always invite. The lagging partner is courted, not shamed ("Your partner's answer unlocks when you answer"). Streak marketing celebrates the mercy day, never punishes the miss.
- DV-aware reticence extends to marketing: no "catch your partner" framing, no surveillance jokes, nothing that makes the lock a weapon.
- Frozen guarantee copy (consent, legal, coach disclaimer/help/paused, delete/couple-ended, sign-in footer) may be quoted but never reworded.
- Visual: Alert (#B04A3E / dark #D96C5F) never appears in marketing. Gold (#D9A441 dark / Brass #866112 light) only on premium/celebration. No faces or embracing figures in AR-market assets; the global launch system stays abstract (Nightbloom) — two-ness shown as paired forms: two seeds, two branches, two lit windows.

---

## 4. App Store listing strategy

### Name, subtitle, keywords

- **Name:** `Hayati — Couple Ritual` (EN) / `Hayati — Çift Ritüeli` (TR) / `حياتي — طقس يومي للزوجين` (AR). The suffix buys category keywords and disambiguates from the vape brand; keep the wordmark investment light until trademark clears. If Apple rejects "Hayati" as taken, the fallback names are pre-vetted and the seed mark carries continuity.
- **Subtitle (30 chars):** EN `One question a day, for two` (shipped, keep). TR `Günde bir soru, ikiniz için` (shipped, keep). AR `سؤال واحد كل يوم، لكما` — **the AR metadata directory does not exist yet (`fastlane/metadata/` has only `tr/` and `en-US/`); creating `ar-SA` is a launch blocker for Phase 3.**
- **Keyword directions** (100-char field; iterate with search-ads data):
  - EN: `couples,marriage,relationship,questions,daily,partner,love,streak,paired,intimacy,ritual` (current `keywords.txt` is close; add competitor term `paired`).
  - TR: `sevgili,eş,evlilik,ilişki,çift,soru,sorular,aşk,oyun,günlük` (capture "sevgiliye sorular" / "eşe sorulacak sorular" — huge organic TR query families).
  - AR: `زوجين,زواج,أسئلة,حب,علاقة,يومي,أزواج,عائلة` (avoid anything dating-adjacent like تعارف — actively negative-match it in Search Ads).
- **Promotional text** (updatable without review): rotate seasonally — Ramadan: "Ramadan questions for the two of you — written for the month, not translated into it."

### Screenshot storyboard (canonical eight-slot set; 6.9" 1320×2868 + 6.1" 1179×2556; light Paper #FAF3E8 background frames, device mockups on Night #231A33; captions Rubik 800 Latin / 700 Arabic in Plum Ink #2A2138; produce ×3 locales, AR fully RTL-mirrored — creative-assets §9.1 executes this table)

| Slot | Visual | Caption (EN / TR / AR) |
|---|---|---|
| 1 | Two-seeds mark + paired home showing today's question in the new Question type style (28/300) | "One question a day, for two." / "Günde bir soru, ikiniz için." / "سؤال واحد كل يوم، لكما." |
| 2 | Paired home, partner slot **locked** state, lock glyph prominent | "No peeking. Answers stay sealed until you've both written." / "Dürüst cevaplar: ikiniz de yazana kadar kilitli." / "لا اطّلاع مسبقًا — يبقى الجواب مغلقًا حتى تكتبا معًا." |
| 3 | The reveal — two answer cards unfolded toward each other, soft-unfold mid-frame | "Then both answers unfold together." / "Sonra iki cevap birlikte açılır." / "ثم يُكشف الجوابان معًا." |
| 4 | Streak seed vessel with seeds + gold milestone particle moment | "Every day you answer together, a seed." / "Birlikte cevapladığınız her gün bir tane." / "كل يوم تجيبان معًا، حبّة رمان." |
| 5 | Lock screen + discreet icon toggle side by side | "What's between you stays between you. PIN, Face ID, a discreet icon." / "Aranızda kalır. PIN, Face ID, sade simge." / "ما بينكما يبقى بينكما — رمز PIN وأيقونة محايدة." |
| 6 | AR paired home, full RTL, Arabic question — shown in *all* locales' set as slide 6 (TR/EN sets show TR/EN respectively; AR set shows register depth instead) | "In your language, written for your culture." / "Kendi dilinizde, kendi kültürünüzde." / "بلغتكما، ومن ثقافتكما." |
| 7 | Paywall entitled view, gold premium mark; two phones, one badge | "One subscription. Premium for both of you." / "Tek abonelik, ikiniz için Premium." / "اشتراك واحد يشمل كليكما." |
| 8 | Partner preview: "Aylin invited you" + sealed answer card | "Start tonight. Invite takes one tap." / "Bu akşam başlayın. Davet tek dokunuş." / "ابدآ الليلة — الدعوة بلمسة واحدة." |

Slide 8's "one tap" is only honest after universal links ship — sequence accordingly, or caption it "Start tonight."

### Feature graphic (Play Store, M6.5) & video

- **Play feature graphic (1024×500):** Night #231A33 canvas, low-opacity lattice texture, two seeds inclining toward each other, primary tagline in the market language. No wordmark dominance (trademark caution). Prepare now; ship at Android launch — Turkey is Android-heavy and Play is where TR scale actually lives.
- **App preview video (~20s, no faces, on-device capture + motion graphics, works muted, ×3 locales):**
  1. 0–2s — Night screen, a single seed drops. Text: "Every marriage drifts a little."
  2. 2–5s — Paired home; today's question types itself on. Text: "One question a day."
  3. 5–9s — She answers; partner slot shows the lock: "Your partner's answer unlocks when you answer."
  4. 9–13s — The reveal: both cards soft-unfold toward each other; a seed drops into the vessel; single gold particle. Text: "Sealed until you both answer."
  5. 13–16s — Quick cut: PIN lock screen → discreet icon toggle. Text: "Private by design."
  6. 16–20s — Two seeds mark + "One question a day, for two." + "Free to start. One subscription for both."

---

## 5. Landing page (single page at the new domain; doubles as universal-link fallback and AASA host)

Paper #FAF3E8 canvas, Plum Ink #2A2138 text, Pomegranate #C04A5A accents, Nightbloom illustration, Rubik. TR/AR/EN language switcher; AR fully RTL. The page's second job: when an invite universal link opens on a phone without the app, this page shows "Aylin invited you" (zero-auth `invitePreview` endpoint) + App Store button — closing today's biggest funnel hole.

1. **Hero.** H1: "One question a day, for two." Sub: "A private daily ritual for couples — your answers stay sealed until you've both written, then unfold together. In Turkish, Arabic, or English." CTA: "Download on the App Store" + secondary "See how it works". Visual: device on Night showing the reveal; two seeds mark.
2. **How it works (3 steps).** "Ask — every day, one question for you both." / "Answer alone — no peeking, no performing." / "Unfold together — and add a seed to your streak." Animated soft-unfold on scroll (reduce-motion respected — practice what the app preaches).
3. **Privacy block (P2's section; place high).** H2: "What's between you stays between you." Bullets, all code-true: 6-digit PIN + Face ID lock; discreet home-screen icon; quiet notifications that never show the message; no feed, no strangers, ever; primary data stored in EU-region servers — and where that isn't true, we say so plainly (link the privacy one-pager; the consent copy's own words are "We do not claim all of your data sits in Europe, because it does not."); export and delete your data any time. Micro-line in the honesty voice: "We built Hayati as if someone else might pick up your phone. Because sometimes they do."
4. **Culture block.** H2: "Written for your culture, not translated into it." Copy: questions authored natively in Turkish and Gulf Arabic; Ramadan and Eid woven in; romance kept halal-appropriate. Show the same question card in TR/AR/EN.
5. **Pricing block.** H2: "One subscription. Premium for both of you." Free-forever line verbatim from the app: "Your daily question and streak stay free, always." Premium: every question pack + the coach, 7-day trial.
6. **Social proof.** Pre-launch: **no fabricated testimonials** (honesty rule). Use founder line ("Built by a couple, for couples"), press logos when earned, and post-launch real review pulls. Until then this section is the G1 content wall: embedded top-performing question cards.
7. **FAQ.** "Is this a dating app?" — "No. Hayati is the app you use with your partner — never to find one." / "Can my partner see my answer before answering?" — "No — sealed by our servers, not by politeness." / "Is it appropriate for our family values?" / "What does Premium include, and do we both pay?" / "What data do you store, and where?" / "Is the coach therapy?" — "No. It's here for warmth and reflection, not medical or psychological care."
8. **Footer CTA.** "Start tonight. The first question is waiting." App Store badge, language switcher, Privacy Policy / Terms (the hosted copies the store listing needs), contact, KVKK/PDPL notices.

---

## 6. Launch strategy

### Phased plan (gate-governed)

| Phase | Gate served | Actions | Exit criteria |
|---|---|---|---|
| **0. Content validation (now; zero app dependency)** | G1 | Run the 60-slideshow TikTok test from `content/` questions exactly as README G1 defines it: **30 TR / 30 AR across 6 fresh accounts** (three per language), 2/day/account for 3 weeks. An EN track runs alongside for P3/Product Hunt supply but does not bear the gate. Simultaneously: analytics slice, domain + landing waitlist, native review, APNs slice. | README G1 verbatim: ≥3 posts >100K views **from <5K-follower accounts, per language (TR and AR)** — or iterate hooks 2 more cycles before any spend. |
| **1. Founder dogfood + friends-and-family TestFlight** | G2 | 20–30 real couples (TR-weighted). Watch the funnel numbers, especially invite→paired and D7 couple retention. Fix invite friction (universal links, invite card). | ≥40% paired ≤7d, D7 couple retention ≥25% directionally. |
| **2. Soft launch — Turkey iOS + diaspora storefronts (DE/UK/NL/FR)** | G2→G3 | Public App Store, TR+EN listings, organic TikTok engine at full cadence, small Apple Search Ads on brand + "sevgiliye sorular" cluster. RevenueCat live, paywall on, first real purchases. Diaspora storefronts monetize at Western prices with the same build — free ARPU. | 4+ paywall weeks of G3 data: trial→paid ≥30%, install→paid ≥2%. |
| **3. GCC launch (KSA, UAE, KW, QA)** | G3 (revenue) | `ar-SA` metadata live, AR screenshot set, Gulf-reviewed copy, PDPL items complete, Khaleeji creator seeding, Snapchat KSA added. Timed to land ≥6 weeks before Ramadan so the Ramadan campaign hits an installed base. | GCC revenue share trending toward the ≥50% month-12 target. |
| **4. EN moment — Product Hunt + press** | Awareness | See below. Android (M6.5) unlocks TR scale; revisit TR paid. | — |

### Product Hunt (Phase 4 — deliberately last: PH reaches P3 and press, not P1/P2)

- **Name/tagline:** "Hayati — One question a day, for two."
- **Description:** "A private daily ritual for couples. Each of you answers today's question alone — sealed until you've both written — then both unfold together and your shared streak grows a pomegranate seed. Native Turkish, Gulf Arabic, and English. PIN lock, discreet icon, no feed, no strangers. One subscription covers both of you."
- **First comment (founder, draft):** "Hi PH — we're a couple, and we built Hayati for couples like our parents' friends: people who would never see a therapist but are slowly drifting into logistics-only marriage. Three things we're proud of: (1) the answer-sealing is enforced by our security rules, not the UI — you genuinely cannot peek; (2) everything is written natively in Turkish and Gulf Arabic by people who live those cultures, because translated intimacy isn't intimacy; (3) privacy is the product — PIN + Face ID lock, a discreet home-screen icon, and answers no algorithm ever reads, because in our markets other people sometimes hold your phone. Free forever for the daily question and streak; one subscription covers both partners. Ask us anything — especially the hard cultural questions."
- **Gallery:** 6 assets — hero card (tagline + seeds), 20s preview video, reveal sequence GIF, privacy suite frame, trilingual question card (identity work — the PH crowd shares this one), pricing card ("no per-person tax on being together").
- **Hunter strategy:** self-launch under the founder account (authenticity beats reach for a couples product), Tuesday 00:01 PT; pre-brief 20–30 diaspora-founder friends for genuine first-hour comments (never vote rings); founder online for 12 hours; prepared answers for the three predictable hard questions: data privacy (point to export/delete + EU-region primary storage and its honestly-disclosed exceptions — never overclaim), "is this halal-washing?" (no — it's authorship), and the DV question (point to the biometric warning + actor-unattributed design, seriously and without marketing gloss).

### Press kit (hosted at /press)

Fact sheet (one page: what/who/where/pricing/gates-honest traction); founder story ("built by a couple, for couples between two cultures"); positioning FAQ (incl. "not a dating app," "not therapy"); screenshot set ×3 locales; two-seeds mark + wordmark-light logo files, color (#231A33, #C04A5A, #F3E7D7, #FAF3E8) and type sheet; product B-roll (reveal, lock, discreet icon — screen capture only); the privacy one-pager ("What Hayati can't see," including the honesty line "We do not claim all of your data sits in Europe, because it does not."); embargo-ready launch release; contact. Target press: TR tech (Webrazzi), Gulf lifestyle/tech (mid-tier first), diaspora media, EN app press at PH time.

---

## 7. Social content engine

**System:** the question bank IS the content engine (G1 design). Every authored question ships as a slideshow card: Night #231A33 canvas, question in Rubik (800 Latin / 700 Arabic), seed motif, small mark. No faces anywhere in the launch system — abstract works in every market and is the only system Gulf-safe by default. Account structure per README G1: six fresh gate accounts (three TR, three AR — the gate is measured from <5K-follower accounts) plus one EN track that feeds P3 and Product Hunt but does not bear the gate; 2 posts/day per account during G1.

### TikTok / Reels concepts (hook + beats)

1. **The Question Slideshow (the G1 workhorse).** Hook (text-on-screen): "Sorular evliliğinizi kurtarmaz. Ama bu soru bir şeyi başlatır." (TR) / "سؤال واحد قد يغيّر مساء اليوم" (AR). Beats: 5 slides — one question per slide from the pack, escalating depth; final slide: seeds mark + "One question a day, for two." + "Answer tonight — link in bio." Produce 60 variants; this alone satisfies the G1 test format.
2. **"Answer before you look."** Hook: "Don't open this with your partner next to you." Beats: one deep question → beat of silence → "Now ask them. Compare answers." → mark. Engineered for tags-a-partner comments.
3. **The Sealed Envelope.** Hook: "Why you can't peek in Hayati." Beats: screen recording — she answers, partner slot shows the lock ("Your partner's answer unlocks when you answer") → the unfold → seed drop. Product truth as content; the reveal moment is inherently satisfying to watch.
4. **"My husband thinks he knows me" (TR playful).** Hook: "Eşim beni tanıyor sanıyor. Bakalım." Beats: question card → "his guess" text → "my actual answer" text → gap or match → "Her gün bir soru. İkiniz için." No faces needed — text-driven.
5. **The Drift (P2, dignified).** Hook: "When did 'how was your day' become 'did you pay the bill?'" Beats: slow text slides naming drift in respectful register → "Five minutes a day, together." → mark. AR version reviewed for register before posting.
6. **The Discreet Phone.** Hook: "This app is designed for phones other people pick up." Beats: screen recording — discreet icon on home screen → PIN lock → quiet notification ("shows that something arrived, not what") → "What's between you stays between you."
7. **The Streak Vessel.** Hook: "We've answered together 34 days in a row." Beats: seed vessel filling time-lapse → mercy-day moment ("miss a day; a weekly grace day keeps a good run alive") → "Every day you answer together, a seed."
8. **Ramadan nights (seasonal).** Hook: "بعد الإفطار، سؤال" ("After iftar, a question"). Beats: Ramadan-window question cards (ADR-026 machinery; requires the ~30 tagged questions authored) → "Written for the month, not translated into it."
9. **"Still getting to know each other" (P2 campaign line).** Hook: "Married 9 years. Learned something new about him last night." Beats: question card → "his answer surprised me" → invitation to try tonight. Voice: warm, never confessional oversharing.
10. **One Subscription, Two People.** Hook: "Couple apps charging BOTH of you is wild." Beats: receipt-style graphic (them: ×2; Hayati: ×1 "covers you both") → "No per-person tax on being together." EN/TR only; AR keeps pricing content quieter.
11. **The Reluctant Husband (activation content).** Hook: "How I got my husband to actually do this with me." Beats: the code-first WhatsApp invite on screen ("I picked an app for us — one question a day, just for the two of us…" — product-copy's rewritten share message) → his three taps → first reveal → "the invite takes one tap." Doubles as a tutorial for the hardest funnel step.
12. **Founder build-in-public (EN).** Hook: "We're building the anti-dating app." Beats: 30s founder story — Muzz ends at the wedding; we begin there → gate scoreboard honesty → follow for the journey. Feeds PH and press.

### Instagram concepts (5)

1. **Carousel — "7 questions for your 7th year":** one question per slide from packs; save/share-optimized; TR + AR variants.
2. **Story polls:** "Could you answer this about your partner?" question card + poll sticker; the interaction primes DM shares.
3. **The Reveal loop:** 15s screen-capture of the unfold + seed drop as a Reel with ASMR-quiet sound; caption "The reveal is the product."
4. **Quote cards in the honesty voice:** shipped copy as brand proof — "No peeking, and no pressure to perform: just a moment that belongs to the two of you." Sand #F3E7D7 on Night.
5. **WhatsApp-Status-sized question cards (9:16, downloadable):** posted explicitly for re-share to Status — the dominant GCC/TR sharing surface; each carries the mark and nothing trackable (identity-safe by design).

### X posts (5 drafts, EN founder account)

1. "Every matchmaking app abandons you at the wedding. We're building the app that begins there. One question a day, for two — sealed until you both answer. 🌱"
2. "Our answer-reveal isn't a UI state. It's a Firestore security rule: your partner's answer literally cannot be read until yours exists. Honesty, enforced by the database."
3. "Designed for a reality Western couple apps ignore: sometimes other people hold your phone. PIN lock. Discreet icon. Notifications that never show the message. Privacy is the feature."
4. "We wrote our Turkish and Arabic questions natively, then translated to English — not the other way around. 'Culturally authored, not translated' is our whole moat."
5. "Pricing decision: one subscription covers both partners. Charging couples twice to be a couple never sat right with us."

### LinkedIn angle

Founder narrative, monthly cadence: (1) the localization-arbitrage thesis (Paired ×8M proves the mechanic; Arabic stores have no marriage companion); (2) gate-governed building — kill criteria in public; (3) privacy engineering for family-phone cultures as product strategy; (4) later: the B2B premarital seed (v2 roadmap) — imam/officiant programs and employer wellness in the Gulf, planting enterprise curiosity early without promising a product.

---

## 8. Email campaigns

**Constraint:** email exists only for Apple/Google sign-ups (phone OTP yields none) and landing-page waitlist. All emails must be content-free about answers (no question text echoing back user activity), respectful register, one CTA each, TR/AR/EN localized, AR RTL templates.

### Waitlist (pre-launch, from landing page)
- **W1 — subject: "You're on the list ❤️ Here's what Hayati is."** Body: one-paragraph pitch, one question card image, "forward this to your partner" CTA (pre-launch virality).
- **W2 (launch day) — "The first question is waiting."** App Store link, "start tonight" framing.

### Onboarding sequence (trigger: account created)
| Send | Subject (EN / TR) | Body outline |
|---|---|---|
| Day 0, +1h | "One small ritual, starting tonight" / "Bu akşam küçük bir ritüel başlıyor" | Welcome, the 3-step ritual, single CTA: answer today's question. P.S. in honesty voice: "Your daily question and your streak stay free, always." |
| Day 1 (if unpaired) | "Hayati is better together" / "Hayati birlikte daha güzel" | The invite is one tap; screenshot of the partner preview ("they'll see your name and today's question"); CTA: send your invite. Never guilt: "whenever you're ready." |
| Day 3 | "Made for phones other people pick up" / "Telefonunuzu eline alanlar için tasarlandı" | Privacy spotlight: PIN, Face ID, discreet icon, quiet notifications — with honest limits ("the app's name still appears under the icon"). CTA: set up your PIN. Serves P2 trust + closes the buried-in-settings gap marketing-side. |
| Day 6 (if unpaired) | "Your seven days, and what's next" / "Yedi günün ve sonrası" | Solo week is ending; your answers will be waiting when you pair. CTA: invite. |
| Day 10 (if paired) | "You two have a rhythm" / "İkinizin bir ritmi var" | Streak/seed story + mercy-day explainer ("miss a day; a weekly grace day keeps a good run alive"). Soft premium mention: packs + coach, one subscription for both. |

### Win-back sequences
- **Unpaired at day 14 — "Should we hold your spot?"** Honest, warm: the ritual needs two; here's the one-tap invite again; here's what the preview shows them. Final send day 30, then stop — never nag (brand rule).
- **Paired-but-lapsed (no mutual answer 7 days) — "The question will be there when you are."** Zero guilt, explicitly forgiving: "Streaks in Hayati forgive — that's what the grace day is for." One CTA: tonight's question. Second send day 14 with a fresh question card as the hook, then stop.
- **Trial-ended-no-convert — "Everything free is still yours."** Reaffirm the free promise verbatim, list what Premium adds (packs, coach — only once these are real, per honesty rule), single reminder of one-subscription-covers-both. One send only.

---

## 9. Blog / SEO article ideas (landing-page blog; TR and AR articles are the priority — EN queries are red-ocean)

| # | Article | Target query (language) |
|---|---|---|
| 1 | 100 eşinize sorabileceğiniz derin sorular | "eşe sorulacak sorular" (TR — huge volume; the article is the product) |
| 2 | Sevgiliye sorulacak 50 soru: yüzeyseli geçin | "sevgiliye sorular" (TR) |
| 3 | أسئلة للزوجين لتعميق العلاقة | "أسئلة للزوجين" (AR) |
| 4 | Evlilikte iletişim nasıl güçlenir: günde 5 dakika kuralı | "evlilikte iletişim" (TR) |
| 5 | كيف تحافظ على التواصل مع زوجتك بعد سنوات الزواج | "التواصل بين الزوجين" (AR) |
| 6 | Questions to ask your spouse every day (and why one is enough) | "questions to ask your spouse" (EN) |
| 7 | أسئلة رمضانية للأزواج: ٣٠ ليلة، ٣٠ سؤالًا | "أسئلة رمضان" + couples (AR, seasonal — publish 6 weeks pre-Ramadan) |
| 8 | Uzak mesafe değil, aynı evde mesafe: rutin kaçınılmaz mı? | "evlilikte monotonluk" (TR — the drift article) |
| 9 | The Paired alternative for Turkish and Arab couples | "Paired app alternative" (EN — competitor capture) |
| 10 | Telefonunuza kimler bakıyor? Çift uygulamalarında mahremiyet rehberi | "uygulama kilidi" / privacy (TR — the privacy moat as content) |
| 11 | خصوصية تطبيقات الأزواج: ماذا يجب أن تعرف | couples-app privacy (AR) |
| 12 | İlk yıl evlilik soruları: birbirinizi hâlâ tanıyorsunuz | "yeni evlilere tavsiyeler" (TR) |
| 13 | What is a couple ritual? The five-minute marriage habit | "couple rituals" (EN — category creation) |

Format rule: every listicle embeds real pack questions with beautiful cards (shareable = linkable), ends with the primary tagline and a store CTA, and doubles as G1 content supply. Articles 1/3/7 are the priority — they are the SEO mirror of the TikTok engine.

---

## 10. Promotional campaigns & seasonal moments

- **Ramadan (the owned annual moment).** The only couples app with a real Ramadan mode (ADR-026 Hijri windows shipped; requires ~30 tagged TR/AR questions authored + adjusted notification windows). Campaign: "بعد الإفطار، سؤال" / "İftardan sonra bir soru" — 30 nights, 30 question cards on social, one/night; Ramadan article live 6 weeks prior; promo text swapped. Rule: reverent, never commercial-loud; Umm al-Qura vs. local moon-sighting can differ ±1 day — campaign copy says "Ramadan nights," never hard dates.
- **Eid al-Fitr & Eid al-Adha.** "حياتي أجمل معًا" gift framing: one subscription covers both of you — Premium as an Eid gift to the marriage. Gold (#D9A441) celebration moment in creative — the sanctioned gold use.
- **Sevgililer Günü (Feb 14, TR + EN only — never AR).** Anti-cliché angle: "Çiçek solar. Soru kalır." ("Flowers fade. The question stays.") 14-day question countdown on TR social.
- **New Year (all markets; `new_year` window exists in code).** "365 questions ahead. Start with one." Year-in-seeds recap concept when streak history allows an identity-safe share card.
- **Wedding season (May–Sep, TR + diaspora).** "Begin your marriage with a ritual" — engagement/newlywed targeting; the İkimiz-adjacent P3 moment; partner with wedding-adjacent TR creators.
- **TR lifetime-tier promotion (post-G3).** ₺2,499 lifetime speaks to TR one-time-purchase culture (feasibility pricing); needs the paywall UI concept built first — flag to product.
- **Launch promo discipline:** no fake urgency, no "50% off forever" games — restraint reads premium, and honesty is the interface. The only launch offer is the built-in 7-day trial, presented exactly as the paywall does.

---

## 11. Four-week content calendar (Phase 0: the 3-week README G1 test + a verdict/remix week; all organic, zero spend)

Cadence: TikTok 2/day per account (six G1 accounts: 3 TR / 3 AR, plus the non-gate EN track), IG 3/week, X 2/week (EN founder), 1 blog/week. AR posts publish only after Gulf-reviewer sign-off. Metrics reviewed Fridays against G1 (≥3 posts >100K per language, from <5K-follower accounts — README verbatim). Weeks 1–3 are the gate window; week 4 is verdict, remixes of proven hooks, and Phase 1 prep.

| Week | Mon | Tue | Wed | Thu | Fri | Weekend |
|---|---|---|---|---|---|---|
| **1** | TikTok: Question Slideshow TR #1–2, AR #1–2, EN #1–2 (daily throughout — listed once). IG: carousel "7 soru". Blog: article #1 (TR sorular). | TikTok: Sealed Envelope (product capture, all langs). X: post 1 (thesis). | TikTok: slideshows. IG Story: poll sticker card. | TikTok: "Answer before you look" TR/EN. | TikTok: slideshows. X: post 2 (security-rule honesty). Metrics review. | Slideshow reruns of top hooks; WhatsApp-Status downloadable card drop. |
| **2** | TikTok: The Drift (AR, reviewed) + TR variant. IG: Reveal loop Reel. Blog: article #3 (AR أسئلة). | TikTok: slideshows. X: post 3 (privacy). | TikTok: Discreet Phone (all langs). IG Story: privacy Q&A sticker. | TikTok: "My husband thinks he knows me" TR. | TikTok: slideshows. Metrics review — kill bottom-quartile hooks, double top hooks. | Status card drop #2. |
| **3** | TikTok: Streak Vessel + slideshows. IG: honesty quote card. Blog: article #4 (evlilikte iletişim). | TikTok: slideshows. X: post 4 (culturally authored). | TikTok: Reluctant Husband tutorial TR/EN. IG: carousel AR (reviewed). | TikTok: "Still getting to know each other" AR/TR. | TikTok: slideshows. Metrics review. | Founder build-in-public #1 (EN). |
| **4** | TikTok: best-performing format ×3 remixes per language. IG: Reveal loop v2. Blog: article #8 (drift TR). | TikTok: slideshows. X: post 5 (pricing). | TikTok: One Subscription (TR/EN). IG Story: poll. | TikTok: slideshows + new hook experiments from comment mining. | **G1 verdict review:** per-language views table vs. gate; decide iterate/proceed/kill per README criteria. | LinkedIn: thesis post #1; prep Phase 1 TestFlight brief. |

**Operating rules for the month:** every post's comment section is mined for question ideas (audience-sourced content feeds the bank); every asset carries the seed mark, not the wordmark; nothing links to the app until TestFlight exists — bio links go to the landing waitlist; and the whole month runs before a single lira/riyal of paid spend, because that is what G1 is for.

---

*Cross-references: product truth in `docs/prd.md`, `docs/feasibility-report.md`, `docs/operator-expected.md`; visual constitution in `docs/frontend-brandkit.md` + the sibling redesign documents; copy families that may never be reworded in ADR-023/025. When this document and the code disagree, the code is right and the marketing claim comes out.*
