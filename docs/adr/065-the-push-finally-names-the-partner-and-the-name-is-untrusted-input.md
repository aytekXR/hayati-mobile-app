# ADR-065: the push finally names the partner, and the name is untrusted input

- **Status:** Accepted — **revision 1** (2026-08-30, Session 089), written **before** the code
- **Date:** 2026-08-30 (Session 089)
- **Deciders:** session agent (the wiring, the source of the name and the hardening are all device-independent and emulator-provable; the one thing that is not — whether any of it reaches a phone — is blocked on billing and is stated, not guessed)
- **Related:** **ADR-012 D3** (the push policy, the discreet mode, the injectable `MessagingPort`), **ADR-059** (the bidi correctness of the named copy, and `sanitizePushName` — **D3's invariant is given a mechanism here**), **ADR-033** (isolate for rendering, never for outgoing text), **ADR-053** (generated bidi ranges — and why the set enumerated here is *not* that), **ADR-058 / #226** (the version-3 privacy draft, corrected here in the same diff), **ADR-063 D8** (assert what the port RECEIVES), **ADR-019 D6** (the per-user discreet override), issues **#253** (this one), **#136** (whose seam this activates)

> **Review status.** This revision was written and committed **before** the fix
> (`session-context.md` §5 item 1, lesson **115**). The design pass has not yet
> run against it; the built-diff pass has not yet run at all. Both are recorded
> here when they do, with their agent counts.

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
Firebase Auth **client** SDK's `updateProfile` lets a signed-in user set their
own to an arbitrary string; `name_capture_screen.dart` has **no `maxLength`**, and
even if it did, the screen is not the only writer. So the string that Decision 1
routes into the partner's lock screen is chosen by the other member of the couple.

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

## Decision 2 — The lookup happens only where its result can be used

Inside `deliverPush`, after the recipient's user document, the token check, the
timezone/quiet-hours guards **and** the discreet resolution, and only when
`kind === 'partnerAnswered'` and `discreet === false`.

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

## Decision 3 — `sanitizePushName` becomes the one gate, and gains three rules

All hardening lands in `sanitize-push-name.ts` rather than at the call site. One
function decides whether a name is usable, so the next caller inherits the
decision instead of re-deriving it. In order:

**3a — Strip what cannot legitimately appear in a name.** After the existing
trim, remove every character in Unicode general category **`Cc`** (the C0/C1
controls, which is where `\n`, `\r` and `\t` live), **`Zl`**, **`Zp`**, and
**`Cf`** — *except* **`U+200C` ZWNJ** and **`U+200D` ZWJ**, then collapse every
remaining whitespace run (including `Zs`, so `U+00A0` and `U+3000` too) to a
single `U+0020` and re-trim.

* Expressed as Unicode **properties**, not as a hand-rolled range (lesson **124**,
  ADR-053). `\p{Cf}` is what makes this durable: it covers all twelve UAX #9
  explicit formatting characters (`U+061C`, `U+200E`, `U+200F`, `U+202A`–`U+202E`,
  `U+2066`–`U+2069`) **and** the invisibles a list would have missed — `U+00AD`
  soft hyphen, `U+2060` word joiner, `U+FEFF`, and `U+FFF9`–`U+FFFB`, the
  interlinear annotation characters, which exist to hide text behind other text.
* **ZWNJ and ZWJ are the deliberate exceptions.** ZWNJ is orthographically
  required in Persian and Urdu and is not decoration; ZWJ joins emoji sequences.
  Neither can reorder text or introduce a line, which is what 3a is about. Two
  named exceptions with a linguistic reason beat a blanket rule that quietly
  damages a real person's name.

**3b — Cap the length, and degrade rather than truncate.** Over **48** code
points (measured after 3a, **before** the RTL edge trim), return `undefined`.

* **Before the trim, so the decision is language-independent.** Whether a name is
  usable *at all* must not depend on the copy's direction; only its *edge
  trimming* does.
* **48 is a product bound, deliberately not the safety bound** — the safety bound
  is 3a. It sits above any personal name this product has encountered and below
  the width at which the name would displace the copy it is embedded in (an iOS
  notification title truncates well before it). Because it is not load-bearing,
  getting it slightly wrong costs a name-free push, not a broken one.
* **Degrade, do not truncate.** Truncation invents a name its owner does not
  have, and doing it safely means not splitting a grapheme cluster — machinery
  bought to produce a worse string. The name-free copy is already correct.

**3c — The contract is restated.** `sanitizePushName` returns *"a name safe to
interpolate into outgoing push copy, or `undefined`"* — no longer *"a name with
its RTL edge neutrals trimmed"*. Bidi is now one of its three concerns.

**This is what gives ADR-059 D3 a mechanism.** D3's invariant — no `U+2068`/
`U+2069` in a push payload — stops being a promise we keep by not acting and
becomes one the code enforces on input it does not control. D3 is not
contradicted; it is completed, and its reasoning (*"isolate for rendering, never
for outgoing text"*, ADR-033) is what makes stripping them correct rather than
merely safe.

## Decision 4 — The proof is end to end, asserts the payload, and pins the direction

The existing unit suites keep their scope. What is new:

1. **The seam is exercised for the first time, from `handleAnswerCreated`**, in
   the emulator, with a real Auth record created via `getAuth().createUser` — the
   `invite-preview.test.ts` precedent — so the production lookup shape is the one
   under test rather than a fake standing in for it.
2. **Assert what the port RECEIVES** (ADR-063 **D8**): the `FakeMessagingPort`'s
   `{title, body}` must be the *named* copy in the recipient's language, not
   merely that a send occurred. That gap was found on the daily-question pass and
   this is the same shape.
3. **Finding 2 is pinned by construction.** Both members get **distinct** display
   names, and the assertion is that the recipient's payload carries **the other
   member's**. A build that passes `partnerUid` instead of `authorUid` must
   redden a *named* assertion, not a generic one.
4. **`sanitizePushName` gets its bidi property asserted at the seam that now
   reaches it**, not only in its own unit test: an author whose display name is
   Arabic, delivered to an `en` recipient, must produce copy whose first strong
   character came from the copy (the ADR-059 D4.1 rule), asserted on the payload
   the port received.
5. **Each of Finding 3's three defects gets an assertion at the seam**: a name
   with `\n` produces a single-line payload; a name with `U+202E` and one with
   `U+2068`/`U+2069` produce payloads containing neither; a 500-character name
   produces the byte-identical **name-free** payload.
6. **The discreet path is asserted twice** — that an AR recipient's payload is the
   generic one (Finding 4's structural guarantee, now with a name available to
   leak), *and* that the lookup was **not called at all** (Decision 2's ordering).
   The second is the one a refactor breaks silently.
7. **Mutation-checked, and the mutant checked** (lesson **112**): removing 3a's
   strip must redden a named assertion; swapping `authorUid` for `partnerUid`
   must redden a named assertion; and each mutation must be confirmed to change
   behaviour rather than be a no-op.
8. **A floor on the input** (lesson **110**): the number of cases the value table
   walks is asserted, so a matcher that matched nothing cannot report a clean zero.

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

The draft is **not** the shipped notice: `docs/legal/proposed/` is a version-3
draft awaiting the founder and the lawyer (**#226**), and `app/assets/legal/`
still carries version 2. Nothing here lands a consent re-gate or changes what a
user has agreed to; it keeps the un-landed draft honest so that when #226 is
taken up, the document describes the system that exists. `legal_proposal_test.dart`
guards the draft's structure and continues to pass.

## Consequences

* **The named copy becomes reachable for the first time**, and with it ADR-059's
  entire body of work — including the bidi property that has never been exercised
  outside its own unit test. #136's autonomous half gets its first real exercise.
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
| **Enumerate the twelve UAX #9 bidi controls instead of using `\p{Cf}`** | Correct today and silently incomplete tomorrow — and it would have missed `U+FFF9`–`U+FFFB` and `U+00AD`, which are not bidi controls but hide text just as well. Lesson **124**: prefer the property. |
| **Sanitise at the call site in `reveal-service.ts`** | Two places would then decide what a usable name is, and the next caller would inherit neither. |
| **Do the lookup before the discreet check, for simpler code** | Spends an Auth call on every Arabic recipient specifically to discard the result — and makes Decision 4.6's "the lookup was not called" assertion unwritable, which is the assertion a refactor breaks silently. |
| **Fix the shipped v2 privacy notice instead of the draft** | v2 says ikimiz *"does not send push notifications today"* — already false, already ADR-058's subject, and already blocked on #226. Changing shipped legal text is a consent re-gate and is the founder's and the lawyer's, not a session's. |
| **Defer the hardening to a follow-up issue** | Decision 1 without Decision 3 ships the line-break injection. The measurement in Finding 3 is what makes them one change. |
