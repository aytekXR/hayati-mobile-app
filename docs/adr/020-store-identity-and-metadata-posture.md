# ADR-020: Store identity & metadata posture — "Hayati" as store name, the display-name question stays founder-owned, TR/EN metadata in `fastlane/metadata` with an empty-URL honesty lint

- **Status:** Accepted
- **Date:** 2026-07-13 (Session 022, M6.3)
- **Deciders:** session agent, per resume-prompt M6.3; founder-owned halves flagged, not decided
- **Related:** ADR-006 (iOS-first), ADR-018 (the discreet-icon honesty bound and the display-name question it deferred here), ADR-019 (data-rights copy bounds), `docs/frontend-brandkit.md` §7, `docs/prd.md` §2/§8/§10, operator-expected items 1/4

## Context

M6.3 creates the first store-facing artifacts: `fastlane/metadata` per locale. Store metadata bakes in identity decisions of three different reversibility classes, and the session rule (resume-prompt: "any irreversible store-facing choice … gets written down BEFORE it is baked into metadata") requires separating them explicitly:

1. **Irreversible or founder-owned:** the App Store *name* (changeable in App Store Connect until launch, but it seeds every marketing artifact), the on-device *display name* (`CFBundleDisplayName` — ADR-018 Decision 6 recorded that this label is what the discreet icon CANNOT change, and explicitly deferred "whether the shipped display name should itself be less identifying" to this pass as "a founder/product call"), and the primary category.
2. **Reversible but review-gated:** all copy (description, subtitle, keywords, promotional text) — AI-drafted, native-review PENDING per the binding W9/content rules, joins operator item 1's gate.
3. **Structurally absent:** the three URLs App Store submission requires (privacy policy, support, marketing). The scout pass confirmed **no product domain, no hosted privacy policy, and no support page exist anywhere in the repo or brandkit** — `docs/mvp.md` item 12 (legal bundle) is honestly recorded as unbuilt, and the domain choice is explicitly open (operator-expected, universal-links note).

Constraints the copy must satisfy, gathered before drafting:

- **Brand voice (binding):** "warm, private, dignified, quietly playful. Never clinical (we are not therapy), never neon-dating (we are not Tinder), never saccharine" (`frontend-brandkit.md`). The one committed tagline, EN-only: *"The app you use with your partner — never to find one."* The canonical product one-liner: *"One question a day, revealed only when you both answer."*
- **Naming (binding):** the brand is **"Hayati"** — the string "Hayati App" appears nowhere in the brandkit; the wordmark is lowercase but prose is "Hayati". A **trademark/store-name collision caveat is recorded** (an unrelated vape brand uses "Hayati" in some markets); vetted alternates exist (İkimiz, Baynana, Mawadda, Roohi). Store-name search is a pre-launch founder task.
- **The over-claim blacklist (binding, from ADR-018/019 review lineage):** store copy must never claim the app can be hidden or disguised (the name label is immutable — ADR-018 D6), that the discreet mode changes the *name*, that the lock is asked "every time" (60s grace), that Face ID is personal ("anyone whose face … is saved on this phone can unlock Hayati"), that the protection defeats a determined credential-holding partner, that screenshots are blocked, that deletion cancels a subscription or un-reveals what a partner saw, or that export is "all your data". Guarantee-vs-mechanism gaps are the highest-value defect class (S020) — store copy is exactly such a surface.
- **Positioning guardrails (PRD):** never matchmaking/dating framing; never therapy/clinical claims (the AI coach is described with its "not therapy" guardrail, not as counseling); spice mode is OUT of MVP and "never advertised"; P2's purchase driver is that the app is *face-saving and private* — the listing must read as a marriage companion, not "a suspicious app on my spouse's phone".
- **Locales:** launch storefronts are TR + SA, but M6.3's committed scope is metadata **TR/EN** (roadmap: "App Store assets TR/EN"); the AR listing rides Phase 4. Apple locale codes: `tr`, `en-US`.

## Decision 1 — App Store name: **"Hayati"**, subtitle carries the ritual

`fastlane/metadata/{tr,en-US}/name.txt` = `Hayati` (6/30 chars). NOT "Hayati App" — that string is a scaffold artifact, not a brand decision, and putting it in the store would launder it into one. The subtitle carries the product one-liner within Apple's 30-char limit: EN `One question a day, for two`, TR `Günde bir soru, ikiniz için`.

The trademark caveat stays live: if Apple rejects "Hayati" as taken at Phase B (operator runbook), the founder picks from the vetted alternates — the metadata files are one-line edits, and this ADR records that the name is **provisional until the founder's store-name search** (operator item, recorded at session close). Nothing else in the listing embeds the name in prose more than necessary, precisely to keep a rename cheap.

## Decision 2 — `CFBundleDisplayName` stays **"Hayati App"** this session; the change is drafted, flagged, and founder-owned

ADR-018 D6 made the label under the discreet icon an honesty bound and deferred the "should the shipped display name be less identifying?" question here. The two live variants:

- **(a) Keep "Hayati App"** (current, conservative default — chosen this session).
- **(b) Rename to "Hayati"** — cleaner, brand-consistent, *slightly more identifying is not the axis*: both variants name the app; neither is neutral. A genuinely neutral label (e.g. "Journal") is a real product-identity decision with store-review risk (Guideline 2.3.7 metadata mismatch) and is NOT drafted as a default.

Chosen: **(a)**, because the label is load-bearing in shipped safety copy — `settingsDiscreetSubtitle` says "The app's name still appears under it", the ADR-018 settings flow shows the bound, and three ARB locales + ADR-018 prose reference the current reality. Changing the label is a one-line Info.plist edit **plus a copy-and-docs sweep**, and doing that without the founder would spend an identity decision that was explicitly reserved. Variant (b) and the neutral-label option are recorded in operator-expected at close; whichever the founder picks, the discreet-icon honesty copy must be re-audited in the same commit.

## Decision 3 — Category: primary **Lifestyle**, no secondary

Health & Fitness reads clinical (the brand is "never clinical"); Social Networking reads dating-adjacent and stranger-shaped (the PRD's hardest non-goal). Comparable couples apps sit in Lifestyle. Category is version-editable in App Store Connect, so this is a low-regret default — but it is store-facing, so it is written here rather than silently baked into a session's head. No secondary category: nothing honest fits, and an empty slot is cheaper than a wrong signal.

## Decision 4 — Age rating posture: answer Apple's questionnaire plainly; the MVP targets the standard (non-17+) tier

Spice mode — the one 17+ driver in the PRD — is OUT of the MVP by explicit decision ("keeps MVP store rating simple"). The rating questionnaire is answered in App Store Connect by the founder (it is not a metadata file), but this ADR records the posture so no session drafts copy that drags the rating up: no sexual-content references, no gambling-shaped streak framing. **Rev 2 (review minor):** whether the coach's user-facing AI chat affects the rating is NOT asserted here — Apple has treated unrestricted user-generated/AI content as a maturity factor, and the questionnaire's current shape is unverifiable from this box. It becomes a founder verify-item at first submission (operator item 4's checklist): if the coach surface forces a higher tier, the founder decides between constraining the surface and accepting the tier — with the guardrail description (server-side crisis spine, not-therapy disclaimer, premium-gated) as the honest answer either way.

## Decision 5 — The three URLs ship as **empty files + a loud lint**, not placeholders

`privacy_url.txt` and `support_url.txt` are created EMPTY in both locales. A fake or aspirational URL would be worse than absence: Apple validates reachability at submission, and a wrong privacy-policy URL is a legal statement. The new `tool/store_metadata_lint.dart` (Decision 6) treats empty REQUIRED-for-submission URL files as a **named, counted warning under an explicit `--allow-empty-urls` flag** wired into CI — removing the flag is the ratchet once the founder supplies a domain + hosted privacy policy (TR/AR/EN, mvp item 12). **Rev 2 (review minor):** `marketing_url.txt` is NOT in the required set — Apple does not require a marketing URL, and lint-requiring one would make the ratchet permanently unreachable for a founder who never wants one; it is optional (absent or empty is always fine, a non-empty value gets the same well-formedness checks). The gap is recorded as a **new operator sub-item at session close** (pre-submission blocker, not a build blocker): it cannot be closed by any session alone — it needs a domain choice and legal-text review.

## Decision 6 — A repo-local metadata lint replaces credentialed `fastlane precheck`; it runs in the ubuntu `quality` job

`fastlane precheck` needs App Store Connect credentials and a Ruby toolchain (neither exists on the dev box; enrollment is operator item 4). The acceptance line says "precheck-style lint where runnable without credentials" — so the honest equivalent is a pure-`dart:io` tool in the house style (`// Usage:` header, `--flag value` and `--flag=value` args, exit 0 = pass / 1 = violations / 64 = usage-or-input error, stdout for PASS detail, stderr for failures):

- Per present locale dir: required files exist (`name.txt`, `subtitle.txt`, `description.txt`, `keywords.txt`); Apple char limits enforced (name/subtitle ≤ 30, keywords ≤ 100, description/release_notes ≤ 4000, promotional_text ≤ 170) counted in Unicode code points; no leading/trailing whitespace in single-line fields; keywords have no empty terms and no duplicate terms.
- Empty URL files: warning + count under `--allow-empty-urls`, hard failure without it. An unknown `.txt` filename (a typo `deliver` would silently ignore) is a hard failure — silent-ignore is exactly the fail-open this repo's rules forbid.
- Locale dirs are an explicit allowlist argument (`tr en-US`), so a misnamed locale dir cannot sit unvalidated.

Wired into `ci.yml` `quality` (before `pub get`, like the content validator — no pubspec dependency) and into `release.yml`'s preflight. Metadata drift from Apple's limits turns the cheap ubuntu job red pre-merge.

## Decision 7 — iOS localization surface: `CFBundleLocalizations` [en, tr, ar] + localized `InfoPlist.strings` for the Face ID purpose string

The store listing's "Languages" row derives from the binary's declared localizations; today the pbxproj `knownRegions` is `[en, Base]` and there are zero `InfoPlist.strings` variant groups, so the App Store would honestly claim EN-only for an app that ships full TR/AR/EN + RTL. ADR-018 D7 explicitly deferred `NSFaceIDUsageDescription` localization ("EN-only in v1: Info.plist localization rides the M6.3 store-metadata pass") — this is that pass:

- `Info.plist` gains `CFBundleLocalizations` = [en, tr, ar] and `ITSAppUsesNonExemptEncryption` = false (the export-compliance answer from the operator runbook — standard TLS only — so the question never blocks an upload).
- `en.lproj/tr.lproj/ar.lproj` `InfoPlist.strings` localize the Face ID purpose string (the only user-facing Info.plist string): TR "Hayati'yi Face ID ile açın.", AR "‏افتح حياتي باستخدام Face ID." — AI-drafted, same native-review gate as all copy.
- The pbxproj edit (knownRegions + one variant group) is hand-authored on Linux; `ios-build-smoke` proves it still builds. **Rev 2 (review minor — the S020 "native/asset config can fail silently green" class):** a compiling build does NOT prove the `.lproj` files actually land in the bundle — a variant group missing its Resources-build-phase entry builds green and ships an EN-only Face ID prompt. `ios-build-smoke` therefore gains a **bundle assertion step**: after the build, fail unless `{en,tr,ar}.lproj/InfoPlist.strings` exist inside the built `Runner.app`. Assert the mechanism, not the green.
- If the pbxproj turns out Xcode-hostile, the fallback recorded here is: revert the pbxproj half, keep the plist keys, file an issue for the Mac era — the export-compliance key must land regardless.

## Decision 8 — All store copy is AI-drafted and joins operator item 1's native-review gate; the review flag lives in `fastlane/README.md`, not inside `metadata/`

`deliver` uploads recognized filenames from locale dirs; parking review-status markers inside `fastlane/metadata/` risks them being treated as content. The PENDING flag, the register choice (TR copy is authored in **TR-respectful** — the store listing is read by P2's world too; playful register stays in-app), and the copy inventory live in `fastlane/README.md` + operator-expected. Store copy additionally must not contradict the in-app honest-bound strings — the description's privacy paragraph uses the settings row's own vocabulary ("discreet app icon", "the app's name still appears under it" honesty is NOT restated in marketing copy, but nothing may contradict it).

## Consequences

**Positive:**

- The three reversibility classes are now explicit; no irreversible choice was spent without the founder (name is provisional-flagged, display name untouched, category low-regret).
- The listing cannot silently claim more than the product delivers — the blacklist is written down where the copy lives, and the lint makes structural drift a red CI job.
- The store's language row will finally match the shipped TR/AR/EN reality; export compliance stops being a per-upload question.

**Negative / accepted trade-offs:**

- Empty URL files mean the metadata set is NOT submittable today — deliberately: submission is blocked on operator items anyway (enrollment, app record), and a placeholder URL would be a lie with legal weight. The lint flag makes the gap loud, not green.
- "Hayati" may fail the founder's trademark search or Apple's availability check — the rename cost is one metadata line + marketing artifacts, accepted for brand consistency now.
- Hand-editing pbxproj on Linux risks an Xcode-format break that only `ios-build-smoke` catches; the fallback (revert pbxproj half, keep plist keys) is pre-recorded.
- TR-respectful register for the listing sacrifices some P1 playfulness in the store; the in-app experience keeps both registers. Recorded as a marketing-era revisit.

## Pre-code adversarial review record (Session 022 — eight-for-eight)

Shared record in ADR-021 (5 lenses × 2 verifiers over all three ADRs). Landed here as rev 2, all three hand-adjudicated minors: `marketing_url` demoted to optional in Decision 5/6 (a required-empty marketing URL would make the lint ratchet unreachable); Decision 7 gained the built-bundle assertion for `InfoPlist.strings` (a compiling pbxproj does not prove the `.lproj` bundles — the S020 silent-green class); Decision 4's "AI-chat disclosure is not a rating driver" over-assertion replaced with a founder verify-item at first submission. One refuted finding is worth keeping visible: the "empty URL files clobber founder-entered values via deliver" claim was refuted against the pinned deliver source (absent/empty values are skipped, not uploaded) — but the first enrolled `deliver` run should still eyeball the App Store Connect URL fields, which the operator runbook note carries.
