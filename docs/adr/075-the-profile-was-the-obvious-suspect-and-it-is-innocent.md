# ADR-075: The provisioning profile was the obvious suspect, and measuring it proved it innocent

- **Status:** Accepted — **the tool ships and the hypothesis it was built to test
  is REFUTED.** That is the outcome, not a disappointment: the alternative to
  building it was asking the founder to run a signing-affecting operation on a
  guess.
- **Date:** 2026-09-06 (Session 101)
- **Deciders:** session agent. **Read-only throughout.** Nothing was written to
  Apple, no profile was regenerated, and no release was dispatched.
- **Related:** **ADR-074** (the session's first half — the refusal callback),
  **ADR-032** (`match` readonly, and the single bootstrap run), **ADR-041** (the
  0/1/2 taxonomy this reuses), **ADR-040** (the release an unread entitlement
  cost), lessons **65**, **78**, **135**

## Context — the suspect, and why it was a good one

ADR-074 left one question: permission is held, APNs never answers, and the OS's
reason was going to an `NSLog`. Before shipping an instrument to catch that
reason, the obvious cause deserved a look, and it looked very strong.

**An entitlement has to survive three places and this repo could read two:**

```
Runner.entitlements  ->  the App ID capability  ->  the PROVISIONING PROFILE
(in git, readable)       (appid_capabilities)      (nothing could read it)
```

**iOS checks the third.** A binary signed with `aps-environment` whose embedded
profile does not grant it installs, launches, and is refused by APNs at runtime
with *"no valid 'aps-environment' entitlement string found for application"* —
which is precisely the observed symptom.

And the third link is the one that can go stale silently:

* `match` fetches profiles **readonly** (ADR-032), so CI can never mint one;
* ticking a capability **invalidates** the App ID's existing profiles — the
  `appid-capabilities.yml` job says so in its own warning;
* the documented recovery is a one-run `MATCH_BOOTSTRAP=true` release, and per
  ADR-032 that has run **exactly once, at bootstrap**, long before
  `PUSH_NOTIFICATIONS` was ticked on **2026-08-06**;
* release runs **#15** (2026-08-06 23:41) and **#16** (2026-08-07 01:23) both
  went **green** — the lane never broke, which is consistent with a profile that
  was never regenerated and never carried the capability.

Every observable fact pointed one way. **The next step would have been to ask the
founder to run `MATCH_BOOTSTRAP`** — a one-shot variable that must be deleted
after use, that changes how a real binary signs, and that `session-context.md` §7
lists as never-without-asking. Asking for that on an inference is how a session
spends someone else's risk.

## Decision 1 — Read the profile Apple is actually serving

The App Store Connect API exposes no `entitlements` field, which is why this had
been treated as unreadable. It exposes something better: `/v1/profiles` returns
**`profileContent`**, base64 of the `.mobileprovision` — a CMS-signed blob with a
plain XML plist inside it, and the plist carries the `Entitlements` dictionary.

So `tool/ci/profile_entitlements.py` reads the bytes and reports what they say.
No signature verification is attempted and none is needed: Apple served them over
TLS, and the question is what they **say**, not whether they are authentic.

⚠️ **`rfind` on the terminator, not `find`.** A `</plist>` appearing inside an
entitlement value would truncate the document into something `plistlib` parses
**partially** — a smaller dictionary, accepted without error. That is a wrong
answer rather than a crash, and it is the only failure mode in this parser worth
engineering against. Pinned by a test with a hostile fixture.

**Matched on the `bundleId` relationship, never on the profile's name.**
`match AppStore com.beyondkaira.hayati` is a convention someone can rename; a
name match would let this tool quietly report on the wrong app.

## Decision 2 — Five ways to not-measure, and only one of them is a finding

The taxonomy carries more weight here than in the capability probe, because a
profile can be **absent**, of the **wrong type**, another **app's**, **INVALID**,
or **undecodable** — and reporting any of those as *"the entitlement is
missing"* would send the founder to regenerate a signing artifact on no evidence.

| state | verdict |
|---|---|
| an ACTIVE matching profile grants it | **0** |
| an ACTIVE matching profile does not | **1** — the finding |
| no profile / wrong type / another app / undecodable | **2** — nobody looked |
| an **INVALID** profile grants it | **1** — what a profile the lane cannot use grants is history |

That last row is the one that would have hidden the defect if it existed: Apple
keeps superseded profiles listed, and counting one as evidence would report a
healthy entitlement for a build that cannot use it.

## Decision 3 — Keys are printed; values are not

A `.mobileprovision` also carries `DeveloperCertificates` (full DER certificates)
and the team's provisioned device list, and this runs in a **public** Actions log.

The read-out prints the entitlement **keys**, and values **only** for keys the
caller explicitly named on `--require` — keys that are already in this
repository's own `Runner.entitlements`. Pinned twice: once at the formatting, and
once structurally, because `ProfileFacts.granted` cannot hold a value nobody
asked for.

## Decision 4 — The measurement, and the hypothesis it kills

Run **34040358971**, dispatched read-only:

```
com.beyondkaira.hayati: IOS_APP_STORE provisioning profiles
  match AppStore com.beyondkaira.hayati  [ACTIVE]  uuid=7ae73b07-…-89281fa5b1e4
    created 2026-08-07T00:16:11Z   expires 2027-07-26T04:18:09Z
    entitlement keys (7): application-identifier, aps-environment,
      beta-reports-active, com.apple.developer.applesignin,
      com.apple.developer.team-identifier, get-task-allow, keychain-access-groups
    ✅ aps-environment = 'production'
```

**The profile grants it, it is ACTIVE, and it was created 2026-08-07T00:16 —
after the capability was ticked, and an hour before release #16 used it.** So the
profile *was* regenerated; the reasoning that said it could not have been was
sound and wrong.

**All three links are now proven intact**, each by its own instrument:

| link | proven by |
|---|---|
| the binary claims it | `Runner.entitlements`, in git |
| the App ID permits it | `appid_capabilities.py`, run 34038316432 |
| **the profile grants it** | **this tool, run 34040358971** |

⚠️ **This is lesson 135 paying for itself.** Four converging facts, a plausible
mechanism, and a documented recovery all pointed at a conclusion that a
five-minute read disproved. The cost of *not* measuring would have been a founder
running `MATCH_BOOTSTRAP`, a regenerated profile, a release cut to carry it, and
the same silence at the end of it.

## Consequences

**Positive**

- The most likely remaining cause of the dead notification chain is eliminated
  **by measurement**, and the elimination is reproducible by one dispatch.
- A permanent instrument for a class of question this repo has repeatedly called
  unanswerable. ADR-040 lost a release to an entitlement nobody could read; that
  is now a five-minute read.
- The suspicion recorded in `Runner.entitlements`' own comment — *"a build
  claiming this key before the App ID carried the capability would fail at
  CODESIGN"* — gains its missing third fact.

**Negative / accepted trade-offs**

- **It answers what the profile GRANTS, not what the shipped IPA EMBEDS.** They
  are the same only if `match` served this profile to the build that produced
  120 — which the release log's UUID `7ae73b07-…` confirms for that build and
  cannot promise for the next one. The tool reads the portal, not the artifact.
- **The refutation narrows the field without naming a cause.** After this, the
  entitlement chain is exonerated and the remaining candidates are the device's
  own APNs conversation — which is exactly what ADR-074's callback was built to
  capture, and it needs a build to reach a phone.
- One more tool and one more workflow input to maintain, for a question asked
  rarely. Accepted: the alternative was answering it by guess, and the guess was
  wrong.
