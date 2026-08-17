# Resume Prompt — Session 077

> **This file contains ONE objective. That objective is the session; nothing else is.**
> (`project-rules.md` #1, `session-rules.md` §1.)
>
> Read `session-context.md` (toolchain, machine, review discipline, the
> never-without-asking list) and `session-lessons.md` (numbered to **112**) first.
> Re-derive the session number from `git log`.

**Objective: #227 — the data-rights export omits every trace of the user's
devices, and that omission was inherited rather than decided.**

`projectProfile` in `functions/src/data-rights/data-rights-core.ts` builds the
export's profile lane as a **whitelist**: `status`, `contentLanguage`,
`register`, `createdAtMs`, the Auth record fields, plus `notificationPrivacy` and
`consent` when present. Everything else on `users/{uid}` is silently absent.

That excludes **`fcmTokens`** (one FCM registration token per physical device,
ADR-042 — a pseudonymous device identifier tied to an identified person) and
**`pushDiagnostic`** (the device's self-reported permission state and the
server-stamped time it reported, ADR-049).

ADR-049 kept `pushDiagnostic` out **for consistency with `fcmTokens`** and pinned
that with a test, so it is a recorded decision rather than drift — but the
consistency argument never asked whether `fcmTokens`' own exclusion was right.
**That is this session's question, and it is a genuine one with a cost on both
sides:**

* Under KVKK Art. 11 / PDPL / GDPR Arts. 15 & 20 a subject's export should carry
  the personal data held about them, and device identifiers linked to an
  identified person qualify — here the document key *is* the uid.
* But a raw `fcmTokens` value **addresses a phone**. Putting it in a file the
  user may store, email to themselves, or forward puts a live credential into
  general circulation. That is the argument for a **redacted device lane**
  (device count, last-registered timestamp, the diagnostic state) rather than the
  raw tokens — an answer that serves Art. 15's *"what do you hold about me"*
  without shipping the thing itself.

**Decide it in an ADR before writing code (§5.1 — and read S076's ADR to see what
inverting that order actually costs).** The three defensible answers are: include
raw, include redacted, or exclude with a written justification. Whichever wins,
the test ADR-049 left behind must be *changed deliberately*, not deleted.

⚠️ **Check whether the export's own documentation and the privacy policy agree
with whatever you choose.** #226 is the sibling defect and is founder-blocked;
do not let this session quietly create a fourth statement of what we hold.

## 1. Where things actually stand *(measured 2026-08-17 — re-measure, do not inherit)*

| | State |
|---|---|
| **Notifications, server side** | **RUNNING** as of S070: `prod_pulse.py --from-firebase-cli` exit 0, scheduler ENABLED, sweep summary `assigned=0 buckets=1 existing=1 failed=0`. **Not re-measured since** — run it before relying on it. |
| **Notifications, device side** | **STILL ZERO** as of S071: `push_delivery_probe.py` exit 1, 0 of 4 accounts have ever registered. Unchanged since S063. |
| **The build gap that gates it** | Last `release.yml` run is **2026-08-09, build 119**. Everything client-side merged since — ADR-046's Settings row, ADR-049's `pushDiagnostic`, ADR-051's reveal announcement, ADR-052's card surfaces, **and now ADR-053's bidi tables** — is on **nobody's phone**. |
| **Deployed rules vs `main`** | `rules_drift.py --from-firebase-cli` exited **1 for both projects** at the S071 close; S071 changed `firestore.rules`. Deploying is a **§7 founder ask**. ⚠️ Not "the field does not work until it deploys" — the old ruleset has no `pushDiagnostic` clause, so writes LAND either way; what is missing is the *validation*. Re-measure rather than inherit. |
| **`hayatiapp-prod` Functions** | CLEAN at S070 (`functions_drift.py` exit 0, 13 deployed, 0 foreign). **S077's objective changes `functions/` source**, so a deploy becomes relevant — and remains a §7 ask. |
| **`hayatiapp-dev` Functions** | 12 of 13; `revenueCatWebhook` cannot deploy there until **0(c)** puts `RC_WEBHOOK_TOKEN` on dev. |
| **`functions-drift` / `rules-drift` in CI** | Both **visibly SKIPPED** by design — one absent secret (operator **2(e)(iv)**). |
| **#137** | **CLOSED (ADR-053).** |
| **#175, #174, #221, #222, #223, #206** | **CLOSED** (S075, S074, S071, S073, S072, ADR-048). |

### What S076 changed that a later session will trip over

* `app/lib/core/l10n/strong_bidi_ranges.dart` is **GENERATED — never edit it.**
  Re-derive with `python3 tool/gen_bidi_rtl_ranges.py`; CI runs `--check` plus
  `tool/gen_bidi_rtl_ranges_test.py`.
* **If `--check` fails after a runner-image bump, read the message.** The table
  is derived from the interpreter's own UCD, so a newer Python emits a newer
  Unicode. The tool prints a *different sentence* for that than for a hand-edit,
  because a version move is news and the fix is to regenerate and read the diff
  as a changelog.
* `intl` is gone from the bidi seam and must not return. It remains a `pubspec`
  dependency only because Flutter's generated localizations import it.
* The generator's output must stay **`dart format`-clean**. It emits the
  formatter's own choices deliberately; if that ever drifts, `dart format
  --set-exit-if-changed` and `--check` deadlock against each other and no edit
  satisfies both.

---

## 2. Then, in priority order

**1 — #226**, the sibling of this session's objective and the more serious half:
the privacy policy states *"ikimiz does not send push notifications today"*,
which is true of the outcome and **false of the system** (the server has composed
and attempted a push on schedule since 2026-08-11), and its "what we collect"
list names neither `fcmTokens` nor `pushDiagnostic`. **Founder/lawyer-blocked**,
because any revision bumps `CURRENT_LEGAL_VERSION` in three places and re-gates
consent for every existing user. A session can draft the wording; it cannot land it.

**2 — #208** — `integration-emulator` hung **silently** for 38 minutes and burned
the whole 50-minute budget. Second blow-out; raising the ceiling again is not a
fix, it is the third one queued.

**3 — #204** (`deliver` has failed to create the `tr` localization on **every**
release since build 1) · **#165** (`rules-drift` built but unarmed) · **#136**
(the Functions-side bidi twin — see below) · **#129/#121** (release lane) ·
**#115** · **#41** · **#63/#71** (brandkit).

⚠️ **Do not add `UIBackgroundModes: remote-notification`** without deciding SEC-3
first. Token capture needs none of it; only background *delivery* does.
`signing_sentinel_test` reddens if it is added.

### A note on #136, now that #137 is closed

#136 is *not* unblocked by ADR-053. The app-side table is Dart; #136 is
TypeScript in `functions/src/notifications/payload-policy.ts`, and its real
blocker is a **device question the repo cannot answer from here** — whether iOS
and Android notification chrome honour `U+2068`/`U+2069` at all. The issue is
explicit: *do not assume it works — measure on a device*, and do not ship
invisible control characters into a push payload on faith. Its fallback (reorder
the Arabic copy so the placeholder never sits beside a neutral) **is** available
to a session and needs no device.

---

## 3. Blocked — re-check every line

| What | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **A build carrying ADR-046/049/051/052/053** | founder | `release.yml` uploads a real binary to TestFlight — **§7**. Last build **119, 2026-08-09**. Five merged slices are on no device |
| **M3.4's last inch** | the founder's phone | One permission grant, on a build that has the fix. **If the prompt was ever declined, iOS will not show it again** — 119's only remedy is iOS Settings → Notifications → ikimiz |
| **Deploying S071's rules** | founder | §7. Additive, so nothing is broken until it lands — but `rules-drift` reports prod behind `main` |
| **`tr` App Store localization** | founder | Apple refuses the **name**, not the locale. A different Turkish display name fixes **eight** audit findings |
| **operator 2(d)** — Associated Domains | founder | Measured absent. Same portal page as the push tick |
| **operator 2(e)(iii)** | founder | `FIREBASE_SERVICE_ACCOUNT`. Arms **three** lanes |
| **operator 2(e)(iv) / #165** | founder | One read-only SA, two roles. Until then `rules-drift` **and** `functions-drift` are SKIPPED by design |
| **operator 2(a)** | founder | The budget alert — the control that would have caught #219's cause rather than its symptom |
| **operator 0(c)** | founder | `RC_WEBHOOK_TOKEN` on dev |
| **operator 2(e)(ii)** | founder | The controller's legal name. Blocks `/privacy`, `/terms`, the listing |
| **#226** | founder/lawyer | Changing the legal texts re-gates consent for every existing user |
| **#115** | founder | Making a prod endpoint world-reachable is a security decision on a live system |
| **#41** | founder | Live billing identity — *clean change* vs *migration* |
| **#48**, **#15** | the device | On-device observation nobody has made |
| **#136** | the device | Whether notification chrome honours the isolates. **Its fallback path needs no device** |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions |

---

## 4. Close sequence — `session-rules.md` §3/§4

Append to `past-prompts.md` → regenerate this file (one objective) → refresh
`operator-expected.md` → commit + push → verify CI → **watch the post-merge `main` run**
(`integration-emulator` is main-only) → `codegraph sync`.

> ⚠️ **Write the ADR FIRST, and mean it** (§5.1, lesson **111**). S076 inverted
> the order and it cost three specific claims: a figure — *"62,408"* — that
> corresponded to **nothing measurable** and had reached three files, a *"strict
> superset of `intl`'s RTL class"* assertion that was **false by 322 code points**
> and had reached a test where it would have forced a correct table to stay
> wrong, and a stale filename in the generator's own docstring. All three sat
> beside code that compiled and tests that passed. An ADR written first has to
> state its numbers while there is nothing green lending them authority.

> ⚠️ **A scan whose glob matches nothing reports the same clean zero as a scan
> that passed** (lesson **110**). S076's golden declaration rested on a corpus
> scan that first reported *"200 strings, 0 changes"* — its ARB glob pointed at a
> directory that does not exist, so it had classified **no localized string at
> all**. Assert a floor on the input before believing the output, in throwaway
> probes as much as in committed tests.

> ⚠️ **State a mutant by its measured post-condition, not its intent** (lesson
> **112**). S076's third mutant was described as reproducing `intl`'s exact gap.
> It removed nine of ten ranges and left **22 of 150** code points covered,
> because one generated range spans `intl`'s class boundary. Both tests went red
> anyway, so nothing pushed back on a sentence that was simply false.

> ⚠️ **A mutation run that applies nothing prints the same green as a guard that
> works** (lesson **109**). Assert the anchor and the landed edit **before**
> running the test, and use **absolute paths** — S076 hit this again, restoring a
> mutated file from a `cd`-shifted relative path and leaving the tree dirty.

> ⚠️ **An empty lens is UNVERIFIED, never a clean bill** (§5.5). Read the raw
> findings list (lesson **107**), and when a lens is quiet on a subject you have
> not checked yourself, check it.
