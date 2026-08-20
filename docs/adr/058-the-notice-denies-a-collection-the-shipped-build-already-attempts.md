# ADR-058: the notice denies a collection the shipped build already attempts — one revision, drafted and deliberately not landed

- **Status:** Proposed — **revision 2** (2026-08-21, after the design review). The *draft* is the deliverable; landing it is a founder/lawyer decision
- **Date:** 2026-08-20 (Session 082)
- **Deciders:** session agent for the drafting and the landing mechanics; **founder + lawyer for the version bump**, which is the thing this ADR deliberately does not do
- **Related:** **ADR-023** (the consent surface, the legal bundle, the three-way version sentinel, the byte-sync drift test, lawyer questions A/B/C — to which this ADR adds **D** and **E**), **ADR-012 / ADR-042 / ADR-044 / ADR-045 / ADR-046 / ADR-049** (the push chain, its storage, **its quiet window — ADR-045 moved it to 23:00–08:00**, its diagnostic), **ADR-054** (the export's device lane and why a raw token never enters it), **ADR-057** (the funnel, its no-op prod sink, and the paragraph-not-a-CI-check gate), **ADR-028** (the v1→v2 bump precedent), **ADR-019** (the deletion cascade), `docs/legal/README.md` (the bump procedure), `docs/dpa-inventory.md`, `docs/architecture.md` §7 and §8, issues **#226** (this one), **#242**, **#243**, operator items **16** and **18**

> **Review status.** Revision 1 was written and committed **before** the draft it
> governs (`session-context.md` §5 item 1, lesson 111), and stated prospectively
> that neither review pass had run.
>
> **The design pass has now run against revision 1** — 5 lenses × 2 independent
> verifiers, **26 agents, 0 errored, 0 empty results**, 13 findings, 6 surfaced
> under the either-verifier rule plus 3 from a completeness critic; nothing was
> dropped unverified. **Revision 2 is what that pass produced**, and every change
> it made is listed at the end of this ADR.
>
> **The built-diff pass (§5 item 3) has NOT run at the time of this revision.**
> What it finds is recorded in `past-prompts.md`. Nothing below claims a review
> that has not happened.
>
> ⚠️ **Everything this ADR says about `docs/legal/proposed/` and
> `legal_proposal_test.dart` is a SPECIFICATION of what will be built, not a
> description of what exists.** The design review flagged that revision 1 wrote
> Decision 8 in the present tense about artefacts that did not exist. Decision 8
> is now written prospectively. *(The reviewer additionally called this "the sixth
> instance" of this repo's recorded over-claim shape; that framing is not
> accepted — the previous five were claims that verification had **happened**,
> while this was specification prose in a Proposed ADR. The tense is corrected
> because it is cheap and clearer, not because the two are the same defect.)*

## Context — measured on 2026-08-20, not inherited

### The sentence that is false, and how false it is

`docs/legal/privacy-policy.{tr,ar,en}.md` v2 says, in *"Keeping ikimiz private on
your device"*:

> ikimiz does not send push notifications today. If notification delivery is
> added later, the discreet-notifications setting controls how much a
> notification reveals …

The resume prompt for this session called that *"true of the outcome, false of
the system."* Measured, it is worse than that phrasing suggests, because the
system is not merely built — **it is deployed, it is running, and part of it is
already on a real phone.**

* **The shipped binary attempts the collection.** The last release is **build 119,
  2026-08-09** (`release.yml`, run 31319947579, head `355036878a`). Both ADR-042
  and ADR-044 are ancestors of that sha (`git merge-base --is-ancestor`, run this
  session). At that sha `app/lib/app.dart:71` holds
  `ref.listen(pushTokenSyncProvider, (_, _) {})`, and `PushTokenSync` calls
  `FcmPushTokenSource` → `_messaging.requestPermission()` and, on success,
  `FunctionsPushTokenRepository.register` → the `registerPushToken` callable,
  whose server half writes `users/{uid}.fcmTokens`.
  **The app on people's phones asks for notification permission and tries to
  register a device address**, and the notice tells those same people the product
  does not do notifications.
* **The server half is deployed and sweeping.** The hourly sweep has been RUNNING
  since S070 (`prod_pulse.py --from-firebase-cli`, exit 0). `deliverSweepPush`
  resolves recipients, applies the quiet-hours guard, composes a payload and
  sends it through FCM.
* **Only the outcome is empty.** Re-measured this session:
  `push_delivery_probe.py --from-firebase-cli` → **exit 1, 0/4 accounts have ever
  registered, and all four report "no report."** No notification has ever been
  delivered. That is a *device-side failure* — the one link ADR-042 D5 left
  unverified — not a decision not to collect.

So the honest reading of v2's sentence is: **the outcome sentence is true, the
system sentence is false, and a privacy notice is a statement about the system.**
A user reading v2 cannot learn that the app asks their phone for a push address,
because v2 says the feature does not exist.

### The two fields the collection list does not name

`users/{uid}` carries two device fields that *"What we collect, and where it is
kept"* never mentions:

| field | what it is | who writes it | since |
|---|---|---|---|
| `fcmTokens` | an array of FCM registration tokens — **one live address per physical device**, server-owned; rules forbid a client minting it | `registerPushToken` (Functions) | ADR-042, on phones since build 119 |
| `pushDiagnostic` | `{state, detail?, at}` — the device's own report of where it stands in the notification chain, including `permissionRequestRefused`, i.e. *the person was asked and did not grant* | the app, `FirestorePushDiagnosticRecorder` | ADR-049, merged 2026-08-17, **not yet on any phone** |

`docs/dpa-inventory.md` has named **both** since S071 and says so in as many
words. So the engineering register and the user-facing notice already disagree
with each other — and **the register is the one that is right**. That is the
precise shape of #226: not a stale doc, but two documents describing the same
system where only one of them is read by the data subject.

`pushDiagnostic` deserves a sentence of its own. It is not a device attribute; it
is a **record of a person's answer to a permission prompt**, retained
indefinitely on their user document. ADR-054 already decided it is honest enough
to hand back in the export *verbatim*. A field we show the subject on request is
a field the notice must be able to name.

### The recipients with no row

Notification delivery leaves our infrastructure through two parties that have
**no row in the processor register**:

* **Google — Firebase Cloud Messaging.** It receives the registration token and
  the content-free payload, and it is not pinned to the European region.
* **Apple — APNs.** It relays every notification to an iOS device.

The register's device-registration note currently disposes of both in a
subordinate clause — *"Notification delivery remains a Google/Apple leg already
covered by the DPAs above"* — which is a claim about **coverage**, not a
disclosure of a **recipient**. A notice that must tell the user *"who it is
shared with, at home and abroad"* (the Art-11 rights list the policy itself
recites) cannot be built on a register that never names them.

### The analytics half — narrower than push, and not nothing

ADR-057 shipped eight client funnel events on 2026-08-19. Prod is wired to
`NoopAnalyticsSink`; `main_prod.dart` installs no sink and a test asserts it.
**Nothing leaves any device, no vendor exists, and no processor is engaged** —
`dpa-inventory.md`'s placeholder row is correct to stay a placeholder.

But v2's sentence is:

> There is no analytics or tracking product in the app today; if we ever add one,
> it will arrive with its own separate opt-in, not folded into this notice.

Two things about it. First, **the literal claim survives** — there is no
analytics *product*, no SDK, no vendor. Second, **the claim a reader takes from
it does not**: the app now records what you do, it simply throws it away. And
there is a residue that is not thrown away. `Analytics._emit` calls `_claimOnce`
**before** it consults the sink:

```dart
if (onceKey != null && !_claimOnce(onceKey)) return;
_ref.read(analyticsSinkProvider).record(event, …);
```

so on production today the app writes `analytics.install`,
`analytics.signup.<uid>`, `analytics.paired.<uid>.<coupleId>`,
`analytics.q.<uid>.<dayKey>.<mode>`, `analytics.reveal.<uid>.<dayKey>` and
`analytics.streak.<uid>.<lastMutualDate>` into `SharedPreferences` — **on the
device, keyed to the user's uid and their couple id** — and then discards the
event into silence. Nothing transmits it, nothing exports it, and account
deletion does not reach it (it is device-local, and a reinstall clears it, which
is the honest bound already recorded in ADR-057 D4).

That is small. It is also exactly the kind of thing a notice claiming *"there is
no analytics in the app"* should not be quietly sitting on top of.

Third: **v2 makes a promise** — *"its own separate opt-in, not folded into this
notice."* Any revision that touches this paragraph inherits that promise and must
keep it. This ADR treats it as binding.

## Decision 1 — What is material, what is free, and therefore what the bundle actually buys

`docs/legal/README.md`'s bump procedure defines materiality: *"any change that
alters purposes, recipients, the transfer mechanism, or the data-location
split."* Applied honestly to the two halves:

| half | new purpose | new data categories | new recipients | new transfer leg | **material?** |
|---|---|---|---|---|---|
| **push** | notification delivery | `fcmTokens`, `pushDiagnostic` | Google FCM, Apple APNs | yes — neither is EU-pinned | **YES** |
| **analytics correction** | none | none *(the on-device markers are stored, never collected)* | none | none | **NO** |

**The push half forces the bump. The analytics correction cannot justify one on
its own and therefore rides for free.** That is the bundle, stated precisely: one
founder/lawyer review, one re-consent prompt, both corrections.

**What the bundle does NOT buy, and operator item 18 currently over-promises it.**
Item 18 reads *"Bundle the two: one legal revision, one re-consent, covering both
push and analytics, rather than asking your users twice."* Engineering cannot
guarantee the second half of that sentence. The day a vendor adapter lands, the
notice gains a recipient, a transfer mechanism and a region — three of the four
materiality triggers — and by the conservative reading that is a second bump and
a second prompt.

**"But Mixpanel is already named."** The design review pressed exactly this, and
it is worth answering rather than waving away: `architecture.md` §1 lists
*"Mixpanel (product funnels)"* in the stack and §7 says funnels *"are built in
Mixpanel before launch day"*, and `dpa-inventory.md` carries a
*"Mixpanel / product analytics (when built)"* row. **Both verifiers refuted the
finding, and the reason they gave is the right one: a technology intention is not
an engaged recipient.** The register's own cell says *"no processor exists … no
processor is engaged … no row is due yet"*, its region cell reads *"to be
determined when built"*, and there is no account, no token, no contract and no
DPA. A privacy notice that named Mixpanel today would tell users their data goes
to a company we have never contacted — a *different* false sentence from the one
this ADR is correcting, in the same document, pointing the other way. The notice
names recipients that receive data; the architecture names tools we intend to
reach for.

Whether it *must* be is a question this repo may not answer for itself, so it is
recorded as one:

> **Lawyer question D (new).** v3 will state that product analytics is off, that
> connecting it requires a separate opt-in, and that the provider will be named
> in that opt-in before any event leaves the device. **Does naming the recipient
> at the opt-in surface discharge the Art-10 aydınlatma obligation for that
> processing — so the analytics adapter needs no further version bump — or does a
> new named recipient in the notice require its own bump and its own re-consent
> regardless?**

The conservative default stands until the lawyer relaxes it, exactly as ADR-023
chose for question A: **assume the adapter bumps.** Relaxing later is cheap;
discovering a missed re-consent after the fact is not. Operator item 18 is
corrected in the same diff that lands this ADR, because a promise the code cannot
keep is a promise that will be executed as an instruction (lesson 64).

## Decision 2 — The draft lands as `docs/legal/proposed/`, merged; not as an open PR

The resume prompt required this to be decided deliberately and stated here rather
than discovered at push time. Both options were checked against the guards that
actually exist, by reading them:

**Why a merged `docs/legal/proposed/` is invisible to every existing guard:**

* `legal_assets_drift_test.dart` iterates `LegalDocument.values × {tr, ar, en}`
  and builds **exact paths** — `../docs/legal/${document.assetBase}.$locale.md`.
  A subdirectory is not matched.
* `legal_version_sentinel_test.dart` reads `^version:\s*(\d+)\s*$` out of
  `docs/legal/README.md`. The proposal introduces **no line of that shape**
  anywhere — a constraint, stated here because it is invisible in the diff.
* `legal_document_screen_test.dart`'s `shippedPolicyVersionLine` pins the
  *shipped asset's* `Version 2. Effective 26 July 2026.` line. Untouched.
* `tool/ci/build_site.py` iterates a **fixed stem tuple**
  `(("privacy", "privacy-policy"), ("terms", "terms"))` (**line 323**) and
  composes `legal_dir / f"{stem}.{loc}.md"` (**line 325**) — **not a glob**.
  `/privacy` and `/terms` cannot pick the proposal up. *(Revision 1 cited line
  325 for the stem list; the composition is on 325, the list on 323.)*
* `app/pubspec.yaml` bundles `assets/legal/`, not `docs/legal/`. Nothing about a
  `docs/` subdirectory can reach the app bundle.
* Goldens: no rendered string changes, so no golden set moves.

**Why not an open PR — with the weak argument removed.** Revision 1 also claimed
a founder would not find an open PR, and that an open branch is *"outside the
process that keeps things true."* The design review was right that both are
self-serving: GitHub surfaces open PRs prominently, and **the drift risk is
identical either way** — a merged proposal can go stale against the shipped
documents exactly as an open branch can. Neither is a reason.

What survives is narrower and is the actual reason: **a merged file is the only
one CI can check.** Decision 8's guards run on `main`; on a never-merged branch
they run only when someone remembers to push it. An open PR additionally
accumulates merge conflicts against a `main` that moves every session, so it
carries the drift risk *plus* a rebase cost, for no gain in what is verified.

**Consequence, accepted and not minimised:** the proposal is a *second*
description of the same subject, and second descriptions drift. Decision 8's
parity and anchor assertions make the drifts that matter loud; a purely editorial
drift in the shipped text would not be caught. That is a real cost of this
decision, not a risk the decision avoids.

## Decision 3 — Only the three privacy policies change; the terms do not

Measured: `grep -in 'notification|push|analytic'` over `terms.{tr,ar,en}.md`
returns **nothing**. The terms describe the agreement, not the processing, and
neither correction touches the agreement.

Recorded explicitly so a later reader does not conclude the terms were
overlooked, and so the bump diff does not gratuitously re-issue three documents
whose content did not change.

## Decision 4 — The proposal is dated with a placeholder, and the placeholder's SHAPE is a guard

Each proposed document carries:

```
Version 3. Effective [EFFECTIVE DATE — set on the day this revision ships].
```

The date cannot be known now: it is the day the founder says go. Writing a
plausible one would be inventing a fact into a legal document, which is the same
error class as guessing the founder's legal name (`session-context.md` §7).

The bracketed em-dash span is chosen deliberately. `build_site.py`'s
`PLACEHOLDER_SPAN = re.compile(r"\[[^\[\]\n]*—[^\[\]\n]*\]")` matches it, and the
site build **fails closed** on any unfilled placeholder in published legal text.
So a revision that lands with the date still unset cannot reach `/privacy`. That
guard already exists; this decision only chooses a shape that steps into it.

The three existing placeholders (legal entity, contact address, governing law)
are carried through **unchanged and still bracketed**. This session does not
invent them.

## Decision 5 — The push disclosure describes the SYSTEM, and states the empty outcome separately

The failure mode being corrected is a notice that described an outcome. The
replacement therefore says, in each locale:

1. **What is stored** — the address the device is reachable at for notifications,
   one per device; and the device's own report of whether notifications are
   switched on. In user language, not field names.
2. **Why — all FOUR of them.** `PushKind` has four members, and revision 1's
   purpose list named two. A purposes list that is a subset of the purposes is
   the same defect as the sentence this ADR exists to correct, one level down.
   The four, measured from `payload-policy.ts` and the two senders:

   | kind | when | sent to |
   |---|---|---|
   | `partnerAnswered` | immediately, on the partner's answer write (`reveal-service.ts`) | the member who has not answered |
   | `reveal` | immediately, once both have answered | the member who answered first |
   | `dailyQuestion` | couple-local **09:00** (`DAILY_QUESTION_LOCAL_HOUR = 9`) | whoever has not answered |
   | `streakAtRisk` | couple-local **22:00** (`AT_RISK_LOCAL_HOUR = 22`) | whoever has not answered |

   All four are service messages about the couple's own activity in a product
   they signed up for. Nothing else is sent.
3. **The bounds that are already built, stated as bounds rather than as
   reassurance** — a notification never carries the question or an answer
   (structural: `composePush` has no such parameter); nothing is sent inside
   couple-local quiet hours **23:00–08:00**; the discreet setting limits what
   shows on a lock screen and is on whenever the reading language is Arabic or
   the user has switched it on (`resolveDiscreet`).

   ⚠️ **The window is 23:00–08:00, not 22:00–08:00**, and revision 1 said the
   latter. **ADR-045 moved it** so the 22:00 streak nudge would not be swallowed
   by our own defence-in-depth guard — *"22:00 is the last legal hour"*
   (`local-hour.ts:47-60`, `isQuietLocalHour` = `hour >= 23 || hour < 8`).
   Writing 22:00 into a privacy policy would have told users they cannot be
   notified at 10pm on the one evening hour the product deliberately uses. It is
   recorded here rather than silently fixed because it is precisely the failure
   this ADR is about: **an inherited number that describes a system that changed.**
3a. **That a notification can carry the partner's NAME.** `partnerAnsweredNormal`
   interpolates it into both title and body (*"Aylin answered"*). It carries no
   answer text — but a name on a lock screen is exactly what a DV-aware product
   must disclose rather than let a user discover, and it is the one thing the
   discreet setting is really protecting. v2's copy says the discreet setting
   shows *"only that something new arrived"*, which describes the discreet path
   correctly and says nothing about the default path. The draft states both.
4. **Who else sees it** — Google's Firebase Cloud Messaging and Apple's push
   service, neither pinned to Europe, with the same region honesty the rest of
   the document already uses.
5. **How long** — the address is removed at sign-out and on account deletion; the
   permission report lives on the user document until the account is deleted.
6. **That it has never actually happened.** *"We have not delivered a single
   notification yet"* stays true, stays in, and is stated as an outcome next to
   the system description rather than in place of it. A notice that over-claims a
   working feature is its own kind of dishonesty — and this one is checkable by
   the reader, which is the standard the document's own opening paragraph sets.

Point 6 is the whole lesson of #226 rendered as drafting practice: **describe the
system, then state the outcome; never let the outcome stand in for the system.**

## Decision 6 — The analytics paragraph is corrected without spending the promise

The replacement paragraph, in each locale, says:

1. **What the app records** — a short, fixed list of milestones (installed,
   signed in, invite sent, paired, question answered, reveal seen, streak day,
   coach message), each a count of something happening.
2. **What it structurally cannot contain** — no reflection, no answer, no coach
   message. This is not a promise of care: `AnalyticsEvent` is a sealed hierarchy
   with **no `String` field anywhere**, asserted by
   `analytics_event_test.dart`. The notice may say it plainly because the type
   system says it first.
3. **Where it goes: nowhere.** Today the app records these and discards them on
   the device. No analytics provider is connected and none receives anything.
4. **What stays on the device** — a small marker per milestone, so a milestone is
   not counted twice. It never leaves the phone, and removing the app removes it.

   **And the honest bound the design review made us look at: deleting the
   account does not remove them.** The cascade sweeps `users/{uid}` and the
   couple's shared space server-side (ADR-019); the markers live in the phone's
   own `SharedPreferences`, which no server can reach, so
   `analytics.signup.<uid>` and its siblings survive a deletion on the device
   that wrote them — carrying a uid and, for one key, a `coupleId`. Two verifiers
   independently held that this does **not** make the analytics correction
   material (nothing is transmitted, no recipient gains anything, and the
   *"data-location split"* trigger is about server-side geography — see ADR-023's
   own use of that phrase), and that judgement is accepted. It is still a gap
   between what *"delete my account"* sounds like and what it reaches, so the
   draft says removing the app is what removes them, and the gap is **filed as
   its own issue** rather than left in this paragraph.
5. **The promise, kept verbatim in substance** — if analytics is ever connected,
   it arrives with its **own separate opt-in**, off until it is turned on, with
   the provider named at that moment, and it is never folded into the one
   consent this app already asks for.

Point 3 is what makes the paragraph honest and point 5 is what keeps v2's word.
Neither pre-consents to anything, and the paragraph names no vendor — see
Decision 1 and lawyer question D for why naming one now was rejected.

## Decision 7 — The register gains the two rows it has been hand-waving, and records the İYS position

`docs/dpa-inventory.md` gains:

* **Google — Firebase Cloud Messaging** — processor; registration tokens and the
  content-free payload; not region-pinned; the same entity-wide Google Cloud DPA;
  rides the existing KVKK cross-border block.
* **Apple — Apple Push Notification service** — the relay for every iOS
  notification. **Apple's role on this leg is a lawyer question**, not an
  engineering fact: the register already treats Apple as an *independent
  controller* for store data, and APNs is a different leg under different terms.
  It is entered as **role: to be confirmed (founder/lawyer)** rather than
  asserted, because asserting it would be playing counsel — **and it is raised as
  numbered lawyer question E in `docs/legal/README.md`**, not left as an
  annotation in a register cell (the design review's catch: a question only a
  reader of the register would ever meet is not a question anyone has been
  asked).

And the device-registration note stops disposing of both in a subordinate clause;
it points at the rows.

**İYS / ETK, recorded as a position and not as advice.** The two push kinds the
sweeps compose (`PushKind` — the daily question, the at-risk streak nudge) are
**service messages about the recipient's own activity in a product they signed up
for**, not *ticari elektronik ileti*. On that reading İYS registration is not
triggered by what is built today. **Any promotional push would trigger it**, and
the register carries that as a forward obligation rather than a settled one.

## Decision 8 — A structural test guards the draft, and the bump diff deletes the test

The draft is prose, and prose is exactly what this repo has learned not to trust
a green signal about (lesson 110: *a scan whose glob matches nothing reports the
same clean zero as a scan that passed*). So the test is built to fail loudly on
an **empty or missing input** before it asserts anything about content.

`app/test/features/legal/legal_proposal_test.dart` **will assert** — it does not
exist yet, and neither does the directory it reads:

1. **The input exists and is a closed set** — `docs/legal/proposed/` contains
   **exactly** `privacy-policy.{tr,ar,en}.md` plus `README.md`, no more and no
   fewer, and each document clears a **line-count floor**. A proposal that
   silently lost a locale is a red, not a clean zero.
2. **The draft is exactly one version ahead, and has NOT landed** — each document
   declares version **3**, and `currentLegalVersion` is still **2**. This is the
   assertion that makes "deliberately not landed" a machine-checked state rather
   than a sentence in an ADR.

   ⚠️ **The version line is LOCALISED, and a literal `Version 3.` match would
   guard one of the three locales.** The shipped documents read `Version 2.` (en),
   `Sürüm 2.` (tr) and `الإصدار 2.` (ar). The assertion therefore parses a
   **per-locale pattern** and compares the extracted integer — the recurring
   shape 5 failure (*a gate written in one language guards one language*) caught
   by the design review before it was written rather than after.
3. **Renderer-subset conformance** — no table, link, bold, italic, inline code,
   block quote, image, numbered list or nested bullet, per
   `docs/legal/README.md`'s authoring rules. A draft that cannot render is a
   defect discovered now rather than at bump time, on the day the founder is
   waiting.
4. **Section parity across locales** — the three documents carry the same `##`
   sections in the same order. *"No locale may promise anything another does
   not"* is not fully checkable by a machine; the section skeleton is the part
   that is.
5. **No shipped section was dropped** — every `##` heading position present in
   the shipped document has a counterpart in the proposal. A revision that
   silently deletes *"How long we keep your data"* reddens.
6. **The anchors** — the exact sentence being corrected is asserted **present in
   the shipped document** and **absent from the proposal**, in all three locales.
   The presence half is the control: it proves the instrument can see the thing
   it is looking for, so the absence half is evidence rather than a vacuous pass.
   If the shipped text ever changes such that the anchor disappears, the test
   says *the premise moved*, which is the message a later session needs.

**What the test deliberately does not do.** It does not review the law, does not
check translation fidelity, does not know whether a disclosure is adequate, and
cannot tell a good notice from a bad one. It guards *shape*. The founder and the
lawyer guard *substance*, and this ADR does not let the green reflect on them.

**The test is deleted by the landing diff.** Its first assertion is that
`docs/legal/proposed/` exists, so once the proposal moves into place the file
must go with it. That is the intended coupling: the bump diff cannot leave a
stale guard behind, and `docs/legal/proposed/README.md` carries the deletion as
step 0 of its procedure.

**And by the SUPERSEDING diff too.** If some future revision becomes v3 without
using this draft, assertion 2 turns red — correctly, because the premise moved —
and a session then has to work out from a failing test what to do. Both verifiers
held that red CI is an adequate recovery mechanism under `session-rules.md` §3.5,
and that is true; it is also an archaeology exercise that costs nothing to
prevent. `docs/legal/proposed/README.md` therefore carries the one-line
alternative: **if a different revision lands first, delete
`docs/legal/proposed/` and `legal_proposal_test.dart` in that same diff and say
in the commit message that the proposal was superseded.**

## Consequences

* **#226 stays open, and its state changes from "the notice is wrong" to "a
  reviewable correction is on `main`, awaiting the founder and the lawyer."**
  Nothing about the shipped product changes in this session. No user is
  re-consented. `CURRENT_LEGAL_VERSION` remains 2 in all three sources, and a
  test now says so out loud.
* **The gap widens with the next build, and the operator file must say so.**
  Build 119 already attempts the `fcmTokens` collection. The next `release.yml`
  dispatch adds `pushDiagnostic` (ADR-049) and the on-device analytics markers
  (ADR-057) to real phones. The correction is therefore **overdue today and more
  overdue after the next build** — which reorders operator item 18's *"before the
  adapter"* to something sooner.
* **The founder now has one decision instead of two**, and it is a decision about
  substance rather than about mechanics: approve the drafted text (with the
  lawyer), then a single diff bumps three version sources, re-syncs **the three
  changed privacy policies** into `app/assets/legal/` (the three terms documents
  do not change and are not touched — Decision 3), sets the effective date,
  **updates `shippedPolicyVersionLine`**, regenerates three golden sets, and
  deletes the proposal together with its test. That diff is written out step by
  step in `docs/legal/proposed/README.md` so it does not have to be re-derived
  under time pressure.

  ⚠️ **`shippedPolicyVersionLine` is the step this ADR's first revision left
  out**, and `docs/legal/README.md` step 3 names it as one of **two** places the
  three-way sentinel does not cover — both *"found the hard way when the v1→v2
  bump left them behind"*. Revision 1 carried the goldens and dropped the pin,
  i.e. reproduced half of a mistake the repo had already paid for once. Lesson
  115 exactly: the rule was cited, and the part not quoted was the part being
  dropped.

* **`docs/legal/README.md` gains lawyer questions D and E**, so the lawyer's
  canonical list is the one that is complete. Question D is Decision 1's (does
  naming the analytics recipient at the opt-in surface discharge the aydınlatma
  obligation, or does the adapter bump the version too). **Question E is Apple's
  role on the APNs leg** — Decision 7 raises it, and revision 1 left it as an
  annotation inside a register cell where a lawyer reading the question list
  would never meet it. Two questions raised for a lawyer, in a document that says
  *"These three questions"*, is a list that lies by arithmetic.
* **A second bump is likely when a vendor lands**, and this ADR says so rather
  than letting operator item 18's phrasing imply otherwise. Lawyer question D can
  remove it; nothing else can.
* **The proposal can drift from the shipped documents.** Decision 8's parity and
  anchor assertions make the common drifts red; a purely editorial drift in the
  shipped text would not be caught, and that is accepted rather than hidden.
* **Nothing here is legal advice.** Every document in the bundle remains
  *AI-drafted, review-PENDING*, exactly as `architecture.md` §8 records — and
  this ADR adds a fourth open lawyer question to A, B and C rather than closing
  any of them.

## What the design pass changed (revision 1 → revision 2)

5 lenses × 2 independent verifiers + a completeness critic. **26 agents, 0
errored, 0 empty results, 13 findings, nothing dropped unverified** — the
`agents_error` / `agents_empty_result` check `session-context.md` §5 item 5
requires, stated as numbers rather than as "the review passed".

**Surfaced and fixed:**

| # | severity | what revision 1 got wrong |
|---|---|---|
| 1 | **blocker** | Decision 5 wrote the quiet window as **22:00–08:00**. ADR-045 moved it to **23:00–08:00** so the 22:00 nudge could be delivered. The wrong number was heading into a privacy policy |
| 2 | **blocker** | Decision 8 described `docs/legal/proposed/` and `legal_proposal_test.dart` in the present tense; neither exists. Now written prospectively |
| 3 | major | The Consequences bump-diff summary omitted **`shippedPolicyVersionLine`** — one of the two places `docs/legal/README.md` step 3 says the sentinel does not cover, and one the v1→v2 bump had already been caught by once |
| 4 | major | Decision 8 assertion 2 said each document declares `` `Version 3.` ``. The line is **localised** (`Sürüm`, `الإصدار`), so that guard would have covered one locale of three |
| 5 | minor | Consequences said the bump *"re-syncs six bytes-identical files"* while Decision 3 says only three documents change. Corrected to three |
| 6 | minor | `build_site.py`'s stem list is on **line 323**; line 325 is the path composition. Both are now cited |

**Raised by the completeness critic and acted on:**

| # | what nobody else looked for |
|---|---|
| 7 | **Lawyer question D was created and never added to the lawyer's list.** `docs/legal/README.md` still said *"These three questions"*. D and E now land there |
| 8 | **Apple's APNs role was a fifth question hidden inside a register cell.** Now numbered E |
| 9 | The analytics-adapter gate exists only as prose across two ADRs and an operator item, with no issue tracking it. Filed |

**Attacked and NOT changed — both verifiers refuted, and the reasoning is
recorded so the same objection does not have to be re-litigated:**

* *"Mixpanel is already named, so name it in the notice."* A technology intention
  in `architecture.md` is not an engaged recipient; the register itself says no
  processor exists and no row is due. Answered in Decision 1.
* *"The analytics correction is material on its own — the on-device markers are
  a new storage location for identifiers."* The *"data-location split"* trigger
  is about server-side geography (ADR-023's own usage), and nothing is
  transmitted. The **deletion gap** the finding surfaced along the way is real,
  is now stated in Decision 6, and is filed.
* *"A different v3 could supersede the proposal and leave CI red."* True, and red
  CI is the designed recovery (`session-rules.md` §3.5) — but the one-line
  cleanup instruction is cheaper than the archaeology, so Decision 8 carries it.

**Also corrected without a finding**, from the session's own reading of
`payload-policy.ts` while the review ran: Decision 5's purpose list named **two**
of the **four** `PushKind` members, and said nothing about `partnerAnswered`
interpolating the **partner's name** into a notification. A purposes list that is
a subset of the purposes is the same defect as the sentence this ADR exists to
correct.
