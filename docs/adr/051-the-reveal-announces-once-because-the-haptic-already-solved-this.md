# ADR-051: the reveal announces at beat 2, because the haptic already solved every hard part of this and the two are one event

- **Status:** Accepted
- **Date:** 2026-08-17 (Session 074)
- **Deciders:** session agent (no operator dependency; three new ARB strings, no new dependency, no new surface)
- **Related:** **ADR-025** (the reveal choreography and its ≤1.2s budget), the `RevealChoreography.onSettle` contract, **ADR-018 D7** (fail-direction discipline), **ADR-033** (bidi at the render boundary), issue **#174**, filed out of **#173**, lessons **65**, **108**

## Context — measured 2026-08-17, not inherited

```
$ grep -rn "liveRegion\|SemanticsService" app/lib
(no output)
```

Zero hits, exactly as #174 filed it. `RevealChoreography` runs three beats and
fires a haptic at beat 2 — the product's signature moment — and a VoiceOver user
gets **the haptic and nothing else**. The partner's answer arrives in the tree
silently.

**And the source already claims otherwise.** `RevealPairGroup`'s doc comment says
`alwaysIncludeSemantics` exists so *"the reveal announces as one event — a screen
reader must never lose it mid-unfold"*. The first half is aspirational: nothing
announces. Keeping both answers **reachable** through the unfold is real and
already works; announcing the **event** was never built. That sentence is the
same class of defect S073 spent a session on, one file over, and it is corrected
in this diff rather than left to be quoted.

## Decision 1 — The fire point is beat 2's settle, in the same call as the haptic

#173 deferred this because *"it needs a fire-point decision (choreography beat 2
vs. the card's own mount) that deserves its own review pass"*. The review's answer
is that the question is already settled by code nobody wrote for accessibility.

`RevealChoreography.onSettle` — and `PairedHomeScreen._fireRevealHaptic` behind it
— **already has every property this announcement needs**, each for its own
independent reason:

| property | why it is already true | why the announcement needs it |
|---|---|---|
| fires **at most once per State instance** (`_revealHapticFired`) | a second buzz on one reveal is a defect | a second announcement **interrupts the user mid-sentence** — the failure #174 calls worse than silence |
| the State is **re-keyed per dayKey** (parent `ValueKey`) | a new day must be able to buzz again | a new day must be able to announce again |
| **preserved under reduce-motion** — the choreography collapses and still calls it | ui-ux §8: the reveal stays *feelable* without motion | reduce-motion users are disproportionately likely to be the ones listening |
| **survives app resume** (the State and the flag survive; the choreography does not restart) | resume must not re-buzz | resume must not re-announce |
| **re-fires on the permission-denial remount, and the caller's flag absorbs it** | at-most-once per dayKey per session | same |

Building a second guard beside that one would mean maintaining two answers to
"has this reveal already happened?" — and the interesting failure is not that they
disagree today but that a future change teaches one of them about a case and not
the other. **The haptic and the announcement are one event delivered through two
channels**: felt and heard. They fire from one line.

So `_fireRevealHaptic` becomes `_signalReveal`, and its doc comment stops being
about haptics.

**Rejected: the card's own mount.** It is earlier, which sounds better and is
worse. The card mounts at beat 1 while the partner card is still unfolding, so the
announcement would race the visual event it describes — and it would fire on a
mount that is not a reveal (the locked→waiting transition also mounts a card).
Beat 2 is the moment the composition *lands*, which is what "this just unlocked"
means.

## Decision 2 — A one-shot announcement, NOT `liveRegion: true`

They are not two spellings of one thing.

`liveRegion: true` marks a node whose **contents** are worth re-reading whenever
they change. On this screen that is a trap with a specific shape: the reveal
surface holds the streak strip, which updates on its own schedule, and every
`AnimatedBuilder` frame rebuilds the subtree. A live region there re-announces on
changes that are not the reveal — the *"interrupts mid-sentence, repeatedly"*
failure #174 names, arriving not through a missing guard but through the widget's
own semantics.

A one-shot **announcement event** is what a reveal is. Three details, each read
out of the installed SDK rather than assumed:

**It is `sendAnnouncement`, not `announce`.** `SemanticsService.announce` is
`@Deprecated` *"after v3.35.0-0.1.pre"* and this repo is on **Flutter 3.44.5** —
writing it into new code would embed a deprecation warning in a feature that has
not shipped. The live API is
`SemanticsService.sendAnnouncement(View.of(context), message, textDirection)`;
both post the same `AnnounceSemanticsEvent` to `SystemChannels.accessibility`, so
the test seam of Decision 4 is unaffected. *(Found by the design review, in an ADR
that had named the deprecated one.)*

**It is gated on `MediaQuery.supportsAnnounceOf(context)`**, because the SDK's own
doc says so: *"Not all platforms support announcements. Check to see if it is
supported… before calling this method."* An unsupported platform must get the
haptic and no attempted announcement, not a dropped call nobody notices.

**The direction is passed explicitly from `Directionality.of(context)`**, never
assumed: the Arabic build is RTL and an announcement queued with the wrong
direction is the bidi failure ADR-033 exists to prevent, in the one channel no
golden can catch.

### ⚠️ And a forward note the SDK volunteers, recorded now rather than found at M6.5

The same doc says: *"**Android has deprecated announcement events** due to its
disruptive behavior with TalkBack forcing it to clear its speech queue… Instead,
use mechanisms like `Semantics` to implicitly trigger announcements."*

This repo is iOS-first (ADR-006) and Android is M6.5, so the decision above is
right for the platform it ships on. **It will need revisiting when Android lands**
— not as a bug then, but as a platform whose accessibility model rejects the
mechanism this one requires. Written here because M6.5 will not think to look.

## Decision 3 — The string names the EVENT, not the content

A new ARB key in all three locales, and its job is narrow. The partner's answer
text is already reachable by exploration and already labelled
(`pairedPartnerAnswerLabel`); `pairedRevealedCaption` ("You both answered today.")
is already on screen. **Re-reading either would be noise.** What no channel
currently carries is the transition: *it just unlocked*.

**It carries no answer text.** An announcement is *spoken aloud*, and the room may
contain someone other than the couple — the risk is the room, not the lock screen.
(ADR-012's discreet-push default answers a *different* question — what a
notification shows on a locked device to a passer-by — and citing it here would be
reasoning by analogy where the direct argument is stronger.)

### The exact strings, and the register they had to match

Measured from the neighbouring `paired*` keys rather than chosen: **TR and AR
address the user in the INFORMAL singular** — `Cevapladın`, `أجبت`, `Partnerinin`,
`شريكك`. (The `-nız` in `pairedRevealedCaption` is the *dual* "you both", not a
formality shift; reading it as one would have made this string wrong in a way no
test could catch.)

| locale | `pairedRevealAnnouncement` |
|---|---|
| en | `Your partner's answer is shown.` |
| tr | `Partnerinin cevabı görünüyor.` |
| ar | `إجابة شريكك ظاهرة.` |

Each reuses the noun phrase already shipped in `pairedPartnerAnswerLabel`
(`Partnerinin cevabı` / `إجابة شريكك`), so the announcement speaks the vocabulary
the screen already uses.

⚠️ **They are drafts pending the founder's native review** (operator item 1, the
standing content-review gate). They are announced text, so a register slip is
heard rather than read — which is worse, not better.

### Why it says "is shown" and not "is NOW shown"

Because of a bound the code is honest about and this ADR must be too.
`_fireRevealHaptic`'s own comment records it: the choreography *"also runs on
cold-open-into-revealed, not only on the live 'partner just answered' moment;
there is no cheap client signal that separates them."*

For a haptic, a stray buzz on cold-open is mild and was accepted. For an
announcement, **"is now shown" would be a false claim about a transition** on
every cold-open of an already-revealed day. Dropping one word makes the sentence
true in both cases without needing a signal the client does not have.

**Suppressing it on cold-open was considered and rejected**: it requires exactly
the signal the source says does not exist, and the failure mode of guessing wrong
is silence on a real reveal — the defect this ADR exists to remove. A redundant
sentence on a screen a reader is already reading is the cheaper error.

*(Neither this nor the fire-point question was raised by the design review's
`firepoint` lens, which returned **zero findings**. Per §5.5 that is *unverified*,
not a clean bill, so both were worked through by hand — the same correction S071
had to make when its `data-rights` lens went quiet.)*

## Decision 4 — The test asserts the MECHANISM, and it must be able to fail

#174 asks for this in those words, and lesson **108** is the reason: *"a
`liveRegion` node exists"* is a green tick that measures nothing, and this repo
has one of those on record already.

The test intercepts the accessibility channel
(`SystemChannels.accessibility`, mocked through the test binding) and asserts:

1. **exactly one** announcement across a rebuild — pumped, rebuilt, pumped again;
2. it still fires **under reduce-motion**, where the choreography collapses to a
   single frame;
3. it does **not** fire for the locked or waiting states — the states that also
   mount cards;
4. a **new dayKey re-announces**, because the guard is per-State and the State is
   re-keyed;
5. the **`TextDirection` matches the ambient `Directionality`**, asserted in both
   an LTR and an RTL locale. An announcement queued with the wrong direction is
   the one bidi failure (ADR-033) that no golden can see, because it is never
   drawn.

Each is mutation-checked: the guard removed, the reduce-motion path skipped, the
call moved to mount. If a mutation leaves the suite green, the test is renamed to
what it actually proves (lesson 108) rather than left to imply more.

## Decision 5 — The documents that change in the SAME commit (project rule #8)

| document | what changes |
|---|---|
| `app/lib/core/l10n/arb/app_{en,tr,ar}.arb` | the new `pairedRevealAnnouncement` key, all three locales, drafts pending native review |
| `app/lib/features/daily_question/presentation/paired_home_screen.dart` | `_fireRevealHaptic` → `_signalReveal`, and a doc comment that stops being only about haptics |
| `app/lib/core/widgets/reveal_choreography.dart` | the `RevealPairGroup` comment that claims *"the reveal announces as one event"* — true only after this diff |
| `docs/test-suite.md` | the accessibility-channel test pattern. **It is new to this repo** — there is no prior interception of `SystemChannels.accessibility`, and the nearest prior art is the `SystemChannels.platform` haptic mock. A technique that lives only in one test file is a technique the next session re-invents |
| `docs/architecture.md` | the a11y line for the reveal surface, if §-level prose enumerates it |

**What deliberately does NOT change:** the choreography's timing or budget
(ADR-025's ≤1.2s stands untouched), the haptic's behaviour, and any golden — an
announcement draws nothing.

## Consequences

**What this buys.** The product's signature moment stops being silent for the
users least able to see it happen, through the one code path that already knew
when the moment was.

**What it costs.** Three ARB strings, one method rename, and a doc comment that
stops claiming something the code did not do.

**What it does not buy, stated plainly.** No screen reader has run against this
build. `flutter test` asserts the announcement is *dispatched*, with the right
text and direction, exactly once — it cannot assert that VoiceOver speaks it, or
that it is spoken at a useful moment relative to the visual settle. That needs a
device and a person, which is the on-device observation nobody has made (#48,
#15, #136 are the same shape). Recorded here rather than discovered later.
