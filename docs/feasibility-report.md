# Feasibility Report — Hayati

**Date:** 2026-07-08 · **Status:** Approved with gates · **Verdict: GO WITH CAUTION**

---

## 0. The brief, challenged

The instruction was "copy an already-working app" — the reference being Flame (couples daily-ritual app: 250K downloads, 50M organic TikTok views, $3K→$10K MRR in 8 months, ~1% conversion from organic social, grown via 100–150 test videos/day at ~$1/UGC video).

A founder's first duty is to interrogate the instruction, so: **what exactly is worth copying, and what is not?**

- **Worth copying:** the *mechanic* (daily question → mutual reveal → streak → AI coach paywall) and the *distribution system* (volume short-form testing under the VSC framework). Mechanics and business models are not protected IP. This is the Rocket Internet playbook applied to a category with a proven US/UK incumbent (Paired) and zero localized challenger.
- **Not copyable:** Flame's or Paired's name, question banks, copy, assets, or code. All content must be original and — critically — *culturally authored*, not translated. Translated intimacy content reads as foreign; this is precisely where clones fail and where our moat lives.
- **What must change:** positioning. In the GCC, "couples app" flavored like a Western dating-adjacent product is dead on arrival. Repositioned as a *marriage companion* — private, dignified, faith-compatible — it aligns with the culture rather than fighting it.

So the honest framing: this is not a copy. It is a **localization arbitrage on a twice-validated mechanic**, with the distribution engine as the actual product.

## 1. First-principles interrogation

**Does this solve a painful problem?** Yes. Relationship drift is universal; couples therapy is expensive, scarce, and — in Turkey and the GCC — heavily stigmatized. An app is private, cheap, and face-saving. Paired's independent evaluation (Open University / University of Brighton) found a 36% relationship-quality increase in 3 months, so the category has evidence, not just vibes.

**Willingness to pay?** Proven in the West (Paired: US-only Sensor Tower estimates of roughly $200K/month on iOS plus ~$100K/month on Google Play; 8M downloads). Proven-adjacent in Arabic: matchmaking apps (Soudfa: 10M+ members; Muzz: 800K marriages claimed) monetize Arab users on subscriptions today. Unproven for *this category* in TR/AR — that is Gate 3.

**Daily habit?** By construction. The daily question with mutual reveal is a variable-reward loop with a built-in accountability partner who shares your bed.

**Subscription business?** Yes — content depth + AI coach + couple features gate naturally.

**Network effects?** Micro (pair-level lock-in: leaving means abandoning your shared streak, timeline, and answer archive — a two-person network with real switching costs). Not macro; do not pretend otherwise.

**Viral loops?** Two: (a) structural — the product is unusable alone, so every activated user recruits ~1 partner; (b) content — shareable quiz results and streak cards sized for WhatsApp Status, the dominant sharing surface in both markets.

**Emotional trigger?** The strongest ones available: love, guilt, fear of drift, delight of being known.

**Flirting?** Yes — strictly *intra-couple*. A "spice" mode between spouses is desirable, defensible, and in Islamic framing actively virtuous. Stranger-flirting is rejected outright: it would destroy the trust positioning, trigger store/regulator risk in the GCC, and turn us into the 40th Arabic matchmaking app. Full reasoning in `prd.md` §Social Layer.

**AI opportunity?** Yes: coach personas (relationship coach, date-night planner, gift genie, spice mode), auto-generated localized question packs, and — internally — AI-generated slideshow content for the growth engine.

**Gamification?** Streaks (couple-shared, loss-aversion doubled), pomegranate-seed progression, percentile cards ("more consistent than 92% of couples"), challenges.

**Creator economy?** Deferred to v2: licensed counselors/hocas selling question packs. Real option, wrong year.

**B2B?** Deferred but real: premarital programs (GCC states run marriage funds and family-cohesion initiatives under Vision 2030-type agendas), wedding-industry partnerships, corporate wellness. Log it, ignore it until v2.

**Legal risks?** KVKK (TR) and PDPL (KSA) treat relationship/intimacy data as sensitive; AI coach must carry non-therapy disclaimers and crisis-redirect logic; spice mode forces a 17+/18+ rating and must be region-flaggable. All handled in `architecture.md` and `prd.md`.

**Religious/cultural considerations?** Central, not peripheral. Positioning as marriage-strengthening; Ramadan mode (gratitude/spiritual prompts, adjusted notification windows); no photographic intimacy in AR marketing; discreet app icon + PIN lock (shared-phone reality); dual-tone content (Turkish secular register vs. Gulf-respectful register) — same engine, different packs.

**Gender differences?** Assumption (flagged): the installing partner skews female, consistent with the relationship-app category; the invite flow must therefore be optimized for "get a reluctant husband to tap one link" — zero-signup preview for the invited partner, value visible before account creation.

**Localization as competitive advantage?** It is the *entire* advantage. See §3.

**Category leader potential?** In "Arabic/Turkish marriage companion" — yes, because the category has no leader. Globally — no, and we won't pretend.

## 2. Market sizing

All figures below distinguish **sourced data** from **labeled assumptions**.

**Category anchor (sourced):** Paired, the category leader, shows US-only estimates around $200K/mo (iOS) + $100K/mo (Google Play) per Sensor Tower, with 8M lifetime downloads and a Google Play Award. Flame reached $10K MRR / 250K downloads in 8 months as a solo-founder operation. The category supports both a venture-scale leader and profitable indie players.

**Audience (sourced):**
- Turkey: 40.2M TikTok users aged 18+ (61.6% of all Turkish adults, DataReportal Digital 2025); 58.5M social media users; users average 7h13m/day online.
- Arabic markets: Egypt 41.3M, Iraq 34.3M, Saudi Arabia 34.1M TikTok users — three of the largest TikTok countries in MEA.
- GCC app economy: downloads grew 2.6% YoY in Q2 2025 vs 0.5% globally; MENA accounts for ~10% of global app traffic and revenue; Saudi app/digital spending exceeded $4.5B (2023) growing ~15%/yr; Ramadan and salary cycles drive predictable engagement spikes.

**Competitive whitespace (sourced):** Arabic app stores are crowded with *pre-marriage* apps — Soudfa (10M+ members), Muzz (800K marriages), Oolfa, buzzArab, Ahlam — all matchmaking. None serve the couple *after* the wedding. Paired exists in Arabic stores but with English-first content and per-person pricing that draws public complaints in its own reviews. Turkey: no notable localized couples app found. **The post-nikah category is empty in both languages.**

**TAM (assumption, reasoned):** global couples-app category plausibly $50–100M/yr gross today (extrapolating Paired's US estimates to its global footprint plus the long tail), inside a much larger relationship-wellness market.

**SAM (assumption, reasoned):** smartphone-owning couples aged 18–45 open to a relationship app: TR ~4M couples, GCC (nationals + resident expats) ~2.5M, wider Arabic-speaking + diaspora ~6M → ~12.5M couples. At a blended realistic wallet of $8–20/couple/yr → **SAM ≈ $100–250M/yr**.

**SOM (target, 3-yr):** 0.3–0.6% of SAM → **$0.6–1.2M ARR**. Year-1 target mirrors Flame's proven trajectory: ~70K installs, ~1,700 paying couples, **$7–9K MRR by month 10–12**.

## 3. Turkey analysis

- **Payment habits & pricing:** high price sensitivity, lira volatility, but store-billed subscriptions are frictionless and the subscription economy (streaming, delivery) has normalized recurring payments among under-40s. Regional store pricing makes TR tiers cheap in USD terms — accept it; Turkey's job is *volume, content, and testing velocity*, not margin.
- **Demographics:** young, hyper-online (7h+/day), enormous relationship-content consumption on TikTok/Instagram ("sevgiliye sorular", couple tests are established viral formats).
- **Cultural:** dual-register market — secular metropolitan couples tolerate playful/flirty tone; conservative Anatolian couples need the respectful register. Content packs must ship in both tones behind one product.
- **Legal/privacy:** KVKK compliance (consent, data-subject rights, deletion); avoid storing anything beyond what features require.
- **Growth channels:** TikTok (40.2M adults), Instagram Reels, WhatsApp Status sharing; UGC creator cost is low in TR/Egypt, matching Flame's ~$1/video economics.
- **Founder-market fit:** founder is Istanbul-based — native content judgment, local creator network, TR-first soft launch is the obvious move.

## 4. GCC / Arabic analysis

- **Localization:** RTL is a first-class engineering requirement, not a patch (`architecture.md`). Content in MSA with a light Gulf register for v1; dialect packs (Egyptian, Levantine) later. Arabic *authored*, never translated.
- **Monetization:** this is the margin market. High ARPU, high iOS share, store billing ubiquitous, Vision-2030-era consumers spend on lifestyle/wellness apps. Premium pricing tier (see §6).
- **Social norms & sensitivity:** market as a *marriage* app; imagery abstract (no embracing photography); spice mode text-only, opt-in, discreet, and remotely region-flaggable; discreet icon + PIN lock as headline privacy features. Strengthening marriage aligns with explicit state family agendas — tailwind, not headwind.
- **Seasonality:** Ramadan is the single biggest content/product moment of the year (sourced: GCC engagement spikes around Ramadan). Ship Ramadan mode before the first Ramadan post-launch.
- **Growth:** Saudi TikTok (34.1M) + Egypt (41.3M) as the content wedge; Gulf-dialect creator UGC; diaspora (EU/US Arabs and Turks) monetizes at Western prices for free.
- **Risk:** app-store or regulator objection to intimacy content → mitigation: default-off, text-only, 17+ rating, Remote Config kill-switch per storefront.

## 5. Competition

| App | Position | Weakness we exploit |
|---|---|---|
| Paired | Category leader, EN-first | English content, per-person pricing (user complaints in reviews), zero cultural adaptation |
| Flame | Indie validator of the playbook | Same — EN-only, no TR/AR presence |
| Agapé / Lasting / Evergreen | Therapy-flavored US apps | Clinical tone, no localization |
| Between (KR) | Couple messenger, Asia | Utility not ritual; no TR/AR content |
| Soudfa / Muzz / Oolfa (AR) | Matchmaking giants | **They end at the wedding — we begin there.** Also proof Arab users pay subscriptions for relationship tech |

## 6. Monetization & unit economics

**Model:** freemium subscription. Free = 1 question/day + streak. Premium = full packs, AI coach, quizzes, spice mode, timeline. **One subscription unlocks both partners** — directly attacks Paired's most-complained-about policy and matches the category's emerging best practice.

**Pricing (assumption, to be A/B'd):** TR ₺169.99/mo, ₺999.99/yr, lifetime ₺2,499 (TR only — one-time purchase culture). GCC SAR 37.99/mo (~$10), SAR 249.99/yr (~$67). Diaspora/US $9.99/mo.

**Funnel assumptions (labeled; calibrated to Flame's ~1% and category norms):** install→signup 65% · signup→invite sent 60% · paired within 7d 40% · install→trial 7% · trial→paid 35% → **install→paid ≈ 2.5%**. Monthly churn 9% → ~11-month average paid life.

**Value:** net-of-store-fee blended ARPPU/mo ≈ $2.8 (TR) / $6.5 (GCC+diaspora). At a 65/35 revenue mix → **blended LTV ≈ $45/paying couple**.

**Cost:** organic-first. Content ops $1,200–1,800/mo (UGC creators, tools) + infra/AI/tools ~$700/mo. At 2,500 installs/mo, CAC/install ≈ $0.6–0.8; CAC/paying ≈ $25–35; partner-invite effect (each activated user brings a free second install) pulls effective CAC/paying toward **$17–25 → LTV/CAC ≈ 1.8–2.6 at start, >3 as annual mix and virality compound.** Paid UA will *not* pencil early — do not buy installs before Gate 3.

**Break-even:** fixed ~$2,100/mo → **~500–550 active paying couples**, targeted month 8–10. Solo-founder cost structure means the downside is time, not capital.

**Other levers (sequenced):** gift-your-partner Premium (natural in-category gifting, live at launch); AI-credit top-ups (v1.5); occasion commerce/affiliate around anniversaries and Eid (v2); B2B premarital licensing (v2).

## 7. SWOT

**Strengths:** twice-validated mechanic; built-in partner invite loop; founder in-market (Istanbul); empty localized category; distribution playbook documented step-by-step by the reference case.
**Weaknesses:** no product moat; solo-founder bus factor; Turkish ARPU thin; brand from zero.
**Opportunities:** post-nikah whitespace in Arabic; Ramadan as an owned annual moment; diaspora at Western prices; incumbents structurally unlikely to author culturally-native AR/TR intimacy content; B2B/state family programs later.
**Threats:** Paired ships proper AR/TR localization (response: speed + cultural depth they can't fake); TikTok algorithm/regulatory shifts in TR or GCC (response: multi-platform from day 1 — Reels + Shorts + WhatsApp sharing); store rejection of spice content in GCC storefronts (response: flag-off per region, text-only, 17+); FX erosion of TR revenue (response: GCC/diaspora mix target ≥50% of revenue by month 12); copycats of the copycat (response: content velocity is the moat — outrun them).

## 8. Risk register (top 6)

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | TR/AR content doesn't go viral (thesis fails) | Med | Fatal | **Gate 1 before build investment**; kill criteria explicit |
| 2 | Pairing friction kills activation | Med | High | Zero-signup partner preview; Gate 2 |
| 3 | Willingness-to-pay lower than modeled | Med | High | Gate 3; GCC premium mix; annual-first paywall |
| 4 | Cultural misstep in AR content | Low-Med | High | Native Gulf reviewer on every pack; conservative defaults; regional flags |
| 5 | Solo-founder burnout on content volume | Med | Med | Outsourced UGC at ~$1/video + AI slideshow generation from week 1 |
| 6 | Platform dependency (TikTok) | Med | Med | Multi-platform distribution; owned WhatsApp/email list from launch |

## 9. Exit potential

Realistic outcomes, in order of probability: (1) profitable solo lifestyle business at $15–50K MRR; (2) acquisition by a category consolidator (Paired-type player buying its MENA/TR beachhead) or a regional wellness/superapp player; (3) venture path only if GCC ARPU dramatically outperforms — do not plan for it.

## 10. Verdict

**GO WITH CAUTION.**

Go, because: the mechanic is validated twice, the distribution playbook is documented, the localized category is empty on two large, hyper-online markets, the founder sits in one of them, and the downside is a few months of a solo founder's time with near-zero capital at risk.

Caution, because the entire thesis rests on one unproven link — that Turkish and Arabic couple-content converts like English couple-content. Therefore:

- **Gate 1 (weeks 1–3):** 60 test slideshows (30 TR / 30 AR, 6 fresh accounts). Pass = ≥3 posts >100K views from <5K-follower accounts *per language*. Fail in both → NO GO. Fail in one → single-market re-scope.
- **Gate 2 (TR soft launch):** ≥40% signups paired within 7 days; D7 couple retention ≥25%.
- **Gate 3 (paywall +4 weeks):** trial→paid ≥30%; install→paid ≥2%. Only then: GCC push and any paid spend.

Every downstream document assumes these gates. `roadmap.md` sequences them; `resume-prompt.md` starts the machine.

---
*Sources: Sensor Tower app-overview estimates for Paired (US, iOS & Google Play); Paired press/TechCrunch seed coverage and Open University/Brighton evaluation; Google Play listings and reviews (Paired, Soudfa, Muzz, Oolfa, buzzArab); DataReportal Digital 2025: Turkey; Daily Sabah / We Are Social & Meltwater Digital 2025 Türkiye; resourcera TikTok users by country 2026; Sensor Tower 2025 Middle East App Growth Report; namaait Saudi app-market overview; Flame founder interview (uploaded brief). All other figures are labeled assumptions.*
