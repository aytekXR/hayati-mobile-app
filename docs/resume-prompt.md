# Resume Prompt

> This file contains ONE and only ONE objective. Every session executes ONLY this file. (See `project-rules.md` #1, `session-rules.md`.)
>
> **Standing de-gating note (ADR-007):** engineering milestones M1→M6 proceed without content-ops preconditions. Gates 1–3 are decision instruments for marketing/spend/launch posture, not build blockers. TikTok/content-ops work is out of session scope unless the founder re-activates it. First release target: the founder couple's own devices (personal-use-first).
>
> **Standing sequencing note (ADR-006):** iOS-first — milestones validate and ship on iOS first; Android work is re-sequenced into M6.5 (whose *timing* is a founder decision informed by Gate 3 — it is not the automatic next slice).
>
> **Standing tooling note (CodeGraph, founder directive 2026-07-09):** orient with CodeGraph at session start and use it for symbol/call-path/impact navigation throughout — `codegraph_explore` MCP tool (CLI fallback `codegraph explore|node|callers`); sub-agents and workflow agents use the same tools via ToolSearch. Before the session ends, `codegraph sync` after the merge (session-rules §1 step 4 / §3 step 6). The index is machine-local (`.codegraph/`, gitignored). **S026 addendum: `.claude/skills/` is gitignored the same way** — a fresh machine runs `uipro init -a claude` once if it wants the corpus, and **only the `ui-ux-pro-max` skill may be invoked in this repo** (ADR-025 D9).
>
> **Standing session-hygiene note (Sessions 013 + 014 incidents):** before writing ANYTHING, check for another live Claude session on this repo — `tmux ls` + `ps aux | grep claude` + `readlink /proc/<pid>/cwd` and recent non-self mtimes in the tree. **Identify your OWN claude PID first** (walk `$$` up the ppid chain) or you will report yourself as the intruder. **S029/S030/S047/S050/S051 addendum: the other claudes on this box work OTHER repos (`evrak`, `repo`(parent), `ams-pulse`, `unhooked`)** — confirm by walking cwd before treating one as a conflict, **and a leftover background `bash` from your OWN pre-`/clear` session will show up as a child of your own claude PID** (S051 saw one that had been sleeping in a monitor loop for 15 hours). **S038 addendum: a CONCURRENT session on ANOTHER machine/tree can merge to `main` mid-session** — `ps`/`tmux` only cover THIS box, so after every merge read `git log --oneline -5` and `git show --stat` the commits you did not write. **Session numbers are per-tree and collide.** **Checkpoint-commit implementation output IMMEDIATELY**; commit design docs BEFORE launching workflows. **S037 addendum: REVIEW workflows can mutate the tree** — after every review workflow returns, `git status` + `git diff` must be EMPTY before you commit anything (S047, S050 and S051 all checked; all clean).
>
> **Standing review-ordering note (Sessions 015–051, now TWENTY-SEVEN consecutive pre-code passes):** write the ADR (or the slice design), commit it, then adversarially design-review it BEFORE writing code — that is where the defects are. Use 4–5 lenses × 2 independent verifiers (a refuting skeptic + a governing-docs adjudicator), **and run the review TWICE: once on the design, once on the built diff.** Aggregate so a finding surfaces when EITHER verifier says real. **Check `agents_error`/`agents_done` before trusting a verdict distribution — an empty verdict is *unverified*, and the tooling renders it as the opposite** (S041). **Rebase onto latest `main` before sending a diff to the review workflows** and re-check at merge time (founder directive, S042).
>
> **S051 addendum — (52) THE VERIFIER PANEL IS AN INPUT TO JUDGEMENT, NOT A SUBSTITUTE FOR MEASURING — AND IT WAS WRONG IN BOTH DIRECTIONS TWICE IN ONE SESSION.** S051's pre-code review let through two findings that measurement then refuted, and **killed two that measurement confirmed**: a `letterSpacing` regression (isolating an 8-char code widened it 144.0 → 152.0 px, because Flutter spaces after zero-width controls too) and a whole class of `findsNothing` assertions that would have gone vacuous. The build-diff review then killed a **silent** failure mode that was also real (#137). Three of the session's most useful findings came from overriding the panel with a measurement. **When a verdict and a number disagree, the number wins — so go get the number.**
>
> **S051 addendum — (53) A PROBE WHOSE CONTROL PASSES IS A BROKEN PROBE, NOT A CLEAN RESULT.** S051 tested "does Arabic chrome show the defect?" by isolating the Latin *letters* inside each string — leaving the terminator outside the isolate. Every string came back "identical", **including the known-broken control**, which is the only reason the probe was caught. **Put a known-defective case in every probe and assert it FAILS.** A sweep that reports all-clear without a failing control has reported nothing.
>
> **S051 addendum — (54) YOUR OWN ADR IS A CLAIM SURFACE, AND YOU WILL FALSIFY IT WITH YOUR OWN CODE.** S051's ADR was corrected **four times by its own implementation** — a chrome premise that was false, a "no golden covers this" that the goldens disproved, a "provable no-op" that 37 goldens disproved, and a site list containing a site that must not be touched. Then the build-diff review found four *more* stale claims, all of the shape: *I corrected the claim in D1 and D9 and left its paraphrase standing two paragraphs away.* **Addendum 19 applies to the document you are writing right now, not only to the ones you inherited.** After every change to code an ADR describes, re-read the WHOLE ADR — signatures, file paths, counts, and the sentences that merely *imply* the old behaviour.
>
> **S051 addendum — (55) A FALSIFIED GOLDEN DECLARATION IS A FINDING; SORT THE CAUSES BEFORE ACCEPTING ANY OF THEM.** 37 goldens moved against a declared zero. Two different causes hid in that number — **legitimate repairs** and **pure shaping churn** — and telling them apart needed the PNGs decoded (0.8% of pixels, mean delta 27/255, no reflow = churn; glyphs repositioning = repair). ADR-025 D8 says churn is not to be accepted, so it was **fixed rather than declared**, which also collapsed the test migration from a forecast ~17–39 assertions to four. **"Explain every deviation" means find out WHY, not write a sentence next to it.**
>
> **Earlier addenda that keep paying (condensed):** guarantee-vs-mechanism gaps are the highest-value class — and **a doc under-reporting what code does is hygiene, not a gap**; **N EXPERT SWEEPS CAN ALL MISS THE SAME THING — budget a completeness critic into every fan-out and give it the MODALITIES list, not the findings** (S050's #131, found by no lane); **a remainder deferred into prose is a remainder that gets lost** (S050 → #133; S051 → operator item 0(c)); **when a diff corrects a claim, grep for the NEGATION and the PARAPHRASE, not just the noun** (broken four times now); **a premise that was replaced rather than measured is likely wrong again** (S049); **a new rule can make old rows vacuous — re-run every row** (S048); **a test whose fixture is derived from its subject proves nothing** (S047/S050); **MUTATION-CHECK every guard AND the test, in both directions** (S042); **verify with the command CI runs, not the convenient one** (S044); **`$?` after a pipe reads the PIPE's status** (S047, hit again in S051's first secret probe); **query the PLATFORM, not the docs** (S045); **read the ARTEFACT, not just the source** (S047 — S051 confirmed its fix by reading the re-baselined golden, and diagnosed two defects by decoding PNGs); **run the session, do not assert its conclusion** (S045); **"no unblocked engineering" is a claim to RE-DERIVE every session, never to inherit**; a stale operator item is worse than no item.
>
> **Standing toolchain note:** the functions/rules emulator suites need Java 21+ on PATH (`~/.local/share/java/jdk-21.0.11+10-jre/bin`) and global `firebase-tools@15.22.4`. Build `functions/` first (`npm run build`); the functions emulator never compiles TS. Full suite **FROM THE REPO ROOT** (echo the exit code — and beware that `; echo $?` after a pipe reads the *pipe's* status): `firebase emulators:exec --only auth,firestore,functions --project demo-hayati 'cd functions && npm run test:ci'`. **The emulator suite binds fixed ports and is NOT safe to run concurrently — including with your own review agents** (check `ss -ltn` for 8080/9099/5001; forbid emulator runs in workflow-agent prompts, as S050 and S051 did). **S051 addendum: also forbid workflow agents from running `flutter`/`dart` at all** — concurrent runs collide on `.dart_tool`, and one stray `--update-goldens` would rewrite the baseline mid-review. **Run `flutter gen-l10n` in `app/` before trusting any test or analyze run that touches localized text** (`app/lib/core/l10n/gen/` is gitignored and goes stale). Flutter at `~/flutter/bin` (`dart` is `~/flutter/bin/dart`, not on PATH). **Run `dart format` before every commit** — CI runs `dart format --set-exit-if-changed app/lib app/test tool content` **from the repo root**, which is not where you will be after a `flutter test`. Coverage gates: **app 68** (measured **87.30%** at the S051 close), **functions 80 hard / 85 target**. Content: packs authored under `content/packs/` ONLY — `dart content/validator/validate.dart --sync`. App-side: `.g.dart` committed — `dart run build_runner build --delete-conflicting-outputs` in `app/` after adding providers; ARB edits regenerate on `flutter pub get`. Theme gotcha: global `FilledButton` has infinite min-width — override `minimumSize` inside Rows. Goldens are Linux-canonical: **360 tracked PNGs across 24 directories** at the S051 close (`git ls-files 'app/test/**/*.png' | wc -l` — re-measure rather than quoting this).
>
> **Standing binding-invariants note:** **M6.1 (ADR-018 rev 4)** the four lock invariants; **M6.2 (ADR-019)** the seven cascade invariants, deletion notice sends NO push, export `formatVersion` 2; **ADR-023** consent/legal is BINDING — `users.consent` server-owned, the three-way legal-version source-sentinel means a legal-text revision bumps ALL THREE in one diff, `docs/legal/` byte-synced to `app/assets/legal/` under a drift test, withdrawal is PROSPECTIVE by DV doctrine; **ADR-024** `tool/ci/slack_notify.sh` is the single notifier with NO vote on the build and ALL policy in the script; **ADR-025** the slice-0 firewall stays live (lock-screen forbidden-API sentinel, brandkit→Dart token parity, the 96-pair frozen-sentence digest) and **D8's golden declaration is discipline, not a CI gate — nothing turns red if you ignore it**; **ADR-026** the `seasonalWindow` vocabulary is CLOSED and gated in FIVE readers — adding a season is a five-file change, **but only FOUR of the five are parity-guarded: that is #130, the objective below**; **ADR-032** release signing is fastlane `match` + MANUAL, the build NAME comes from pubspec while the build NUMBER is CI-synthesized, `store_metadata` uses the narrow ASC-only credential check, and `fastlane/metadata/*/name.txt` is PINNED to **İkimiz** — all four enforced per-PR by `tool/release_lane_lint.dart` (**74** mutation checks); **ADR-033 (new, S051)** bidi isolation is applied at the **string boundary** and **at render only** — nothing persisted, exported or shared may ever carry `U+2068`/`U+2069`, chrome is deliberately NOT isolated, and `ContentText` is the seam a new content-rendering screen must use.

## Objective — Session 052: **#131 — seven high-severity npm advisories in `functions/`, two of them in the tree that ships to production. Fix them, then decide honestly whether CI should ever look.**

> **Re-ranked, deliberately, against S050's ordering.** S050 put **#130** here and #131 second, on the ground that #130 is the queue's only guarantee-vs-mechanism gap. That reasoning still holds — but #130 is **latent by its own issue text** (no shipped pack sets `seasonalWindow` yet), while #131 is **live in code that runs in production today**. Latent-but-elegant loses to live-and-shipping. #130 keeps its full brief below and is the next objective after this one.

**Re-measured at the S051 close, not inherited** (addendum 48 — a premise that was replaced rather than measured is likely wrong again):

```
$ cd functions && npm audit
14 vulnerabilities (7 moderate, 7 high)
```

All seven highs report `fixAvailable: true`:

| Package | Reached via | In the production tree? |
|---|---|---|
| `fast-xml-parser` | direct advisory | **YES** — inside `firebase-admin@14.2.0` |
| `google-gax` | `rimraf` | **YES** — inside `firebase-admin@14.2.0` |
| `brace-expansion`, `minimatch`, `glob`, `rimraf`, `postcss` | transitive | toolchain |

### Acceptance criteria

1. **`npm audit fix` claims all seven are non-breaking. VERIFY rather than trust** — run it, then `npm run build` and the **full emulator suite from the repo root**, and read what actually moved in `package-lock.json`. A lockfile diff you have not read is not a reviewed change.
2. **Do NOT run `npm audit fix --force`.** npm's advice for the seven *moderate* findings is to downgrade `firebase-admin` to **10.3.0**, which would undo ADR-031 and conflict with ADR-030. If the moderates cannot be fixed without that, **leave them and say so in the ADR** — an honestly-recorded open advisory beats a silent dependency regression.
3. **Then decide whether CI should carry an audit gate at all, and argue it against ADR-024's lesson** (*an honest gap beats a guard that mostly restates something else*). A `main`-reddening gate fails the build for a transitive advisory nobody can fix that hour; a **dispatch-only or scheduled report in `gemfile-lock.yml`'s shape** may fit better. Either answer is acceptable **if the reasoning is written down**; what is not acceptable is adding a gate because gates feel responsible.
4. If the decision is a gate or a report, it needs a **mutation check**: prove it goes red on a seeded advisory, not merely that it runs.
5. ADR + `docs/architecture.md` §9 updated in the same diff if the dependency posture changes (rule 8). **Write the ADR LAST in a multi-commit branch** (rule 45).
6. Close **#131** with the PR.

**Design-review before the fix.** The question worth adversarial attention: **is a CI audit gate a guarantee or a nuisance?** ADR-024 chose a notifier with *no vote on the build*, deliberately. The same argument may apply here — and if it does, say so rather than reaching for the stricter-looking option.

### Then, in priority order

**#130 — make ADR-026's "five readers" claim true by construction, not by discipline.** Properly TDD-shaped: the failing test *is* the fix.

ADR-026 D3 guarantees the seasonal vocabulary is **"enforced in five places."** All five readers do reject an unknown value. What is missing is the **parity net**:

| Reader | Rejects unknown? | Parity-tested against the schema? |
|---|---|---|
| `content/schema/question-pack.schema.json` (source of truth) | — | — |
| `content/validator/validator_core.dart` | yes | **yes** — `validateSchemaAgreement` |
| `functions/src/rollover/seasonal-window.ts` | yes | **yes** — `functions/test/unit/schema-agreement.test.ts` (#88) |
| `functions/src/rollover/pack-loader.ts` | yes | via the same TS agreement test |
| `app/lib/features/daily_question/domain/question.dart:32` | yes | **NO** |

Nothing in `app/test/` reads `content/schema/question-pack.schema.json`. **And the test that looks like the fifth guard is self-referential:** `app/test/features/daily_question/data/question_pack_dto_test.dart:62` is `for (final window in knownSeasonalWindows)` — it iterates **the very list under test**, so it can only prove the DTO accepts what the app already knows.

**The failure it permits:** add a season to the schema, validator and TS parser; forget the Dart file. **CI is fully green** and the app throws `FormatException` at pack-load **on a real device**.

Acceptance: (1) a failing test first — `seasonal_window_parity_test.dart` reads the schema, extracts the enum, asserts **set-equality** with `knownSeasonalWindows`; pattern to follow is `brandkit_token_parity_test.dart`, which already reads a JSON source-of-truth from a Dart test. (2) **Widen it while you are there** — `category` and `register` have the identical comment-instead-of-guard shape; one parity test covering **every enum in the schema** closes all three, and any enum deliberately not mirrored gets its reason **in the test**. (3) **MUTATION-CHECK both directions** and re-run the neighbouring DTO tests — the self-referential loop at line 62 is a prime candidate for deletion once real parity exists. (4) Correct ADR-026 D3's wording in the same commit, strikethrough-plus-dated-note style. (5) Close #130.

**Design-review the plan before writing the test.** The question worth adversarial attention: **is set-equality right, or should the app's list be permitted to be a strict subset?** A reader that knows fewer seasons fails *closed*; one that knows more fails *open*. Those are not symmetric — encode the answer deliberately.

### And after those

- **#129** — delete `release.yml`'s false `Gemfile.lock` comment (uncontroversial), and decide on `--frozen`. Read the issue's honest scoping first: **no doc ever claimed the release lane installs frozen**, so this is the S044 lesson applied to the producer, not a broken written guarantee. The `--frozen` half should land on a run someone is watching (addendum 44), which pairs it with **#121**.
- **#136** — the Functions-side twin of #133: Arabic push bodies interpolate a partner name with no isolation. **Latent, not live** — no current wording is affected. Its blocker is honest: *nobody has established whether iOS/Android notification chrome honours `U+2068`/`U+2069` at all*, and ADR-033's evidence is Flutter-engine-side and does not transfer. Ride it along with the on-device checks rather than shipping control characters into a push payload on faith.
- **#137** — `intl`'s first-strong ranges miss Arabic Extended-A **and misclassify it as LTR**, so the bidi seam silently no-ops for it in LTR chrome. Not reachable in Turkish or Gulf Arabic. Filed because it fails **quietly**; carries a `// DEBT:` comment. Fixing it means diverging from `intl`, which needs its own guard — read the issue's three options before choosing.

**FIRST — the preemptions. Query the platform, not the docs; re-derive from issues AND PRs.**

1. **#115** — `curl -i -X POST https://revenuecatwebhook-mzym2uw5gq-ew.a.run.app -H 'Content-Type: application/json' -d '{}'`. **JSON = fixed. HTML = still broken** (HTML at the S051 close, unchanged for four sessions). If fixed: ask for a RevenueCat event replay, and **#41 becomes urgent** — real entitlement state starts accumulating, and its remedy is a migration rather than a clean change once purchases exist.
2. **Prod runtime** — `firebase functions:list --project hayatiapp-prod`. Still 11 × `nodejs20` at S051, with a live **2026-10-30** decommission date. If it moved: re-verify Scheduler `ENABLED @ 0 * * * *`, Eventarc `RETRY_POLICY_RETRY`, and **whether the redeploy restored the webhook's public invoker**. HTML *after* a fresh deploy means something is actively removing that binding — worse than #115 itself.
3. **`RC_WEBHOOK_TOKEN` on dev** — still absent at S051 (Secret Manager 404, with prod as the exit-0 control), so dev runs **ten** of eleven functions. Now tracked as **operator item 0(c)**, which is also the cheapest way to de-risk #115.
4. **Open issues and PRs** — re-derive both from scratch. Do not inherit any list, including this one.
5. **Gate 3 / Android green-light** → M6.5.

### The blocked table as it stood at the S051 close — re-check every line; do not copy it forward

| Issue | Blocked on | Why a session cannot take it alone |
|---|---|---|
| **#115** | founder | Making a production endpoint world-reachable is a security-posture change on a live system, and a session cannot read the webhook token to confirm it matches RevenueCat |
| **#41** | founder | Live billing identity. Whether sandbox purchases already exist decides *clean change* vs *migration* |
| **#48** | the device | Its own text defers to on-device observation of a transient Face ID lockout |
| **#15** | the device | Needs a native crash log from a real iPhone (Xcode → Devices → Console) |
| **#136** | the device | Needs one observation nobody has made: does the iOS/Android notification shade honour bidi isolates? |
| **#13** | M6.5 | Android, Gate-3 gated (ADR-006) |
| **#63**, **#71** | founder | Brandkit revisions — Phosphor-vs-Material, and a motion token |
| **#121** | **a go-ahead, not a decision** | Confirming the orphaned `.p8` step means dispatching the release lane, which **builds and uploads a real binary to the founder's TestFlight**. Ask first. **Pair it with #129** — the same dispatch is also the first exercise of the committed `Gemfile.lock` |

**Do NOT** grant public invoker on prod, migrate RC subscriber ids, redeploy prod, re-bootstrap `match` certificates, run `npm audit fix --force`, or dispatch the release lane without asking. Each is a live-system, irreversible, or outward-facing action the founder owns.

**What is DONE (do not re-do):** the whole MVP **M1–M6.3 including M5.3**, consent/legal at **legal version 2**, CI→Slack, the UI/UX arc + the redesign waves, **#74**, **#29**, **#88**, **#47**, the bundle-id rename, the first dev deploy, release-lane signing, the `match` lane (#103, #117), **Node 22 on dev**, **#76**, **firebase-admin v14**, **#70**, **ADR-032** + `tool/release_lane_lint.dart` + **#99**/**#67** (S047), **#120** (S048), **#100** (S049), the S050 queue re-derivation which filed **#129**/**#130**/**#131**, and **#133** — the bidi-isolation seam (**ADR-033**, S051): `ContentText` + `isolateWithin`, 11 call sites, 34 goldens re-baselined, the mirror case covered by a test no golden asserts.

**Open and UNBLOCKED at the S051 close — this is the queue:** **#131** (the objective above), **#130**, **#129**, **#137**. All four are Linux-only and need nothing from the founder. Re-derive them anyway — do not inherit this line.

On completion, follow `session-rules.md` §3/§4: append to `past-prompts.md`, regenerate this file, refresh `docs/operator-expected.md`, commit, push, verify CI, watch the post-merge main run, then `codegraph sync`.
