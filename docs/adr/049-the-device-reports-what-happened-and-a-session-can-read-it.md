# ADR-049: the device now knows why it has no push token, and the only reader is the person holding it — so it writes one bounded, self-reported field the server can see

- **Status:** Accepted
- **Date:** 2026-08-17 (Session 071)
- **Deciders:** session agent (this **removes** an operator dependency: today the founder is the only instrument for "what happened on the phone", and that is the defect)
- **Related:** **ADR-046** (the five states this reports, and the reason they exist), **ADR-042** (D1 the `fcmTokens` freeze — untouched and re-proven here; D2 the port seam this follows), **ADR-044** (the bounded capture whose exhaustion is one of the reported facts), **ADR-019** (D2 the cascade, D5 the export — both reviewed here, asserted not assumed), **ADR-039** (D1 fail-open, D2 bounded waits), **ADR-023** (the server-owned `consent` freeze whose rules shape this borrows), **ADR-026** (closed vocabularies, gated in every reader), issues **#221** (this slice), **#226** / **#227** (filed by it), lessons **65**, **69**, **86**, **90**, **105**

## Context — measured 2026-08-17, not inherited

`python3 tool/ci/push_delivery_probe.py --from-firebase-cli` → exit **1**:
`hayatiapp-prod: 0/4 account(s) have registered a device`. Unchanged since S063.

ADR-046 turned four indistinguishable device-side failures into five named states
and put them on the phone, with the action that fixes each one. It deliberately
added no server-visible breadcrumb, and said so in its own Consequences. So the
question a session can answer is still only *"did a device register?"* — never
*"did the app ever reach the prompt, and what did it do?"*

The gap is not theoretical. Every one of these produces the same observable —
four user documents with no `fcmTokens` — and each has a different fix:

| what happened on the phone | who fixes it | today's evidence |
|---|---|---|
| no build carrying the code was ever installed | the founder, via TestFlight | nothing |
| iOS never showed its dialog (nobody reached the paired home) | the app | nothing |
| permission was requested and refused | **iOS Settings, and nothing else** | nothing |
| permission is held, APNs never answered | a retry, or ADR-046 D6's explicit forward | nothing |
| the token existed and `registerPushToken` threw | the server, or the network | nothing |

Row 5 is the shape that cost 37 hours in #219, and row 4 is the one runtime link
ADR-042 D5 left unverified. **They are the two most expensive rows and they are
the two that look identical to every instrument this repo has.**

## Decision 1 — One client-owned field on `users/{uid}`, written over Firestore, NOT through a callable

`users/{uid}.pushDiagnostic` — a small map the **device** writes about **itself**.

Two candidate transports were considered, and the choice is not stylistic:

* **a callable** (`recordPushDiagnostic`, admin-SDK write, field stays
  server-owned like `fcmTokens`) — **rejected, and it is the trap.** One of the
  facts this field exists to report is *"the callable failed"*. A diagnostic that
  travels over the same transport as the thing it reports on is silent in exactly
  the case it was built for. It would also need a Functions deploy to become
  readable, and the deploy lane is unarmed (operator 2(e)(iii)) while §7 still
  gates prod by hand. Both objections are decisive on their own.
* **a direct Firestore write** — chosen. Firestore's transport is independent of
  the Cloud Run callables, so `registerFailed` is reportable *by the failure
  itself*. It needs no deploy to start working, which matters because the client
  half already cannot ship without one (see Consequences).

**`fcmTokens` stays exactly as ADR-042 D1 left it: server-owned, frozen at create
and at update, in both directions.** Nothing here rides on it, touches it, or
loosens it — a client that could append to that array could name another phone's
token and take delivery of that phone's notifications. The whole reason this is a
*new* field is that the existing one must not move.

### What this field is, and what it is NOT

It is **the device's own claim about the device**, and it is trusted only as
that. `fcmTokens` remains the evidence: it is written by the server, from a token
the server verified, and it is the only thing that proves reachability. The probe
therefore prints the two side by side and, where they disagree, says so rather
than picking a winner (Decision 8).

This is also the entire security surface. The field is on the caller's own
document, addresses nothing, is read by no other rule, and — because of Decision
2 — cannot hold a free-form string at all. A client lying in it lies about
itself, to itself.

## Decision 2 — Two CLOSED vocabularies and a server stamp; no free-form string anywhere

```
pushDiagnostic: {
  state:  'unknown'|'notDetermined'|'denied'|'awaitingDeviceToken'|'registered',
  detail: 'permissionRequestRefused'|'captureExhausted'|'registerFailed'|'permissionUnreadable',  // optional
  at:     <server timestamp, == request.time>
}
```

**`state`** is `PushRegistrationState.name` — ADR-046's vocabulary, unchanged and
unextended. Reusing it means the screen and the server report the same five
words, and it makes the parity sentinel of Decision 9 a set comparison rather
than a mapping table. Those enum names become **wire values** the moment this
ships; renaming a member is a data migration, exactly as `profile_dto.dart`
already says of the profile enums.

**`detail`** is the resolution the UI deliberately does not have. ADR-046 D2
merged *"granted but no token"* and *"the callable threw"* into one state on
purpose — the person holding the phone gets the same sentence and the same
button either way. A session needs them apart: one indicts APNs, the other
indicts the server. So the extra resolution lives here and **only** here, as a
**Dart enum of its own — `PushDiagnosticDetail`** (`domain/push_diagnostic.dart`,
beside `PushRegistrationState`) — closed at four members, each naming *what the
app did* rather than what the user meant:

| `detail` | the app did this | the link it indicts |
|---|---|---|
| `permissionRequestRefused` | called `requestPermission()` and was not granted | the prompt path RAN — iOS Settings is now the only door (ADR-046 D3) |
| `captureExhausted` | ran ADR-044's bounded loop to its end without a token | APNs never answered; ADR-046 D6's forward, or the `.p8` |
| `registerFailed` | held a token and `registerPushToken` threw | the callable / the network — the #219 shape |
| `permissionUnreadable` | asked the OS for its permission state and the call threw | the plugin seam itself |

**Both vocabularies are Dart enums, and both become wire values.** That is what
makes Decision 9's sentinel a two-way set comparison rather than a hand-kept
table, and it is why `detail` is not a bare string: a free-form diagnostic string
is the thing that rots into four spellings of the same fact.

`permissionRequestRefused` is named for the call, not for a tap, and that is a
correctness point rather than a style one: after the first install-time dialog,
`requestPermission()` returns the standing answer **without showing anything**,
so "the user declined" would be a confident wrong label — the exact defect
ADR-046 D2(a) records one level up. What the field can honestly assert is that
the app reached the prompt path and was refused, which is what "did the tap
happen" reduces to once you refuse to guess.

**`at` must equal `request.time`.** A client clock cannot forge freshness, the
same discipline `createdAt` and `soloAnswers.answeredAt` already hold. Freshness
is load-bearing here: *"declined"* with no date cannot distinguish a phone that
reported it this morning from one that reported it in July.

**No app version / build number, deliberately.** It would answer a real question
("which build is this device on?"), and the only way to read it is
`package_info_plus` — a new dependency, a new plugin registration and a new
ADR-034 advisory obligation, which is precisely the trade ADR-046 D4 rejected for
`permission_handler`. `at` plus the release history answers it well enough; if
that stops being true, the dependency can be argued on its own merits.

**Consequence of the closed sets:** the whole field is bounded at roughly a
hundred bytes and contains no attacker-chosen text. There is no storage-abuse
vector to bound separately, and nothing in it can carry content, a name, or a
bidi-sensitive string (ADR-033 does not apply — nothing here is rendered).

## Decision 3 — The write is `update()`, never `set(..., merge: true)`

A diagnostic must never bring a `users/{uid}` document into existence.

`PushTokenSync` starts at **sign-in**; profile capture happens later, so on a
brand-new account the first diagnostic can fire while the document does not yet
exist. A `set(merge: true)` there is a **create** in rules terms, and a created
document carrying only a diagnostic would have no `createdAt` (breaking the
create-once server stamp) and no `status` (breaking `profileFromMap`, which
throws `FormatException` on a missing enum field and would take the profile
stream — and therefore the onboarding gate — down with it).

`DocumentReference.update()` fails with `not-found` instead, which is the exact
semantics wanted: **annotate an existing profile, or do nothing.** That failure
is swallowed like every other on this path (Decision 6). The rules still validate
the field at create as well as at update (Decision 4) — belt and braces, because
the freeze comments in `firestore.rules` already record what happens when a guard
spans one direction only.

## Decision 4 — The rule is *unchanged OR valid*, applied at BOTH create and update

```
function pushDiagnosticValid() { ... shape, vocabularies, at == request.time ... }
function pushDiagnosticUnchanged() {
  return request.resource.data.get('pushDiagnostic', null)
      == resource.data.get('pushDiagnostic', null);
}
allow create: ... && pushDiagnosticValid();
allow update: ... && (pushDiagnosticUnchanged() || pushDiagnosticValid());
```

**The `unchanged` half is not defensive padding; without it this ADR bricks
onboarding.** Rules see the *post-merge* document, so `saveProfile`'s
`set(..., merge: true)` — which never mentions `pushDiagnostic` — still presents
the stored map, whose `at` is an old timestamp. A bare `at == request.time` would
therefore deny **every profile edit made after the first diagnostic write**, on
a path that maps `permission-denied` to a `ProfilePermissionException` the
onboarding screen surfaces to the user. A positive-control test pins this, and it
is written to go red if the clause is removed.

Validating at **create** too costs one predicate and closes the mint-at-create
bypass the existing freeze comments call out by name: a guard on update alone is
worthless if the same value can be planted on a fresh (or post-deletion
re-created) document. Here the field is client-owned, so the create rule
*validates* rather than *forbids* — the harm being prevented is a junk shape the
probe would misread, not an escalation.

**Deleting the field stays legal.** Absence and deletion make the same statement
— *nothing measured* — and nothing depends on the field's persistence.

## Decision 5 — A port in the notifications feature, not a method on `ProfileRepository`

`PushDiagnosticRecorder` (domain) + `FirestorePushDiagnosticRecorder` (data) +
an unimplemented-at-base provider the flavor entrypoints override — the exact
mold `PushTokenRepository` / `FunctionsPushTokenRepository` already uses two
files away.

`ProfileRepository` was the obvious alternative: it owns `users/{uid}` and it is
an existing seam, which is what #221 asks for. It is the wrong one. Its contract
is *the onboarding profile*, its errors are a `ProfileException` taxonomy the UI
renders, and this write has neither — it is fire-and-forget telemetry that must
never produce a user-visible failure. Widening that interface would put a
never-throwing method inside a throwing contract and hand every existing fake a
method it has no business implementing.

The port also buys what ADR-042 D2 bought: the decision logic (what to record,
when, and when not to) stays above the seam and is proven on Linux with a fake,
while the adapter is a thin, branch-free Firestore call.

## Decision 6 — When it writes: on a NEW observation, once per process, never blocking, never throwing

* **Never `unknown`.** It is the not-measured state and the signed-out state; an
  absent field says the same thing, and at sign-out the auth context is already
  gone so the write would only produce a denial to swallow.
* **A new observation only.** Skipped when the state is unchanged *and* the new
  `detail` is null or identical — a null detail carries no new information about
  a state already reported, a non-null one always does. The rule exists to stop a
  generic refresh from overwriting `denied + permissionRequestRefused` with a
  bare `denied` and losing the one fact worth having.
* **Per process, not persisted — and reset whenever the synced uid changes.** The
  dedup memory dies with the app, so every cold start reports once and `at` tracks
  *"the last time this phone looked"* rather than drifting arbitrarily far into
  the past. It is also cleared on **every** `_syncedUid` transition, not only on
  sign-out: `AuthSignedIn(A) → AuthSignedIn(B)` reaches `_syncFrom` with no
  `AuthSignedOut` between (a token swap, a credential link), and a baseline
  carried across that boundary would skip B's first report because A happened to
  be in the same state. B's document would then be silent about a device that had
  in fact measured itself — the precise blindness this ADR exists to remove.

### The mechanism for `permissionUnreadable`, written down rather than implied

`_stateForCurrentPermission(source)` today catches a throwing
`permissionStatus()` and returns `awaitingDeviceToken`, and its **return type
cannot express that an exception happened** — so an implementer adding a recorder
would faithfully record `awaitingDeviceToken + captureExhausted` and blame APNs
for a plugin fault. Two changes make the fourth detail reachable, and they are
requirements, not suggestions (lesson **106**):

1. `_stateForCurrentPermission` returns a **`(PushRegistrationState, PushDiagnosticDetail?)`
   record**: the throw path yields `(awaitingDeviceToken, permissionUnreadable)`,
   the ordinary path yields `(state, captureExhausted)`. Where both facts are
   available the **more specific one wins** — a permission read that threw is a
   sharper statement than a loop that ended.
2. `refresh()`'s own `permissionStatus()` catch currently returns `_current` and
   **emits nothing at all**, so that failure is invisible even to the phone. It
   must record `awaitingDeviceToken + permissionUnreadable` through the same
   guard (`_emitUnlessRegistered`), so a device whose messaging seam is broken
   says so instead of looking like a device that was never asked.
* **`unawaited`, and it catches everything** (ADR-039 D1/D2, ADR-022): a
  diagnostic that costs a frame, or that can throw into the boot path, is a worse
  bug than the blindness it cures.
* **Resolving the recorder is itself guarded**, like `pushTokenSourceProvider`:
  the base provider throws by design, so every widget test that builds the app
  without overriding it lands there and must get a logged no-op, not a failure.

## Decision 7 — ADR-019 review: it cascades because the document does; it is NOT exported, and that is a decision

**Cascade (D2): covered, and now asserted.** The field lives inside
`users/{uid}`, which `deleteAccountCascade` deletes wholesale, so no new step is
needed. "No new step needed" is exactly the kind of claim this repo has been
burned by, so the cascade fixture now seeds a `pushDiagnostic` on the deleted
account **and** on the surviving partner: A's must be gone with the document, B's
must survive the detach transaction that stamps `coupleEnded` on it.

**Export (D5): deliberately omitted.** `projectProfile` is a whitelist, and the
whitelist already omits `fcmTokens` — device-registration technical state has
never been part of the export. Adding this field to the export while its older
sibling stays out would be an inconsistency invented by a session whose objective
was diagnostics. The omission is pinned by a test so it is a decision rather than
an oversight, and the real question — *should the export carry device-registration
state at all?* — is **issue #227**, answered on its own merits rather than in
passing. `formatVersion` is untouched: nothing was added to the envelope.

### The legal texts say something this field makes less true, and that is NOT a session's call

Measured 2026-08-17, and **the design-review lens that should have caught this
returned zero findings — so it was checked by hand instead** (§5.5: an empty
result is *unverified*, never a clearance):

* `privacy-policy.{tr,en,ar}.md` each say **"ikimiz does not send push
  notifications today"**. The server has composed and attempted a push every day
  since 2026-08-11; nothing is delivered only because no device holds a token.
* the policy's *"what we collect"* list enumerates the Firestore contents and
  names **neither `fcmTokens` nor** — after this ADR — `pushDiagnostic`.
* `dpa-inventory.md`'s Firestore row lists data categories in the same
  enumerating style, and carries a note asserting *"nothing writes the field"*
  about `fcmTokens`, which stopped being true at ADR-042.

**This ADR does not touch the legal texts, and that restraint is the decision.**
Those files are byte-synced to `app/assets/legal/` under a drift test, and a
revision bumps `CURRENT_LEGAL_VERSION` in three places at once (ADR-023's
source-sentinel), which **re-gates consent for every existing user**. Making
every user re-consent is a founder/lawyer decision about a product's relationship
with its users; it is not a side effect a diagnostics slice gets to cause. So the
gap is **issue #226** and is recorded here, not fixed in passing — while
`dpa-inventory.md`, an engineering register with no consent consequence, **is**
corrected in the same commit as the code.

## Decision 8 — The probe reads it, names the link, and never lets a claim outrank the evidence

`push_delivery_probe.py`'s default (read-only) mode gains a per-account report:
the server-owned token count **and** the device's self-report, with `--uid`
narrowing it to one account.

Rules the mode is built on:

* **The exit taxonomy does not move.** 0 = a device is registered, 1 = none, 2 =
  could not measure. A device self-report never flips the verdict — the whole
  point is that it is a claim.
* **`--uid` narrows what is PRINTED, never what is judged.** The exit code
  continues to answer *"has any device registered?"* across every account read,
  so a lane that greps the exit is unaffected by a human narrowing the report.
  The two questions are different and the flag answers only the first.
* **A named uid is fetched DIRECTLY, not filtered out of the listing.** The
  listing is capped at `pageSize=100` with no `nextPageToken` handling (4 accounts
  today, measured 2026-08-17), and a `--uid` beyond that cap would otherwise print
  a confident *"no diagnostic"* for an account the tool never looked at — an
  absence manufactured by pagination, which is lesson **65**'s failure with an
  extra step. So `--uid` reads `documents/users/{uid}` and a 404 is **exit 2, "no
  such account"**, never exit 1 and never a report.
* **The wire shape is measured, not assumed** (hayatiapp-prod, 2026-08-17): a map
  field arrives as `{"mapValue": {"fields": {"state": {"stringValue": …},
  "detail": {"stringValue": …}, "at": {"timestampValue": …}}}}`. Every level is
  read defensively — a missing key, a non-map, a non-string state — because a
  device self-report must never be able to crash the instrument that reads it. A
  state the tool does not recognise prints as `UNMAPPED state '<x>'`, which is
  neither a crash nor a silent "nothing here".
* **A disagreement is printed, not scored.** `registered` with no `fcmTokens` is
  usually not a bug: `registerPushToken` evicts a token from every *other* user
  document (ADR-042 D1), so a phone that later signed into a second account
  legitimately leaves the first account saying `registered` with nothing stored.
  Making that exit 1 would produce a red nobody can ever clear, which is how a
  useful instrument becomes an ignored one.
* **Silence is reported as silence.** No `pushDiagnostic` means *either* no build
  carrying this code has run *or* the app never reached the point of measuring —
  and the tool says both, because it cannot tell them apart and lesson **65**
  says an absence is not a negative.

## Decision 9 — The vocabulary is pinned in both languages by a source sentinel

`firestore.rules` hard-codes the two vocabularies; Dart owns the two enums.
Nothing connects them, and a sixth state added in Dart would be silently rejected
by the rules and swallowed by Decision 6's catch — a guard failing in the one
direction nobody watches.

So a Dart test reads `firestore.rules` and asserts **set equality, in both
directions, for BOTH vocabularies**: the rule's `state` list against
`PushRegistrationState.values.map((s) => s.name)`, and the rule's `detail` list
against `PushDiagnosticDetail.values.map((d) => d.name)`. One comparison would
leave the other half exactly as unguarded as it is today, which is why `detail`
was given an enum rather than left as a string (Decision 2).

It follows the `legal`-asset drift test's prior art (a test that reads a repo file
to prove two artifacts agree) and ADR-023's three-way source sentinel (the version
constants). Cross-language parity is asserted, never assumed — this repo has
lesson **105** for what "the pattern looks airtight" is worth.

## Decision 10 — The documents that change in the SAME commit (project rule #8)

Named here so the docs pass is a checklist rather than a memory:

| document | what changes |
|---|---|
| `docs/architecture.md` §3 | the `users/{uid}` line gains `pushDiagnostic?{state, detail?, at}`, with a comment naming it CLIENT-owned, shape-validated, and self-reported — the first client-owned field in that block, so the distinction is spelled out rather than assumed |
| `docs/test-suite.md` | the rules cases + their mutants, the cascade fixture's new seed/assertions, the export-omission test, the two-vocabulary parity sentinel, and the probe's new pure-function tests |
| `docs/dpa-inventory.md` | the Firestore row's data categories gain device-registration state; the stale *"nothing writes `fcmTokens`"* note is corrected (an engineering register, no consent consequence — unlike the legal texts, D7) |
| `docs/operator-expected.md` | §4(a) gains what a session can now read, and the standing fact that it reads nothing until a build ships |
| `firestore.rules` | the two predicates and their comments |

**What deliberately does NOT change:** `docs/legal/*` and `app/assets/legal/*`
(D7), `PushRegistration` and the Settings row (ADR-046's UI vocabulary is
unextended), and `formatVersion` (nothing was added to the export envelope).

## How this ADR was reviewed, and where the review was thin

Five lenses (rules · client · data-rights · probe · governing-docs), each finding
put to a refuting skeptic **and** a governing-docs adjudicator, surfacing when
either called it real: **10 findings, 7 surfaced**, all folded in above — the
`detail` enum and its half of the parity sentinel (blocker), the
`permissionUnreadable` mechanism, the `--uid` exit/pagination rules, the dedup
reset across a uid change, and this checklist.

**Two lenses returned zero findings — `rules` and `data-rights` — and that is
recorded rather than reported as a clean bill.** An empty result is *unverified*
(§5.5). The `data-rights` silence was demonstrably a false negative: the legal-text
gap in D7 was found by hand afterwards, in the same files that lens was pointed at.

## Consequences

**What this buys.** For a named uid, without the founder and without a device in
hand, a session can distinguish: the prompt path never ran · the prompt path ran
and was refused · permission is held and APNs never answered · a token existed
and the server call failed · registered. Four of those five were byte-identical
before, and two of them are the most expensive failures this repo has had.

**The ceiling, stated plainly and first.** This writes a field a *device* must
run code to produce, and **no build has been cut since 2026-08-09** (`release.yml`,
sha `3550368`, build 119). ADR-046's Settings row is on nobody's phone; this is
behind it in the same queue. Until the founder authorises a release (§7), the
probe's new section will correctly report *no device has said anything*, and that
is not evidence of anything. This slice is complete when it is merged; it is
**useful** when a build ships.

**What it does not buy.** It says nothing about delivery. A phone can report
`registered`, hold a valid token, and still receive nothing if the APNs `.p8` was
never uploaded — the one link no Google API exposes (six endpoints tried,
2026-08-11). `push_delivery_probe.py --send-test --confirm SEND` remains the only
instrument for that, and it needs a registered device first.

**What it costs.** One client-writable field on the user document, one predicate
in the rules, one port and one adapter in the app, and a per-process write on the
first observation of each launch. The field is self-reported and must never be
read as authority; every reader added later inherits that obligation, which is
why Decision 8 makes the probe say it out loud rather than leaving it to the
reader.
