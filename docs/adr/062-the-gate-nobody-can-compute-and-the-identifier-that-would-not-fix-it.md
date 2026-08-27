# ADR-062: the gate nobody can compute, and the identifier that would not fix it

- **Status:** Proposed
- **Date:** 2026-08-26 (Session 086) · **Revision 2, 2026-08-27** — the design review refuted revision 1's central bias claim, and the recommendation changed with it
- **Deciders:** session agent records the options; **the founder decides** — minting an identifier is collection, and the definitional question in Finding 3 is a product call
- **Related:** **ADR-057 D3** (no uid or `coupleId` on any client event, ever) and **D7** (which filed this), **ADR-060 D3** (which held D3's line at the one server seam where both identifiers were in scope, and handed the *relaxation* here), **ADR-007** (gates are decision instruments, not build blockers), **ADR-013 D5** (the couple-scoped entitlement mirror), **ADR-006** (iOS-first, so the Gate reads come from one platform), issues **#243** (this one), **#226**, **#242**, **#247**, `docs/mvp.md` Gate 3, `docs/dpa-inventory.md`

> **Review status.** Revision 1 was written and committed **before** any other work
> (`session-context.md` §5 item 1, lesson 115). **Revision 2 folds the design
> review** — 4 lenses × 2 independent verifiers, `agents_error=0`,
> `agents_empty_result=0`, 6 findings, 6 verified, **0 dropped unverified**, 3
> surviving. There is no built diff to review: **nothing is built by this ADR and
> no identifier is minted.**

## Revision 2 — the review refuted the argument the recommendation rested on

Revision 1's Finding 3 said an aggregate ratio's error *"runs the safe way"* under
growth, and Decision 1 recommended a **lagged** window ratio on that basis. **Both
verifiers refuted it, at high confidence, and they are right.**

The dilution argument — *"the denominator carries users who have not yet had time
to convert"* — is a property of the **same-window** ratio (lag 0). Applying a lag
is precisely what removes it. Worse, with a distributed conversion lag and growing
installs, the lagged numerator collects payments from **later, larger cohorts**
than its denominator, so by Jensen's inequality it **overstates** — the opposite
of safe, in the one direction a spend gate must not fail.

Worked, because the sign of an error is not a thing to reason about loosely. A
product whose true cohort conversion is **1.5%** — which should **fail** a ≥2%
gate — with installs doubling per window and half the cohort converting after one
window and half after two:

| lag | reads | vs truth | gate verdict |
|---|---|---|---|
| **0 (same window)** | 0.56% | understates | **fails** ✅ correct |
| 1 | 1.13% | understates | fails ✅ |
| **2** | **2.25%** | **overstates** | **PASSES** ❌ **wrong — green-lights spend** |
| 3 | 4.50% | overstates | PASSES ❌ |

With flat installs every lag is exact, which is why the error is invisible in a
steady state and appears exactly when a launch is working.

**So the recommendation inverts**: the gate's decision number is the
**same-window** ratio, *because* it is the one that cannot falsely pass. Revision
1 had the right instinct — prefer the estimator that fails safe — and named the
wrong estimator.

## Context — four measurements, and two of them move the question

`mvp.md` Gate 3: **`trial→paid ≥30%; install→paid ≥2%`**. #243 says the second is
uncomputable because the two emitters share no identity. That is true. It is also
not the whole problem, and the identity question is not the first one to answer.

### 1. There is genuinely no join, and the missing one was removed on purpose

`install` is a **client** event fired at first launch, before an account exists.
`paid` is a **server** event, emitted from `processRevenueCatEvent`'s `applied`
outcome (ADR-060 D1). ADR-057 D3 forbids a uid or `coupleId` on any client event
**ever** — stronger than ADR-016 requires, and deliberately so, because this is a
domestic-violence-aware product. ADR-060 D3 then held that line at the one server
seam where both identifiers were in hand, and explicitly handed the *relaxation*
to this issue rather than taking it silently.

So the absence is a decision that has now been reaffirmed twice. Reversing it
should cost at least as much argument as making it did.

### 2. The three denominators are not the same thing, and no identifier fixes that

This is the measurement that reframes the issue, and it was found by asking what
each event **counts** rather than what it is keyed by:

| | counts one per | source |
|---|---|---|
| `install` | **device installation** | `DeviceFlag.install` (ADR-057 D4, re-confirmed S085). Not "once per phone": D4 records the honest bound that **a reinstall re-emits**, because the key lives in `SharedPreferences`, which app deletion removes |
| `signup` | **uid** | `AccountFlag.signup`, once per account per device |
| `paired` | **uid** | both partners' devices emit; ADR-057 D4 says so explicitly — *"this counts users paired, never couples"* |
| `paid` | **couple** | the entitlement mirror is `subscriptions/{coupleId}` (ADR-013 D5); one purchase entitles both members |

**`install→paid` divides a couple count by a device count.** A couple who both
install and then subscribe once is **two** installs and **one** `paid`. Read
naively, the gate's own arithmetic halves itself for exactly the users the product
is for — and the error is invisible, because both numbers are individually
correct.

**A distinct id does not fix this.** Joining devices to accounts tells you which
installs became which users; it does not tell you whether the founder means *"2%
of installs produce a payment"* or *"2% of installs become a paying user"*, and
with a couple-scoped subscription those differ by **2×** on the paired population.
A 2× definitional ambiguity dominates every estimator question below, and it is
free to resolve now, while nothing depends on the answer.

### 3. For a go/no-go threshold, the join is not needed — but WHICH aggregate matters

Gate 3 is a **decision instrument for launch and spend posture** (ADR-007), not a
product feature. The question it answers is *"do enough installs turn into revenue
to make acquisition spend viable?"* — and a **ratio of two counts** answers that
without any identity.

**But the choice of window is not a detail, and revision 1 got it backwards.**
Write `w[k]` for the share of a cohort that converts `k` windows after install,
`c = sum(w)` for the true cohort rate, and let installs grow at `g` per window.
The ratio taken with lag `L` is:

```
R(L) = payments(W + L) / installs(W) = sum over k of  w[k] * (1 + g)^(L - k)
```

* **`L = 0`** — every term has a negative exponent, so `R < c` while `g > 0`: it
  **understates**, and converges to `c` as growth flattens. Conservative.
* **`L` near the mean lag** — the numerator collects payments from *later, larger*
  cohorts than its denominator. `(1+g)^(L-k)` is convex in `k`, so by Jensen the
  weighted average exceeds `(1+g)^(L - mean k) = 1`: it **overstates**, strictly,
  unless the lag is deterministic. Conversion lag is **not** deterministic — trial
  lengths and decision time spread it.
* **Deterministic lag, correct `L`** — exact, and unavailable for that reason.

The table in Revision 2 above puts numbers on it: a **1.5%** product reads
**2.25%** at lag 2 with doubling installs and **passes a 2% gate it should fail**.

What no aggregate can do, stated so nobody discovers it later: it cannot attribute
by acquisition channel, cannot answer *"of the users who installed in week 1, what
share paid by week 8"* exactly, and inherits Finding 2's ambiguity like every other
option. **None of those is what a ≥2% launch threshold is for.**

### 4. Nothing is measurable today under ANY option, and that is the real critical path

Prod ships a **no-op sink** (ADR-057 D2c). No `install` count exists anywhere, on
any device. The server three have **no emitter at all** (ADR-060 built nothing,
and `ProcessOutcome` must grow first). The vendor adapter is gated behind a legal
change that is founder/lawyer-blocked (#226, #247).

So `install→paid` is not blocked *first* on identity. It is blocked on a sink, an
emitter, and a legal revision — all three of which every option below needs
equally. **Minting an identifier today would buy nothing that could be read.**

## Decision 1 — The gate's number is the SAME-WINDOW ratio; mint no identifier

**Compute Gate 3's `install→paid` as `payments(W) / installs(W)` — same window,
no lag — and treat that as the number the gate is read against.** No device
identifier, no alias, no change to `PrivacyInfo.xcprivacy`, no new row in
`docs/dpa-inventory.md`, no legal-version bump beyond the one #226 already owes.

**The lagged ratio may be reported beside it as the optimistic bound.** Between
the two lies the truth; the gate clears when the **conservative** one clears. That
is the whole discipline, and it is one line to implement.

The reasoning is not that the ratio is as good as a cohort join. It is that:

* the join's **only** advantage over the ratio is precision the threshold does not
  use, and channel attribution the MVP does not buy;
* the same-window ratio's error runs **toward refusing spend**, which is the
  direction a gate should fail in — and it is the *only* one of the three
  estimators in Finding 3 for which that is true;
* and the join's cost is the one identifier in this system that **survives
  sign-out** — see Decision 3.

**The cost of the conservative choice, named rather than buried.** Under steep
growth the same-window ratio reads far below the truth (0.56% against a real
1.5%, in Finding 3's table), so it can hold spending back on a product that is
actually clearing the bar. That is a real cost and it is the one worth paying:
the opposite error spends money on a product that is not.

## Decision 2 — Ask the founder the definitional question FIRST, because it is free and it is larger

Before any identifier is considered, `mvp.md`'s `install→paid` needs one sentence
saying whether the numerator is **payments** or **paying users**. On the paired
population those differ by 2× (Finding 2), which is 100% of the threshold's own
value — a gate that reads 2% under one definition reads 4% under the other.

This is a **product** question with no privacy cost and no engineering
prerequisite, and answering it may well settle #243 on its own: if the founder's
intent is a coarse *"is acquisition viable"* read, Decision 1 is sufficient and
the identifier never comes up again.

**This ADR does not edit `mvp.md`.** Gate thresholds and their definitions are the
founder's (ADR-007); a session that quietly rewrote one would be deciding launch
posture by commit.

## Decision 3 — If an identifier is ever minted, these are its costs, priced now

Recorded so the option is refusable on evidence rather than on unease, and so a
later session does not re-derive it:

* **It is collection.** `PrivacyInfo.xcprivacy` today declares
  `NSPrivacyTracking=false` with an **empty** `NSPrivacyTrackingDomains`, and its
  `NSPrivacyCollectedDataTypes` list mirrors the future App Privacy answers. A
  persistent cross-session device identifier interacts with both, and the manifest
  already carries **one unresolved judgement call** (the Sensitive Info question,
  issue #55) that the founder has to answer at submission anyway.
* **It needs a `docs/legal/` line and a processor row**, which means a
  `CURRENT_LEGAL_VERSION` bump, which **re-gates consent for every existing
  user** — the same cost that has held #226 still since S082, paid a second time
  if it is not folded into that revision.
* **It survives sign-out.** Every other identifier in this system dies with the
  session or the account; ADR-061 has just made the account-scoped device flags
  die with the account too. A device id would be the **only** thing that persists
  across both — in a product whose threat model is *a partner holding the phone*.
  That is not a reason it can never exist; it is the reason it cannot be inherited
  from an SDK default.
* **It reopens a line held twice.** ADR-057 D3 and ADR-060 D3 both refused an
  identifier on an event. A third document permitting one should supersede them
  explicitly rather than sit beside them.

## Decision 4 — The install-time server ping is refused, and not on privacy grounds

The issue's third option — a server call at first launch — is worse than both
others on its own terms. It **is** the distinct id, with extra steps: an
unauthenticated write surface reachable before any account exists, which must be
rate-limited and abuse-resisted. **#115 is the relevant precedent for the shape of
that decision, not for the abuse risk**: it records that making a prod endpoint
world-reachable is a security decision on a live system, founder-gated, and still
open. A new pre-account surface would be a second one. The ping produces a record
that is either
identifier-bearing (Decision 3's costs, plus a network leg) or anonymous (in which
case it is Decision 1's count, arrived at expensively).

It is listed in #243 as a real alternative and it is priced here so that listing
does not read as an open question.

## Consequences

* **#243 does not close.** It stays open for **Decision 2's one sentence**, which
  only the founder can write. The engineering side of it is now decided.
* **Gate 3's `trial→paid ≥30%` is unaffected** and always was — both events are
  server-side (ADR-060). **Gate 2 is unaffected** — both events are client-side and
  uid-keyed. **One threshold of four** was ever at stake, and this ADR does not
  leave it unmeasurable: it leaves it measurable with a stated bias.
* **The estimator's window must be reported with the number, every time.** A ratio
  quoted without saying whether it is same-window or lagged is a cohort figure
  that is quietly wrong **in an unknown direction** — and revision 1 of this very
  ADR made that mistake in the direction that green-lights spend. There is no test
  that can enforce it, because nothing is computing it yet; this paragraph is the
  only guard, which is why the arithmetic is written out above rather than
  summarised.
* **Finding 2 is a live defect in a document, not a hypothetical.** `mvp.md`'s
  Gate 3 line is ambiguous *today*, and would have been read wrong by whoever
  first built the funnel — including under the identifier option. It is now
  written down before anyone acts on it.
* **Nothing here unblocks measurement.** The sink, the emitter and the legal
  revision remain the critical path (Finding 4), and all three are ahead of this
  decision, not behind it.
