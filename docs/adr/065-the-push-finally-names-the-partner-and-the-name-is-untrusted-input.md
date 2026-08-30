# ADR-065: the push finally names the partner, and the name is untrusted input

- **Status:** Accepted — **revision 2** (2026-08-30, Session 089), after the design pass; still **before** the code
- **Date:** 2026-08-30 (Session 089)
- **Deciders:** session agent (the wiring, the source of the name and the hardening are all device-independent and emulator-provable; the one thing that is not — whether any of it reaches a phone — is blocked on billing and is stated, not guessed)
- **Related:** **ADR-012 D3** (the push policy, the discreet mode, the injectable `MessagingPort`), **ADR-059** (the bidi correctness of the named copy, and `sanitizePushName` — **D3's invariant is given a mechanism here**), **ADR-033** (isolate for rendering, never for outgoing text), **ADR-053** (generated bidi ranges — and why the set enumerated here is *not* that), **ADR-058 / #226** (the version-3 privacy draft, corrected here in the same diff), **ADR-063 D8** (assert what the port RECEIVES), **ADR-019 D6** (the per-user discreet override), issues **#253** (this one), **#136** (whose seam this activates)

> **Review status.** Revision 1 was written and committed **before** the fix
> (`session-context.md` §5 item 1, lesson **115**). **The design pass has now
> run** — 5 lenses × 2 independent verifiers + a completeness critic, **22
> agents, 0 errored, 0 empty results, 0 skipped**, 8 lens findings + 5 critic
> findings, **nothing dropped unverified**. Revision 2 is what it produced. The
> built-diff pass has not run yet.
>
> ⚠️ **The aggregation surfaced ZERO of the 8 lens findings, and that verdict is
> overridden here rather than obeyed.** Both verifiers refuted all eight with
> `confidence: high`, and reading the refutations shows why: nearly every one
> argues *"no governing document requires an ADR to specify this"* — a question
> about ADR completeness standards, not about whether the finding is TRUE. Two
> concede the fact outright (*"The finding's technical observation is correct …
> However, this is NOT a design deficiency"*). I re-measured the load-bearing
> ones myself (lesson **123**, and lesson **135** — a refutation is a claim too)
> and six were true and worth fixing. The harness defect is recorded as lesson
> **137**: a verifier asked *"is this mandated?"* will refute every true finding
> that no rule happens to cover, and a 12/12-refuted distribution is a signal
> about the question, not about the design.
>
> **The completeness critic, whose findings do not pass through that
> aggregation, found the one thing in this ADR that was simply false.**

> ⚠️ **This ADR contradicts the objective it was given, on one point of fact, and
> says so rather than absorbing it.** `resume-prompt.md` for S089 specifies the
> name comes from *"the partner's `users/{uid}` document — which field"*. There is
> no such field and there never was: `users/{uid}` stores **no name by design**,
> which `auth_repository.dart:47` states in as many words and which the write
> sites confirm. Decision 1 is what the measurement says instead. The rest of the
> assigned acceptance criteria stand unchanged.

## Context — measured, 2026-08-30

### The gap, restated from the code rather than from the issue

`composePush` accepts `partnerName`; `partnerAnsweredNormal` has named copy in
all three languages; **no production caller passes one.** Both senders omit it:

```ts
// reveal-service.ts:341                 // sweep-push.ts:80
composePush({ kind, language,            composePush({ kind, language,
  discreet });                             discreet, streakCount });
```

So every `partnerAnswered` push ever composed used the name-free variant, and
ADR-059's `sanitizePushName` — written to stop a partner's name choosing the
paragraph direction — sits in a branch nothing reaches. That is #253, and it is
the last piece of the notification feature that is *wrong* rather than *unshipped*.

**Only one sender can produce this kind.** `grep -rn "'partnerAnswered'"` over
`functions/src` returns `reveal-service.ts:272` and `payload-policy.ts` and
nothing else; the sweep's two passes compose `dailyQuestion` and `streakAtRisk`.
So this is a **one-call-site change**, and there is no fan-out anywhere: the
trigger fires once per answer create and sends to exactly one recipient.

### Finding 1 — there is no name in `users/{uid}`, and the shipped precedent reads Auth

The user document carries `status`, `contentLanguage`, `register`, `createdAt`,
`coupleId`, `coupleEnded`, `notificationPrivacy`, `consent`, `fcmTokens`,
`pushDiagnostic`. No name field is written by any of the sixteen
`collection('users')` sites in `functions/src`, nor by `profile_dto.dart`.
`auth_repository.dart:47` says why, and names the consumer:

> Writes `displayName` onto the signed-in user's AUTH record — the exact surface
> the zero-auth invite preview resolves the inviter's name from
> (`invite-preview.ts` reads `getUser(uid).displayName`; `users/{uid}` stores no
> name by design).

So the name exists, in exactly one place, and **this repo already reads it that
way once**: `invite-preview.ts:80-84`'s `authCreatorName`, an injectable
`CreatorNameLookup` whose production default is
`getAuth().getUser(uid).then(u => u.displayName)` and whose failure never
downgrades the surrounding result. That is the shape to copy.

### Finding 2 — the word "partner" means opposite things at the two seams

In `reveal-service.ts`, `partnerUid` is the **partner of the author** — i.e. the
**recipient**. In `payload-policy.ts`, `partnerName` is the **recipient's
partner** — i.e. the **author**. The name to interpolate is therefore
`event.authorUid`'s, *not* `tx.partnerUid`'s, and the two identifiers sit four
lines apart in the same function. This is the single most likely way to build
this wrong, and building it wrong would send each person their **own** name.

### Finding 3 — a display name is untrusted, client-writable input, and three things survive the sanitiser

`displayName` is not a server-owned field. It lives on the Auth record, and the
Firebase Auth **client** SDK's `updateProfile` lets a signed-in user set their own
to an arbitrary string. So the string that Decision 1 routes into the partner's
lock screen is chosen by the other member of the couple.

> ⚠️ **Revision 1 said `name_capture_screen.dart` has "no `maxLength`". That was
> false, and the completeness critic caught it.** The screen caps input at
> **50** (`nameCaptureMaxLength`, applied through a
> `LengthLimitingTextInputFormatter`, lines 16 and 112). The error came from a
> **case-sensitive grep**: `grep -rn "maxLength"` over
> `app/lib/features/profile/` returns **0** lines, `grep -rni` returns **2**, and
> an empty result was read as an absent fact. Recorded as lesson **138**.
>
> **The conclusion survives the correction, and the reason is the second half of
> the original sentence.** A client-side formatter is a keyboard bound, not a
> write bound: `updateProfile` is callable directly by any signed-in client, so
> the server may not treat 50 as a guarantee. What the correction *does* change
> is Decision 3c's number — see there.

`sanitizePushName` was designed for one axis — bidi neutrals at the **edges** of
the name, in **RTL copy only** — and it does that correctly. It was never asked
about the rest. Measured by driving the shipped function directly (probe run
2026-08-30 against `functions/src/notifications/sanitize-push-name.ts`, output
below verbatim):

| input | `sanitizePushName(…, 'en')` | why it matters |
|---|---|---|
| `Aylin\n\nSecurity alert: verify at evil.example` | **unchanged** | |
| the same, `'ar'` | **unchanged** | |
| `Ay<U+202E>lin` (RLO mid-string) | **unchanged**, in `en` *and* `ar` | |
| `Aylin<U+202E>` (RLO trailing) | **unchanged** under `en` | edge trim runs for `ar` only |
| `Ay<U+2068>lin<U+2069>` (FSI/PDI) | **unchanged** | |
| `'A' × 500` | **unchanged**, length 500 | |

and the composed payload for the first row is, verbatim:

```
title: "Your partner Aylin\n\nSecurity alert: verify at evil.example answered"
body:  "Your partner Aylin\n\nSecurity alert: verify at evil.example answered
        today's question. Open ikimiz to add yours."
```

Three distinct defects, none of them live today because the branch is
unreachable, **all three of which Decision 1 would ship if it landed alone**:

1. **Line-break injection.** A name carrying `\n` puts attacker-chosen lines on
   another person's lock screen, under our app's name, in the visual position a
   system message occupies. Nothing in the product tells the reader that the
   second line was typed by their partner. This is the one that is a *security*
   defect rather than a rendering one, and it is why this ADR exists at all
   rather than being a two-line wiring change.
2. **Explicit bidi controls survive.** `U+202E` (RLO) mid-name reverses the
   remainder of the sentence; it survives in both languages. And
   `U+2068`/`U+2069` survive — which makes **ADR-059 D3 false as written**.
   D3 says *"No `U+2068`/`U+2069` enters a push payload"*, and its mechanism is
   an **abstention**: we decided not to *add* isolates. An abstention is a
   complete mechanism only while no external string can carry them. Decision 1
   is precisely the change that makes one able to.
3. **No length bound.** 500 characters compose a 1088-byte payload. FCM/APNs cap
   a payload around 4KB, so a long enough name does not merely look bad — it
   makes the send **fail**, and `deliverPush` counts that as `send-failed`,
   i.e. the partner silently receives nothing at all.

### Finding 4 — the discreet promise holds, asserted rather than assumed

`resolveDiscreet(language, notificationPrivacy)` returns true iff
`notificationPrivacy === 'discreet'` **or** `contentLanguage === 'ar'`
(`recipients.ts:26`) — so discreet is ON by default for every Arabic-reading
recipient (PRD F6) and opt-in elsewhere (ADR-019 D6). `composePush` returns
`{APP_NAME, DISCREET_BODY[language]}` **before** the kind switch, so
`partnerName` is not merely ignored in discreet mode, it is **unreachable**:
there is no code path from the parameter to the payload. That is a structural
guarantee, and it is the pre-existing one this ADR must not weaken.

## Decision 1 — The name is the author's Auth `displayName`, read through an injectable lookup

`reveal-service.ts` resolves the name of **`event.authorUid`** — the member who
just answered — via a `PartnerNameLookup` seam whose production default is
`getAuth().getUser(uid).then(u => u.displayName)`, the same call
`invite-preview.ts` already makes. It is injected on `RevealServiceDeps`, like
`now` and `beforeWrite`, and threaded through `OnAnswerCreatedDeps` so the trigger
factory can fake it too.

Not a Firestore field, and this ADR does not add one. Mirroring the name into
`users/{uid}` would be a second copy of a mutable personal datum, a new
server-owned field with its own rules freeze, its own deletion-cascade entry, its
own export lane entry and its own staleness bug. The Auth record is where the
product already decided this lives.

**The lookup's failures are never the push's failures.** It gets its **own**
`try/catch` returning `undefined`, not the ambient one: `deliverPush`'s outer
`catch` returns `send-failed`, so letting a name lookup throw into it would
convert *"we could not find out their name"* into *"the notification was not
sent"*. A deleted author, an unavailable Auth backend, an absent `displayName`
(Sign in with Apple's private relay routinely has none) all resolve to
`undefined`, which routes to the name-free copy that is already written, already
shipped and already tested.

**It logs, because a silent degradation is indistinguishable from a broken
lookup.** `deliverPush` already has six logger calls covering every skip it can
take, and the critic was right that a seventh failure mode without one leaves an
operator unable to tell *"Auth was unreachable"* from *"they have no name"* from
*"the sanitiser rejected what they had"*. A lookup that **throws** logs
`warn` with the author uid and the error — the `invite-preview.ts:121` precedent
verbatim. A lookup that **succeeds with no usable name** logs nothing: that is
the ordinary case for every Sign in with Apple private-relay account, and a warn
per push for the normal state is how a log stops being read.

## Decision 2 — The lookup happens only where its result can be used

Inside `deliverPush`, after the recipient's user document, the token check, the
timezone/quiet-hours guards **and** the discreet resolution, and only when a name
is wanted at all.

**The signature, stated rather than left to a builder to infer.** Revision 1 said
only *"inside `deliverPush`"*, and `deliverPush` receives `recipientUid` — not
`event.authorUid`, whose name is the one wanted. The design review's mechanism
lens called that blocking; both verifiers refuted it on the ground that no rule
obliges an ADR to enumerate parameters. They are right about the rule and wrong
about the cost: Finding 2 says the uid confusion is *the* way to build this
wrong, and an ADR that leaves the uid to be inferred is an ADR that leaves
Finding 2 to be re-derived. So:

```ts
async function deliverPush(
  db, messaging, recipientUid, kind, timezone, now,
  naming?: { uid: string; lookup: PartnerNameLookup },   // ← new, optional
): Promise<PushOutcome>
```

and at the two call sites in `handleAnswerCreated`, where `authorUid` is already
destructured from `event`:

```ts
// reveal → no name in the copy, so nothing to look up
deliverPush(db, messaging, tx.partnerUid, 'reveal', tx.timezone, now);
// partnerAnswered → the name of the person who ANSWERED
deliverPush(db, messaging, tx.partnerUid, 'partnerAnswered', tx.timezone, now,
            { uid: authorUid, lookup });
```

**Passing `naming` only where a name belongs makes "one kind resolves a name" a
property of the call sites rather than a `kind === 'partnerAnswered'` test inside
`deliverPush`** — there is no condition for a later edit to drift away from, and
the `reveal` path cannot acquire a lookup by accident. The seam itself rides
`RevealServiceDeps` beside `now` and `beforeWrite`.

⚠️ **`makeOnAnswerCreatedHandler` destructures its deps and forwards
`{ now, beforeWrite }` explicitly.** Adding the seam to the *interface* without
adding it to *both* the destructure and that forwarded object leaves the
injection inert while every service-level test still passes — green, and wrong.
Decision 4 pins it at the handler layer for that reason.

That ordering is the entire cost argument:

* **`reveal` pushes add nothing** — the kind takes no name.
* **Every discreet recipient adds nothing**, which is *every Arabic-reading user
  by default*. The privacy setting and the cost saving are the same branch.
* **No-token, no-user-doc and quiet-hours recipients add nothing** — those return
  before composition.
* What remains is **at most one Auth `getUser` per `partnerAnswered` push that
  will actually be composed with a name**, on a trigger that fires once per
  answer create for one recipient.

**ADR-012 §10's cost shape is unchanged, and the reason is not "it is small".**
That budget counts *Firestore document reads per couple per sweep*. This is not a
Firestore read; it is an Auth admin API call, a different quota with a different
price (zero, at Firebase Auth's current terms) and a different failure mode
(handled in Decision 1). The honest statement is that a **new dependency** is
added to the reveal trigger's hot path, not a new Firestore read — and its
failure is contained rather than propagated.

## Decision 3 — `sanitizePushName` becomes the one gate, and gains four rules

All hardening lands in `sanitize-push-name.ts` rather than at the call site. One
function decides whether a name is usable, so the next caller inherits the
decision instead of re-deriving it. In order:

**3a — Separators become a space; invisibles are deleted.** After the existing
trim, map every character in Unicode general category **`Cc`** (the C0/C1
controls, which is where `\n`, `\r` and `\t` live), **`Zl`** and **`Zp`** to a
single space; **delete** every character in **`Cf`** *except* **`U+200C` ZWNJ**
and **`U+200D` ZWJ**; then collapse every whitespace run (including `\p{Zs}`, so
`U+00A0` and `U+3000` too) to one `U+0020` and re-trim.

* **The two halves map differently, and revision 1 got it wrong.** It said
  *"remove"* for both. Measured: deleting `\n` turns
  `Aylin\nSecurity` into `AylinSecurity` — two words silently welded into one
  nobody typed. Separators separate, so they become a space; format characters
  occupy no width, so a space would invent one.
* Expressed as Unicode **properties**, not a hand-rolled range (lesson **124**,
  ADR-053). `\p{Cf}` is what makes it durable: it covers all twelve UAX #9
  explicit formatting characters (`U+061C`, `U+200E`, `U+200F`, `U+202A`–`U+202E`,
  `U+2066`–`U+2069`) **and** the invisibles an enumeration would have missed —
  `U+00AD` soft hyphen, `U+2060` word joiner, `U+FEFF`, and `U+FFF9`–`U+FFFB`,
  the interlinear annotation characters, which exist to hide text behind text.
* **ZWNJ and ZWJ are the deliberate exceptions.** ZWNJ is orthographically
  required in Persian and Urdu and is not decoration; ZWJ joins emoji sequences.
  Neither can introduce a line or reorder a paragraph, which is what 3a is about.
* ⚠️ **The regexes that are `.test()`ed must be NON-GLOBAL.** A `/g` regex
  carries `lastIndex` between `.test()` calls, so alternate matches are skipped.
  Measured while designing this: the two-newline case came back with **one
  newline still in it** — a strip that reads exactly like a working strip.
  Lesson **136**.

**3b — Cap consecutive combining marks at 8.** A run of more than eight
`\p{M}` characters between base characters is truncated to eight.

*This one the review refuted, and it is adopted anyway in a milder form.* The
refutation is substantively right on its own terms: a combining-mark smear
injects no line, reorders no text, and inflates no payload past 4KB, so it
breaches none of 3a's or 3c's stated bounds — and the refuter's warning that
stripping `\p{M}` would damage `José` in NFD is exactly the principle this ADR
argues elsewhere. But the rule adopted is not *"strip marks"*; it is *"stop a run
at eight"*, and the difference is measurable. Measured against real orthography:
**fully-pointed Hebrew, Hebrew with cantillation, Vietnamese precomposed and
decomposed, `José` in NFD, Arabic with full tashkeel, Thai and Devanagari are all
byte-unchanged at a cap of 4 — none of them reaches four consecutive marks on one
base.** The cap is set at **8** rather than 4 purely as margin, because it costs
nothing measured. A 1000-mark name becomes 13 code points instead of being
rejected outright by 3c, which is a *better* degradation, not merely a safer one.

**3c — Cap the length at 64 code points, and degrade rather than truncate.**
Measured after 3a and 3b, **before** the RTL edge trim: over 64, return
`undefined`.

* **64, not revision 1's 48.** The critic's correction to Finding 3 is what moved
  it: the name-capture screen caps input at **50**, so a 48-code-point server
  bound would silently discard names the app itself invites people to type — the
  app and the server disagreeing about what a name is, with the server winning in
  silence. 64 sits above the client's bound with headroom.
* **Before the trim, so the decision is language-independent.** Whether a name is
  usable *at all* must not depend on the copy's direction; only its *edge
  trimming* does.
* **A product bound, deliberately not the safety bound** — the safety bound is
  3a. Because it is not load-bearing, a value slightly wrong costs a name-free
  push, not a broken one. It also bounds the payload: 64 code points is at most
  **256 UTF-8 bytes**, far under the ~4KB FCM/APNs ceiling a long name would
  breach, and a breach there is a *failed send*, not a cosmetic problem.
* **Degrade, do not truncate.** Truncation invents a name its owner does not
  have, and doing it safely means not splitting a grapheme cluster — machinery
  bought to produce a worse string. The name-free copy is already correct.

**3d — The contract is restated.** `sanitizePushName` returns *"a name safe to
interpolate into outgoing push copy, or `undefined`"* — no longer *"a name with
its RTL edge neutrals trimmed"*. Bidi is now one of its four concerns.

**This is what gives ADR-059 D3 a mechanism.** D3's invariant — no `U+2068`/
`U+2069` in a push payload — stops being a promise we keep by not acting and
becomes one the code enforces on input it does not control. D3 is not
contradicted; it is completed, and its reasoning (*"isolate for rendering, never
for outgoing text"*, ADR-033) is what makes stripping them correct rather than
merely safe.

### What sanitising can and cannot bound

**It bounds the FORM of the name and not its CONTENT, and the difference must be
said out loud rather than left for a reader to assume the strip covers both.**
After 3a–3c a name cannot add a line, cannot reorder the sentence around it,
cannot hide text behind other text and cannot fail the send. It can still *say
something*: a partner may set their display name to `Security Alert` using no
special character at all, and no sanitiser can distinguish that from a person
named for a job. What bounds content is elsewhere and is already built — the
discreet setting removes the name entirely, and the name is rendered inside our
own sentence, in the grammatical position a name occupies, never on a line of its
own. Decision 5's privacy copy says the name is the partner's own, unverified by
us, for exactly this reason.

## Decision 4 — The proof is end to end, asserts the payload, and pins the direction

The existing unit suites keep their scope. What is new — four of the design
pass's eight findings landed here, which is itself the signal that this was the
weakest section of revision 1.

**The two mechanisms, and which claim each one proves.** Revision 1 mandated a
real Auth record (4.1) *and* an assertion that the lookup was never called (4.6),
which cannot both hold in one test: "not called" is observable only through an
injected double. They are separated rather than reconciled:

* **Integration proof — no injection.** `handleAnswerCreated` runs with the
  production default, so `getAuth().getUser()` really executes against the auth
  emulator and the production lookup shape is the thing under test. This is what
  covers `authPartnerName`, exactly as `invite-preview.test.ts` covers
  `authCreatorName`.
* **Ordering and negative proofs — injected counting fake.** "The lookup was not
  called" for a discreet recipient, for the `reveal` kind, and for a
  token-less recipient are assertions about *when* we spend the call, and they
  need a double that counts.

**The setup that makes the integration proof possible at all.**
`reveal-service.test.ts` builds only the named `no-trigger` app, so there is no
`[DEFAULT]` app and `getAuth()` throws *"The default Firebase app does not
exist"* — **measured, not assumed**. The suite therefore adopts the pattern
already shipped in `deletion-service.test.ts:28-32`: Firestore stays on
`demo-hayati-notrigger` for trigger isolation, while a guarded
`initializeApp({ projectId: EMULATOR_PROJECT_ID })` gives Auth the default
project. *(That same throw is why every **existing** reveal test stays green
through this change — they exercise the degradation path. Which is precisely why
they are not evidence of anything, and these tests are needed.)*

Then:

1. **Assert what the port RECEIVES** (ADR-063 **D8**): the `FakeMessagingPort`'s
   `{title, body}` must be the *named* copy in the recipient's language, not
   merely that a send occurred.
2. **The expected name is a LITERAL in the test, never computed from
   `composePush` with the uid the production code used.** An oracle derived from
   the code under test cannot detect the code choosing the wrong uid — it would
   choose the same wrong uid. This is what makes finding 5 of the review real
   even though both verifiers refuted it.
3. **Finding 2 is pinned by construction.** The two members get display names in
   **different scripts** — `Alice` and `أيلين` — so a `partnerUid`-for-`authorUid`
   swap produces a visibly wrong string rather than a differently-spelled right
   one, and the RTL name is simultaneously the fixture 4 below needs.
4. **`sanitizePushName`'s bidi property is asserted at the seam that now reaches
   it**, not only in its own unit test: an author named `أيلين` delivered to an
   `en` recipient must produce copy whose first strong character came from the
   copy (the ADR-059 D4.1 rule), asserted on the payload the port received.
5. **Each of Finding 3's defects gets an assertion at the seam**: a name with
   `\n` produces a single-line payload whose words are not welded; names with
   `U+202E` and with `U+2068`/`U+2069` produce payloads containing neither; a
   500-character name and a 1000-mark name each produce the byte-identical
   **name-free** payload.
6. **The Auth lookup's failure is proven, not just specified.** A seam that
   **throws** must produce the name-free payload and a `status: 'sent'` outcome —
   never `send-failed`. Decision 1 makes that claim and revision 1's test plan
   did not carry it; the precedent is
   `invite-preview-handler.test.ts:214`. A seam that resolves `undefined` gets
   the same assertion.
7. **The discreet path is asserted twice** — that an AR recipient's payload is
   the generic one, *and* that the lookup was **not called**. The second is the
   one a refactor breaks silently.
8. **The handler layer pins the threading.** An injected lookup must be the one
   that runs through `makeOnAnswerCreatedHandler`, or the deps-destructure trap
   in Decision 2 ships green.
9. **Mutation-checked, and the mutant checked** (lesson **112**): removing 3a's
   strip, removing 3b's mark cap, and swapping `authorUid` for `partnerUid` must
   each redden a *named* assertion; each mutation is confirmed to change
   behaviour rather than be a no-op.
10. **A floor on the input** (lesson **110**): the number of cases the value
    table walks is asserted, so a matcher that matched nothing cannot report a
    clean zero.

## Decision 5 — The version-3 privacy draft is corrected in the same diff

`docs/legal/proposed/privacy-policy.{en,tr,ar}.md` currently says, in each locale:

> No notification names anyone. The app carries copy that would name your partner
> — as in "Your partner Aylin answered" — but nothing supplies the name to it, so
> every notification we could send today says "your partner" instead. **If that
> ever changes**, the discreet-notifications setting is what takes the name away
> again …

Decision 1 *is* "that ever changes". The sentence was written by ADR-059 D5 to
correct ADR-058's draft toward what was then true, and this session makes it false
again — which is the same defect class, one session later, and exactly what the
document exists to prevent. The bullet is rewritten in all three locales to say
that a notification about your partner's answer **does** carry their name, that
the discreet setting removes it, that it is on by default in Arabic, and that the
name comes from what the partner themselves entered.

**The replacement is quoted here rather than described**, because the critic was
right that a described edit cannot be reviewed — a rewrite that drifts from its
own acceptance criteria would pass unnoticed. English:

> One of the four notifications names your partner: the one telling you they have
> answered today's question. It reads "Your partner Aylin answered", using the
> name your partner entered themselves — we do not check it, and if they entered
> none it says "your partner" instead. That name is the only personal detail of
> theirs that any notification carries. The discreet-notifications setting takes
> it away again: with it on, a notification says only that something is waiting
> for you — no name, no event, no streak count. It is on by default when your
> question language is Arabic, and you can switch it on in any language.

The Turkish is the same sentence. **The Arabic carries one clause the other two
must not**, and it is a consequence rather than a translation choice:
`resolveDiscreet` returns true for `contentLanguage === 'ar'` and the v1 override
is opt-**in** only, so for an Arabic-reading recipient the named copy is not
merely off by default — it is **unreachable**. The Arabic bullet says so
(*"…أي أن هذا الاسم لا يظهر لكم ما دامت لغة أسئلتكم العربية"*); the English and
Turkish do not, because for their readers it would be false.

The draft is **not** the shipped notice: `docs/legal/proposed/` is a version-3
draft awaiting the founder and the lawyer (**#226**), and `app/assets/legal/`
still carries version 2. Nothing here lands a consent re-gate or changes what a
user has agreed to; it keeps the un-landed draft honest so that when #226 is
taken up, the document describes the system that exists.

`legal_proposal_test.dart` guards the draft's SHAPE — a 90–160 line floor and
ceiling, the localised version line, section parity across locales, and the
v2 anchor sentences being absent from the draft and present in the shipped
document. The edit is bullet-for-bullet (the files stay at 104 lines) and touches
no anchor. **Revision 1 asserted that the test "continues to pass"; the critic
noted that was a claim about code that did not exist yet. It is therefore an
acceptance criterion of this ADR, not an aside: the diff runs it.**

## Consequences

* **The named copy becomes reachable for the first time**, and with it ADR-059's
  entire body of work — including the bidi property that has never been exercised
  outside its own unit test. #136's autonomous half gets its first real exercise.
* **Turkish- and English-reading users start receiving a named push by default.**
  Today every user of every language gets the name-free copy, because no caller
  supplies a name; after this, the default for `tr` and `en` is a lock screen that
  says who answered. Arabic readers are unaffected — discreet is on for them by
  default and is not overridable downward. A `tr`/`en` user who needs the name
  hidden must switch discreet on themselves, which is the setting working as ADR-012
  and ADR-019 D6 designed it, and is not a new control this change owes them.
  *(The design review raised this and both verifiers refuted it — correctly, on
  the narrow question of whether any governing document mandates saying it. It is
  said anyway: it is the most user-visible consequence of the change, and
  Consequences is where a reader looks for it.)*
* **Nothing can be observed on a phone.** Production has been down since
  2026-08-22 (billing account `012195-7EF76F-3A9083` is closed;
  `prod_pulse.py --from-firebase-cli` **exits 1** as of this session, last
  completed sweep 2026-08-25T15:00:11Z), and **0 of 4** accounts have ever
  registered a device (`push_delivery_probe.py --from-firebase-cli` **exits 1**,
  four *"no report"*). Both are operator items, neither is this session's. The
  work is correct or not regardless, and it is proven in the emulator — which is
  the only place any of the notification feature has ever been proven.
* **A new dependency on the reveal trigger's hot path.** Auth is now reachable
  from the answer-created path; if it is unavailable, pushes go out name-free
  rather than not at all.
* **`sanitizePushName` is now load-bearing for safety, not only for rendering.**
  It is the only thing between a partner-chosen string and another person's lock
  screen. Its unit test is a security test now, and should be read as one.
* **The `48` cap will eventually cut a real name.** Someone's full legal name is
  longer than any we have seen; they will get the name-free copy and never know.
  That is the intended failure, and it is recorded so a later session recognises
  it as a decision rather than a bug.
* **Deploying this changes nothing until billing is restored and a build ships.**
  The last build was cut 2026-08-09; this joins the eleven ADRs already waiting on
  it (§7 of `resume-prompt.md`).

## Alternatives rejected

| | why not |
|---|---|
| **Mirror the name into `users/{uid}`** | A second copy of a mutable personal datum: a new server-owned field needing a rules freeze in both directions, a deletion-cascade entry, an export-lane entry (ADR-054), and a staleness bug the Auth record does not have. The product already decided where the name lives. |
| **Truncate an over-long name instead of dropping it** | Invents a name its owner does not have, and doing it without splitting a grapheme cluster is machinery bought to produce a worse string than the name-free copy we already ship. |
| **Strip all `\p{Cf}`, with no exceptions** | Deletes ZWNJ, which is orthographically required in Persian and Urdu. It would damage a real person's name to close an attack neither ZWNJ nor ZWJ can carry. |
| **Strip `\p{M}` outright, to kill the combining-mark smear** | The design review's refuter named the cost exactly: `José` in NFD is `Jose` + `U+0301`. 3b caps a *run* at 8 instead, which is measured to leave `José`, pointed and cantillated Hebrew, decomposed Vietnamese, Arabic tashkeel, Thai and Devanagari byte-unchanged. |
| **Count grapheme clusters rather than code points in 3c** | It is the more principled unit, and it makes the cap blind to exactly the abuse 3b exists to bound — 200 marks on one base is *one* cluster. Code points plus a mark-run cap bound both the payload and the smear; clusters bound neither alone. |
| **Enumerate the twelve UAX #9 bidi controls instead of using `\p{Cf}`** | Correct today and silently incomplete tomorrow — and it would have missed `U+FFF9`–`U+FFFB` and `U+00AD`, which are not bidi controls but hide text just as well. Lesson **124**: prefer the property. |
| **Sanitise at the call site in `reveal-service.ts`** | Two places would then decide what a usable name is, and the next caller would inherit neither. |
| **Do the lookup before the discreet check, for simpler code** | Spends an Auth call on every Arabic recipient specifically to discard the result — and makes Decision 4.6's "the lookup was not called" assertion unwritable, which is the assertion a refactor breaks silently. |
| **Fix the shipped v2 privacy notice instead of the draft** | v2 says ikimiz *"does not send push notifications today"* — already false, already ADR-058's subject, and already blocked on #226. Changing shipped legal text is a consent re-gate and is the founder's and the lawyer's, not a session's. |
| **Defer the hardening to a follow-up issue** | Decision 1 without Decision 3 ships the line-break injection. The measurement in Finding 3 is what makes them one change. |

## What the design pass changed, and what it did not

5 lenses × 2 verifiers + a completeness critic; **22 agents, 0 errored, 0 empty
results, 0 skipped**; 8 lens findings, all 8 verified, **0 dropped unverified**;
5 critic findings.

**Surfaced by the aggregation: none.** Adopted anyway, on re-measurement: six.

| from | finding | what changed |
|---|---|---|
| lens *mechanism* (blocking) | `authorUid` is not in scope in `deliverPush` | D2 now carries the signature and both call sites |
| lens *adversarial* | combining marks survive 3a and the length cap | new **D3b**, at a run cap of 8, measured against seven orthographies |
| lens *testability* | D4.1 and D4.6 specify contradictory mechanisms | D4 splits them and says which proves what |
| lens *testability* | `reveal-service.test.ts` has no `[DEFAULT]` app, so `getAuth()` cannot work | D4 names the `deletion-service.test.ts:28-32` pattern; the throw was measured |
| lens *testability* | the uid-swap mutation passes if the oracle is computed from `composePush` | D4.2 requires a literal expected name |
| lens *privacy* | Consequences omits the TR/EN default change | added, with the refutation noted |
| **critic** | *"`name_capture_screen.dart` has no `maxLength`"* — **false** | Finding 3 corrected; **D3c's cap moved 48 → 64** so the server does not silently reject what the client invites |
| **critic** | no test covers an Auth lookup that throws | D4.6 |
| **critic** | no logging specified for the new failure mode | D1 |
| **critic** | D5 describes the new privacy wording but never quotes it | D5 quotes all three locales |
| **critic** | *"`legal_proposal_test.dart` continues to pass"* was a claim about code that did not exist | now an acceptance criterion — the diff runs it |

**Found by my own measurement rather than by the review:** the `/g`-plus-`.test()`
statefulness trap (lesson **136**), and that 3a's separators must map to a space
rather than be deleted, or `Aylin\nSecurity` welds into `AylinSecurity`.

**Not adopted:** the review's observation that D4's "byte-identical name-free
payload" assertion is implementable — the reviewer's own verdict was *"no change
needed"*, and it is recorded rather than actioned.

**What this pass could not check.** No lens ran the emulator suite or `flutter
test` (both are forbidden to sub-agents, `session-context.md` §3), so every claim
about a test *passing* is still a claim. The built-diff pass, and the runs the
diff itself performs, are what settle them.
