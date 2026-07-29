# ADR-040: Ship a build that works without universal links, rather than block every release on a portal capability

- **Status:** Accepted
- **Date:** 2026-07-30 (Session 056)
- **Deciders:** founder (asked to get the app to the `Friends` group now, and chose *"ship now without universal links"* over waiting on the Apple Developer portal); session agent (the measurement that forced the choice, and the restoration path)
- **Related:** **ADR-036** (which added the entitlement and the https invite link), **ADR-039** (which made the link point at a host that answers, and shipped the site that now serves it), **ADR-032** (`match` is readonly, which is *why* this is a blocker and not a build flag), **ADR-037/038** (the TestFlight path this unblocks)

## Context

`Friends` — the external TestFlight group the founder wants five people in — is
currently attached to **build 110**. Build 110 was built from `fa990e6`, and that
is the whole problem:

```
$ git merge-base --is-ancestor 6d1f736 fa990e6 ; echo $?
1                     # 6d1f736 is the ikimiz rename + ADR-036; build 110 predates it
```

So the build those five people would install is the one **before** ADR-036 and
**before** ADR-039. It has the permanent loading screen the founder reported, and
it shares `hayati://invite/<code>` — a custom-scheme link that is not tappable in
WhatsApp at all. Both founder reports describe *that build*. A fixed build is not
a nice-to-have here; it is the entire deliverable.

The obstacle is one line in `Runner.entitlements`. ADR-036 added
`com.apple.developer.associated-domains`, and ADR-039 extended it to two hosts.
An entitlement must also be present in the **provisioning profile**, which means
the Associated Domains capability must be enabled on the App ID in the Apple
Developer portal — and `match` fetches profiles **readonly** by deliberate design
(ADR-032), so the release lane cannot add it.

**Measured, not assumed:** because build 110 predates ADR-036, *no build has ever
been signed with this entitlement.* The portal capability has never been
exercised. It is not "probably fine" — it is untested, and the failure mode is a
codesign-time entitlement mismatch that aborts the release.

That produces the actual decision: **wait for a portal visit before anyone gets a
working build, or ship a working build whose invite links resolve one step less
directly.**

## Decision — remove the entitlement, ship the build

The entitlement is removed. The key's former contents, the reason for its
absence, and the ordered restoration steps are written **into
`Runner.entitlements` itself**, because that file is where someone will be
standing when the question occurs to them.

**The invite loop still closes, end to end:**

1. the sender shares `https://ikimiz.web.app/i/<code>` — a real https URL, and
   tappable in every chat app, which the custom scheme never was;
2. tapping it opens the browser on the invite page, which is **live and verified**
   (`/i/<code>` → 200), and which shows the code with a copy button;
3. the invitee opens ikimiz and enters it via **"Have a code?"** →
   `PartnerPreviewScreen`'s manual entry, a path that already exists and is
   already tested.

The cost is stated plainly rather than minimised: **the invitee copies a code
instead of landing in the app.** One extra step, for the invitee only, on one
screen. Against that: five people get an app that starts, versus nobody getting
anything until a portal page is visited.

**This does not repeal ADR-036.** ADR-036's load-bearing claim was that an invite
link must be *clickable in a chat app and must land on something real* — the
custom scheme was neither, which is why it was replaced. An https link that opens
a working page is still both of those things. Universal links are the polish that
removes the last step, not the thing that makes the link work.

## What is deliberately kept

* **The app still parses all three hosts** (`kInviteLinkHosts`). Nothing about
  parsing needs the entitlement — the entitlement only decides whether *iOS hands
  the URL over*. Keeping it means every link sent during this window opens the app
  the moment a build carrying the entitlement is installed.
* **The AASA is still served, and is already correct** — verified live at
  `https://ikimiz.web.app/.well-known/apple-app-site-association`, valid JSON,
  `application/json`, `UH7MXG7Z94.com.beyondkaira.hayati`, `/i/*`. Apple fetches
  it at install time, so having it in place *before* the claiming build exists is
  the correct order, not a leftover.
* **`kInviteLinkUsesCustomDomain`** and the closed parsed-host set are untouched.
  The DNS cutover remains one boolean.
* **The `hayati://` scheme** in `Info.plist` is untouched, as it has been
  throughout.

Restoration is therefore additive and small: enable the capability, re-add the
key with both hosts, ship. Nothing has to be undone.

**The share copy was checked, not assumed, and it already matches.** The obvious
way this decision could have shipped a lie is a share message promising a tap that
no longer happens. All three locales already instruct the code path explicitly and
let the link trail as the fallback:

| | `inviteShareMessage` |
|---|---|
| en | "… My invite code: {code}. **Get ikimiz, then enter the code.** I'm waiting for you ❤️ {link}" |
| tr | "… Davet kodum: {code}. **İndir, kodu gir.** Seni bekliyorum ❤️ {link}" |
| ar | "… رمز الدعوة: {code}. **حمّل تطبيق ikimiz ثم أدخل الرمز**. بانتظارك ❤️ {link}" |

That is the code-first ordering the product-copy pairing rewrite chose for its own
reasons — a code survives being retyped, read aloud, or pasted into a chat app
that mangles URLs. It happens to be exactly the copy this decision needs, so no
string moved and no translation was touched.

## What was deliberately NOT done

* **The entitlement was not left in place on a hope.** Claiming the domain and
  letting the release lane discover whether the profile carries it would, on
  failure, convert "the founder has not visited a portal page" into "the release
  is broken and nobody knows why" — the precise class of mystery ADR-032's
  readonly rule exists to prevent, and the class ADR-039 was written about.
* **The https link emission was not reverted to the custom scheme.** The link is
  the half that works; only the OS hand-off is missing.
* **The AASA was not removed from the site build.** It costs nothing, breaks
  nothing while unclaimed, and removing it would guarantee a second deploy later.
* **Nothing was assumed about the portal.** A session cannot read the Apple
  Developer portal, so this ADR does not claim the capability is absent — it
  claims it is **unverified**, which is a sufficient reason not to bet a release
  on it. The one observation that settles it is an operator item.
