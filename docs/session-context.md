# Session Context

The standing operating context for a coding session on this repo: the toolchain,
the machine, the review discipline, and the invariants that are binding no matter
what the objective is.

Extracted from `resume-prompt.md` on **2026-08-05** so that the resume prompt can
carry one objective and nothing else. **This file is stable — it changes when the
environment or an ADR changes, not every session.** The per-session objective lives
in `resume-prompt.md`; the numbered lessons live in `session-lessons.md`.

_Environment facts below were last re-measured **2026-08-05**._

---

## 1. Sequencing and scope

* **ADR-006 — iOS-first.** Milestones validate and ship on iOS first. Android is
  re-sequenced into M6.5, whose *timing* is a founder decision informed by Gate 3 —
  it is not the automatic next slice.
* **ADR-007 — build de-gated from content ops.** M1→M6 proceed without content-ops
  preconditions. Gates 1–3 are decision instruments for marketing/spend/launch
  posture, not build blockers. TikTok/content-ops work is out of session scope
  unless the founder re-activates it.
* **"Personal-use-first" is history.** ADR-007's first release target was the founder
  couple's own devices. As of 2026-08-05 build 113 is approved, the `Friends` group
  holds eight entries, four have installed — including **two anonymous public-link
  installs**. The product has real users beyond the founder couple; scope decisions
  should assume an audience.

## 2. The machine

* **Another Claude session may be live on this box.** Before writing anything:
  `ps -eo pid,ppid,args` and read the tree; `readlink /proc/<pid>/cwd` to confirm which
  repo each is in. **Identify your OWN pid first** by walking `$$` up the ppid chain, or
  you will report yourself as the intruder. **Do not hand-roll that walk from
  `/proc/<pid>/stat` field 4** — `comm` contains spaces, and S056's version printed
  20,000 characters of garbage before it was killed.
* Other claudes on this box work **other repos** (measured 2026-08-05: `yanki-mvp`,
  `ai-videos`; historically also `evrak`, `ams-pulse`, `unhooked`, `bilet`). Confirm by
  cwd before treating one as a conflict.
* **A leftover background `bash` from your own pre-`/clear` session appears as a child of
  your own claude pid.** S051 found one sleeping 15 hours, S053 one spinning 25, S056 two
  `gh` poll loops running for ~2 days. Poll loops under *another* repo's claude are not
  yours — leave them.
* **A concurrent session on another machine can merge to `main` and consume your session
  number.** Re-derive the session number and the queue from `git log` + `gh issue list`,
  never from a document's prose.
* `gcloud` is **not installed** and there is **no ADC**. ~~Cloud Scheduler and Eventarc state
  cannot be verified from here.~~ **That was wrong, and it cost 37 hours (S068, #219.)**
  The firebase CLI's stored refresh token carries the **`cloud-platform`** scope, so
  `tool/ci/rules_drift.py`'s existing `token_from_firebase_cli()` mints a token that reads
  Cloud Scheduler, Cloud Logging, Cloud Billing, Cloud Functions v2 and the Firestore REST
  API — no `gcloud`, no ADC, no service account. **Import that helper; do not re-implement
  the OAuth dance.** The absence of `gcloud` is not the absence of the credential, and
  treating the two as the same thing is what left an unmonitorable backend.
* 🔴 **THE DEV BOX WAS REBUILT AROUND 2026-08-31, AND THE `firebase` CLI IS GONE** *(measured
  S095, 2026-09-02)*. `command -v firebase` → not found; `~/.config/configstore/` does not
  exist. **Everything in the table below now answers `2 — could not measure` for want of a
  credential, not because production is in that state.** ADR-063 built exit 2 as a distinct
  state for exactly this, so do not read it as a production reading — and do not read a
  *previous session's* exit 1 forward either.
  **Restoring it needs the founder**: `npm i -g firebase-tools` is a session's, but
  `firebase login` is an interactive OAuth on the founder's Google identity. Operator item 10.
* It **was** logged in as the founder (`aaytekinerdogan@gmail.com`) with access to
  `hayatiapp-prod` and `hayatiapp-dev`, and that is what the table below describes. It is a
  **local** path only, and it is currently unavailable.
* **What that login can actually do was unknown until S063, and one of them is the only
  instrument this repo has for a question it keeps getting wrong.** All five work today:

  | | |
  |---|---|
  | `firebase functions:log --project hayatiapp-prod --only <fn>` | **reads PRODUCTION logs.** This is what caught S063's silent failure: four hourly sweeps logged two of the three per-pass summaries, and the missing line was the whole diagnosis. Free, read-only, instant. ⚠️ **A line per hour is not health** — S067 read 38 consecutive `E` lines as "the job fired". |
  | `python3 tool/ci/prod_pulse.py --from-firebase-cli` | **"is the daily loop actually RUNNING?"** — the question `functions:list` and `functions_drift` cannot answer. Keyed on the sweep's own `sweep complete` record, so a punctual scheduler over a dead backend reads red. Exit 0/1/2. ⚠️ **Rebuilt at S087 (ADR-063) after it answered `2 — could not measure` through a six-day outage**: it now probes each fact separately (a failure is a *named gap*, never a discarded run), reads the billing **account's `open`** rather than the project's `billingEnabled` — which said `true` for the whole outage — and quotes the refusal from the function's own error stream. **A gap can never produce a green**: findings → 1, else any gap → **2**, else 0. |
  | `firebase functions:list --project hayatiapp-prod` | the deployed function inventory. Set-compare it against the exports in `functions/src/index.ts`. |
  | `python3 tool/ci/rules_drift.py --project hayatiapp-prod --from-firebase-cli` | verifies deployed rules against this ref **with no `FIREBASE_SERVICE_ACCOUNT`** — the CI lane needs that secret, this path does not. |
  | `firebase deploy --only functions` / `--only firestore:rules` | the deploy. **§7 applies — ask first.** |

  **There IS a Functions deploy workflow since S070** — `deploy-functions.yml` (#206,
  ADR-048), dispatch-only, prod pinned to `main` and behind a typed project id, which
  measures → deploys → reads back. Until 2026-08-17 there was none, and deployment was a
  manual step nothing tracked: that cost S063 the entire push feature — everything merged,
  every check green, and the callables the app calls did not exist in production.
  **"Merged and green" is not "running"** (lesson **86**) — and the first row of that table
  is how you tell the difference in about ten seconds. Use it before reporting any feature
  that spans a deploy boundary as shipped.

  **The lane is UNARMED** until operator **2(e)(iii)** (`FIREBASE_SERVICE_ACCOUNT`), exactly
  like `deploy-rules.yml`, so the row above is still how a session deploys today — and §7
  still applies to prod. The lane's own command sequence is reproducible locally:
  ```sh
  # every exported function
  python3 tool/ci/functions_drift.py --project <p> --require-clean-tree
  firebase deploy --only functions --project <p> --non-interactive
  python3 tool/ci/functions_drift.py --project <p>

  # or a subset — note the `functions:` prefix goes on EVERY name, and a
  # selector without it is silently dropped (an all-dropped list means NO
  # filter, i.e. deploy everything)
  python3 tool/ci/functions_drift.py --project <p> --require-clean-tree --only a,b
  firebase deploy --only functions:a,functions:b --project <p> --non-interactive
  python3 tool/ci/functions_drift.py --project <p> --only a,b
  ```
  **Never pass `--force`**: it deletes functions absent from the source with no prompt.

## 3. Toolchain and commands

> 🔴 **WHAT IS ACTUALLY INSTALLED ON THIS BOX, measured S095 (2026-09-02).** The machine was
> rebuilt around 2026-08-31 and most of this section describes a toolchain that is no longer
> here. **Re-measure before trusting any command below** — `for c in node npm python3 java
> dart flutter ruby gh git; do command -v $c; done` takes two seconds and this section cost a
> session an hour.
>
> | present | absent |
> |---|---|
> | `node` 22, `npm` 10, `python3` 3.12, `gh`, `git`, `codegraph` | **`flutter`**, **`java`**, **`ruby`/`bundle`**, **`firebase`** |
>
> **`dart` was restored by S095** as a standalone SDK at
> `~/.local/share/dart-sdk/bin` (3.12.2, matching `app/pubspec.yaml`'s `^3.12.2`). It is NOT
> on PATH — export it. It runs the five `dart:io` lints (`adr_index_lint`,
> `release_lane_lint`, `store_metadata_lint`, `deploy_lane_lint`, `rtl_lint`) and their
> self-tests, and `dart format`. It does **not** give you `flutter analyze`, the app suite,
> goldens or the emulator suites — those need Flutter and Java. **Say which half you proved
> and which half CI proved** (lesson **78**); do not let a green CI stand in for a claim you
> could have measured locally, or vice versa.
>
> Restoring Flutter/Java/Ruby is a session's to do (downloads, no credential). Restoring the
> **firebase login** is not — operator item 10.

**Flutter / Dart**
* ⚠️ **Not installed** (above). Historically: Flutter at `~/flutter/bin`; `dart` is
  `~/flutter/bin/dart`, not on PATH.
* **Run `flutter gen-l10n` in `app/`** before trusting any test or analyze run that touches
  localized text.
* **Run `dart format` before every commit.** CI runs
  `dart format --set-exit-if-changed app/lib app/test tool content` **from the repo root**.
* `.g.dart` is committed — `dart run build_runner build --delete-conflicting-outputs` in
  `app/` after adding providers.

**Functions / emulator**
* Needs Java 21+ on PATH (`~/.local/share/java/jdk-21.0.11+10-jre/bin`) and global
  `firebase-tools@15.22.4`.
* **Build `functions/` first** (`npm run build`) — the functions emulator never compiles TS.
* Full suite, **from the repo root**:
  ```sh
  firebase emulators:exec --only auth,firestore,functions --project demo-hayati \
    'cd functions && npm run test:ci'
  ```
  Echo the exit code — and remember `$?` after a pipe reads the *pipe's* status
  (`session-lessons.md`, standing).
* **The emulator suite binds fixed ports and is NOT safe to run concurrently**, including
  with your own review agents. Check `ss -ltn` for 8080/9099/5001.

**Gates**
* Coverage: **app 68**, **functions 80 hard / 85 target**.
* Content: packs authored under `content/packs/` **only** —
  `dart content/validator/validate.dart --sync`.
* Goldens are Linux-canonical; re-measure the count with
  `git ls-files 'app/test/**/*.png' | wc -l`.

**Gotchas**
* Global `FilledButton` has infinite min-width — override `minimumSize` inside Rows.
* `hayatiTheme` is **memoized** (ADR-039 D7): same `ThemeData` instance per language code.

**Sub-agents and workflow agents must be forbidden from:** running the emulator suite;
running `flutter`/`dart` at all; and any package-manager command that **writes**
(`npm install|ci|audit fix|update|dedupe`).

## 4. CodeGraph *(founder directive, 2026-07-09)*

Orient with CodeGraph at session start and use it for symbol / call-path / impact
navigation throughout: the `codegraph_explore` MCP tool, CLI fallback
`codegraph explore|node|callers`. Sub-agents reach the same tools via ToolSearch.
Run `codegraph sync` after the merge at session close, so the next session's
orientation is against merged `main`. The index is machine-local (`.codegraph/`,
gitignored).

`.claude/skills/` is gitignored the same way — a fresh machine runs `uipro init -a claude`
once if it wants the corpus, and **only the `ui-ux-pro-max` skill may be invoked in this
repo** (ADR-025 D9).

## 5. Review discipline

Twenty-eight consecutive pre-code review passes have found real defects. The procedure:

1. **Write the ADR (or slice design) and commit it BEFORE writing code.** That is where
   the defects are.
2. Review it with **4–5 lenses × 2 independent verifiers** — a refuting skeptic and a
   governing-docs adjudicator. Aggregate so a finding surfaces when **either** says real.
3. **Run the review twice: once on the design, once on the built diff.**
4. **Rebase onto latest `main` before sending a diff to review**, and re-check at merge
   time *(founder directive, S042)*.
5. **Check `agents_error` / `agents_empty_result` before trusting a verdict distribution.**
   An empty verdict is *unverified*, and the tooling renders it as the opposite.
6. **Cap your verify fan-out with a `log()` of what you dropped.**
7. **Say which instrument you actually ran.** Verification-of-inherited-work is not
   review-of-your-own-design. An inline pass by the session itself is a legitimate
   substitute only when the findings are mechanical rather than judgemental. **Never claim
   a panel you did not run.**
8. **After every review workflow returns, `git status` must be EMPTY before you commit** —
   review workflows can mutate the tree.

**Checkpoint-commit implementation output immediately.** S056 opened on 38 files and ~1,400
insertions of finished, tested work sitting uncommitted — one `git checkout .` from total loss.

## 6. Binding invariants

Do not change these without reading the ADR that set them.

| Source | Invariant |
|---|---|
| **ADR-018 rev 4** (M6.1) | The four device-lock invariants. |
| **ADR-019** (M6.2) | The seven cascade invariants; the deletion notice sends **no push**; export `formatVersion` 2. |
| **ADR-023** | Consent/legal is binding. `users.consent` is server-owned; the three-way legal-version source-sentinel means a legal-text revision bumps **all three** in one diff; `docs/legal/` is byte-synced to `app/assets/legal/` under a drift test; withdrawal is **prospective** by DV doctrine. |
| **ADR-024** | `tool/ci/slack_notify.sh` is the single notifier, with **no vote** on the build and **all policy in the script** (D1). |
| **ADR-025** | The slice-0 firewall stays live; D8's golden declaration is discipline, **not** a CI gate. |
| **ADR-026** | The `seasonalWindow` vocabulary is CLOSED and gated in five readers. **All five are now parity-tested** (#171 closed #130) and D3's wording was corrected there — do not re-open it. |
| **ADR-032** | Release signing is fastlane `match` + MANUAL. The build **name** comes from pubspec; the build **number** is CI-synthesized (`100 + GITHUB_RUN_NUMBER`). `fastlane/metadata/*/name.txt` is pinned to **`ikimiz`** — lowercase, the value `release_lane_lint.dart`'s `pinnedStoreName` actually holds and the value the live listing holds (re-measured S095, ADR-070 D6; this row said **İkimiz** until then, and ADR-035 is what moved it). Enforced per-PR by `tool/release_lane_lint.dart`. ⚠️ **The lint stops a drifted `name.txt`, not a session that also moves the pin** — which is what "reconciling to the invariant" would do, and `deliver(force: true)` then renames the live listing. Change this row only with the founder. |
| **ADR-033** | Bidi isolation is applied at the **string boundary** and **at render only**. Nothing persisted, exported or shared may carry `U+2068`/`U+2069`. |
| **ADR-053** | `app/lib/core/l10n/strong_bidi_ranges.dart` is **GENERATED — never edit it**. Re-derive with `python3 tool/gen_bidi_rtl_ranges.py`; CI runs `--check`. The two tables must stay **disjoint**, and the seam iterates **runes**, never code units. `intl` must not return to this seam. |
| **ADR-054** | The data-rights export carries a **`device` lane** — `pushDiagnostic` verbatim, `fcmTokens` as a **COUNT**. ⚠️ **A raw registration token must never enter the export**, at any nesting level: delivery is `Clipboard.setData`, so it would land on the system pasteboard. A shape change bumps `FORMAT_VERSION`. |
| **ADR-055** | `integration-emulator` wraps each suite in `tool/ci/integration_watchdog.sh` so a wedge **FAILS** (named) instead of being **CANCELLED** (silent) — `slack_notify.sh` sends nothing for `cancelled`, correctly, and GitHub uses that word for a timeout too. **The guard is SILENCE** (`WATCHDOG_SILENCE_SECONDS`), not elapsed time: runner speed alone moves a suite 1.82×, while wedged-vs-healthy differ 7.6× on silence. The wall-clock bounds are deliberately loose **backstops** and their sum MAY exceed the ceiling. ⚠️ `integration_watchdog_test.sh` asserts the *silence* bound stays comfortably inside `timeout-minutes` — do **not** raise the ceiling, and do not re-tune the wall clock instead (lesson **116**). |
| **ADR-034** | Advisories are gated on what a change **introduces**. No baseline file, no cron. Fail-closed (exit 2). |
| **ADR-039** | The boot is **fail-open** and always ends in a frame; every blocking wait on the launch→paired path is **bounded**; `kInviteLinkHosts` is CLOSED. |
| **ADR-040** | The `associated-domains` entitlement is deliberately **absent**; the AASA is already served and correct; the app still parses all three hosts. **Read this ADR before touching `Runner.entitlements` for any reason — including push.** |
| **ADR-041** | Merged-vs-deployed firestore rules: no committed marker file; exit codes are a **taxonomy** (0 / 1 drift / **2 could not measure**); byte-exact, no normalization; a second `cloud.firestore/{db}` release fails **closed**; runs post-merge on `main` only; prod rules deploys are dispatch-only and require typing the project id; the watcher's credential is read-only by construction. **D6.1 is a recorded exception** to architecture §9's *"never a `::warning::` on a green build"* — do not tidy it back to a `::notice::` without re-reading that decision. |

## 7. Things a session must never do without asking

* Deploy anything to `hayatiapp-prod` — **Functions or rules** — without asking the founder
  first. *(ADR-041 D5's typed-confirmation guard is a guard, not permission.)*
* Dispatch the release lane (it uploads a real binary to the founder's TestFlight).
* Grant public invoker on prod, or migrate RevenueCat subscriber ids.
* Re-bootstrap `match` certificates. **`MATCH_BOOTSTRAP=true` is a ONE-RUN variable** —
  it makes `match` non-readonly so it can regenerate a profile. Delete it the moment the
  run lands, or CI keeps the ability to mint credentials that ADR-032's readonly exists to
  remove. S063 set it, used it, and deleted it in the same sitting; verify with
  `gh variable list` rather than assuming.
* **Enable or disable a capability on the App ID.** `tool/ci/appid_capability_enable.py`
  exists since S063 and works, behind a `--confirm ENABLE` literal — but it changes how a
  real binary signs and it **invalidates the existing provisioning profile**. Its read-only
  sibling's header explains why it was deliberately not built for a year; the founder
  authorised the write on 2026-08-06 for one capability, which is not standing consent for
  the next one. Undo is `--disable-id <id>`.
* `npm audit fix --force`, or downgrade `firebase-admin` (ADR-034 refuses it).
* Enable Dependabot on the founder's behalf.
* Guess the founder's legal name into a legal document.
* Add a real person as a TestFlight tester without the founder's list.

**Dev is a session's to exercise.** One authorization is not standing consent for prod.

## 8. Standing measurement commands

The point of this list is the command, not the cached answer. Re-measure.

```sh
# TestFlight build + tester state (read-only)
gh workflow run testflight-testers.yml -f status_only=true -f group=Friends
gh api repos/:owner/:repo/actions/jobs/<id>/logs      # NOT `gh run view --job --log`

# Deployed-vs-merged firestore rules — exit 0 in sync, 1 drift, 2 could not measure
python3 tool/ci/rules_drift.py --from-firebase-cli \
  --project hayatiapp-prod --project hayatiapp-dev

# Secrets, the RevenueCat webhook, the site
gh secret list
curl -i -X POST https://revenuecatwebhook-mzym2uw5gq-ew.a.run.app \
  -H 'Content-Type: application/json' -d '{}'         # JSON = fixed, HTML 403 = broken
curl -so /dev/null -w '%{http_code}\n' https://ikimiz.web.app/i/9U4VUVRV

# Prod runtime
firebase functions:list --project hayatiapp-prod

# Is the daily loop actually RUNNING? (not "is it deployed" — keyed on the
# sweep's own `sweep complete` record, so a punctual scheduler over a dead
# backend reads RED.) Exit 0/1/2. This is the instrument #219 was missing —
# and ADR-063 is why it can now answer during the outage rather than after it.
# A `COULD NOT MEASURE <fact>` line is a NAMED GAP, not a failed run; exit 2
# means "nothing found AND something was unread", never "one probe threw".
python3 tool/ci/prod_pulse.py --from-firebase-cli

# Has any device EVER registered a push token — and, since ADR-049, what does
# each phone say about itself? `--uid <uid>` narrows the report to one account
# (read directly, so pagination cannot manufacture an absence).
python3 tool/ci/push_delivery_probe.py --from-firebase-cli

# Did the store listing actually PUBLISH? Positive evidence — the expected
# locales come from fastlane/metadata and the TEXT is compared, so a locale
# Apple silently dropped is a finding rather than a green (ADR-047, #204).
# It rides testflight-testers.yml; there is no store-metadata workflow of its
# own. Exit 0 published / 1 finding / 2 could not measure.
gh workflow run testflight-testers.yml -f store_metadata_audit=true
```

A transient `HTTP 503 … Policy checks are unavailable` from the rules API is **exit 2,
"could not measure"** — not drift. Re-run before believing it, and do not read that exit
code through a pipe.
