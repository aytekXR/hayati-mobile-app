# Proposed legal revision — version 3 (DRAFT, NOT IN FORCE)

**Nothing in this directory is live.** The documents in force are the ones one
level up in `docs/legal/`, byte-synced into `app/assets/legal/`, at **version 2**.
These three files are a **draft of version 3**, waiting on the founder and the
founder's lawyer. See **ADR-058** for why the draft was written this way and why
it deliberately stops short of landing.

Issue: **#226**. Operator items **16** and **18**.

## What this revision changes, in one paragraph each

**Push.** Version 2 says *"ikimiz does not send push notifications today."* That
is true of what anyone has received and false of what the app does. Build 119 —
the only build on any phone — already asks the user's phone for a notification
address and sends it to the server to be stored; the hourly sweep on our side
already composes and sends. Version 3 names the two things we store (the device's
notification address, one per device; and the device's own report of whether
notifications are on, refused, or could not be set up), names the two recipients
that carry a notification (Google's Firebase Cloud Messaging and Apple's push
service, neither pinned to Europe), states the four notification kinds and their
hours, states that a notification never carries question or answer text, states
that the ordinary form can show a partner's **name** and that the discreet
setting removes it, states the quiet window, and states plainly that **no
notification has ever actually been delivered**.

**Analytics.** Version 2 says *"There is no analytics or tracking product in the
app today; if we ever add one, it will arrive with its own separate opt-in."* The
first half survives literally — there is no SDK, no provider, no account — but
since ADR-057 the app records eight plain milestone counts and, on production,
throws them away. Version 3 says what is recorded, that none of it leaves the
phone, that the once-only markers stay on the device and go when the app is
removed, and **keeps version 2's promise verbatim in substance**: an analytics
provider arrives with its own separate opt-in, off until you turn it on, named
before anything is sent, never folded into the one consent the app already asks.

**The terms are NOT changed by this revision.** `terms.{tr,ar,en}.md` say nothing
about notifications or analytics (measured), so they are not reissued. Only the
three privacy policies are here — deliberately.

## What is still open, and what only the founder or the lawyer can close

- **The three bracketed blanks are still blank** and are carried through
  unchanged: the controller's legal entity, the contact address, and — in the
  terms, which this revision does not touch — the governing law. **No session may
  guess the founder's legal name into a legal document** (`session-context.md` §7).
- **A fourth blank is new: the effective date.** It reads
  `[EFFECTIVE DATE — set on the day this revision ships]` (and its TR/AR
  equivalents). It cannot be known before the founder says go. Its bracketed
  em-dash shape is deliberate: `tool/ci/build_site.py`'s placeholder gate matches
  it, so a version 3 that lands **undated cannot be published to `/privacy`** —
  the build fails closed.
- **Lawyer questions A, B, C, D and E** are in `../README.md`. **D** (does naming
  the analytics provider at its opt-in discharge the aydınlatma obligation, or
  does the adapter bump the version again) and **E** (is Apple a processor or an
  independent controller on the APNs leg) are new with this revision and neither
  is answerable here.
- **Native review is still PENDING** for all three locales, exactly as for
  version 2. These drafts are AI-written. The Turkish register and the Gulf
  Arabic register both need a human reader before this ships.

### One thing to decide WHILE the lawyer is already reading

The built-diff review found a **third** omission in the same *"What we collect"*
list, and it is neither push nor analytics: the consent record itself.
`users/{uid}.consent` stores `{version, acceptedAt, ageAttested}` — when you
consented, to which version, and that you attested you are of age — and **no
locale's collection list names any of it** (issue **#249**).

It was deliberately **not** folded into this draft: widening a revision the
founder is about to review is scope creep, and the session's objective was push
and analytics (`session-rules.md` §2). But you are about to pay for a legal
review and a re-consent prompt **once**. Adding one true bullet — *"a record of
when you consented to this notice and which version you consented to"* — is
close to free while the lawyer has the document open, and expensive as its own
round later. **Ask them; it is a one-line decision, and it is yours, not the
session's.**

### A second thing to decide while they are reading — and it is smaller

Session 085 (#246, ADR-061) changed a fact this draft describes. The analytics
paragraph says the once-only markers *"go when you remove the app"*. As of that
change, **deleting your account also removes the ones tied to it** — every
uid-keyed marker on the phone that runs the deletion. `analytics.install` and the
pre-sign-in `ritualPreviewSeen` marker carry no account and stay, correctly.

**The sentence is still true**, which is why it was not edited: removing the app
does still clear them, and the notice now promises *less* than the app does. That
is the safe direction, and the opposite of the mismatch this whole revision
exists to correct — so re-opening a draft the founder is about to review would
have been scope creep, not diligence (`session-rules.md` §2).

But *"they go when you remove the app"* sits in the paragraph a user reads to
learn what happens to their data, and it invites the inference that deleting the
account does **not**. That inference is now wrong. One added clause closes it, in
three locales. **Same shape as #249 above: nearly free while the lawyer has the
document open, its own round later.** Filed as issue **#258**.

### A promise this draft makes that the Android build must keep

The analytics paragraph says the on-device markers *"go when you remove the
app"*. That is true on iOS, the only platform shipping today (ADR-006). It is
**false on Android by default** — Auto-Backup is on unless you turn it off, and
`AndroidManifest.xml` currently sets neither `android:allowBackup="false"` nor
extraction rules, so the markers would be backed up to Google and restored on
reinstall. The draft is worded to stay true either way (it says plainly that the
markers ride your device's backups), but the **M6.5 Android slice must configure
backup exclusion** or the honest wording becomes the only thing holding the line.
Filed as issue **#250**.

## The landing diff — every step, in order

Do all of it in **one commit**. A partial bump fails CI in both directions by
design (the three-way sentinel), and that is the point of it.

0. **Delete this directory and its guard together.** `git rm -r docs/legal/proposed/`
   **and** `git rm app/test/features/legal/legal_proposal_test.dart`. That test's
   first assertion is that this directory exists, so the two are coupled on
   purpose — the bump cannot leave a stale guard behind.
1. **Move the three drafts into force.** Copy each
   `docs/legal/proposed/privacy-policy.<loc>.md` over
   `docs/legal/privacy-policy.<loc>.md`, and copy the same bytes into
   `app/assets/legal/privacy-policy.<loc>.md`. **Three documents, six files.** The
   three terms documents are not touched.
2. **Fill the effective date** in all three, in each locale's own wording. The
   date is the day the revision ships.
3. **Raise all three version sources to 3, in this same commit:**
   - the `version:` line in `docs/legal/README.md`,
   - `currentLegalVersion` in `app/lib/features/legal/domain/legal_version.dart`,
   - `CURRENT_LEGAL_VERSION` in `functions/src/data-rights/data-rights-core.ts`.
4. **Update `shippedPolicyVersionLine`** in
   `app/test/features/legal/presentation/legal_document_screen_test.dart` to the
   new English line (`Version 3. Effective <date>.`). ⚠️ **The three-way sentinel
   does NOT cover this**, and the v1→v2 bump was caught by exactly this omission
   once already — `docs/legal/README.md` step 3 names it for that reason.
5. **Regenerate the goldens, declaring the expected set first** (ADR-025's goldens
   rule): the version string and the processors notice render, so
   `legal_screen`, `legal_document_screen` and `consent_gate_screen` move.
   Anything outside that declared set is a defect, not churn. Goldens are
   **Linux-canonical** and cannot be produced correctly on a macOS box.
6. **Add the two processor rows to `docs/dpa-inventory.md` if they are not already
   there** — Google Firebase Cloud Messaging and Apple APNs. *(As of S082 they
   are: the register was updated in the same diff that wrote this draft, because
   the register describes what the system does, not what the notice says about
   it.)*
7. **Deploy ordering.** The Functions constant must deploy **before, or together
   with**, the app binary that raises the gate's expectation, so the gate never
   expects a version the server has not yet stamped.
8. **Say in the PR body what changed and why re-consent is needed.** Every
   existing user will be re-prompted; the reason belongs in the trail.

## If a DIFFERENT revision becomes version 3 first

Then this draft is superseded, not landed. Delete `docs/legal/proposed/` and
`app/test/features/legal/legal_proposal_test.dart` **in that same diff**, and say
in the commit message that the proposal was superseded and by what. Leaving them
behind turns CI red on the guard that asserts this draft is exactly one version
ahead of what shipped — correctly, but a session then has to reconstruct why from
a failing test.

## Review status of these three drafts

| Document | Native / register reviewer | Legal reviewer | Status |
|---|---|---|---|
| `privacy-policy.tr.md` | Founders (TR-respectful register) | Founder's lawyer | **PENDING** |
| `privacy-policy.ar.md` | Gulf reviewer (MSA, family-safe) | Founder's lawyer | **PENDING** |
| `privacy-policy.en.md` | Founder (plain EN) | Founder's lawyer | **PENDING** |

The engineering claims inside them — what is stored, which recipients, which
hours, what a payload can contain — were each read out of the code in Session 082
and are recorded with their sources in ADR-058. The **legal** judgement on top of
those facts is not, and this table is not a proxy for it.
