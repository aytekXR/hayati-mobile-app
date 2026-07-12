# ADR-017: Coach chat UI — one premium surface, help-latched conversations, ephemeral threads, server-side persona scaffolds

- **Status:** Accepted (rev 2 — post-review)
- **Date:** 2026-07-12 (Session 019, M5.2)
- **Deciders:** Session 019 (autonomous, per resume-prompt objective); founder
  directives inherited: ADR-007 (personal-use-first), ADR-013 Decision 5
  (expiry pairing), ADR-014 (PremiumGate / `isPremiumProvider` — the seam this
  slice mounts on), ADR-016 (the FROZEN coach wire contract and the
  drop-or-retain obligation this ADR discharges).
- **Related:** PRD F5 (coach personas, disclaimer, register-aware tone), F4
  (premium gating), §8 NFR ("AI inputs never retained beyond session context
  window budget"); `mvp.md` IN #7; `implementation-plan.md` M5;
  `architecture.md` §2/§4/§8; `frontend-brandkit.md` (registers, voice,
  design principles); ADR-009 (clock seam), ADR-011 (dayKey discipline —
  deliberately NOT consumed here, see Decision 6), ADR-015 (couple-scoped
  premium).
- **Review note:** adversarially design-reviewed BEFORE code (the S015–S018
  discipline, now FIVE-for-five): a four-lens workflow (safety-ux,
  privacy/DV, wire-contract, Flutter-architecture), every finding verified by
  two independent passes (skeptic + governing-docs adjudicator), all
  hand-adjudicated. **1 BLOCKING** (rev 1's help-stickiness had no durable
  latch — window trimming evicted the crisis turn after ~20 turns, and
  post-filter crises never stuck at all because their windows are
  pre-scan-negative by construction; all four lenses converged on it
  independently) **+ 6 SERIOUS + ~10 MINOR** findings are folded in below.
  One verifier-lens disagreement (document-the-bounded-stickiness vs
  client-latch) was settled by the governing docs per the S018 rule:
  ADR-016's asymmetry mandate ("conservative everywhere") plus rev 1's own
  rejected-alternative rationale decide for the protective latch. Findings
  refuted or accepted-as-designed are recorded in Consequences.

## Context

M5.1 shipped the coach's safety spine and `coachProxy` — emulator-proven,
fail-closed, zero live calls. Its wire contract is FROZEN (ADR-016): request
`{coupleId, personaId, language, register, messages[≤20 × ≤2,000 chars, last
role 'user']}`; response `{kind: 'reply'|'help', category?, text,
remaining?}`; errors separable by CODE first — `failed-precondition`/
`'not-premium'`, `resource-exhausted`/`'cap-daily'|'cap-monthly'|
'rate-limited'`, `permission-denied` = non-member only, `unavailable` =
provider/infra. M5.2 mounts the couple-facing chat experience on that spine
and claims three parked decisions: the chat surface shape, the
crisis-turn window decision (ADR-016 pinned the obligation: a crisis turn
retained in the window re-routes every subsequent call to the help path —
and required the M5.2 behavior to be "documented, not discovered"), and the
private-thread persistence scope.

Forces:

- **The free tier sees ZERO coach surface** (PRD F5: free tier zero; the
  resume prompt makes it an accept line with assertion extension). This is
  stricter than the packs tile (which free users SEE, locked): the coach
  must not exist for free users, not even as a teaser.
- **Safety UX inherits ADR-016's asymmetry rule.** An under-protective
  window policy is dangerous; an over-protective one costs persona replies.
  The client owns the window, so the client's construction rules are part
  of the safety posture — and the help path must never be mistakable for
  the persona (the `kind` discriminator exists for exactly this).
- **Stickiness cannot live in the window alone.** The server scans only
  the client-carried window and persists nothing (ADR-016 D8), the window
  is capped at 20 messages by the frozen contract, and a post-filter help
  response fires precisely when the window was pre-scan-NEGATIVE (the
  crisis text was in the discarded model reply, not in any retained turn).
  So "retain the crisis turn" alone cannot deliver a durable help-sticky
  conversation — the review's blocking finding, resolved by Decision 2's
  client-side latch.
- **This is a DV-aware product on shared devices.** M5.1's strongest review
  finding split the cap counters so a partner cannot monitor the other's
  coach usage. The same threat model applies to CONTENT at rest: a
  persisted coach thread is discoverable by a partner holding the phone.
  Device-level privacy protections (PIN/biometric lock, discreet icon) are
  M6 scope and do not exist yet.
- **Retention is a privacy stance, not an engineering default.** PRD §8
  says "AI inputs never retained beyond session context window budget";
  `architecture.md` §3 sketches `coach_sessions` with TTL-30d as FUTURE;
  the resume prompt's stopping condition names TTL/retention posture a
  founder decision. No native Firestore TTL policy exists in this repo.
- **No local persistence exists app-side.** `core/storage/` is an empty
  placeholder; the app has no shared_preferences/hive/sqflite dependency.
  Every persisted thing today lives in Firestore behind rules with a
  deliberately narrow write surface.
- **Crashlytics is ON in prod and the global error hooks forward
  `error.toString()`** (`error_hooks.dart` routes every uncaught error to
  the reporter). The server closed this exact leak class in ADR-016 D8
  (static-message `HttpsError`s because the callable framework auto-logs);
  the app side now hosts the same data class (message + reply text,
  potentially crisis disclosures) and needs the same structural rule
  (Decision 5).
- **Three register vocabularies exist and none matches the wire.** The
  profile stores `ContentRegister {playful, respectful}` +
  `ContentLanguage {tr, ar, en}`; the wire wants the brandkit union
  `'tr-playful'|'tr-respectful'|'ar-gulf-respectful'|'en-neutral'`. A
  naive `.name` send would be rejected by `validateCoachRequest`
  (`bad-register`).
- **The generic failure mapper mis-buckets the coach codes** (confirmed:
  `mapFunctionsFailure` collapses `resource-exhausted` into the unknown
  bucket and reads `permission-denied` as a generic permission problem —
  which for the coach means "non-member", a different UX). ADR-016's
  review already mandated an app-side coach-owned taxonomy mapped by CODE
  first, `details.reason` second (the platform channel may drop details).
- **Copy discipline:** all coach-facing copy is AI-drafted in the brandkit
  voice and joins the founder native-review gate (TR by the founders, AR
  incl. register by the Gulf reviewer). The "not therapy" disclaimer
  currently lives server-side (`help-content.ts`) with NO wire consumer —
  M5.2's UI is its only real consumer, and two homes for one safety string
  is drift waiting to happen (the repo's answer to two homes has always
  been one authoring home + sync or a single home: ADR-010).

Alternatives considered are inlined per decision.

## Decision 1 — Chat surface: ONE coach screen, persona switcher, per-persona transcripts

**Shape:** one `CoachScreen` (feature `app/lib/features/coach/`), pushed
from a paired-home tile, with a **persona switcher** (three choice chips:
Coach / Date Genie / Gift Genie) and **one transcript per persona**.
Switching personas swaps the visible transcript; it never mixes windows — a
window sent to `coachProxy` only ever contains turns exchanged with the
selected persona (a Date-Genie window carrying Coach turns would feed one
persona's context to another's system prompt).

*Alternative rejected — three separately-pushed persona screens:* three
pushed routes triple the golden surface and the state plumbing for zero UX
gain at three personas; the switcher keeps discovery of all three personas
one tap away (PRD F5 presents them as presets of one coach feature).
*Alternative rejected — one shared transcript with a persona dropdown per
message:* mixes personas inside one window; the provider port takes ONE
`personaId` per call, so a mixed transcript misattributes turns.

**Mount (two layers, both on the ADR-014 seam):**

1. **Paired-home coach tile** — the tile AND its inter-sibling spacer live
   INSIDE the gate's unlocked subtree:
   `PremiumGate(coupleId:, unlocked: Column[SizedBox(height: x6),
   _CoachTile(...)], locked: SizedBox.shrink())`. The locked branch renders
   NOTHING — no tile, no spacer, no pixel shift: the free tier sees zero
   coach surface AND every existing free-tier paired-home golden stays
   **byte-identical** (review finding: the `_PacksTile` precedent places
   its spacer unconditionally outside the gate, which would have
   re-baselined every free golden for an invisible feature). The tile
   follows the packs-tile placement (inside the question view only) and
   navigates via the exported `showCoach(context, {required uid, required
   coupleId})` helper (the `showPaywall` mold). Premium-tile presence is
   pinned by widget tests, not by new golden cells.
2. **The screen itself** — `CoachScreen` is a pushed route
   (`Scaffold(appBar: AppBar())` back affordance; auth-loss self-pop via
   the `authControllerProvider` listen idiom) whose body mounts
   `PremiumGate(coupleId:, unlocked: <chat>, locked: _CoachGatedView(...))`.
   The gated view exists for the mid-session downgrade (premium expires
   while the route is open): lock icon + honest copy + a
   `showPaywall(context, coupleId:)` CTA — the pack-selection `_GatedView`
   mold. A free user can never *reach* the screen (the tile is their only
   path and it renders nothing); the gated view is defense in depth, not a
   discovery surface.

The screen takes `{required String uid, required String coupleId}` (the
`PairedHomeScreen` construction mold).

**Language/register derivation — and its settling precondition** (review
finding: `language`/`register` are REQUIRED closed-enum wire fields; a send
fired before the profile resolves has no valid source). The chat body
layers on `profileStreamProvider(uid)` with the repo's AsyncValue-flag
idiom (the `PairedHomeScreen` layered-settling mold): loading → spinner;
error or null profile → the honest error state with retry; **the composer
is only constructible from a settled non-null profile**, so every send has
a derivable `language`/`register` by construction. From the settled
profile:

```dart
CoachRegister coachRegisterFor(ContentLanguage language, ContentRegister register) =>
    switch (language) {
      ContentLanguage.tr => register == ContentRegister.playful
          ? CoachRegister.trPlayful : CoachRegister.trRespectful,
      ContentLanguage.ar => CoachRegister.arGulfRespectful,
      ContentLanguage.en => CoachRegister.enNeutral,
    };
```

— a total pure function (unit-tested over the full 3×2 product). The wire
`language` field is `profile.contentLanguage.name` (verbatim match with the
server union). The app-side `CoachRegister` enum carries explicit wire
strings (`'tr-playful'` …) — enum `.name` is NOT the wire value here (the
hyphens make that impossible), so the DTO carries an explicit `wire` field,
the `QuestionRegister.msaGulf`/`'msa_gulf'` precedent.

## Decision 2 — Window construction + the help-sticky LATCH: transcript-derived, help-excluded, crisis-retained, client-latched

The client-owned window sent to `coachProxy` derives from the selected
persona's transcript by fixed rules:

1. **Only user and persona turns enter the window.** Help-path entries
   (`kind:'help'` responses) are UI artifacts of the safety system, not
   conversation turns — they are NEVER sent as `assistant` messages (a help
   text in an `assistant` slot would be forged conversation the provider
   never produced, and its crisis-adjacent vocabulary could trip the
   post-filter's lexicons on legitimate later turns… or worse, teach the
   persona to imitate the help voice).
2. **Crisis turns are RETAINED.** The window builder applies NO
   crisis-aware filtering: every confirmed user turn stays, including one
   that drew a help response. The client needs no knowledge of WHICH turn
   was a crisis (pre-scan and post-filter hits are indistinguishable
   client-side by design — the response carries no per-turn attribution),
   and retention keeps the server's pre-scan as a second net for
   pre-scan-detectable turns while they remain in the window. **Retention
   alone is NOT the stickiness mechanism** — the review's blocking
   finding: oldest-first trimming evicts the crisis turn after ~20
   subsequent turns, and a post-filter hit's window is pre-scan-negative
   by construction (the crisis text was in the DISCARDED model reply), so
   window contents cannot carry the guarantee. Stickiness is the latch's
   job (rule 3). Retention stays as defense in depth and transcript
   honesty, not as the safety guarantee.
3. **The help-sticky LATCH — the actual guarantee.** The persona's
   conversation state carries a `helpSticky` flag, **set whenever ANY
   response arrives with `kind:'help'`** (pre-scan, post-filter, or the
   fail-closed detector path — the client cannot and need not distinguish)
   and **cleared ONLY by the explicit "new conversation" affordance**.
   While latched:
   - the composer is replaced by a **paused panel**: the help state stays
     visible, honest copy explains that this conversation is paused for
     safety, and "start a new conversation" is the only forward action
     (ARB copy, native-review flagged);
   - **no further `coachProxy` calls can be issued from that
     conversation** — the guarantee is enforced client-side and does not
     depend on window contents, pre-scan re-detection, trimming order, or
     the provider's language. This closes BOTH blocking failure modes
     (trim-eviction and the post-filter class), makes the paused caption
     true by construction, and — a privacy bonus — stops re-transmitting
     the crisis text on subsequent calls entirely;
   - the quota caption is suppressed (Decision 6 — usage economics do not
     belong next to a crisis help card).
   The latch involves NO client-side crisis detection or lexicon
   knowledge: it reacts to the server's explicit `kind` discriminator.
   The safety policy stays server-owned; the client only honors the
   server's verdict durably. **Latch scope is per persona conversation**
   (the conversation is the safety unit ADR-016 pins): a fresh persona's
   thread is structurally identical to a post-reset thread, which this
   design already blesses, and per-message detection covers all new
   content anywhere — the cross-persona consequence is documented in
   Consequences, not discovered.
4. **The exit is explicit, not silent: the "new conversation" affordance**
   (per persona) clears that persona's transcript, its latch, and its
   quota hint — visible whenever the transcript is non-empty. A user whose
   crisis mention was conversational (a news story, a film) can
   deliberately start fresh; the reset is not an evasion vector because
   detection is per-call and normalization-based — a NEW conversation's
   messages are scanned exactly the same; only the latch of the OLD
   conversation ends.
5. **Bounds mirror the wire — enforced in wire units.** The window is the
   LAST `kCoachWindowMaxMessages = 20` eligible turns (including the new
   user message, which is always last and always role `'user'`),
   oldest-first trimming. Message length is validated server-side in
   UTF-16 code units (`raw.text.length` in JS), and Dart's
   `String.length` counts the same units — so the client gates in the
   SAME unit: the send action disables when `entry.length > 2000` (with
   an honest "too long" caption), and `LengthLimitingTextInputFormatter`
   remains only a UX convenience (review finding: the formatter counts
   grapheme clusters, so emoji/ZWJ-heavy text can pass it while exceeding
   the server bound — the formatter alone was an over-claim). Persona
   turns re-entering the window are server-generated and carry no length
   contract, so the window builder **truncates assistant-turn text to
   2,000 code units** defensively (context loss on a pathological reply is
   benign; user turns are never truncated — they already conform by the
   send gate). Empty/whitespace-only sends are disabled (trimmed, the
   `_entry` mold).

*Alternative rejected — drop crisis turns from subsequent windows:* resumes
persona coaching mid-crisis-conversation; requires client-side crisis
attribution that the wire deliberately does not provide. *Alternative
rejected — document the window-bounded stickiness instead of latching (one
verifier lens preferred this):* overruled by the governing docs — ADR-016's
asymmetry rule ("conservative everywhere") and rev 1's own rationale (a
silent persona resume mid-crisis-thread is "exactly what 'we are not
therapy' forbids") make the protective mechanism the only coherent
resolution, and the latch is cheap, attribution-free, and strictly
safer. *Alternative rejected — auto-clear the transcript after a help
response:* destroys the user's own words moments after a crisis disclosure
(hostile UX at the worst moment); the explicit affordance keeps agency
with the user.

## Decision 3 — Persistence: ephemeral in-memory this slice (the private-thread scope decision)

**No conversation content is persisted to any app-controlled storage — no
`coach_sessions`, no local database, nothing.** Transcripts (entries +
latch + quota hint) live in a `keepAlive` Riverpod family keyed by
`(uid, coupleId, personaId)`. Backgrounding survives (the family is
keepAlive); app restart clears; the route can be popped and re-pushed
without loss (the durable `PendingPurchase` precedent). Keying by `uid`
means a second account signing in on the same device gets fresh families —
no cross-user bleed through the UI.

**Teardown is explicit, not incidental** (review finding: keepAlive
providers survive route pops BY DESIGN — rev 1's "sign-out pops the route"
was not a teardown, so a sign-out→sign-in cycle within one process would
have resurrected the prior conversation and crisis text would linger
reachable): on any auth transition away from a signed-in user, the app
root **invalidates the coach transcript family wholesale**
(`ref.invalidate` of the family from the `HayatiApp` root listener idiom —
the `purchasesIdentitySyncProvider` mount precedent), in addition to the
route's self-pop. A test pins that a signed-out session's transcript is
GONE (fresh family state), not merely off-screen.

Scope of the claim, stated honestly: this is **zero retention in
app-controlled storage** and in-memory state torn down on sign-out.
Process-memory residue until GC/process death is not preventable in Dart
and is accepted; the OS app-switcher snapshot (the system images the
on-screen conversation to disk on backgrounding) is a real, documented
exposure that is NOT app-controlled storage — its mitigation
(snapshot-obscuring/secure-screen) is platform-channel work that belongs
to M6's device-privacy layer (PIN/biometric, discreet icon) and is
recorded there, not silently (Consequences + architecture §8).

Why ephemeral is the RIGHT scope now, not a deferral of convenience:

- **It is the most conservative KVKK/PDPL posture** — PRD §8's "never
  retained beyond session context window" is satisfied server-side (M5.1)
  AND in app-controlled storage client-side (this decision).
- **The DV threat model:** a persisted private thread on a shared/observed
  device is readable by whoever holds the phone; the app's device-privacy
  layer is M6 and unbuilt. Shipping persistence BEFORE the lock exists
  would be backwards.
- **Retention posture is the founder's privacy stance to set** (the resume
  prompt's stopping condition names it): TTL length, whether threads
  survive un-pairing, whether export/delete cascades cover them (M6 KVKK
  work) — all one decision bundle. The options are recorded in
  `operator-expected.md` this session (ephemeral-forever vs
  `coach_sessions/{uid}` per-user private thread, TTL-30d, self-read-only
  rules + mutation tests + no-partner-read pin + M6 cascade/export
  integration + the no-native-TTL note). Until answered, ephemeral.
- **`coach_sessions` stays an unmatched collection** in `firestore.rules`
  (default-deny; the header comment already lists it as deferred), so
  nothing can write it prematurely.

Cost, accepted and visible: a couple loses coach context on app restart.
At personal-use scale (ADR-007) this is a non-cost; it becomes a product
question exactly when the founder answers the retention question.

## Decision 4 — Disclaimer: ARB is the single home; shown before first use; ack persisted in a NEW local-flag seam

**Copy home:** the "not therapy" disclaimer moves to the app's ARB files
(`coachDisclaimer*` keys, TR/AR/EN) — the UI is its only consumer.
`help-content.ts` keeps ONLY the help-path response (which IS wire
content); its `disclaimer()` export and `DISCLAIMER` table are REMOVED in
the same commit that lands the ARB keys (single home, ADR-010 spirit; two
AI-drafted homes for one safety string WILL drift through the native
review; verified: `disclaimer()` has no non-test consumer). The functions
unit suite drops the disclaimer cases; the ★ operator item's pointer moves
accordingly (help response + lexicon in `functions/src/coach/`, disclaimer
in the ARB set). **The ADR-016 Decision 4 no-phone-number hard rule
survives the move** (review finding: the functions suite's `\d{3,}` guard
covered the disclaimer — an app-side test now asserts every `coach*` ARB
value in all three locales contains no phone-number-shaped digit run, so
the defense-in-depth check outlives the home change).

**Show semantics:** on first open of the coach surface (per user, per
device), the chat is replaced by a full **disclaimer view** — brandkit-warm
"not therapy" framing + a single acknowledge CTA. Until acknowledged,
nothing can be sent and no transcript renders (PRD F5 "disclaimer shown
before first coach use", literally enforced: the CTA gates the chat).
Acknowledgement is **persisted per device + uid** and never re-asked on
that device — except after reinstall/new device, where re-showing a safety
note is a feature, not a bug.

**Persistence home:** a NEW minimal local-flag seam —
`LocalFlagStore` (abstract) in `core/storage/` with a
`SharedPreferencesLocalFlagStore` implementation (`shared_preferences` is
added as the app's first local-persistence dependency), exposed through a
throw-until-overridden `@Riverpod(keepAlive: true)` provider bound in the
flavor entrypoints (the repository-seam discipline everywhere else; the
entrypoints are already async, so `SharedPreferences.getInstance()` is
awaited before `runHayati` and the store is bound by value), faked in
tests (`FakeLocalFlagStore` — platform-channel-free by construction). Key
shape: `coachDisclaimerAck.<uid>`.

**The uid-keyed flag's DV exposure, analyzed explicitly** (review finding,
verified then downgraded to a consistency note by the skeptic pass): the
flag is a uid-namespaced boolean inside the app's OS sandbox. A partner
signed in as themselves can neither reach the other's key through any UI
nor read the store without filesystem/backup/jailbreak access — access
that already exposes strictly more than this boolean. It records only
"opened at least once" — never frequency, timing, or content (the
signal ADR-016 D7's cap-lane split actually protects). The alternatives
are worse in the safety direction: a device-level key would SKIP the
disclaimer for the second partner on a shared device (under-showing a
safety note), and no persistence would re-prompt every launch against PRD
F5's "dismissal persisted". Accepted, with this analysis recorded.

*Alternative rejected — a `users/{uid}.coachDisclaimerAckAt` Firestore
field:* passes today's rules (no `hasOnly` on the profile block) but widens
the client-writable profile surface that M2-era reviews deliberately kept
narrow; records coach-adjacent metadata server-side that the M5.1 privacy
posture spent real effort NOT recording (data minimization: the server
currently cannot say whether a given user ever opened the coach — a
Firestore ack field would change that for zero functional gain); and
auto-syncs the ack across devices, silently skipping the safety note on
every new device. *Alternative rejected — in-memory only:* re-shows the
disclaimer every launch; PRD F5 says "dismissal persisted".

## Decision 5 — App-side wire taxonomy: coach-owned, code-first, total — and content-free by construction

`app/lib/features/coach/domain/coach_exception.dart` — a sealed
`CoachException` family, mapped in ONE data-layer choke point
(`mapCoachFailure`, the pairing `mapJoinFailure`/`_reasonOf` mold), by
CODE first, `details.reason` refinement second:

| Wire | Exception | UX (frozen contract → surface) |
|---|---|---|
| `permission-denied` | `CoachNotMemberException` | honest error state (should be unreachable: the screen only mounts with the caller's own coupleId) |
| `failed-precondition` (any reason) | `CoachNotPremiumException` | **paywall push** via `showPaywall(context, coupleId:)` + the gated inline state (the mirror will catch up through `PremiumGate`) |
| `resource-exhausted` + `'cap-daily'` | `CoachDailyCapException` | distinct copy: today's messages are used, come back tomorrow |
| `resource-exhausted` + `'cap-monthly'` | `CoachMonthlyCapException` | distinct copy: this month's shared limit is reached |
| `resource-exhausted` + `'rate-limited'` | `CoachRateLimitedException` | slow-down copy, immediate retry honest |
| `resource-exhausted`, reason absent/unknown | `CoachLimitReachedException` | neutral limit copy ("a limit was reached — try again later"): the channel dropped the reason, so the client claims neither "tomorrow" nor "this month" (never over-claim on a dropped detail) |
| `unavailable`, `deadline-exceeded` | `CoachUnavailableException` | honest unavailable state + retry affordance (provider outage and transport outage are indistinguishable client-side and share the UX) |
| `unauthenticated` | `CoachUnknownException` | unreachable in practice (auth-loss self-pops the route first); no dedicated surface |
| anything else (`invalid-argument`, `internal`, non-Functions throws) | `CoachUnknownException({code, message})` | generic honest failure copy |

`failed-precondition` maps to not-premium on CODE alone (reason is
confirmation, not requirement) — the server emits no other
`failed-precondition` on this callable, and the mapping must survive a
dropped `details` (ADR-016 rev-2 finding, discharged here).

The RESPONSE mapper (`coachReplyFromCallable`) is the pure/loud mold:
`kind` must be `'reply'|'help'`, `text` a non-empty string; `category` and
`remaining` optional with type-checked shapes; anything else throws
`FormatException`. **The conversion site is the repository** (review
finding: the controller catches ONLY `CoachException`, so a raw
`FormatException` must never escape the data layer): the repository wraps
the parse and converts `FormatException` →
`CoachUnknownException(code: 'malformed-response')` — the send path is
total over `CoachException` by construction, and a malformed body never
renders as a persona reply.

**The app-side no-content rule (ADR-016 Decision 8's client twin;
review finding).** Crashlytics collection is ON in prod and the global
error hooks forward every uncaught error's `toString()` — so the coach
path adopts the server's structural rule on the client: **no coach message
text, reply text, or window content may ever appear in an exception
message, a `CrashReporter.log` breadcrumb, or any `toString()` of coach
state that could escape.** Concretely: `FormatException`s in
`coachReplyFromCallable` interpolate ONLY `.runtimeType`/field names
(the `issuedInviteFromCallable` mold — verified it never interpolates
values); `mapCoachFailure`'s terminal fallback carries
`code: 'unexpected'` + the failure's `runtimeType` — NEVER the pairing
mold's `message: '$failure'` stringification (the one place that mold is
deliberately NOT copied); `CoachUnknownException.message` carries only
server-originated `FirebaseFunctionsException.message` strings (static by
ADR-016 D8) or null. A sentinel test (the server suite's analogue) seeds
marker text through every failure path and asserts no thrown exception's
`toString()` contains it.

## Decision 6 — Quota surface: response-hint only, display-only, DAILY-only

The UI renders remaining quota ONLY from the response `remaining` hint: no
live watch on `coachUsage` this slice. ADR-016 documents the watcher's
staleness trap (lazy resets mean a boundary-crossing client must re-derive
period keys via `coupleDayKey` to avoid rendering yesterday's exhausted
count) and explicitly blesses "prefer the response's `remaining` hint" —
the hint needs no dayKey math, no timezone read, and no new Firestore read
path.

**State home and transitions, pinned** (review finding: rev 1's transcript
entries carried no `remaining`, so the caption had no implementable home):
the transcript notifier's state carries a nullable `lastRemaining` record
alongside `entries` and `helpSticky`. It updates whenever a response
CARRIES `remaining` (persona reply, post-filter help — coach-proxy returns
it on every capped path) and is left unchanged by responses without it
(pre-scan help carries none); it resets to null on "new conversation".
The caption renders only when `lastRemaining` is non-null AND the
conversation is not latched (Decision 2: no usage economics next to a
crisis help card — pinned by a widget test). Before the first response
there is no hint and no caption (never fabricate a count).

**The caption renders `remaining.daily` ONLY.** The monthly figure derives
from the couple-shared bucket; a running monthly readout would let one
partner infer the other's usage by subtraction (skeptic-pass finding).
ADR-016 D7 deliberately made the monthly bucket member-readable ("genuinely
joint state"), so this is not a new *data* channel — but the UI need not
make the inference ambient, so monthly surfaces only in the
`cap-monthly` error state's copy (server-declared, no arithmetic shown).
At `remaining.daily == 0` the caption uses a dedicated non-plural
`coachQuotaExhausted` string (review finding: EN/TR have no CLDR `zero`
category — an ICU `zero{}` branch would never fire there; the repo's
special-count idiom is the language-independent `=N{}`/dedicated-string
form); positive counts use the plural `coachQuotaRemaining` with the full
AR CLDR set.

**The hint never gates sending.** An exhausted caption renders but the
input stays enabled: the hint is point-in-time (a partner's concurrent
turn stales it instantly; a day boundary un-caps without the client
knowing), and the server is the only authority — a send after exhaustion
gets the typed `cap-daily`/`cap-monthly` answer and its honest state.

*Deferred loudly:* a live `coachUsage` watch (with the client-side key
comparison obligation) becomes worth building only if the founder wants a
quota meter visible before the first message of the day — recorded, not
built.

## Decision 7 — Persona system prompts: server-side pure scaffolds, register-aware, unconsumed until the live adapter

`functions/src/coach/persona-prompts.ts` — a pure builder in the provider
path:

```ts
buildPersonaSystemPrompt(input: {
  personaId: CoachPersonaId; language: CoachLanguage; register: CoachRegister;
}): string
```

Composed EXCLUSIVELY from static literals keyed by the closed enums (the
signature admits no user content — the injection-closed posture of
ADR-016 Decision 5 extended to prompt construction; there is nothing to
sanitize because there is no interpolation site):

- a **shared safety preamble** (every persona): warm companion framing;
  NOT therapy, no medical/legal/psychological advice; never claim to be
  human; brief, concrete, couple-positive; never guilt (brandkit voice
  rules); respond only in the requested language.
- a **persona block** (PRD F5): Coach — communication help between
  partners; Date Genie — locale-aware date ideas; Gift Genie —
  occasion-aware gift ideas.
- a **register block** (brandkit §7): `tr-playful` arkadaşça, light
  playfulness allowed; `tr-respectful` warm-formal; `ar-gulf-respectful`
  formal-warm, family-safe Gulf register; `en-neutral` neutral-warm.
- a **language directive** naming the reply language explicitly (defense
  for the all-lexicon post-filter: the reply language is requested, never
  assumed).

The builder is TOTAL over the full 3×3×4 enum product — including
mismatched pairs the wire permits (`language:'en'` + `register:'tr-playful'`
passes validation by design; the scaffold must produce something coherent:
the language directive wins, the register tone note stays).

**Review tiers, corrected** (review finding: rev 1 put the whole prompt on
the tone tier while simultaneously claiming safety "lives in the
preamble" — self-contradictory, and PRD F5 designates "not therapy" and
"no medical/legal advice" as HARD guardrails, not tone): the preamble's
**safety-bearing lines** (not-therapy / no-medical-legal-psychological /
never-claim-human, per language) join the **★ BLOCKING native-review
gate** alongside the lexicon and help response — they are hard guardrails
with NO detector backstop (the crisis post-filter runs the
selfHarm/violence lexicons only and cannot catch a persona giving medical
advice or claiming humanity; stated here so no one assumes otherwise).
The persona and register TONE blocks stay on the standard copy tier (the
paywall-copy gate). Marked `nativeReview: PENDING` accordingly, per
section. Consumed by no production code this slice (the default provider
stays `UnconfiguredCoachProvider`); the M5.3 live adapter picks it up —
shipping it now fixes the contract while the copy goes through review.
Unit tests pin totality, non-emptiness, per-enum content markers, the
not-therapy line in every language, and zero interpolation surface (the
function's only inputs are enums — asserted by type, like `composePush`).

*Alternative rejected — scaffolds in the app, sent over the wire:* the
wire's `register` union was closed specifically so no free client text
flows toward a system prompt; client-side prompts would reopen that seam
at full width.

## Decision 8 — Transcript state + send discipline: server-ack, manual-op, no optimistic UI

- **Transcript model** (pure Dart): sealed `CoachTranscriptEntry` —
  `CoachUserTurn(text)`, `CoachPersonaTurn(text)`,
  `CoachHelpTurn(text, category?)`. The transcript notifier
  (`CoachTranscript`, the keepAlive family of Decision 3) holds
  `{entries, helpSticky, lastRemaining}` and appends **confirmed turns
  only**: on a successful send, the user turn + the response entry land
  together (plus the latch/hint updates of Decisions 2/6); nothing is
  appended while in flight, and a failed send leaves the transcript
  untouched with the draft still in the input (the M3.3 server-ack
  discipline — this codebase has no optimistic UI anywhere, and a chat
  bubble that later "un-sends" is worse than a spinner).
- **Send controller** (`CoachSendController`) is an **autoDispose family
  keyed `(uid, coupleId, personaId)`** — the same key as the transcript
  (review finding: rev 1 left the key unspecified; a global controller
  would let persona A's in-flight send block persona B, and a per-persona
  controller without the append rule below would LOSE a paid-for reply if
  the user switched personas mid-send and autoDispose tore the controller
  down before the await returned). Sealed state
  `CoachSendIdle | CoachSendSending | CoachSendFailure(CoachException)`;
  re-entrant sends dropped per persona while one is in flight; catches
  ONLY `CoachException`. **The transcript append survives controller
  disposal:** the controller captures its persona's keepAlive
  `CoachTranscript` notifier BEFORE the await and applies the exchange
  through that captured reference after the call returns — the keepAlive
  notifier outlives the route and the controller, so a mid-send persona
  switch or route pop still lands the reply (and its latch/hint effects)
  in the right conversation; `ref.mounted` guards only the controller's
  OWN state writes (the manual-op contract, `SoloAnswerController` mold).
  Success clears the input; failure keeps it (retry = tap send again; no
  auto-retry — the repo's `_noRetry` philosophy).
- **Help rendering is structurally distinct:** `CoachHelpTurn` renders as
  its own widget type (full-width card: alert-family styling per brandkit
  `alert`/`sand` tokens, safety icon, no persona chip/avatar) — never a
  chat bubble. Widget tests pin the TYPE distinction (`find.byType`), not
  just styling, so a refactor cannot quietly re-bubble the help path (the
  resume prompt's accept line). While latched, the paused panel (Decision
  2) replaces the composer beneath the transcript.
- **Persona reply bubbles** are visually attributed (persona label chip)
  and aligned with logical `start`/`end` only (RTL lint). Dynamic type to
  130% covered by the golden scale variants.
- **While sending:** input disabled + inline progress on the send button
  (the answer-save mold); `pumpAndSettle`-safe by completing fakes.

## Test commitments (pinned, not inferred)

1. `coachRegisterFor` total over `ContentLanguage × ContentRegister` (3×2);
   wire strings byte-equal to the server union (a fixture-free parity
   table in the app unit suite mirroring `COACH_REGISTERS`).
2. Window builder: ≤20 turns including the new last-user turn; help
   entries never enter; crisis turns never filtered (a transcript with a
   help entry still re-sends its user turns verbatim); oldest-first
   trimming; assistant turns truncated to 2,000 UTF-16 code units; user
   sends blocked above 2,000 code units (emoji/surrogate boundary case
   pinned); empty/whitespace sends impossible.
3. **The latch:** ANY `kind:'help'` response sets `helpSticky` (pre-scan
   shape without `remaining` AND post-filter shape with it); while
   latched the composer is replaced by the paused panel and **zero
   repository calls can be issued** (fake call log asserted empty across
   attempted interaction); the latch survives route pop/re-push (keepAlive)
   and persona switches away/back; "new conversation" clears exactly
   {entries, latch, hint} for the active persona and re-enables the
   composer; other personas' conversations are untouched.
4. `mapCoachFailure`: the full matrix of Decision 5 — every code × reason
   (present/absent/junk `details`) lands in exactly the documented member;
   non-Functions throws → `CoachUnknownException` with runtimeType-only
   content; `FormatException` from the parser converts to
   `CoachUnknownException(code: 'malformed-response')` inside the
   repository (nothing but `CoachException` escapes the data layer).
5. `coachReplyFromCallable`: valid reply/help shapes (with/without
   `category`/`remaining`), every malformed shape throws `FormatException`
   whose message interpolates only runtime types — plus the **no-content
   sentinel suite**: marker text seeded through every failure path never
   appears in any thrown exception's `toString()`.
6. Controller: re-entrant drop per persona (Completer-gated double-tap →
   one repo call), a persona-B send proceeds while persona A is in
   flight, mid-send persona switch still lands the reply in persona A's
   transcript (captured-notifier rule), `ref.mounted` teardown safety,
   failure keeps state/draft, success appends exactly [user, response].
7. Widget: disclaimer gates the chat until CTA (and persists — re-pump
   with the fake flag set skips it); profile loading → no composer;
   profile error/null → honest error state; send flow renders persona
   bubble from fixture reply; help turn renders the distinct TYPE (never
   the bubble type); each error state renders its copy (cap-daily ≠
   cap-monthly asserted as distinct strings); `not-premium` failure pushes
   `PaywallScreen`; auth-loss self-pops AND the transcript family is
   invalidated (fresh state on next build); persona switch swaps
   transcripts and windows; quota caption renders daily-only from the
   hint, uses `coachQuotaExhausted` at 0, is absent before the first
   response, is suppressed while latched, and never disables input.
8. Free-tier probes (the M4.2 suite extended): free couple → NO coach
   tile and NO spacer (the free paired-home goldens stay BYTE-IDENTICAL —
   no re-baseline in this slice), NO `CoachScreen` push anywhere in the
   daily answer flow; premium couple → tile present (widget-pinned);
   the live-mirror flip flips tile visibility BOTH directions (incl.
   past-expiry downgrade); the gift probe untouched.
9. Goldens: `coach_screen` × {`disclaimer`, `conversation`, `help_path`}
   × six cells + scale-130 naturals (27 PNGs), deterministic fixture
   transcript through the fake repo (the help_path cell shows the latched
   paused panel — the state a real crisis leaves behind).
10. ARB: every `coach*` key present in all three locales; no `coach*`
    value in any locale contains a phone-number-shaped digit run
    (`\d{3,}` — the ADR-016 D4 guard, ported app-side).
11. Functions (touched surface only): `persona-prompts` totality/content
    suite (36 enum combos; not-therapy line per language; static-literal
    construction); `help-content` suite updated for the disclaimer
    removal; full functions gate re-run green (80 hard).

## Docs-with-code checklist (this session's pass)

`architecture.md` §2 (coach feature dir goes live app-side), §4 (coach
flow: chat UI status, window rules + latch, ephemeral scope, disclaimer
home), §8 (client-side retention posture incl. the OS-snapshot note +
disclaimer ARB home + local-flag seam + the app-side no-content rule);
`test-suite.md` §1 (coach app rows: unit/widget/golden; functions row for
persona-prompts); `implementation-plan.md` (M5.2 entry);
`resume-prompt.md` (M5.3 next); `operator-expected.md` (persona-prompt
safety lines join the ★ gate; tone blocks + coach ARB copy join the
standard native-review scope; the private-thread founder decision recorded
with options; ★ item pointer updated for the disclaimer move);
`past-prompts.md` (Session 019 entry).

## Consequences

**Positive**

- The couple-facing coach ships end-to-end against the emulator with zero
  live calls, zero new server surface (persona scaffolds are pure,
  unconsumed), zero persistence — the smallest honest slice that makes the
  frozen contract renderable.
- **The help-sticky guarantee is now real**: latched client-side on the
  server's explicit `kind` signal, independent of window contents,
  trimming, or which filter fired — and once latched, crisis text is
  never re-transmitted because no further calls leave the conversation.
- Every frozen wire outcome has exactly one typed exception and one
  surface; a dropped `details.reason` degrades to honest-generic copy,
  never to a wrong claim; nothing but `CoachException` escapes the data
  layer, and no exception can carry conversation content into Crashlytics.
- The free tier's zero-coach-surface guarantee is structural (locked =
  nothing, spacer included) AND assertion-pinned, with free goldens
  byte-identical.
- The disclaimer gains one home, one review surface, a ported
  no-phone-number guard, and a per-device re-show property that favors
  safety.

**Negative / accepted trade-offs**

- **Transcripts die on restart** (ephemeral scope). Deliberate; the
  founder owns the retention decision (operator-expected).
- **Latched conversations cost persona replies until the user starts
  fresh** — the over-trigger direction, accepted per the asymmetry rule.
  A benign mention (a news story) latches the conversation; the explicit
  reset is one tap away.
- **The latch is per persona conversation.** A user who latched Coach can
  chat with Date Genie — structurally identical to starting a new
  conversation, which the design blesses; per-message detection covers
  all new content. Documented, not discovered (review finding accepted
  as designed).
- **Process-memory residue and the OS app-switcher snapshot** are outside
  app-controlled storage: RAM is cleared on sign-out invalidation but not
  scrubable; the snapshot mitigation (secure-screen/obscuring) rides M6's
  device-privacy layer. Recorded loudly here and in architecture §8.
- **A new dependency** (`shared_preferences`) enters for one flag. The
  seam keeps it swappable; the empty `core/storage/` dir existed for this.
  The uid-keyed ack flag's on-device metadata exposure is analyzed and
  accepted in Decision 4.
- **The server loses its disclaimer export** — a consumer that never
  existed; if a future surface needs server-delivered disclaimers (e.g.
  web), the ARB→server move reverses with the same single-home rule.
- **Quota visibility starts at the first response** (no meter before the
  day's first message), renders daily-only, and goes quiet in help
  states. Deferred/shaped loudly, not silently.
- **Persona scaffold copy ships unreviewed** (nativeReview: PENDING per
  tier) and unconsumed; it cannot affect any user until the live adapter
  lands, by which time both review gates apply.

**Neutral**

- The live provider adapter (+ `LLM_API_KEY`), `coach_sessions`
  persistence, hotline numbers (★), Remote-Config caps, and any coach
  analytics event remain out of scope, unchanged from ADR-016's deferrals.
- `coach_msg` analytics, when built (M6), inherits `logCoachEvent`'s
  typed-fields shape (ADR-016 binding) — nothing in this slice loosens it.
- Review findings adjudicated but NOT taken as-is (recorded per the S017
  discipline): the monthly-remaining "new inference channel" claim was
  scoped by ADR-016 D7 (the bucket is deliberately member-readable — the
  UI change is minimization, not leak-closure); the device-level
  disclaimer key proposal was rejected because it under-shows a safety
  note to the second partner (Decision 4's analysis); "document bounded
  stickiness instead of latching" was overruled by the governing docs
  (Decision 2).
