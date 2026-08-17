# ADR-052: "raised" had one definition and fourteen implementations, four of which were right

- **Status:** Accepted
- **Date:** 2026-08-17 (Session 075)
- **Deciders:** session agent (no operator dependency; no new dependency, no new theme slot)
- **Related:** **ADR-025** (the brandkit is the constitution; D1's *no `CardThemeData`* decision, which this preserves rather than overturns), **ADR-039 D7** (`hayatiTheme` is memoized), **ADR-025 D8 / W4** (the golden-declaration discipline this diff is the largest test of), issue **#175**

## Context — counted, not estimated

```
card-shaped BoxDecorations on surfaceContainerHighest: 14
  WITH ElevationTokens shadow: 4
  FLAT (no boxShadow):         10
```

`ElevationTokens.level1` — the plum Level-1 shadow, ui-ux §9.3, *never black* — is
the token that defines what **raised** means in this product. The brandkit assigns
it to "Cards, sheets" (§2/§4). It reaches **4** of the 14 card surfaces:
`paired_home` ×2, `partner_preview`, `privacy_spotlight_card` (plus `SeedVessel`,
which is a glyph painting its own decoration, not a card).

The other **10** are an inline
`BoxDecoration(color: surfaceContainerHighest, borderRadius: cardRadius)`
copy-pasted per screen with **no shadow at all** — so they separate from the page
by a `nightRaised`-vs-`night` colour step of about **1.3:1**, and read as flat
panels of a slightly different colour.

**The defect is not that ten values are wrong. It is that there are fourteen
values.** Ten happen to be missing a line today; the eleventh surface someone
writes will copy whichever neighbour they happen to be looking at.

## Decision 1 — One function, not a theme slot, and ADR-025 D1 stays intact

`raisedCardDecoration(BuildContext)` in `core/design_system/`, carrying the
surface colour, the card radius and `ElevationTokens.level1`. The 10 inline
decorations migrate to it; the 4 correct ones migrate too, because *"the four
that already agree"* is a coincidence to remove, not a state to preserve.

**It takes an optional `border`, because one of the four already needs one.**
`privacy_spotlight_card` carries `Border.all(outlineVariant)` on top of the same
surface/radius/elevation. Measured before designing — a function without that
parameter would have forced that card to keep its inline decoration and left the
sentinel of Decision 2 with an exception to carve out, which is how a rule
acquires its first hole.

**A `CardThemeData` is still refused, and ADR-025 D1's reasoning is why.** That
decision recorded: `grep` found **zero** `Card(` in `lib/`, and theming a widget
the app never builds is dead configuration that reads as coverage. The app builds
`Container`s.

> **Re-measured, with a trap worth recording.** `grep -rn "\bCard(" app/lib`
> returns **1**, not 0 — and the single hit is the *comment in
> `hayati_theme.dart` that states the claim*: `// … grep finds zero Card(, …`.
> The assertion's own text is the only match for the query that verifies it.
> Constructed `Card(` widgets: still **zero**, so ADR-025 D1 stands. But a
> session re-measuring casually sees `1` and "corrects" a true claim into a false
> one — the S073 failure running backwards, and a reminder that a grep-shaped
> claim should say what it excludes.

A theme slot for a widget nobody constructs would be exactly the "declaration
nothing enforces" shape ADR-025 D8 names elsewhere.

A function is not a lesser version of a theme: it is the form that matches how
this app actually builds surfaces, and it can be *called* from a `Container`,
which a `CardTheme` cannot.

**`hayatiTheme` is memoized (ADR-039 D7)** — one `ThemeData` instance per language
code — so reading the surface colour off the theme inside this function costs a
map lookup per build, not a theme rebuild.

## Decision 2 — The test asserts ONE SOURCE, not "this screen has a shadow"

*"Each of these ten screens renders an elevation"* is satisfied by ten
hand-copied decorations carrying the right value — the exact state this ADR
exists to end, passing its own test. Lesson **108** in its natural habitat.

So the assertion is a **source sentinel**, the shape
`brandkit_token_parity_test.dart` already uses for the palette: no file under
`app/lib/features/` may construct a `BoxDecoration` naming
`surfaceContainerHighest`. There is one definition, it lives in
`core/design_system/`, and a new screen that hand-rolls a card fails the build
rather than joining a silent majority.

The sentinel is **mutation-checked** by reintroducing an inline decoration and
confirming it reddens — because a scanner over a set that has quietly become
empty is this repo's most familiar green.

## Decision 3 — The goldens move, and the declaration comes first

156 of the repo's 360 tracked goldens sit on the six affected screens; not all of
them render a card, so the expected set is smaller and **must be written down
before `--update-goldens` runs, not read off the result afterwards** (ADR-025 D8,
`agent-workflows.md` W4). A golden that changes outside the declared set is a
defect to explain; a declaration written from the output is not a declaration.

**The four already-raised surfaces must produce byte-identical goldens**, and
that is the strongest single check in this diff: their decoration is being
re-routed through the new function, so an unchanged pixel proves the function
reproduces the value they already had. If any of those four move, the function is
wrong and the other ten would have been wrong with it.

## Consequences

**What this buys.** Ten surfaces stop reading as flat panels, and — more durably —
"raised" acquires one definition, so the eleventh card inherits it instead of
copying a neighbour.

**What it costs.** A large golden regeneration, and the risk that carries is
named in #175's own words: *"a shadow that lands wrong is more visible than one
that is missing."*

**⚠️ The verification this session cannot perform, stated plainly.** A golden
suite is a **regression net**, not a design review: it proves these pixels do not
change again without someone declaring it, and it cannot judge whether the shadow
*looks* right. Nobody has looked at the result on a device.

Two things bound that risk without removing it: the shadow is not a new value —
it is `ElevationTokens.level1`, the token already rendering on four card surfaces
in this same app, so this makes ten surfaces match four that are already
considered correct; and the brandkit is the constitution (ADR-025 D3), so if the
result is wrong the token is wrong, which is a founder call (the shape of #63 and
#71) rather than a per-screen judgement. **The appearance check belongs to the
founder's next look at a build**, and it is written here rather than implied by a
green suite.
