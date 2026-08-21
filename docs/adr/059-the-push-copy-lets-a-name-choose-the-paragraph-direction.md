# ADR-059: the push copy lets a partner's name choose the paragraph direction, and the worst case is not the Arabic one

- **Status:** Accepted
- **Date:** 2026-08-21 (Session 083)
- **Deciders:** session agent (the fix is device-independent; the isolate question that is *not* stays blocked and is re-filed rather than guessed)
- **Related:** **ADR-033** (bidi isolation at the content-text seam, and D10, which recorded this deferral), **ADR-053** (the generated strong-bidi ranges; `intl` must not return to this seam), **ADR-012 / ADR-042 D4 / ADR-045** (the push kinds, the recipients, the hours), **ADR-058** (S082's legal draft, which now tells Arabic users in writing that a notification can show their partner's name), issues **#136** (this one), **#133** (the app-side twin, closed by ADR-033)

> **Review status, stated prospectively.** Written and committed **before** the
> fix (`session-context.md` §5 item 1, lesson 111). At the moment of this commit
> neither review pass has run. What each finds is recorded in `past-prompts.md`
> and in this ADR's revision history.

## Context — measured with the reference implementation, not reasoned

Issue #136 says the Arabic `partnerAnswered` copy interpolates a partner name
with no bidi isolation, that the defect is **latent**, and that the device-free
option is *"reorder the Arabic copy so the placeholder never sits next to a
neutral."*

**Two of those three statements survive measurement. The third is wrong, and the
issue's own diagnosis pointed at the wrong locale.**

### The instrument, and its control

There is no Flutter here — the renderer is the OS notification shade — so
ADR-033's evidence does not transfer, and neither does its instrument.
`tool/bidi_visual.py` drives **FriBidi** (the reference Unicode bidi
implementation, already on the box as `libfribidi.so.0`) through `ctypes` and
returns the **visual** reordering of a logical string.

**Its control is #133 itself.** The app-side doc comment records the visible
defect that ADR-033 exists to fix — a Turkish answer inside Arabic chrome
rendering as `.Kahvaltıda birlikte gülmemiz`. Fed that string, the harness
returns:

```
logical : إجابة شريكك: Kahvaltıda birlikte gülmemiz.
visual  : .Kahvaltıda birlikte gülmemiz :ﻚﻜﻳﺮﺷ ﺔﺑﺎﺟﺇ
```

— the recorded defect, verbatim, on a case whose answer was already known. Every
claim below is output from that harness.

### Finding A — the severe defect is in the TURKISH and ENGLISH copy

`partnerAnsweredNormal` puts `${name}` **first** in both the TR and the EN
strings:

```ts
case 'en': return { title: `${name} answered`, body: `${name} answered today's question. Open ikimiz to add yours.` };
case 'tr': return { title: `${name} cevapladı`, body: `${name} bugünün sorusunu cevapladı. ikimiz'de sen de cevapla.` };
```

A first-strong renderer takes the paragraph direction from the **first strong
character** — which, when the placeholder leads, is *the name's script, not the
copy's*. Measured, with an Arabic name:

```
logical : أيلين answered today's question. Open ikimiz to add yours.
visual  : .answered today's question. Open ikimiz to add yours ﻦﻴﻠﻳﺃ
```

**The entire English sentence is laid out right-to-left and its final full stop
jumps to the head of the line.** That is not a stray punctuation mark beside a
name; it is the whole notification rendered backwards, for an English- or
Turkish-reading user, because of who their partner is.

**The Arabic copy is immune to this**, and by accident rather than by design:
`أجاب ${name}` opens with a verb, so a strong Arabic character always precedes
the placeholder and the paragraph direction is never the name's to decide.

The file's own comment says the name *"sits in SUBJECT position in all three
languages (no possessive/case suffix attaches to it)"*. The placement was
reasoned about — for **grammar**. #136 predicted this exactly: *"the precedent
was followed for grammar and missed for direction."* It just did not predict
which locale would pay.

### Finding B — the Arabic defect is real, and reordering CANNOT fix it

```
logical : أجاب Aylin Y.          logical : أجاب Aylin!
visual  : .Aylin Y ﺏﺎﺟﺃ           visual  : !Aylin ﺏﺎﺟﺃ
```

The `#133` shape again: the name's own trailing punctuation resolves to the
paragraph direction and detaches to the far side of the Latin run. The body
breaks the same way (`… ﻦﻋ .Aylin Y ﺏﺎﺟﺃ`).

**The neutral is inside the name, at its tail** — so no arrangement of *our*
words can help. Wherever the placeholder sits, a name ending in `.`, `!` or `?`
carries its own neutral to the boundary. #136's suggested step 3 addresses a
different case: a neutral that *our copy* places next to the placeholder. It is
sound advice for that case and insufficient for the one the issue names.

Two things that do **not** break, so the fix does not need to cover them:

* **Bracketed names.** `Ayşe (Y)` renders correctly — Unicode's paired-bracket
  rule (N0/BD16) resolves both brackets to the enclosed text's direction. A
  guard that also stripped brackets would be removing characters for no reason.
* **A leading neutral.** `.Aylin` → `Aylin. ﺏﺎﺟﺃ` is the mirror case and is
  ordinary.

### Finding C — the two defects have different blast radii, and only one is ours to see

Finding A depends on **how the shade resolves paragraph direction**: first-strong
auto-detection reproduces it, a shade that forces the UI locale's direction does
not. Finding B reproduces under **both**. That asymmetry matters, because
step 1 of #136 — *does the shade honour `U+2068`/`U+2069`* — is a device
question nobody can answer from here, and **the fix below deliberately does not
depend on the answer to either.**

## Decision 1 — Put a strong copy-language character before the placeholder, in TR and EN

The named variants become the name-free variants with the name inserted **after**
the opening word, which is what the copy was already saying without it:

| | before | after |
|---|---|---|
| EN title | `${name} answered` | `Your partner ${name} answered` |
| EN body | `${name} answered today's question. …` | `Your partner ${name} answered today's question. …` |
| TR title | `${name} cevapladı` | `Partnerin ${name} cevapladı` |
| TR body | `${name} bugünün sorusunu cevapladı. …` | `Partnerin ${name} bugünün sorusunu cevapladı. …` |

Measured, with an Arabic name, under first-strong detection:

```
Your partner ﻦﻴﻠﻳﺃ answered today's question. Open ikimiz to add yours.
Partnerin ﻦﻴﻠﻳﺃ cevapladı
```

Correct, and correct under a forced-LTR shade too. **This is why reordering is
the right instrument for Finding A and not for Finding B:** paragraph direction
is decided by the *first* strong character, which is a property of the sentence
we author; a trailing neutral is a property of the name we are handed.

The copy gains nothing awkward — `Your partner Aylin answered` is the
name-free sentence with a name in it, and the two variants now read as one
family rather than as two unrelated strings. The Arabic keeps `أجاب ${name}`
unchanged, because it already satisfies the rule.

## Decision 2 — Strip bidi-neutral characters from the ENDS of the name, and fall back when nothing strong is left

A single `sanitizePushName()` in `functions/src/notifications/`, applied to every
language rather than to Arabic alone:

* trim whitespace, then trim characters whose Unicode bidi class is neutral or
  weak from **both ends** — `.` `!` `?` `…` `:` `،` `-` and their kin;
* **brackets are deliberately NOT stripped** (Finding B: N0 already handles
  them, so removing them would be damage with no benefit);
* if nothing strong remains — a name that is entirely punctuation — return
  `undefined`, so `composePush` degrades to the **existing** name-free copy
  rather than interpolating an empty string. That path already exists and is
  already tested; this decision only routes to it.

**Applied to all three languages, not just Arabic**, for the reason ADR-052
gives about single definitions: a language-conditional sanitiser is two rules
that will be taught separately, and the next copy change to TR or EN would have
to re-derive which one it lives under.

**The cost, stated rather than buried:** `Aylin Y.` is displayed as `Aylin Y`.
A person's name loses a trailing full stop in a lock-screen notification. That is
a real, if small, alteration of someone's name — and it is the *lesser* of the
two options, because the alternative is that same name rendered with its period
on the wrong side. It is recorded here so a founder or a native reviewer can
overturn it in one sentence.

## Decision 3 — No `U+2068`/`U+2069` enters a push payload, and step 1 stays blocked

The isolate route is not taken, and this is not a deferral by convenience:

* `session-context.md` §6 / ADR-033 — **nothing persisted, exported or shared may
  carry the isolates.** A push payload travels through FCM and APNs, is logged by
  both, and lands in a notification-shade database on the device. It is
  plausibly all three.
* Whether the shade honours them is **unmeasurable from here**, and #136 says so
  in as many words: *"Do not assume it works — measure on a device, and if it
  cannot be measured, say so rather than shipping invisible control characters
  into a push payload on faith."*
* **The fix above needs neither answer.** Decisions 1 and 2 are correct whether
  the shade auto-detects or forces a direction, and whether or not it honours
  isolates.

Step 1 therefore remains open and **device-blocked**, and #136 stays open for it.
If a device ever shows the isolates working, that is an *improvement* on this
fix, not a correction of it — it would let a name keep its own punctuation.

## Decision 4 — The test asserts the RULE, not the rendering

The suite runs in Node; FriBidi does not. Rather than add a native dependency to
`functions/` for a test, the measurement is done **once, here**, and what ships
is the invariant that measurement established:

1. **No composed push string may begin with the interpolated name** — asserted
   over every `(kind × language)` combination that accepts a name, by composing
   with a known Arabic name and requiring the string to start with a character
   the *copy* contributed. This is Finding A's rule, and it is a property of the
   template, checkable without a bidi implementation.
2. **The sanitiser's contract, by value** — the exact output for a table of
   inputs (`Aylin Y.` → `Aylin Y`, `Ayşe (Y)` → unchanged, `...` → `undefined`),
   because a behavioural test of a trimming rule cannot see *which* characters it
   trims (lesson **117**).
3. **The fallback is reached**, not merely available: an all-punctuation name
   produces the byte-identical name-free payload.
4. **A floor on the input**, so the sweep cannot pass by matching nothing
   (lesson **110**): the number of `(kind, language)` pairs examined is asserted.

`tool/bidi_visual.py` is committed **with** the fix, because the rule above is
only as good as the measurement behind it, and a later session that wants to
re-derive it — or to answer step 1 when a device finally exists — should not have
to rebuild the instrument. It is a tool, not a gate: nothing in CI runs it.

## Consequences

* **A user whose partner has an Arabic name stops receiving backwards
  notifications** in Turkish and English. That is the actual user-visible win,
  and it is not the one #136 was filed for.
* **#136 stays open** for step 1 — the device question. Its severity drops from
  *"a name may render wrongly"* to *"a name loses a trailing full stop"*.
* **ADR-058's legal draft becomes more defensible.** It tells Arabic users, in
  writing, that a notification can show their partner's name. It now does so
  correctly.
* **The `partnerAnswered` copy changed**, so any native review already done on it
  is stale for four strings. Flagged to the founder rather than absorbed —
  `operator-expected.md` item 13 already covers native review of user-visible
  strings, and these four join it.
* **This does not repeal ADR-033**, which governs the app-side render seam and
  remains the right fix there. Two seams, two mechanisms, and D10 predicted the
  split.
* **The sanitiser is a display transformation and nothing else.** It is applied
  at payload composition; no stored name is altered, and the export, the profile
  and the app are untouched.
