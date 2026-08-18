# ADR-054: the export names your devices without handing over their keys

- **Status:** Accepted
- **Date:** 2026-08-17 (Session 077)
- **Deciders:** session agent (no operator dependency; no schema migration, no client release required for correctness)
- **Related:** **ADR-049 D7** (which deferred exactly this question and pinned the omission with a test), **ADR-042** (`fcmTokens` is server-owned and frozen to the client), **ADR-023** (the consent lane, and the `FORMAT_VERSION` precedent), issue **#227**, issue **#226** (the sibling, founder-blocked)

> Written and committed **before** the implementation, per `session-context.md` §5.1.
> S076 inverted that order and it cost three claims that had already been typed
> next to working code (lesson **111**). The numbers below were measured first
> and there is nothing green yet to lend them authority.

## Context

`projectProfile` (`functions/src/data-rights/data-rights-core.ts:349`) builds the
export's profile lane as a **whitelist**: `status`, `contentLanguage`, `register`,
`createdAtMs`, the three Auth fields, plus `notificationPrivacy` and `consent`
when present. Everything else on `users/{uid}` is silently absent — including:

* **`fcmTokens`** — `string[]`, one FCM registration token per physical device
  (ADR-042). A pseudonymous device identifier tied to an identified person; the
  document key *is* the uid.
* **`pushDiagnostic`** — `{state, detail?, at}`, the device's own report of why it
  has no token, server-stamped (ADR-049).

ADR-049 D7 kept `pushDiagnostic` out **for consistency with `fcmTokens`**, and
pinned that with a test so it would be a decision rather than a drift. It said so
plainly: *"for consistency rather than for a reason anyone has argued on the
merits."* This ADR argues the merits.

### The asymmetry that settles the question

**Deletion erases the whole `users/{uid}` document.** `deletion-service.ts` step 5
sweeps `users/{A}/soloAnswers/*` and then `users/{A}` itself, so `fcmTokens` and
`pushDiagnostic` are unambiguously destroyed on an Art. 17 request.

So the system today **deletes data it will not show you.** Whatever the right
answer is about *format*, "we hold nothing about your devices" is not available
as an answer — the deletion lane already concedes we hold it. An export that
omits a category the deletion lane erases is not a defensible reading of KVKK
Art. 11 / PDPL / GDPR Art. 15.

### The measurement that decides the FORMAT

The export is not a file. **`export_screen.dart:59` puts it on the system
clipboard:**

```dart
Clipboard.setData(ClipboardData(text: export.toPrettyJson()));
```

That is the whole delivery mechanism. #227 framed the risk as *"a file the user
may store or forward"*; the reality is sharper. An FCM registration token is a
**live credential that addresses a phone**, and the raw form would be placed on
the general pasteboard — readable by other apps, and on Apple silently relayed to
the user's other devices by Universal Clipboard. The user does not have to
forward it for it to leave the device.

**This is why the answer is not "include everything".** It was found by reading
the delivery path rather than reasoning about exports in general, and it inverts
the naive reading of Art. 20 portability: handing over the token serves no
purpose the data subject can act on, and creates a risk to them specifically.

## Decision 1 — A `device` lane, included; the token itself, redacted

The export gains an optional `device` lane carrying:

| field | source | why |
|---|---|---|
| `registeredDeviceCount` | `fcmTokens.length` | answers *"what do you hold about my devices"* with a true, checkable fact |
| `pushDiagnostic.state` | verbatim | the device's own report — meaningful to the subject |
| `pushDiagnostic.detail` | verbatim, when present | ditto; enumerated, never free text |
| `pushDiagnostic.atMs` | `at.toMillis()` | when we recorded it, consistent with every other timestamp in the envelope |

The **raw token strings are never exported.** `fcmTokens` is `string[]` with no
per-token metadata, so a count is the only non-credential fact it can yield —
there is no "last registered at" to offer, and inventing one would mean writing a
new field to carry it.

**`pushDiagnostic` is exported in full and that is deliberate**, not an oversight
of symmetry. It carries no credential: its `state` and `detail` are closed
enumerations pinned by `firestore.rules` (ADR-049), and its whole content is a
statement *about* the data subject that we recorded without them seeing it. That
is the paradigm case for Art. 15.

So the two fields are treated **differently, on the merits** — which is precisely
what ADR-049 D7 declined to do and asked a later session to do.

## Decision 2 — `FORMAT_VERSION` 2 → 3

`data-rights-core.ts:14` documents the rule: *"A shape change bumps this. v2:
added the optional profile consent lane (ADR-023)."* This is the same shape of
change as v2 — a new optional lane — so it takes the same treatment. The comment
gains a v3 line so the constant keeps explaining itself.

## Decision 3 — ADR-049's test is CHANGED, never deleted

`data-rights-core.test.ts` asserts today that neither field is exported, and its
comment says it exists so the omission *"goes red the moment a future change
starts exporting either field, which is the moment the question in issue #227 has
to be answered rather than inherited."*

**That test is doing its job right now** — this session is the red it was written
to cause. It is therefore rewritten to assert the *new* decision in the same
both-directions shape, and the rewrite must keep the half that still holds:

- `registeredDeviceCount` appears and is correct;
- the diagnostic appears with state, detail and a millisecond timestamp;
- **no raw token string appears anywhere in the serialized envelope** — asserted
  against `JSON.stringify` of the *whole* export, not just the profile object, so
  a future lane that happens to carry tokens somewhere else also reddens.

Deleting the test and writing a fresh one would lose the anti-leak half, which is
the only assertion here guarding a credential.

## Decision 4 — This does NOT wait on #226, and does not pre-empt it

#226 (the privacy policy neither mentions push notifications truthfully nor names
these two fields) is **founder/lawyer-blocked**, because any revision bumps
`CURRENT_LEGAL_VERSION` and re-gates consent for every existing user.

Landing this first is the right order and the asymmetry is one-directional:

* Exporting data the policy does not enumerate **cures** an Art. 15 gap. It
  creates no new disclosure defect — the collection defect is #226's, and it
  exists whether or not the export shows it.
* The reverse — updating the policy to name `fcmTokens` while the export still
  refuses to show it — would leave the subject reading that we hold something we
  will not give them.

⚠️ **What this session must not do:** invent a fourth statement of what we hold.
The wording used in the export lane is deliberately mechanical (`device`,
`registeredDeviceCount`) rather than prose, so it neither contradicts nor
pre-empts whatever the founder and a lawyer settle on for #226.

## Consequences

**What this buys.** The export stops being narrower than the deletion lane. A
subject can see how many devices are registered and what their own device
reported about notification permission — the second of which is the more useful
fact, since it is the thing they never saw us record.

**What it costs.** A `FORMAT_VERSION` bump, which any consumer of the export
format must tolerate; the format is consumed by nothing but a human reading
pasted JSON today.

**What is deliberately NOT provided.** The raw registration tokens. If a
regulator or the founder later decides Art. 20 requires the identifiers
themselves, the change is small and localized — but it should be made knowing
that the delivery path is the system clipboard, and it should probably change the
delivery path first.

**What no test here can prove.** That a count is the *legally* correct
redaction. That is a judgement, argued above from the credential nature of the
token and the clipboard delivery, and it is recorded here so a lawyer reviewing
#226 can overturn it with one sentence rather than having to reconstruct why the
export looks the way it does.
