# Frontend Brand Kit — Hayati

## 1. Brand idea

**Hayati (حياتي / Hayatım)** — "my life," the endearment spouses actually say to each other in both Arabic and Turkish. The brand must feel like the inside of a good marriage: warm, private, dignified, quietly playful. Never clinical (we are not therapy), never neon-dating (we are not Tinder), never saccharine.

**Working-title status:** trademark + store-name search required before public launch (known collision risk: an unrelated vape brand uses "Hayati" in some markets — different class, but verify). Vetted alternates: **İkimiz** (TR "the two of us"), **Baynana** (AR "between us"), **Mawadda** (AR "affection," Quranic resonance), **Roohi** (AR/TR "my soul").

**Central motif: the pomegranate (nar / رمّان).** Symbol of love, abundance and marriage across Anatolian and Middle Eastern culture, and a perfect streak metaphor — *every mutual day adds a seed*. Distinctive, culturally bilingual, and safely distant from competitors' flame/heart clichés. (Note: the word "nar" itself is avoided as a name — in Arabic نار means fire/hellfire.)

## 2. Color

Dark-first UI (evening is the couple's app moment; discretion likes dark screens).

| Token | Hex | Use |
|---|---|---|
| `night` | `#231A33` | Primary background (deep plum night) |
| `night.raised` | `#2E2344` | Cards, sheets |
| `pomegranate` | `#C04A5A` | Primary actions, streak seeds, brand accent |
| `pomegranate.deep` | `#8E3140` | Pressed states, gradients |
| `sand` | `#F3E7D7` | Primary text on dark, light surfaces |
| `gold` | `#D9A441` | Premium/celebration accents only (restraint = perceived value) |
| `sage` | `#8FAE8B` | Success, streak-safe states |
| `clay` | `#B98A6E` | Secondary/illustration tone |
| `alert` | `#D96C5F` | Errors, streak-at-risk |

Rules: gold never for body UI; alert never for marketing; all text pairs ≥4.5:1 contrast (tokens above verified against `night`).

## 3. Typography

**Rubik** (Google Fonts) as the single family — genuinely dual-script with matched Latin (full Turkish diacritics) and Arabic, warm rounded terminals that match the brand voice. Fallback: Noto Sans / Noto Sans Arabic.

Scale (mobile, dp): Display 32/700 · H1 24/700 · H2 20/600 · Body 16/400 (line-height 1.5 Latin, **1.7 Arabic** — Arabic needs air) · Caption 13/400. Numerals: Latin digits in TR/EN; Eastern Arabic numerals optional per user setting in AR. Minimum body size never below 14; dynamic type supported to 130%.

## 4. Spacing, shape, layout

4-pt grid; screen gutter 20; card padding 16; radius 16 (cards) / 24 (sheets) / full (chips); elevation via subtle plum-tinted shadows, not gray. One primary action per screen. RTL: layouts authored with `start/end` only; every asset with directionality (arrows, progress) ships mirrored variants; goldens enforce both directions (`test-suite.md`).

## 5. Iconography & illustration

Icons: Phosphor (rounded weight), 24dp grid, 1.75 stroke. Illustration style: **abstract duotone forms** — intertwined shapes, pomegranate seeds and branches, architectural lattice (Ottoman/Arab geometric echoes) — **no photographic couples, no faces, no embracing figures** in AR-market marketing surfaces; in-app may be one notch warmer but stays abstract. This is both a brand choice and the GCC-safety choice from `feasibility-report.md` §4.

## 6. Motion & sound

Motion is intimate, not gamified-loud: reveal moment = soft unfold + gentle haptic (this is *the* signature interaction — budget polish here first); streak seed drops in with a small settle; celebrations (streak milestones) use gold particle restraint, ≤1.2s, skippable. Lottie for hero moments only. Respect reduce-motion. No sound by default; optional soft chime on reveal.

## 7. Voice & tone

Warm, second-person, never preachy, never clinical. Register system mirrors content packs: **TR-playful** (arkadaşça, light flirt allowed), **TR-respectful**, **AR-Gulf-respectful** (formal-warm, family-safe), **EN-neutral**. Notifications are written like a considerate friend, and in discreet mode collapse to neutral text ("You have a new message"). Never guilt-trip; streak-at-risk copy is invitational, not shaming.

## 8. Accessibility

WCAG AA contrast; touch targets ≥44dp; full TalkBack/VoiceOver labels in all three languages; reveal interaction operable without haptics; color never the sole signal (streak states carry icon + label); dynamic type verified in goldens at 100% and 130%.

## 9. Design principles

1. **Two people, one screen state** — every surface answers "what does my partner see?"
2. **Discretion is a feature** — design as if the phone gets glanced at on the metro.
3. **The reveal is the product** — spend polish budget there.
4. **Culturally authored, not translated** — copy reviewed by native register owners before merge.
5. **Restraint reads premium** — especially with gold.
