# ADR-061: "delete my account" and the local flags it cannot reach

- **Status:** Proposed
- **Date:** 2026-08-21 (Session 085)
- **Deciders:** session agent (device-local behaviour; no operator dependency)
- **Related:** **ADR-019** (the M6.2 deletion cascade), **ADR-017 D3/D4** (the app-root teardown; the `LocalFlagStore` seam and why it is set-once), **ADR-057 D4** (once-only funnel keys and the reinstall bound), **ADR-018** (the PIN store, which cites the sticky contract as a reason for its own design), **ADR-058** (S082's legal draft, which states what happens to these markers), issues **#246** (this one), **#250** (Android backup)

> **Review status, stated prospectively.** Written and committed **before** the
> fix (`session-context.md` §5 item 1, lesson 111). Neither review pass has run
> at the time of this commit.

## Context — four things measured before deciding anything

#246 says the once-only analytics markers survive account deletion. True. Four
measurements change what the fix should be.

### 1. The defect is not analytics-specific — it is every uid-keyed local flag

`LocalFlagStore` has three consumers, and **all three key by uid**:

| prefix | written by | survives deletion? |
|---|---|---|
| `analytics.signup.<uid>` and four uid-keyed siblings | `Analytics._claimOnce` | yes |
| `coachDisclaimerAck.<uid>` | the coach disclaimer gate (ADR-017 D4) | yes |
| `coupleEndedSeen.<uid>.<atMs>` | the couple-ended notice (ADR-019) | yes |
| `analytics.install` | `Analytics.install` — **the only one with no uid** | yes, and correctly |

#246 names one of three. Fixing only the one it names would leave the same
defect, in the same store, behind the same seam — and the next reader would have
no reason to think the other two were considered. **The issue's scope is
narrower than the defect's.**

### 2. Clearing them changes NO counts, because the uid is already in the key

The `resume-prompt.md` that assigned this session said clearing the markers
*"makes a later re-signup re-emit once-only events — a counting change to a
funnel, traded for a data-rights improvement."* **That is wrong, and it was my own
sentence.**

`analytics.signup.<uid>` contains the uid. A deleted account's replacement has a
**different uid**, so it gets a **different key**, so it re-emits `signup`
already — cleared or not. The same holds for `paired`, `q`, `reveal`, `streak`,
`coachDisclaimerAck` and `coupleEndedSeen`. **For every uid-keyed flag, clearing
is behaviourally invisible**; its only effect is that stale personal data stops
sitting on the device.

So there is no trade to weigh here. The trade I wrote into the resume prompt did
not exist, and the reason it looked real is that I reasoned about the *flag*
rather than about the *key*.

### 3. `analytics.install` must NOT be cleared, and needs no defending

It is the one flag with no uid in it, and it is device state rather than account
state: this phone did install the app once, and that stays true across an account
deletion. Clearing it would make a re-signup emit a **second `install`** from one
device — a real counting error, and the only one available in this whole change.

It also carries **no identifier**, so the data-rights argument that motivates the
others does not apply to it. Both concerns point the same way, which is why this
ADR can be decisive rather than balancing.

### 4. The app-root listener CANNOT tell a deletion from a sign-out

`app.dart` already distinguishes two teardown depths, deliberately (ADR-017 D3):

```dart
if (next is! AuthSignedIn) { ref.invalidate(coachTranscriptProvider); }
if (next is AuthSignedOut) { ref.read(privacyLockControllerProvider.notifier).wipe(); }
```

**Both a deletion and an ordinary sign-out end in `AuthSignedOut`.** So hooking
the clearing there would clear on *every* sign-out — and for
`coachDisclaimerAck.<uid>` that is a visible regression: signing out and back in
as the same user would re-show the coach disclaimer they already acknowledged.

This is the finding that decides the shape of the fix. **The clearing belongs to
the delete flow, not to the auth teardown**, because only the delete flow knows
which of the two happened.

## Decision 1 — Clear every uid-keyed local flag, on deletion only

At the point the delete flow has succeeded and before it hands off to sign-out —
the one place that knows a *deletion* occurred rather than a sign-out.

`analytics.install` is exempt, by name and with the reason in the code, so a
later reader does not "fix" the exemption.

## Decision 2 — `LocalFlagStore` gains a scoped removal, and the sticky contract survives for everyone else

The seam is documented as **"one-way STICKY flags (set-once, never cleared)"**
(ADR-017 D4), and `pin_lock_store.dart` cites that contract as a reason for its
*own* design — so widening it is not a local change.

It gains **one** method that removes keys **by prefix**, not a general `clear`:

* a general `clear(key)` invites the auth listener to call it per-flag, which is
  finding 4's trap;
* a prefix removal expresses the actual operation — *"everything this account
  wrote"* — and makes `analytics.install` exempt by **construction**, since it
  matches none of the uid-scoped prefixes;
* the sticky contract is re-stated rather than deleted: flags are still never
  cleared **by the code that sets them**. The only thing that removes them is an
  account deletion, which is the one event that removes everything else too.

## Decision 3 — The legal draft's sentence is checked, and it survives

`docs/legal/proposed/` currently says the markers *"go when you remove the app"*
and that we never receive them. Both stay true. What changes is that deleting the
account **also** removes them, which is strictly more than the draft promises —
so the draft is **not** re-opened. A revision that made the notice promise *less*
than the app does would be the wrong direction; making it promise *more* than the
app does is #226's whole subject.

## Consequences

* **`#246` closes**; the two flags it did not name are covered by the same change.
* **Nothing measurable changes in the funnel.** Finding 2 — and if it were wrong,
  the counting error would be silent, which is why Decision 1 exempts `install`
  explicitly rather than relying on the prefix list being right.
* **The sticky contract is now conditional**, and a later author reading
  `LocalFlagStore` must see that in the seam rather than discover it in a
  cascade. Decision 2's doc comment is the mitigation, and it is the whole reason
  the method is prefix-scoped rather than general.
* **`#250` (Android auto-backup) is untouched and still binds**: on a platform
  where backup restores prefs, a cleared flag can come back. The fix removes what
  is on the device; it cannot reach a copy Google or Apple already took.
