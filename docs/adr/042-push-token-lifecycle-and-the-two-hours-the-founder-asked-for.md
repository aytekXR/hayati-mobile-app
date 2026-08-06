# ADR-042: The FCM token lifecycle, and the two clock hours the founder asked for

- **Status:** Accepted — **D1, D3, D4, D5 IMPLEMENTED** (S062 shipped D1 in #187; S063 shipped D3/D4 in #190). **D2 and D6 remain deferred** on the App ID capability measured absent 2026-08-06 (issue #188). (rev 2 — folds the pre-code adversarial design review. 36 findings raised across 5 lenses; **2 confirmed** and fixed in place, 7 re-adjudicated 3-lens after the first round's verifiers ran against a worktree that did not contain this file. See the review record at the end.)
- **Date:** 2026-08-06 (Session 062)
- **Deciders:** founder (the three notification behaviours, verbatim, 2026-08-05); session agent (the measurement that found none of them can fire, and the slice order)
- **Amends:** **ADR-012 Decision 3** — its push-kind vocabulary (three kinds becomes four), its token-storage deferral (*"nothing writes it yet"* is discharged), its sweep-pass inventory (two passes becomes four), and its at-risk eligibility rule (`streak.count > 0` at hour 20 becomes unconditional at hour 16). ADR-012's hard cost constraint — **one couples read per sweep** — is **not** amended and is preserved by construction.
- **Related:** **ADR-040** (the entitlement/profile/codesign trap, one capability over — read it before touching `Runner.entitlements`, `session-context.md` §6), **ADR-032** (`match` runs readonly, which is *why* that trap exists), **ADR-019** (the delete cascade, and its no-push invariant), **ADR-039** (fail-open boot, bounded waits), **ADR-018** (the device-lock invariants a notification tap must not walk around), **ADR-011** (the hourly sweep this rides), **ADR-033** (bidi isolation at the string boundary — and why a push body is not a "render"), **ADR-023** (the server-owned-field discipline `fcmTokens` was left out of)

---

## Context

### The feature is ticked ✅ and has never once run

`implementation-plan.md:39` records M3.4 complete, with three push kinds, an
injectable `MessagingPort`, quiet-hours policy, discreet-mode policy, recipient
resolution and 35 tests. Every one of those things is real and correct. Four
independent measurements say the delivery path underneath them does not exist:

| Layer | Measured 2026-08-06 |
|---|---|
| `app/pubspec.yaml` | `firebase_app_check`, `_auth`, `_core`, `_crashlytics`, `cloud_firestore`, `cloud_functions` — **no `firebase_messaging`** |
| `app/ios/Runner/Runner.entitlements` | Sign in with Apple only — **no `aps-environment`** |
| `app/ios/Runner/Info.plist` | **no `UIBackgroundModes`** |
| `app/ios/Runner/AppDelegate.swift` | no `UNUserNotificationCenter`, no APNs delegate methods — **the native surface is unwritten, not deferred** |
| a **writer** of `users.fcmTokens` | **none.** Every hit in the repo is a reader (`recipients.ts:53`) or a test seed |

So `fcmTokensOf()` returns `[]` for every user, every send is a counted
`skippedNoToken`, and **no notification has ever been delivered to anyone.**
That is lesson **79**, and this ADR is the first of the two or three slices that
discharge it.

The code was honest at every layer — `recipients.ts:45-52` says *"NOTHING writes
this field yet"* in a doc comment. The **plan** totalled a milestone as shipped
on the strength of its testable half. Criterion 4 of this session corrects that
line in the same diff as the code.

### What the founder actually asked for

Verbatim, 2026-08-05:

> app does not sent notificaiton. It needs to be send new questions at 08.00 TSI
> with a question. And when your partner answers your question you need to be
> notified. If you did not reply the question as of 16.00 you need to be notified
> so that your partner dont get angry.

Three behaviours. Measured against what exists:

| Ask | Today | Gap |
|---|---|---|
| **new question at 08:00** | `questionRollover` writes the day doc at couple-local **midnight**. `PushKind` is `partnerAnswered \| reveal \| streakAtRisk` — **there is no daily-question kind at all** | a fourth kind + an hour-8 pass |
| **partner answered** | **built.** `answerReveal` composes `partnerAnswered` and hands it to the port (`reveal-service.ts:307-321`) | delivery only |
| **unanswered by 16:00** | `runStreakAtRisk` fires at hour **20**, only when **`streak.count > 0`** (`at-risk.ts:34, 202`) | the hour, and the gate |

**"08:00 TSİ" is read as 08:00 couple-local.** It *is* TSİ for the founder
couple, and every other time decision in this system runs off the couple's stored
timezone rather than a fixed offset (`localHour`, `localDayKey`, ADR-011). A
literal `Europe/Istanbul` constant would be correct for exactly one couple and
silently wrong for the Gulf-Arabic audience the product is built for. Stated
here rather than left implied.

### The obstacle nobody can code around

`aps-environment` cannot simply be added. The entitlement must also exist in the
**provisioning profile**, `match` runs `readonly: true` in CI
(`fastlane/Fastfile:80-86`) so it cannot add a capability, and a build claiming
an entitlement its profile lacks **fails at codesign**. That is exactly the
failure ADR-040 was written about, one capability over.

**And CI cannot see it coming.** `ci.yml`'s `ios-build-smoke` runs
`flutter build ios --no-codesign`, so adding the entitlement leaves every
required check green and detonates only in `release.yml`'s macOS sign-upload
job — the most expensive place in the system to learn it. This is not a
hypothetical: it is ADR-040's recorded history with a different key name.

---

## Decisions

### D1 — `fcmTokens` becomes server-owned in fact, not only in a comment

**Measured:** `fcmTokens` is in neither freeze clause of `firestore.rules`, and
`users/{uid}` has no `hasOnly`. A client can write, change and clear it today, at
create *and* at update — while `firestore_profile_repository.dart:87` calls it
server-owned in a comment and `profile_dto.dart:46-48` omits it as server-owned.
Three places assert an invariant the rules do not hold. Nobody decided that; it
is the residue of a field that was designed and never written.

**Decision: two callables, and the field is frozen in both directions.**

* `registerPushToken({ token })` — admin-SDK write to `users/{uid}.fcmTokens`.
* `unregisterPushToken({ token })` — removal, called before sign-out.
* `fcmTokens` joins `coupleId`, `coupleEnded`, `notificationPrivacy` and
  `consent` in **both** the create-forbid list and the update-freeze list.

Both follow the shape `recordConsent` / `updateNotificationPrivacy` already set
(`data-rights.ts:161-207, 222-267`): `requireUid` → validate → a service
returning `{kind:'ok'} | {kind:'profile-missing'}` → `HttpsError`
`unauthenticated` / `invalid-argument` / `failed-precondition`, region
`europe-west1`, `enforceAppCheck: false`. The write uses `update()`, not
`set(merge:true)`, so a registration against a non-existent profile fails cleanly
instead of minting an orphan field — the precedent both existing callables set,
for the same reason.

**Why a callable and not the documented direct write.** The direct-write option
is defensible on its face: `isSelf(uid)` already scopes it, so junk costs the
user their own pushes and nothing else. Three things decide against it, and only
the third is decisive.

1. *Bounding.* The array is unbounded today. Server-side it gets filter-empties
   and `Set`-dedupe, which is what `entitlements/entitlement-core.ts:472`
   (`dedupe`) does and all it does. **It does not get `MAX_TRANSFER_IDS`'
   discipline, and an earlier draft of this ADR said it did.** That cap lives at
   `:511`, it is a *pre-read reject* gate returning
   `{kind:'hold', reason:'oversized'}`, and rejecting an oversized *input* is a
   different act from evicting from a *stored* array. Cited here because the
   correction is the interesting part: the precedent this ADR reached for does
   not exist.

   So the cap is decided here rather than inherited: **5 tokens, and a sixth
   registration drops element 0.** Insertion order is the only order a plain
   `string[]` has — there is no timestamp to sort by, so "evict the oldest" is
   not expressible and "evict the first-inserted" is. Reject-when-full was the
   alternative and is worse: it fails the multi-device user, who is the person
   the cap exists to serve rather than to punish. Five is generous against real
   device counts (phone, tablet, a replaced phone whose token has not yet aged
   out) and still bounds an attacker to a fixed cost.

   **The cap is a bound, not a correctness mechanism.** If a user's sixth device
   evicts their first, that first device stops receiving pushes and nothing tells
   it so. That is acceptable only because re-registration is cheap and happens on
   every launch; it would not be acceptable if registration were rare. A client
   cannot be trusted to cap its own array, and rules cannot express "dedupe".
2. *The asymmetry is already a defect.* Every other server-owned field on `users`
   is frozen at create **and** update, because "the update freeze is worthless if
   a client can mint the field on a fresh self-doc" (`firestore.rules:25-36`) —
   a gap a review found in M6.2. `fcmTokens` is the one that was missed.
3. **A token is device-scoped, and a user is not.** This is the one that settles
   it. If A signs out on a phone and B signs in, B's registration must **evict
   that token from A's document**, or A keeps receiving pushes meant for B — on a
   phone A no longer holds. That is a cross-document write, and **a client can
   never write another user's document under any rule we would accept.** Only the
   admin SDK can.

   The consequence is a design rule, not an optimisation: **registration is
   authoritative, sign-out cleanup is best-effort.** `registerPushToken` removes
   the token from every other user document that carries it, so the privacy
   property survives a sign-out whose cleanup never ran — a killed app, a
   revoked session, a phone that went in a drawer. `unregisterPushToken` is still
   called on sign-out, because prompt removal is better than eventual; but it is
   **not load-bearing**, and nothing is designed on the assumption that it ran.

   Stated the other way: a token that outlives a sign-out is a privacy defect,
   not a cleanup task. Defences that depend on the departing client behaving are
   not defences.

### D2 — The entitlement lands last, behind a measured fact

**Nothing in this slice touches `Runner.entitlements`, `Info.plist`,
`AppDelegate.swift` or `pubspec.yaml`.**

The portal capability is now **measurable** rather than founder-reported:
`tool/ci/appid_capabilities.py` + `appid-capabilities.yml` read
`/v1/bundleIds/{id}/bundleIdCapabilities` over the App Store Connect API with
the credential the release lane already holds. Its exit codes are ADR-041's
taxonomy — `0` ticked, `1` absent, **`2` could not measure** — because an API key
whose role does not cover Certificates/Identifiers answers 403, and reporting
that as "absent" would invent a blocker.

**Measured 2026-08-06, and the answer is `1`.** The probe's first *successful*
live run ([31054773143]) read the portal and returned **exit 1 — absent**, not
exit 2, so the key can see the App ID and this is a read-out rather than a
permissions failure:

```
ticked:  APPLE_ID_AUTH, IN_APP_PURCHASE
absent:  PUSH_NOTIFICATIONS, ASSOCIATED_DOMAINS, APP_ATTEST
```

So step 1 below is **confirmed not done**, and this ADR's slice order is not a
precaution against a hypothetical — it is routing around a measured blocker. Had
this slice shipped the entitlement on the assumption the tick was in place, it
would have signed-failed in the macOS release job, which is exactly ADR-040's
recorded history. Two prior sessions carried this as *"nobody can read the
portal"*; that was a missing tool, not a missing permission.

[31054773143]: https://github.com/aytekXR/hayati-mobile-app/actions/runs/31054773143

**Ordered steps, and they are not reorderable:**

1. the founder ticks **Push Notifications** on the App ID, and uploads the APNs
   `.p8` to **both** Firebase projects (operator item 4(a));
2. `appid-capabilities.yml` returns **exit 0** — the fact, measured, not reported;
3. the profile regenerates and `match` picks it up;
4. **then** `firebase_messaging`, `aps-environment`, `UIBackgroundModes` and the
   native delegate land, in one labelled commit.

Steps 1–3 are exactly ADR-040's restoration pattern, and the ordered steps are
written into `Runner.entitlements` itself for the same reason ADR-040 gives:
that file is where someone will be standing when the question occurs to them.

**The app half is built behind a port, so step 4 is an adapter and not a
rewrite.** `PushTokenSource` is the device-side twin of `MessagingPort`:

```dart
abstract interface class PushTokenSource {
  Future<String?> currentToken();
  Stream<String> tokenRefreshes();
}
```

Every test injects a fake; the FCM implementation is one class written when the
plugin exists. This keeps the entire token lifecycle — capture, refresh,
registration, eviction, sign-out removal — provable on Linux with no plugin, no
Mac, and no APNs key, which is the same trade ADR-012 D3 made for the send side
and the reason its Functions half was provable at all.

### D3 — A fourth push kind, and the hour-8 pass rides the same single couples read

`PushKind` gains **`dailyQuestion`**, localized TR/AR/EN with the discreet
variant, under the standing invariant that **no payload in any mode ever carries
question or answer text** — which `composePush` guarantees structurally by having
no question parameter, not by copy review.

The hour-8 pass iterates the **same `CoupleBuckets`** the assignment and at-risk
passes already share (`question-rollover.ts:72-82`). **Zero additional couples
reads**; ADR-012 D3's hard constraint is preserved by construction, not by
promise. The threading already exists — `makeQuestionRolloverHandler` computes
`bucket(db)` once and hands it to both passes — so a third pass is one more
argument, not a new machine.

**08:00 sits exactly on the quiet-hours boundary and that is fragile.**
`isQuietLocalHour` is `hour >= 22 || hour < 8`: right-open at 08:00, so hour 8 is
the first legal hour of the day and the daily push is the first thing allowed.
Elegant, and an off-by-one in either direction silently suppresses the entire
feature with every test green. The boundary is therefore **mutation-checked in
both directions** — 8 must not be quiet, 22 must be, 16 must not — with the
report naming *which* assertions moved (lesson **75**).

### D4 — The 16:00 nudge REPLACES the 20:00 one. It is a different feature wearing the same code

The existing hour-20 push protects a **streak**: `streak.count > 0`, or the
couple is skipped (`at-risk.ts:202-204`). The founder's protects a
**relationship** — *"so that your partner dont get angry"* — and must therefore
fire for a couple that has **no streak at all**, which is most couples in week
one and every couple that ever broke one.

**Decision: re-point, do not duplicate.** `AT_RISK_LOCAL_HOUR` moves 20 → **16**
and the `streak.count > 0` gate is **dropped**. The streak count still tunes the
copy when a streak exists, so nothing about the existing message is lost.

*Why not keep both.* A couple with a streak who has not answered would get two
pushes in one evening. There is no dedup state and ADR-012 D3 deliberately has
none — double-sends are structurally absent, not guarded — so adding a second
afternoon hour would create exactly the class of duplicate that design avoids.
The 16:00 population is a strict **superset** of the 20:00 one, so re-pointing
loses no couple and gains every couple without a streak. Answering it as
"replace" also keeps the number of nudges per day at one, which is the property
that decides whether a relationship app is helpful or nagging.

*The cost model changes, and ADR-012 §10 is amended to say so.* The day-doc read
was "one per couple per day, in the hour-20 bucket, **for couples with a
streak**". It becomes "one per couple per day, in the hour-16 bucket,
**unconditionally**", because eligibility can no longer be decided from the
couple document already in the bucket. At current scale this is single-digit
reads per day; it is recorded because a cost claim that quietly widened would be
the kind of drift this repo writes ADRs to prevent.

### D5 — Token removal in the ADR-019 cascade sends no push, and cannot break resumability

The delete cascade clears `fcmTokens` as part of the `users/{uid}` document it
already deletes — no new step, no new cursor, no change to the pinned order, and
the auth deletion stays last and idempotent.

**ADR-019's no-push invariant is untouched and load-bearing.** The partner
deletion notice deliberately sends **no** push, on DV grounds: it would deliver
*proactive real-time notification to a possibly-abusive partner at the deleting
victim's moment of escape.* An earlier draft of this ADR said the cascade suite would gain an assertion that
"the injected `MessagingPort` receives nothing during a deletion." **There is no
port to inject.** `DeletionDeps` (`data-rights/deletion-service.ts:27-45`) carries
exactly `checkpoint`, `deleteRef` and `deleteAuthUsers`; the cascade cannot send a
push because it has nothing to send one with. An assertion that a port it does not
hold received nothing would have passed forever while proving nothing — the
vacuous-test shape this repo has been caught by before.

**The invariant is structural, and the test that guards it already exists.**
`payload-policy.test.ts:44-57` string-audits the source and asserts
`not.toContain('coupleEnded')`: no send can happen because no *kind* can be
composed for the event. That is a stronger guarantee than a spy, and it is the
one ADR-019 actually shipped.

> **A tripwire this ADR is about to set off, named now so nobody disarms it.**
> That same test also asserts the union is **exactly three kinds**. D3 adds
> `dailyQuestion`, so **it will go red — on purpose.** The correct response is to
> update the expected union to four and *keep* the `coupleEnded` assertion
> untouched. The "exactly N" clause is a change-detector; the ADR-019 invariant is
> the `coupleEnded` absence. A session that meets the red test and relaxes it
> wholesale deletes a DV safety property while believing it fixed a test.

### D6 — The permission prompt is not a boot step

ADR-039 D1 is binding: the boot is fail-open and always ends in a frame; D2:
every blocking wait on the launch→paired path is bounded. A notification
permission prompt is an **indefinite** wait on a human, and iOS gives one shot at
it per install.

**Decision: ask after pairing completes, never during boot, and never before the
user has seen what the app is for.** Token capture itself is wired through the
`purchasesIdentitySyncProvider` pattern
(`purchases_identity_sync.dart:35-42`) — a `keepAlive` provider that reads the
initial auth state *then* listens for transitions, because `ref.listen` never
fires for the value already present, which is what makes it correct for a
warm-start restored session as well as a runtime sign-in. It never blocks a
frame, and a failure to obtain a token is a logged no-op, exactly as App Check
and Crashlytics fail open where they stand.

---

## Consequences, and the things this ADR deliberately does not do

**This slice ships:** D1 in full (both callables, the rules freeze in both
directions, the cascade assertion, the Flutter repository + provider behind
`PushTokenSource`). **It ships no plugin, no entitlement, and no new push kind.**

**Deferred, filed as issues rather than left in prose** (the standing rule: a
remainder deferred into prose is a remainder that gets lost):

* **The device half** — `firebase_messaging`, `aps-environment`,
  `UIBackgroundModes`, the `AppDelegate` surface, the permission prompt. Blocked
  on operator 4(a) **and** on a Mac: the recon could not verify from Linux
  whether `firebase_messaging` initializes correctly against this project's
  **pure-Dart `FirebaseOptions`** (there is **no `GoogleService-Info.plist`** in
  the iOS project at all), nor whether its method swizzling works with this
  app's **scene-based** `FlutterSceneDelegate` architecture. Both are marked
  UNVERIFIED rather than assumed.

  > **PARTLY RESOLVED 2026-08-06 (#191).** The plugin, the `FcmPushTokenSource`
  > adapter and both provider overrides landed **without** `aps-environment`,
  > which is the ADR-sanctioned "separate labelled commit" route above. That
  > made `ios-build-smoke` compile the plugin against this project for the first
  > time, and it answers both UNVERIFIED items **at build level**:
  >
  > * `firebase_messaging` **compiles and links against the pure-Dart
  >   `FirebaseOptions`** with no `GoogleService-Info.plist` present;
  > * it **coexists with the scene-based `FlutterImplicitEngineDelegate`**
  >   AppDelegate.
  >
  > **Still UNVERIFIED, and narrowed to what it actually is: RUNTIME.** A build
  > cannot prove that method swizzling behaves correctly on a live device, nor
  > that the plugin initializes cleanly against a `FirebaseApp` configured from
  > Dart. Those need a device. They are bounded by ADR-039's fail-open posture —
  > `PushTokenSync` treats a throw or a null as a logged no-op — but "bounded" is
  > not "observed", and the first build to reach a tester should be watched.
  >
  > **The build also found something no reasoning would have.**
  > `firebase_messaging` **16.4.2 declares a constraint its own code violates**:
  > `firebase_core_platform_interface: ^7.1.0`, while using `FirebasePlugin`,
  > which exists only in 8.x. This repo's **dev-only** pin of that package at
  > `^7.1.0` — present solely so one test can import
  > `firebase_core_platform_interface/test.dart` — made 16.4.3+ unsatisfiable
  > and steered pub onto the one broken release. `pub get`, `analyze`, all 1653
  > tests and `format` were green; only the iOS kernel snapshot failed. See
  > lesson **84**.
* ~~**D3 and D4** — the fourth kind and the two sweep hours.~~ **SHIPPED in S063**
  (#190). Two corrections the implementation forced, recorded because both were
  decisions this ADR should have made and did not:

  1. **D4 needed new copy, not just a new hour.** The ADR said "the streak count
     still tunes the copy when a streak exists, so nothing about the existing
     message is lost." True, and incomplete: the count-FREE variant that already
     existed read *"Your streak together is still alive"*, which is **false for
     exactly the population D4 exists to reach** — couples with no streak. A
     separate relationship nudge was written (`unansweredNudgeNormal`), because
     telling someone their streak is alive when they have none is worse than
     saying nothing. Dropping a gate changed who reads the message, and the
     message had to change with it.
  2. **The daily-question pass skips members who already answered**, which the
     ADR did not specify. At local 08:00 the day doc is eight hours old and in
     the ordinary case nobody has answered — but announcing a question to
     someone who already answered it is the small wrongness that makes an app
     feel inattentive. Costs one `getAll` of two answer docs per eligible
     couple; recorded in ADR-012 §10 rather than absorbed silently.

**Four consequences recorded now, because each will be someone's surprise later:**

1. **Push wakes the app on a locked device, and the PIN store already predicted
   it.** `secure_storage_pin_lock_store.dart:25-28` carries a review finding
   (SEC-3): *"When a background launch mode ever arrives (APNs, M6.2+), revisit
   this — a locked-device background read of an `unlocked_this_device` item fails
   and would hit the fail-open path."* Adding `UIBackgroundModes:
   remote-notification` is the event that comment is waiting for. It is **not in
   this slice**, and it must not be added without deciding SEC-3 first.
2. **Tokens are Firebase-project-scoped; the bundle id and the entitlements file
   are not.** `hayatiapp-dev` and `hayatiapp-prod` are different projects with
   different `messagingSenderId`s, but there is one bundle id, one
   `Runner.entitlements`, and one Xcode scheme — the flavor is chosen by the Dart
   entrypoint. So `aps-environment` will apply to both flavors, the APNs key must
   be uploaded to **both** projects, and a token captured in dev can never
   receive a prod push. The eviction rule in D1 is what keeps that from becoming
   a stale-token leak.
3. **A notification tap is a deep link into locked content.** ADR-018's device-lock
   invariants must gate it: tapping a `reveal` push must land on the lock screen,
   not on the answer. The existing `DeepLinkSource` seam
   (`deep_link_source.dart:9-17`) is the pattern to extend, and this is a design
   question for the device slice, named here so it is not discovered by a tester.
4. **#136 stops being latent the moment a push lands.** Arabic push bodies
   interpolate a partner name with no bidi isolation, and ADR-033 applies
   isolation **at render only** — nothing persisted, exported or shared may carry
   `U+2068`/`U+2069`. A push body is composed on the server and rendered by iOS,
   which is a seam ADR-033 does not currently answer for. It must be answered
   before the first Arabic push, not after.

---

## Review record — the pre-code adversarial design review (2026-08-06)

Acceptance criterion 1 of this session: the ADR is written **before** the code and
then adversarially reviewed. It was, in two rounds, and the second round exists
because of a defect in the first.

**Round 1 — 5 finder lenses, 36 findings, and a verification that could not see
the file.** Findings were produced against this ADR correctly. But eleven of the
verdicts refuted findings with the reasoning *"the file
`docs/adr/042-...md` does not exist; the highest ADR number is 041."* They were
right about their worktree and wrong about the world: the session had moved to a
branch that did not carry the ADR, and the verifiers read that branch. **An
`ls` that returns nothing is not a refutation.** Every one of those verdicts was
discarded rather than counted — a "refuted" that was produced blind is worth less
than no verdict at all, because it looks like evidence.

**Round 2 — 9 contested findings × 3 independent lenses (factual accuracy,
decision obligation, adversarial refutation), 27 verdicts, majority-of-3.** This
covered every finding that round 1 left either split 1-1 or unadjudicated. All 27
verifiers confirmed they could read the file.

| Finding | Verdict | Outcome |
|---|---|---|
| `cap-without-order` | **2/3 real** | **Fixed.** The ADR cited `entitlement-core.ts:472` as applying a cap to `MAX_TRANSFER_IDS`. It does not: `:472` is `dedupe`, filter + `Set` only; the cap at `:511` is a pre-read *reject* gate. Verified by hand against the file. D1 now decides the cap (5 tokens, drop element 0) instead of inheriting a precedent that was not there. |
| `cascade-no-push-test-missing` | **2/3 real** | **Fixed.** D5 promised an assertion on an injected `MessagingPort` that `DeletionDeps` does not have and cannot have. Rewritten to the structural guarantee that ADR-019 actually shipped, plus a named tripwire for the "exactly three kinds" assertion D3 will redden. |
| `no-dead-token-pruning` | 0/3 | Refuted. D1 states best-effort token management as a decision; FCM-reported dead tokens cost wasted sends, not correctness or privacy. |
| `token-steal-disables-victim` | 0/3 | Refuted as an *ADR* defect. The attack is real and the trade-off is stated in D1; App Check is a project-wide deferral (ADR-016), not something this ADR silently dropped. **Recorded here rather than dismissed** — if App Check is ever enforced, this callable is one of the reasons to. |
| `slice-coherence-rules-freeze-no-writer` | 0/3 | Refuted. A rules freeze is proven by its DENY path; the repo's four-test pattern for server-owned fields needs no writer to exist. |
| `provider-failure-error-handling-unspecified` | 0/3 | Refuted. D6 specifies it: a failure is a logged no-op, per ADR-039's fail-open posture. |
| `d6-pairing-timing-race`, `consequences-sec3-no-decision`, `bidi-136-no-design` | 0/3 each | Refuted. Each names something this ADR explicitly defers with a reason, which is the documented standard rather than a violation of it. |

**Both confirmed findings were the same species: a citation that asserted more
than the cited line contained.** Neither was a flaw in a decision; both were the
ADR claiming support from code that did not supply it. That is the failure mode
this repo's file:line convention is supposed to prevent and instead makes easy to
commit — the citation looks like evidence whether or not anyone opened it. The
two lenses that caught them are the two that opened the files.

**Lesson for the next review, not just this one:** a verifier that cannot read the
artifact must say so and be discarded, never counted as a refutation. Round 1
would otherwise have closed this ADR with eleven false "refuted" verdicts and both
real findings buried among them.
