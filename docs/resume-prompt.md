# Resume Prompt — Session 084

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **124**) first.
> Re-derive the session number from `git log`.

**Objective: #242 — decide, and record in an ADR, WHICH server surface emits
`trial_start` / `paid` / `churn`. The decision does not need the vendor.**

`architecture.md` §7 assigns three of the twelve funnel events to a **server**
emitter that does not exist: there is no analytics port anywhere in `functions/`.
The app deliberately does not emit them — it learns entitlement from a mirror, so
a client `paid` would timestamp the moment the phone *noticed*, and would be
missing entirely for a user who never reopens the app (ADR-057).

**Two candidate surfaces, and the choice is the session:**

1. **A port on the RevenueCat webhook** (`revenueCatWebhook`) — closest to the
   truth, fires once per real billing event, carries `store` (which is where §7's
   `storefront` dimension was always going to come from). But the webhook is a
   **bearer-token surface whose delivery is not guaranteed**, it is **not
   publicly invocable today** (#115), and it already has an idempotency guard
   whose semantics the emitter would inherit.
2. **A Firestore trigger over `subscriptions/{coupleId}`** — fires off our own
   state, so it cannot miss a delivery the webhook dropped; but it observes a
   *mirror*, so it times the moment we wrote the mirror, and it needs a
   before/after diff to tell `trial_start` from `paid` from `churn`.

**Acceptance:** an ADR that picks one, states what it costs, and answers at
minimum — how each of the three events is *distinguished* from the other two;
what fires on a **replay** (the webhook's idempotency guard is exact-replay only);
what fires on a **restore** or a plan change; whether an event can be emitted
twice; and what happens to events that occur while no sink exists. **No adapter,
no vendor, no token.** Code only if the ADR's own decision demands it.

⚠️ **This rides #226 and #243 and cannot outrun them.** Emitting from the server
is still *collection*, and prod ships a **no-op sink** for exactly that reason
(operator items 16/18, issue **#247**). The ADR may decide the surface; it may
not wire a vendor.

⚠️ **`architecture.md` §7's FIRST SENTENCE is parsed by a test**
(`funnel_event_sentinel_test.dart`) behind a ≥12-name floor. If this ADR changes
which emitter owns an event, **that sentence is the source of truth the test
reads** — edit it deliberately, and expect the suite to tell you.

---

## 1. Where things stand *(measured 2026-08-21 — re-measure, do not inherit)*

| | State |
|---|---|
| **#226** | **DRAFT on `main`, revision NOT landed.** `docs/legal/proposed/` holds version 3 of the three privacy policies; `CURRENT_LEGAL_VERSION` is **still 2** and a test asserts it. Closes only when founder + lawyer approve |
| **#136** | **Autonomous half DONE** (ADR-059). Stays open for **step 1** — whether the notification shade honours `U+2068`/`U+2069` — which is device-blocked |
| **Push, device side** | **STILL ZERO.** 0/4 accounts registered, all four "no report" |
| **`partnerAnswered` never names anyone** | **#253** — no caller supplies `partnerName`. A product gap, filed, not a bug |
| **The build gap** | Last `release.yml` run is **2026-08-09, build 119**. ADR-046/049/051/052/053/057/059 are on **nobody's phone** |
| **Deployed rules / functions vs `main`** | Both **drifted or unmeasured** since S071/S077. **S083 changed `functions/` source**, so prod is further behind. A deploy is a **§7 founder ask** |
| **Open issues** | **#242**, **#243**, **#246**–**#250**, **#253**, plus the older set. None blocks S084 |

### What S083 changed that a later session will trip over

* **`tool/bidi_visual.py` exists, and its `--control` is the point.** It drives
  libfribidi and reproduces #133's recorded rendering. **Run `--control` before
  believing any output.** Not a CI gate — deliberately.
* **`sanitizePushName` runs for `ar` only**, and that is measured, not stylistic:
  in an LTR paragraph a trailing neutral does not detach, so trimming there takes
  a character off a person's name for nothing.
* **Do not hand-roll a Unicode range** (lesson **124**). A five-character regex
  in a *test file* silently declared 63,000 codepoints RTL. `\p{Script=…}`.
* **A capability sentence you WRITE needs the same measurement as one you fix**
  (lesson **122**). S082's draft said a notification can show a partner's name;
  S083's grep showed it cannot.
* **Before writing "latent", grep for the caller** (lesson **123**).
* **The emulator suite can fail on a loaded box.** S083 saw 3 failures that were
  all **timeouts** — including a `beforeAll` hook — and 1132/1132 on a re-run.
  Distinguish by SHAPE: a clock-shaped failure on a busy machine is not an
  assertion about behaviour. Do not re-run to green without saying you did.
* **`architecture.md` §7 first sentence is sentinel-parsed**; §8 is free-form.
* `app/lib/core/l10n/strong_bidi_ranges.dart` is **GENERATED — never edit it**
  (ADR-053). It is the app-side twin of the lesson above.
* **The export must never carry a raw FCM token** (ADR-054); delivery is
  `Clipboard.setData`.
* **`integration-emulator` never runs on a PR.** Prove a change to it with
  `gh workflow run ci.yml --ref <branch>` before merging.
* **Do not probe a Firestore trigger** with `assert_emulator_functions.sh` — a
  trigger answers `404`, exactly like an unknown name. Callables only.
* `FORMAT_VERSION` is **3**, pinned by **four** assertions (lesson **108**).

---

## 2. Then, in priority order

**1 — #243** (the distinct-id: a **privacy** decision that rides #226) · **#249**
(the consent record is named in no collection list — nearly free while the lawyer
has the document open).

**2 — #204** (`deliver` has failed to create the `tr` localization on **every**
release since build 112) · **#165** (`rules-drift` built but unarmed) · **#121**
(a watched release run) · **#248** (ten ADRs missing from the index) · **#246**
(device-local analytics markers survive account deletion) · **#253** · **#115** ·
**#41** · **#63/#71** (brandkit).

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first. Token capture needs none of it; only background *delivery* does.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **Landing the #226 revision** | founder/lawyer | The bump re-gates consent for **every** existing user. `docs/legal/proposed/README.md` has the exact diff |
| **#136 step 1** | the device | Whether the notification shade honours the isolates |
| **A build carrying ADR-046/049/051/052/053/057/059** | founder | `release.yml` uploads a real binary — **§7**. Last build **119** |
| **M3.4's last inch** | the founder's phone | One permission grant. **If the prompt was ever declined, iOS will not show it again** |
| **Deploying S071's rules and S077/S083's functions** | founder | §7 |
| **An analytics vendor sink** | founder + lawyer | #226 is the other half. No CI check stops an adapter landing without it — **#247** |
| **#250** | M6.5 | Android backup exclusion, Gate-3 gated (ADR-006) |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale |
| **operator 2(d) / 2(e)(ii) / 2(e)(iii) / 2(e)(iv) / 2(a) / 0(c)** | founder | Domains, legal name, three secrets, the budget alert |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15** | the device | On-device observation nobody has made |
| **#13** | M6.5 | Android, Gate-3 gated |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main`
run** (`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **THE REVIEW RUNS TWICE.** **S083 ran both and the second one was where the
> code was wrong** — four of its findings were defects in the implementation and
> the test, not the prose, including a test predicate that declared most of the
> BMP right-to-left. The design pass had already inverted the ADR's severity
> claim. Neither pass could have found the other's.

> ⚠️ **WRITE THE ADR FIRST** (`session-context.md` §5 item 1 — **not** §5.1;
> lesson **115**).

> ⚠️ **Report `agents_error` and `agents_empty_result` as numbers**, and say what
> was **dropped unverified** at the cap (§5 items 5 and 6). S083's design pass
> dropped five and listed them in the ADR; its built-diff pass dropped none.

> ⚠️ **FREEZE THE TREE BEFORE THE REVIEW** (lesson **113**); `git status` must be
> EMPTY after every review workflow returns (§5 item 8).

> ⚠️ **Run the guard you just wrote, and mutation-check it.** S083's first
> sanitiser kept `()`; its first parity regex matched a 63,000-codepoint range;
> S082's rewritten assertion failed on correct input because Dart `List` has
> identity equality. All three were found by running, not by reading.

> ⚠️ **If a claim in the issue is load-bearing, measure it yourself** (lesson
> **123**). #136 said *"latent"*; one grep said *unreachable*.

> ⚠️ **Check the issue rows against `gh`, not against the last session's memory.**
