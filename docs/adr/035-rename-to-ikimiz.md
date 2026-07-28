# ADR-035: The rename to **ikimiz** — a copy rewrite, not a substitution

- **Status:** Accepted
- **Date:** 2026-07-28 (Session 054)
- **Deciders:** founder (the name, the casing, and the hosting substrate); session agent (how to land it without breaking Turkish, Arabic rendering, or the consent guarantee)
- **Related:** **ADR-020** (store identity — the name question it left open), **ADR-032 D6** (which already moved the store listing to "İkimiz"), **ADR-033** (bidi isolation; **D3's chrome premise is the one this diff could have falsified**), **ADR-023** (the consent/legal guarantee surface and its version sentinel), **ADR-025 D5.iii / D8** (the frozen-sentence digest and the golden declaration protocol), **ADR-012** (the discreet-notification title), **ADR-027** (the bundle id, deliberately NOT renamed), **ADR-036** (the domain that serves the new brand's links)

## Context

The app is renamed **Hayati → ikimiz**, lowercase. Part of it had already
happened: ADR-032 D6 recorded the founder choosing **İkimiz** for the App Store
listing and `CFBundleDisplayName`, one of ADR-020 D1's own vetted alternates.
This ADR takes the rest of the product there and moves the casing to lowercase.

The naive reading of this task is a find-and-replace over 16 strings × 3
locales. That reading is wrong in three separate ways, each measured.

## Decision 1 — Turkish suffixes change, because the stem now ends in a consonant

Turkish appends case suffixes to proper nouns after an apostrophe, with a buffer
consonant when the stem ends in a **vowel**. "Hayati" ends in `i`; "ikimiz" ends
in `z`. So:

| Old | Naive | Correct |
|---|---|---|
| `Hayati'yi` (accusative) | ikimiz**'yi** | **ikimiz'i** |
| `Hayati'nin` (genitive) | ikimiz**'nin** | **ikimiz'in** |
| `Hayati'de` (locative) | ikimiz'de | ikimiz'de ✓ |

A blind replace ships two visibly broken forms. Verified after the change: the
only suffixed forms anywhere in the tree are `ikimiz'de`, `ikimiz'i`,
`ikimiz'in`.

## Decision 2 — Four Turkish sentences were rewritten, not renamed

**"ikimiz" is an ordinary Turkish word meaning "the two of us."** The brand
therefore collides with the copy's own vocabulary, and in a product *about* two
people that collision is everywhere:

| Key | Substitution would give | Why it fails |
|---|---|---|
| `privacySpotlightTitle` | "ikimiz ikinizin arasında kalsın" | mixes *our two* and *your two* |
| `soloCompletedBody` | "ikimiz iki kişi için tasarlandı" | "the two of us were designed for two people" |
| `soloNudgeBody` | "ikimiz birlikte daha güzel" | reads as the pronoun, not the app |
| `inviteShareMessage` | "her gün **ikimize** bir soru … **ikimiz'i** indir" | same word as pronoun and as brand, one line apart |

Each was rewritten. Where the brand could not sit in a sentence without
ambiguity, it was **dropped from that sentence** (`soloCompletedBody` now says
"Bu uygulama iki kişi için tasarlandı") rather than forced in.

**This is the part of the rename that needs a native reviewer.** The copy is
defensible but it is one non-native pass over a product whose Turkish is its
primary language. It joins operator item 1's native-review gate.

## Decision 3 — Arabic keeps the Latin wordmark, and never lets it lead

The brand is a Latin wordmark; Arabic copy previously used **حياتي** ("my
life"), a genuinely Arabic word. Two options: transliterate (إيكيميز) or carry
the Latin wordmark into Arabic text.

**Latin wordmark, for brand consistency with the App Store listing** — but that
choice runs straight into ADR-033.

ADR-033 D3 deliberately does **not** isolate chrome, and its stated reason is
that *a chrome sentence's first-strong direction already equals the paragraph's*.
A Latin word in the **lead** position of an Arabic string falsifies exactly that
premise: `"حياتي مقفل"` → `"ikimiz مقفل"` would begin an RTL paragraph with a
strong-LTR character.

So every Arabic string is restructured so an **Arabic word leads** and the
wordmark sits mid-sentence — usually by naming the thing: `تطبيق ikimiz`
("the app ikimiz"). `lockTitle` becomes `تطبيق ikimiz مقفل`.

**No isolation controls were added.** ADR-033's premise is *preserved by
construction* rather than patched, which is the cheaper and more honest of the
two repairs — and it keeps the invariant that nothing persisted, exported or
shared carries `U+2068`/`U+2069`. The push bodies in
`functions/src/notifications/payload-policy.ts` already followed this shape
(`افتح Hayati وأضف إجابتك.`) and keep it.

## Decision 4 — The legal version is NOT bumped, and the reason is written down

Three `consent*` strings name the app, so they sit inside the frozen-sentence
digest (ADR-025 D5.iii). Its checklist asks whether a `consent*` change is
**material**, because a material one is a legal-version event under ADR-023 D4
that re-asks **every** user for consent.

This one is not material. What a user consents to is the set of **processors**
(Google, Apple, Anthropic), the **data categories**, the **purposes**, and the
**controller** — and this diff changes none of them. Only the product's trade
name moved.

`currentLegalVersion` therefore stays at **2**, all three sentinel sources are
untouched, and nobody is re-gated. The digest was re-stamped with that reasoning
recorded **next to the constant**, where the next person to hit the failure will
read it, rather than only in a commit message.

The same reasoning covers `docs/legal/` and its byte-synced twin in
`app/assets/legal/` (6 files, re-synced in this diff).

## Decision 5 — What was deliberately NOT renamed

Identifiers are not customer-facing, and renaming them ranges from pointless to
catastrophic:

| Left alone | Why |
|---|---|
| `com.beyondkaira.hayati` | the iOS bundle id. ADR-027 renamed it once, painfully; changing it again creates a *new app* on Apple and orphans TestFlight, signing and both Firebase registrations |
| `com.hayati.app` | Android application id — permanent on Play once published; its decision is deferred to M6.5 (ADR-027) |
| `hayatiapp-dev` / `hayatiapp-prod` / `demo-hayati` | Firebase project ids; not renameable, and never shown to a user |
| `hayati-functions` | the Functions npm package name |
| Dart/TS symbols, test fixtures, file paths | internal vocabulary |

One consequence worth stating because it will look like an oversight: a user who
inspects the app deeply enough (a crash report, a URL scheme) can still see
"hayati". That is accepted.

**ADR-012's discreet-title argument shifts and is re-recorded.** The old comment
justified a Latin title on the grounds that *"Hayati" reads as any app name*.
"ikimiz" gives away even less to a non-Turkish reader, but it is **not** neutral
to a Turkish one — it says "the two of us" on a lock screen. That is a real
change to the discretion story and it is noted at the constant.

## Decision 6 — The golden set was declared before it was regenerated

ADR-025 D8: **declare, then regenerate.** Declared: 91 modified, 0 added, 0
deleted, in exactly 7 suites. Actual, per suite:

| Suite | Cells |
|---|---|
| `solo_home_screen` | 33 |
| `settings_screen` | 18 |
| `lock_screen` | 18 |
| `paywall_screen` | 9 |
| `consent_gate_screen` | 9 |
| `legal_document_screen` | 3 |
| `export_screen` | 1 |

Matched one-for-one, no churn, nothing outside the declaration.

**Three renamed strings moved no golden at all, and each reason was checked
rather than waved through** (the S051 lesson):

- `pairedPackUpdateTitle` renders only in a pack-update state the paired-home
  golden set does not cover.
- `privacySpotlightTitle` *is* covered — it sits inside the 33 solo-home cells.
- `inviteShareMessage` is asserted by a widget test that builds its expectation
  from `l10n.inviteShareMessage(...)` — **self-referential**, so it passes for
  any wording. Pre-existing, not introduced here; it also pins the old
  `hayati://invite/…` link, which ADR-036 changes.

## Consequences

- The App Store listing name **will change on the next release run**:
  `fastlane/metadata/*/name.txt` is now `ikimiz`, `deliver(force: true)` pushes
  it, and `tool/release_lane_lint.dart`'s `pinnedStoreName` moved in the same
  commit — which is precisely the coupling ADR-032 built that lint to enforce.
- The Turkish and Arabic copy is one non-native pass and goes to operator item 1.
- Deep links still say `hayati://` until ADR-036 lands; the two ship together.
- `docs/`, `brandkit/` and `redesign/` keep historical "Hayati" references. They
  are a record of what was decided when, not product surface.
