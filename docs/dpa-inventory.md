# DPA inventory — Hayati processors, transfers, and compliance obligations

The register ADR-023 Decision 7 requires: every third party that touches personal data, the honest region each service processes it in, the transfer mechanism / DPA status, and what remains to be done. Then the four standing obligations — the KVKK cross-border filing, the Kurul adequate-measures item, the PDPL GCC-phase gate list, and the GDPR forward flag.

Every claim here is cross-checked against `architecture.md` §8 and the shipped Firestore inventory (`firestore.rules` + the data-rights services). Nothing is asserted that the code does not do. This is an engineering register, not legal advice; the founder/lawyer items are flagged as such.

Reference: ADR-023 (consent surface + legal bundle), ADR-019 (data rights), ADR-013/014/015 (RevenueCat), ADR-016/017 (coach), the KVKK/PDPL/Apple evidence briefs (2026-07-13).

## Processor register

Region cells are honest per service: some Google legs are EU-pinned and some are not, and we say which (ADR-023 Context, finding `honesty-1`).

| Processor | Role | Data categories | Region per service | Transfer mechanism / DPA status | What to do about it |
|---|---|---|---|---|---|
| **Google — Firebase Authentication** | Processor | Sign-in identifiers: name, email, photo (Apple/Google), phone number for SMS OTP (the Auth record — outside Firestore) | **NOT region-pinned** by the Firestore location (Google-managed) | Google Cloud / Firebase Data Processing Addendum (one entity-wide addendum spans the Google legs) | Founder accepts/countersigns the Google DPA; cross-border transfer covered by the KVKK block below (the non-EU-pinned leg counts too) |
| **Google — Cloud Firestore** | Processor | Relationship content: free-text solo reflections and shared answers (≤2000 chars), profile (`status`, `contentLanguage`, `register`), couple metadata (pairing links, timezone, streak), coach usage counters (never coach text), subscription entitlement mirror, invite records, **device-registration state** (`fcmTokens` — one FCM address per physical device, ADR-042; `pushDiagnostic` — the device's own notification-permission report + server timestamp, ADR-049) | **eur3 (EU multi-region)** | Same Google Cloud DPA | Same; EU hosting is the conservative KVKK/PDPL cross-border posture (`architecture.md` §1) |
| **Google — Cloud Functions** | Processor | Transient processing of the above; stores none of its own (admin-SDK writes to Firestore/Auth) | **europe-west1** | Same Google Cloud DPA | Same |
| **Google — App Check** | Processor | Device/app integrity attestation tokens (no relationship content) | **NOT region-pinned** | Same Google Cloud DPA | Same |
| **Google — Crashlytics** | Processor | Crash diagnostics, prod-only, content-free by sentinel-pinned rule: device/OS, stack traces, installation ID — never reflections, answers, or coach text | **Outside eur3** (Google Crashlytics backend) | Same Google Cloud DPA | Same; the non-EU leg is disclosed in the policy and rides the KVKK cross-border block |
| **Apple — App Store / StoreKit / Sign in with Apple** | **Independent controller** for the data it handles as the store | Purchase transactions, App Store account data, Sign in with Apple identifiers | Apple's own infrastructure | Apple's terms (Apple is its own controller, not our processor, for store data) | No DPA to sign; disclosed as a recipient; App Privacy label + privacy-manifest answers ride the deferred Apple-submission cluster (ADR-023 Decision 8, issue-tracked) |
| **RevenueCat** | Processor (entitlement) | Subscription entitlement status keyed to the Firebase uid — **when configured** | To be confirmed when keyed | **Not yet keyed** — rides operator item 0 (RevenueCat account + `RC_WEBHOOK_TOKEN` created at M4.2); no data flows today | When the RC account is created: accept RC's DPA, confirm its sub-processor regions, add a cross-border safeguard leg if outside adequate coverage |
| **Anthropic (Claude API) — coach** | Processor | Transient coach message content at inference time; nothing persisted server- or app-side (ADR-016/017) | **Anthropic API — US-based, NOT EU-pinned** | Anthropic Commercial Terms + DPA — **founder must accept**; no-training-on-API-data is a standing term. A KVKK SCC leg (below) and a PDPL TRA leg (Phase-4) are required | **Active at M5.3 (Session 037):** Sonnet 5 (`claude-sonnet-5`) via `AnthropicCoachProvider` behind the `LLM_API_KEY` secret; thinking disabled; upstream text never logged (ADR-016 D5, ADR-028). `CURRENT_LEGAL_VERSION` bumped 1→2, the notice names Anthropic, every user re-consents. **Founder/lawyer:** accept Anthropic's DPA + confirm the retention posture (enable zero-data-retention for the stronger notice line), sign + file the KVKK standard-contract leg within 5 business days, add the PDPL TRA leg before the first KSA user |
| **Mixpanel / product analytics (when built)** | Processor (planned) | Pseudonymous product events; no answer/reflection/coach text, ever (`architecture.md` §7 binding) | To be determined when built | **Placeholder** — pinned to mvp item 11 (unbuilt: no analytics SDK exists in app or functions today) | When analytics ships: it arrives with its own separate, unbundled opt-in consent (not the special-category consent); accept the analytics DPA; add a cross-border leg if applicable |

Notes on the register, so no cell over-claims:

- The "one entity-wide Google Cloud Data Processing Addendum" is a single instrument spanning the Firebase/Google Cloud services; the founder must actually accept it. It does not, by itself, discharge the KVKK cross-border filing below.
- **Device-registration state, corrected 2026-08-17 (S071).** This note previously read *"`fcmTokens` / push delivery is not in the register: the device-side token capture does not exist, nothing writes the field"* — and that stopped being true at **ADR-042/ADR-044**, when the `registerPushToken` callable and the app-side capture shipped and were wired in both flavor entrypoints. Nothing is *stored* today only because no device has ever produced a token (4 accounts, 0 registered, measured 2026-08-17), which is a device-side gap rather than a missing writer. **`fcmTokens` and `pushDiagnostic` are therefore listed in the Firestore row above**, as data categories that the system writes the moment a device registers. Notification *delivery* remains a Google/Apple leg already covered by the DPAs above; the İYS/ETK marketing-message obligation attaches to any promotional push (a forward obligation, not a processor row).
- **What this register does NOT settle, and must not be read as settling** (issue **#226**): the privacy policy's *"what we collect"* list names neither field. This is an engineering register; changing the **notice** bumps `CURRENT_LEGAL_VERSION` and re-gates consent for every existing user (ADR-023's three-way source sentinel), which is a founder/lawyer decision and not a side effect a diagnostics slice may cause. **Still open.**
- **The export half is CLOSED, 2026-08-17 (#227, ADR-054).** The whitelist used to omit both fields, so the system **deleted data it would not show you** — `deletion-service.ts` sweeps `users/{A}` in full, which already conceded we hold it. The export now carries a `device` lane: `pushDiagnostic` verbatim, and `fcmTokens` as a **count only**. The tokens themselves are deliberately withheld because a registration token is a live credential addressing a phone and the export is delivered by `Clipboard.setData` — the raw string would land on the system pasteboard and, on Apple, be relayed to the subject's other devices by Universal Clipboard. That redaction is a judgement recorded in ADR-054 for a lawyer to overturn in one sentence if they disagree.

## KVKK cross-border transfer — SCC + 5-business-day Kurum filing (founder/lawyer, pre-public-launch)

Hosting Turkish users' data on Google infrastructure is a cross-border transfer under the amended KVKK Article 9 — and this covers **both** the EU-pinned legs (Firestore eur3, Functions europe-west1) **and** the non-EU-pinned legs (Auth, App Check, Crashlytics), **and — since M5.3 (ADR-028) — the Anthropic coach leg** (transient coach content sent to Anthropic's US-based API). Turkey has issued no adequacy decision for the EU, the US, or any country, so adequacy is unavailable. Continuous SaaS hosting is systematic, not occasional, so the explicit-consent / arızi (Art 9/6) route is **not** available as the standing basis (post-September-2024 rules).

The compliant path, and the founder/lawyer action:

- Sign a Kurul-approved standard contract (standart sözleşme / SCC) with the relevant Google entity as data processor for the transfer, and **file it with the Kurum (KVKK) within 5 business days of signature**. Missing that filing carries its own administrative fine band (50,000–1,000,000 TL under the Law 7499 addition, revalued annually).
- Keep the transfer disclosed in the privacy policy as **notice only** — never presented as consent-based (the drafts already do this; ADR-023 finding `honesty-5`).
- **Anthropic (coach), since M5.3 (ADR-028):** the transient coach-content transfer to Anthropic's US-based API is a **separate** cross-border leg — it needs its own Kurul standard-contract (or approved safeguard) and the same 5-business-day Kurum filing, alongside the Google leg. Unlike the Google hosting leg (contract-necessity notice), the coach content itself rides the special-category **consent** basis (ADR-023) — but the transfer safeguard is still required.

This is not buildable; it lands in `operator-expected.md` as a pre-public-launch founder/lawyer item. Evidence from the KVKK brief (2026-07-13):

- KVKK — Yurt Dışına Aktarım: https://www.kvkk.gov.tr/Icerik/2053/Yurtdisina-Aktarim
- KVKK — Yurt Dışına Aktarım Rehberi No. 48: https://www.kvkk.gov.tr/Icerik/8142/Kisisel-Verilerin-Yurt-Disina-Aktarilmasi-Rehberi
- KVKK — Standart Sözleşmeler: https://www.kvkk.gov.tr/Icerik/7929/Standart-Sozlesmeler
- KVKK — Standart Sözleşme / BCR kamuoyu duyurusu: https://www.kvkk.gov.tr/Icerik/7938/Standart-Sozlesmeler-ve-Baglayici-Sirket-Kurallarina-Iliskin-Dokumanlar-Hakkinda-Kamuoyu-Duyurusu
- Kurul standard-contract templates approved by Decision 2024/959 (04.06.2024)
- CottGroup — standard-contract notification obligation and penalties: https://www.cottgroup.com/tr/blog/kvkk-gdpr/item/standart-sozlesme-bildirim-yukumlulugu-ve-yaptirimlari

## Kurul adequate-measures item — special-category "yeterli önlemler" (lawyer question)

Taking the special-category classification (ADR-023 Ambiguity 1 / Lawyer question A) triggers the Kurul's decision on adequate technical and organisational measures for special-category data. Mapped honestly against the shipped posture:

What the shipped posture already provides:

- TLS encryption in transit and Firestore default at-rest encryption (Google-managed keys) — `architecture.md` §8.
- Content-free logging by sentinel-pinned rule: `logDataRightsEvent` and `logCoachEvent` carry op/outcome/latency only — no uid, no coupleId, no text; crisis/help lines additionally drop coupleId (ADR-016).
- No stored crisis flag is ever written against a user; crisis detection runs transiently (ADR-016).
- The coach is ephemeral — zero conversation content persisted server- or app-side (ADR-016/017).
- Aggressive data minimization as a standing posture, and deny-all Firestore rules with least-privilege access.

What it does not yet provide:

- Customer-managed / separate key management (CMEK) for the reflections corpus.
- Dedicated access-audit logging for the reflections corpus.

Founder/lawyer item: confirm whether the minimization-first posture satisfies the adequate-measures decision at this scale, or whether CMEK and dedicated audit logging must ride the deploy era. Recorded, not decided here.

## PDPL design-ahead — GCC-phase gate list (binding before the first KSA user, none at TR launch)

Saudi PDPL compliance is design-ahead only until the first KSA user. None of these blocks the Turkey soft launch; all are binding before the first KSA user (Phase 4). The seven items:

1. SDAIA-licensed local representative in KSA — required unless the still-unenacted 2025 draft amendment removing it is enacted before the KSA launch.
2. Registration on the National Data Governance Platform / National Register of controllers.
3. SDAIA Standard Contractual Clauses (or an approved safeguard) for the EU-hosting transfer leg (Google Cloud).
4. SDAIA Standard Contractual Clauses (or an approved safeguard) for the **Anthropic (coach)** transfer leg — active since M5.3 (ADR-028).
5. A Transfer Risk Assessment covering both cross-border legs (EU hosting and the Anthropic coach leg).
6. Designation of a Data Protection Officer (DPO).
7. Arabic-language privacy notice made available to KSA data subjects — drafted as `privacy-policy.ar.md`, pending Gulf and legal review.

## GDPR forward flag (recorded, deliberately not analyzed)

The P3 persona is Berlin/London diaspora, and a Phase-4 diaspora revenue channel targets EU-resident Arabic and Turkish speakers. Before any EU-resident targeting, GDPR applicability under Article 3(2) (offering services to data subjects in the Union) needs the founder's lawyer — the same design-ahead treatment as PDPL. Recorded here as one flag; no counsel is played and no analysis is attempted at this stage.
