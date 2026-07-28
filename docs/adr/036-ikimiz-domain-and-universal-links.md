# ADR-036: `ikimiz.beyondkaira.com` — one source for the legal text, and invite links that survive WhatsApp

- **Status:** Accepted
- **Date:** 2026-07-28 (Session 054)
- **Deciders:** founder (the domain, and Firebase Hosting over a VPS); session agent (generate-vs-commit, the link form, the placeholder gate)
- **Related:** **ADR-035** (the rename this serves), **ADR-023** (the legal byte-sync this refuses to duplicate), **ADR-020 D5** (the empty-URL ratchet this closes), **ADR-027/029** (bundle id and Team ID, both needed by the AASA), **ADR-032** (`match` runs readonly, which is why the entitlement is an operator step), **ADR-034** (the reasoning about what may and may not redden a build)

## Context

The rename left three things unserved: the App Store listing had **empty**
privacy and support URLs (accepted behind `--allow-empty-urls` since ADR-020
D5), the legal documents existed only inside the app bundle and the repo, and
the shared invite link was a **custom scheme**.

The founder chose **Firebase Hosting** over nginx-on-a-VPS. The project is
already entirely Firebase, so this adds no new runtime, no TLS to renew, and no
machine to patch — and the deploy can use the same credential model as
everything else.

## Decision 1 — The site is GENERATED from `docs/legal/`, never committed

`docs/legal/*.md` is already byte-synced into `app/assets/legal/` under a drift
test (ADR-023), because the app and the repo must never disagree about what the
policy says. Committing a third, hand-maintained HTML copy would add **a third
thing to drift**, and drift in a legal document is precisely the failure that
test exists to prevent.

So `tool/ci/build_site.py` renders the pages at deploy time and `web/public/`
is gitignored. There is exactly one source of truth, and it is the one the app
already ships.

The Markdown subset is deliberately tiny because the corpus is tiny — measured,
not guessed: `h1`–`h3`, unordered lists, one ordered list, tables, `**bold**`,
`_italic_`, `` `code` ``. An unrecognised line becomes a **paragraph**, which is
the safe failure: legal prose is never silently dropped, and that claim has a
test rather than a comment.

**Link syntax is deliberately not implemented.** The corpus contains zero links
and does contain `[FOUNDER LEGAL ENTITY — to be completed by the founder]`. A
link parser would swallow that into an anchor and *hide an unfilled blank*.

## Decision 2 — The placeholder gate refuses to publish an unfinished policy

A privacy policy served at a public URL that Apple points to must not read *"to
be completed by the founder"*. The builder exits non-zero when it finds one.

`--allow-placeholders` exists so the plumbing can be proven end to end on a
**preview channel** before the founder fills the blanks, and
`deploy-site.yml` refuses that flag on the **live** channel outright — a policy
about the *channel* cannot live in the tool, because the tool cannot see which
channel it is being run for.

Both directions are tested: blanks must fail the build, and clean text must not
need the escape flag. A gate that always failed would look identical to one that
works.

## Decision 3 — Invite links become universal links, and the old scheme keeps working

`hayati://invite/<code>` was not clickable in WhatsApp, had no preview, and did
**nothing at all** for a recipient without the app — which is every invitee, by
definition, on their first invite.

It becomes **`https://ikimiz.beyondkaira.com/i/<code>`**, with
`/.well-known/apple-app-site-association` served from the same host claiming
`/i/*` for `UH7MXG7Z94.com.beyondkaira.hayati`. With the app installed iOS
intercepts the URL; without it, the visitor gets a real page showing their code
and a way to install.

**The custom scheme is still parsed.** Links already sent sit in a partner's
chat history forever, and someone following a months-old invite is the least
equipped to work out why nothing happened. The scheme keeps the **old** name:
it is a registered identifier, not customer-facing text (ADR-035 D5), and
renaming it would break exactly the links this branch preserves.

`inviteLinkFor()` is now the **single constructor**. The share screen built the
string inline, so the message, the parser and the tests could each drift
independently; a round-trip test (`parse(inviteLinkFor(c)) == c`) pins them
together. Twelve new parser tests, including the one that matters for security:
**another host serving the same `/i/<code>` shape is rejected.**

## Decision 4 — Deploying is dispatch-only

Publishing is outward-facing and effectively irreversible — the previous text is
gone the moment the new one is live, and Apple and search engines both fetch it.
So `deploy-site.yml` is `workflow_dispatch` only, in `gemfile-lock.yml`'s shape.
**Merging to `main` is not consent to publish.**

## Decision 5 — ADR-020 D5's ratchet is closed in the same diff

`privacy_url.txt` and `support_url.txt` now carry real URLs, so
`--allow-empty-urls` is removed from **both** `ci.yml` and `release.yml`. Left
in place it would keep accepting empty URLs forever — a guard that guards
nothing, which is the shape this repo keeps meeting.

## Consequences and what only the founder can do

- **DNS.** Firebase issues TXT + A records for `ikimiz.beyondkaira.com`; they
  must be added at the `beyondkaira.com` registrar. A session cannot.
- **`FIREBASE_SERVICE_ACCOUNT`** does not exist as a repository secret. The
  deploy workflow **fails closed and names it** rather than emitting an opaque
  auth error.
- **Associated Domains must be enabled on the App ID** in the Apple Developer
  portal. `match` fetches profiles **readonly** (ADR-032), so it cannot add the
  capability: an un-updated profile makes signing fail with an entitlement
  mismatch rather than silently shipping a dead link.
- **The legal blanks block the live channel**, by design.
- The invite link points at a domain that is **not serving yet**. The app-side
  change is inert until the deploy runs — which is why both live in one PR and
  why the operator page leads with the DNS step.
