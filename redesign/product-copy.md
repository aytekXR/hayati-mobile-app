# Hayati — In-App Copy Blueprint (v1)

Complete copy rewrite for every shipped and proposed surface, keyed to real screens and source files. English is the spec language; TR/AR renderings are provided where a line is brand-load-bearing, with register notes for everything else. Canonical string home: `app/lib/core/l10n/arb/app_{en,tr,ar}.arb`. Every new or changed string ships through native register owners (TR founder couple, Gulf-dialect AR reviewer) before merge — this document is the source draft, not the final localization.

**Frozen families (Class G / ★, per ADR-023/025):** `consent*`, `legal*`, `coachDisclaimer*` / `coachHelp*` / `coachPaused*`, the delete/couple-ended sentences, and the sign-in legal footer are digest-pinned. This document marks them **KEEP VERBATIM** — they may be re-laid-out, never reworded without re-running their legal/safety gates. Lock-screen copy (Class F) is kept at parity by choice: it is already excellent.

---

## Voice & tone guide

Two signatures, kept and canonized: **warm second person** and **radical honesty**. Six working rules, each with a do/don't pair from real or proposed strings.

**1. Talk to the couple, not the user.** The unit of address is "you two." Prefer "both of you," "for two," "between you" over generic app-speak.
- Do: "One subscription. Premium for both of you."
- Don't: "Upgrade your account to unlock premium features."

**2. Never claim more than the code does.** State exactly what happened and what is true now. If a save might still be edited, say so. If a failure left things unchanged, say that too.
- Do: "Saved — you can edit until you both answer."
- Don't: "Answer submitted!" (implies finality the reveal rule doesn't grant)

**3. Invite, never guilt.** The lagging partner is courted, not shamed. Streaks forgive. No "Don't lose your streak!" panic mechanics — Alert may color a state, never the tone.
- Do: "Your partner's answer unlocks when you answer."
- Don't: "Your partner is still waiting on you…"

**4. Errors are calm, blame-free, and three-part.** Name what happened → what is true now → what to do. Never "failed," never exclamation-mark alarm, never blame the user's typing.
- Do: "That code didn't match. Try again."
- Don't: "Invalid code! Verification failed."

**5. Discretion is care, not paranoia.** Privacy copy is matter-of-fact and warm; it explains the protection and its honest limits without drama. DV-aware reticence is a voice rule: no actor attribution on couple-ended, no triumphant copy near the lock.
- Do: "Shows a plain icon on your home screen. The app's name still appears under it."
- Don't: "Stealth mode: hide Hayati from prying eyes!"

**6. One voice, four registers — and the chrome finally follows.** TR-playful (arkadaşça "sen," light warmth between the couple), TR-respectful, AR-Gulf-respectful (formal-warm, family-safe, modest-romantic — never neon-dating, never saccharine), EN-neutral-warm. UI chrome (captions, empty states, nudges, notifications) follows the profile's register field, not just content packs. Legal, safety, and data surfaces always take the respectful register in every language.
- Do (TR-playful caption): "Bugün de buradasınız. Güzel." / (TR-respectful): "Bugün de birliktesiniz."
- Don't: one register for everyone, or playfulness leaking into consent/lock/delete surfaces.

**Mechanical rules:** sentence case everywhere, including buttons. No emoji in UI copy (the invite share message's single ❤️ is the one licensed exception; the reveal's reaction glyphs are user-chosen content, not copy, and don't count). Contractions welcome in EN. Numerals: tabular figures for streaks/timers; Eastern Arabic numerals (٠١٢٣) as an AR setting. Captions render in Mist (`#B9AFC6` dark / `#6B6178` light), never Material grey.

---

## Onboarding copy, line by line

Flow: (NEW) ritual preview → Sign-in → [Phone] → (NEW) name capture → Profile capture → Consent gate → Solo home or Partner preview (+ the one-time NEW privacy spotlight card on first home).

### Proposed: Ritual preview (3 swipeable screens, pre-sign-in)

The store description already contains the pitch; onboarding finally uses it. Each screen: H1 headline (the Question style stays reserved for the daily question — ui-ux §6.1), one body line, Nightbloom illustration. Screen 3 carries the CTA into sign-in. Skippable via "Sign in" text button on every page.

| Step | Headline | Body | Notes |
|---|---|---|---|
| 1 | One question a day, for two. | A five-minute ritual that keeps you close — in your own language, in your own culture. | Primary tagline verbatim (TR: Günde bir soru, ikiniz için. / AR: سؤال واحد كل يوم، لكما.) |
| 2 | Sealed until you both answer. | No peeking, and no pressure to perform: just a moment that belongs to the two of you. | Body reuses the best store line — one pitch, everywhere |
| 3 | What's between you stays between you. | PIN lock, a discreet icon, and answers no one else ever sees. Not therapy, not a feed — just you two. | Tagline verbatim; CTA below: **Get started** |

### Sign-in screen — `app/lib/features/auth/presentation/sign_in_screen.dart`

| Element | Current | New copy | Notes |
|---|---|---|---|
| Wordmark | Text("Hayati") | Hayati (mark + wordmark) | Visual fix; no copy change |
| Tagline (NEW) | — | One question a day, for two. | Under the mark, Mist. TR: Günde bir soru, ikiniz için. AR: سؤال واحد كل يوم، لكما. |
| Support line (NEW) | — | A private daily ritual — just for you two. | TR: Sadece ikinize özel, günlük küçük bir ritüel. AR: طقس يومي خاص — لكما وحدكما. |
| Apple CTA | Continue with Apple | Continue with Apple | Keep; platform convention |
| Google CTA | Continue with Google | Continue with Google | Keep |
| Phone CTA | Continue with phone | Continue with phone | Keep |
| Legal footer | "By continuing you accept our Terms…" + links | **KEEP VERBATIM** | Frozen (aydınlatma footer); relayout only |
| Error title | Sign-in failed | That didn't go through | Softer; detail line carries the cause |
| Network error detail | Check your connection and try again. | You're offline. Check your connection and try again. | Names the state before the remedy |
| Generic error detail | Something went wrong. Please try again. | Something went wrong on our side. Please try again. | Owns the fault |

### Phone sign-in — `phone_sign_in_screen.dart`

| Element | Current | New copy | Notes |
|---|---|---|---|
| Title | Continue with phone | Continue with phone | Keep |
| Number label | Your phone number | Your phone number | Keep |
| Number hint | +90 555 123 45 67 (all locales) | Localized: TR "+90 5xx xxx xx xx" · AR "+966 5x xxx xxxx" · EN "Your number, with country code" | Fixes the Gulf user seeing a Turkish format |
| Helper (NEW) | — | We'll text you a code. Standard SMS rates may apply. | Sets expectation; respectful register |
| Send CTA | Send code | Send code | Keep |
| Code label | Verification code | Enter the code we texted you | Warmer, self-explanatory |
| Code helper (NEW) | — | Sent to {number} | Confirms the target; Mist caption |
| Verify CTA | Verify | Confirm | Softer verb |
| Resend | Resend code | Resend code | Keep; disable 30s with countdown "Resend in {n}s" |
| Wrong code | That code didn't match. Try again. | Keep | Already on-voice |
| Session expired | That took too long. Start again. | Keep | Honest and calm |

### Proposed: Name capture (new step, post-sign-in, pre-profile)

One field. Fixes "Someone invited you" for phone sign-ups and warms every later surface.

| Element | New copy | Notes |
|---|---|---|
| Title | What should we call you? | TR-playful: Sana ne diyelim? · TR-respectful: Size nasıl hitap edelim? · AR: بماذا نناديك؟ |
| Helper | Your partner will see this on your invitation. | The honest reason we're asking |
| Placeholder | Your name or nickname | Nickname explicitly welcome — many Gulf users prefer not to use full names |
| CTA | Continue | Standard forward verb |

### Profile capture — `profile_capture_screen.dart`

| Element | Current | New copy | Notes |
|---|---|---|---|
| Title | About you two | About you two | Keep — the couple-first tone is right |
| Subtitle (NEW) | — | Three quick choices, so every question fits you. | Explains why the form exists |
| Relationship label | Your relationship | Your relationship | Keep; chips keep first-person-dual TR/AR voice (Sevgiliyiz / Nişanlıyız / Evliyiz · نتواعد / مخطوبان / متزوجان) |
| Language label | Question language | The language of your questions | Clarifies it's content, not UI language |
| Tone label (TR only) | Tone | How should Hayati talk to you two? | Makes the register choice legible; chips: Samimi (Playful) / Ağırbaşlı (Respectful) |
| CTA | Continue | Continue | Keep |
| Save error | Couldn't save your profile | Your choices couldn't be saved. Nothing was lost — try again. | Three-part error pattern |

### Consent gate — `consent_gate_screen.dart` — **KEEP VERBATIM**

All four paragraphs, the 18+ statement, "I consent and continue," and the three escape actions are frozen guarantee copy (including "We do not claim all of your data sits in Europe, because it does not."). Redesign scope: layout only — progressive-disclosure structure (short bolded lead per paragraph, body beneath), Veil dividers, generous spacing. **Optional, gated proposal:** a single transition line above the frozen block — "Before your first question — a minute of plain talk about your data." Flag: adding even this line requires re-running the ADR-023 legal gate; ship without it if the gate can't be re-run before launch.

### Proposed: Privacy spotlight (one-time dismissible card on the first home, post-consent — never modal, per ui-ux §6.1)

Privacy is the headline P2 differentiator and is currently invisible until someone finds settings. A card, not a screen: the invitee has already paid a three-screen toll, and Principle 7 forbids blocking.

| Element | New copy | Notes |
|---|---|---|
| Title | Keep Hayati between you two | AR: ليبقى حياتي بينكما |
| Body | Add a 6-digit PIN so only you can open the app — and switch to a plain home-screen icon if you'd like. You can do both later in Settings. | Honest, unhurried; never implies shame in wanting privacy |
| Primary CTA | Set up my PIN | Routes into existing PIN setup |
| Secondary CTA | Maybe later | Never "Skip" — no judgment |

---

## Pairing copy

### Invite share screen — `invite_share_screen.dart`

| Element | Current | New copy | Notes |
|---|---|---|---|
| Title | Invite your partner | Invite your partner | Keep |
| Body | Your invite code is ready. Share it with your partner to pair. | One link, one tap, and the ritual begins. Your code works for 48 hours. | Sells the moment; keeps the honest TTL |
| Code card | ABCD2345 | Keep + **Copy code** icon-button beneath, confirmation caption "Copied." | Copy affordance was missing |
| Expiry | Expires 28 Jul 2026, 3:00 PM | Expires {date} — sharing again keeps the same code. | Discloses idempotent re-issue; removes re-share anxiety |
| Share CTA | Share invite | Share invite | Keep |
| QR caption (NEW) | — | Together right now? Have them scan this. | For same-room pairing; QR encodes the deep link |
| Waiting caption (NEW) | — | We'll bring you together the moment they join. | The screen already self-pops; say so |
| Cross-path | Have a code? | Got a code instead? | Slightly warmer |
| Create error | We couldn't create your invite. Please try again. | Keep | On-voice |

**Share message** (`inviteShareMessage`) — rewritten to survive non-tappable custom-scheme links by leading with the code:

> EN: "I picked an app for us — one question a day, just for the two of us. My invite code: **{code}**. Get Hayati, then enter the code. I'm waiting for you ❤️ {link}"
> TR: "Bize bir uygulama buldum — her gün ikimize bir soru. Davet kodum: **{code}**. Hayati'yi indir, kodu gir. Seni bekliyorum ❤️ {link}"
> AR: "اخترت لنا تطبيقًا — سؤال واحد كل يوم، لنا وحدنا. رمز الدعوة: **{code}**. حمّل حياتي ثم أدخل الرمز. بانتظارك ❤️ {link}"

Notes: the shipped "I'm waiting for you on Hayati ❤️" first line moves to the close (a glanced-at WhatsApp preview should read warm, not conspicuous — discretion rule); the code leads because custom-scheme links aren't tappable in chat apps. Once universal links ship, the link becomes an https URL and moves up.

### Partner preview / join — `partner_preview_screen.dart`

| Element | Current | New copy | Notes |
|---|---|---|---|
| Manual-entry title | Have an invite code? | Have an invite code? | Keep |
| Manual-entry body | Enter the 8-character code your partner shared to see their invitation. | Keep | Clear |
| Field label | Invite code | Invite code | Keep |
| Field validation | That doesn't look like a valid code. Check the 8 characters and try again. | Keep | On-voice |
| Submit | See invitation | See invitation | Keep |
| Hero (named) | {name} invited you | {name} invited you | Keep — the strongest word on the screen is the name |
| Hero (no name) | Someone invited you | Your partner invited you | "Someone" is cold and faintly alarming for this product; name capture makes this rare anyway |
| Valid body | This invitation is ready. Pair up to start answering a question together every day. | One question a day, sealed until you both answer. {name} is ready when you are. | Sells the mechanic in one line; falls back to "They're ready when you are." |
| Question hook (RESTORE, per PRD F1) | — (cut) | Today's question: "{questionText}" — {name} has already answered. Their answer unlocks when you write yours. | The single most Gate-2-relevant line in the app; the endpoint's typed projection was designed to grow exactly this. Second sentence renders only if the inviter has answered. |
| Join CTA | Accept invitation | Join {name} | Person over paperwork; fallback "Accept invitation" |
| Dismiss | Not now | Not now | Keep — no guilt |
| Unavailable title | This invitation isn't available | Keep | Honest single collapsed state |
| Unavailable body | It may have expired or already been used. Ask your partner for a fresh code. | It may have expired or already been used. Ask your partner to share a fresh one — it takes ten seconds. | Removes the dead-end feeling |
| Fetch error | We couldn't load this invitation. Please try again. | Keep | Retryable, on-voice |

**Six join failures** (all keep the "Enter a different code" path):

| Reason | Current | New copy |
|---|---|---|
| Unknown | We couldn't find that code. Check it and try again. | Keep |
| Expired | This invitation has expired. Ask your partner for a fresh code. | Keep |
| Consumed | Someone already used this code. | This code has already been used. If that wasn't you two, ask your partner for a fresh one. |
| Self-join | This is your own invite — share it with your partner instead. | Keep — quietly funny already |
| Already paired | This account is already paired. | You're already paired. Hayati is one space for one couple. |
| Profile missing | Finish setting up your profile first. | Almost there — finish your profile first, then this invitation will be waiting. |

---

## The daily ritual

### Paired home — `paired_home_screen.dart`

The question renders in the new Question style (28/300). Copy stays out of its way.

| Element | Current | New copy | Notes |
|---|---|---|---|
| Caption | Today's question | Today's question | Keep. TR-playful alt: "Bugünün sorusu geldi" |
| Answer hint | Write your answer… | Only {name} will ever read this. | The placeholder is the one spot to restate the private-by-design promise daily; fallback "Only your partner will ever read this." |
| Save CTA | Save answer | Save answer | Keep |
| Saved caption | Saved — you can edit until you both answer. | Keep | Signature honesty; do not touch |
| Partner slot, locked | Your partner's answer unlocks when you answer. | Keep | Canonical rule 3; TR: "Cevapladığında partnerinin cevabı açılır." |
| Partner slot, waiting | You answered — waiting for your partner. | Your side is done. {name}'s answer will unfold here. | Forward-looking; names the reveal verb |
| Revealed caption | You both answered today. | You both showed up today. | The ritual is about showing up, not homework. TR-respectful: "Bugün de birliktesiniz." AR: "كلاكما حاضر اليوم." |
| Partner answer label | Your partner's answer | {name} | A name over a label; own card: "You" |
| Come-back line (NEW) | — | Tomorrow's question arrives after midnight. | Closes the loop with a forward pull; Mist caption |
| Packs tile | Question packs / Premium unlocks more packs for both of you. | Keep title / keep both subtitles | Already honest |
| Coach tile | Coach / Advice, date ideas, and gifts — for the two of you | Keep | On-voice |

### Streak & celebration (NEW surfaces — server data already exists)

The streak becomes the seed vessel (brandkit motif). Copy is quiet; the visual carries it.

| Moment | Copy | Notes |
|---|---|---|
| Streak row (revealed) | {count} seeds · {count} days together | Replaces "4-day streak"; tabular figures; AR uses Eastern Arabic numerals when the setting is on |
| First seed (day 1) | Your first seed. | One line under the vessel; no fanfare — restraint reads premium |
| Milestone 7 | Seven seeds. A whole week of showing up for each other. | Gold particles ≤1.2s, skippable; TR-playful: "Yedi tane oldu. Koca bir hafta." |
| Milestone 30 | Thirty seeds. This is a ritual now. | AR: "ثلاثون بذرة. صار عادةً جميلة." |
| Milestone 100 | A hundred seeds. Few couples get here. You did. | The only place superlative pride is allowed |
| Mercy day used | Life happened yesterday. A mercy day kept your streak whole. | Surfaces the grace token as forgiveness, not mechanics. TR: "Dün hayat araya girdi. Merhamet günü serinizi korudu." AR: "أمسٌ شغلَتكما الحياة — يومُ رحمة حفظ سلسلتكما." |
| Streak strip, mercy indicator (paired home) | Mercy day used — your streak is safe. | Compact caption beside the Sage leaf glyph on the streak strip (ui-ux §6.3); the full line above carries the moment |
| Mercy explainer (tooltip/sheet) | Miss a day and one mercy day bridges it, once a week. Streaks here forgive. | "Streaks here forgive" is the design principle, spoken |

The one-time pairing moment ("You two are in.") lives in the success-states table below.

### The reveal's reaction row (NEW — PRD F2 lite, ui-ux §5.4)

Six reactions + a one-line reply under the partner's revealed answer. Couple-visible only; both freeze with the day. Reactions are content glyphs, not UI icons; the sixth slot follows the profile register. Final set is owned by the native register reviewers.

| Element | Copy / set | Notes |
|---|---|---|
| Reaction set | ❤️ 🥰 😂 🤲 🌹 + one register-aware slot | Register slot: TR-playful 🫶 · AR-Gulf-respectful 🌙 · EN / TR-respectful ✨ — warm, never neon-dating; VoiceOver labels: "Love" / "Sweet" / "Laughing" / "Gratitude" / "A rose" / register label |
| Reply placeholder | Say something back — only {name} sees it. | One line, optional; fallback "only your partner sees it." |
| Reply sent | Sent. | Caption, Mist; the reply renders beneath their answer |
| Frozen day | Past days stay just as you left them. | Shown only if a reaction/reply is attempted on a past day (read-only after the day rolls); "sealed" is reserved for pre-reveal answers |

### Solo home — `solo_home_screen.dart`

| Element | Current | New copy | Notes |
|---|---|---|---|
| Nudge body | Hayati is better together. Invite your partner — your reflections will be waiting when you pair up. | Keep | Honest better-together framing |
| Nudge CTA | Invite your partner | Keep | |
| Progress | Day 3 of 7 | Day 3 of 7 | Keep; add seed-progress visual (7 slots) |
| Answer hint | Write your answer… | This one's just for you. | Mirrors the paired hint's privacy promise |
| Save / saved | Save answer / Saved for today. | Keep both | |
| Completed title | Your seven days are complete | Keep | |
| Completed body | Seven days of reflection, done. Hayati is built for two — pair up to keep going, and your answers will be waiting. | Keep, then add: A new solo question still arrives each week, whenever you want a quiet moment. | Requires the evergreen solo track below; ship the added sentence only with the feature |

**Proposed: evergreen solo track (fixes the day-8 cliff).** One question per week post-day-7, drawn from the solo pack pool. Caption: "This week's reflection." Empty slot: "Your next reflection arrives {weekday}." Keeps unpaired users alive as future pairers without diluting "built for two."

**Proposed: solo-history surface (post-pairing).** Lives as the final section of the Us screen (ui-ux §6.3), not a paired-home overflow row. Header: "Your first seven days" with the sub-line "Seven answers from before you two paired. Still only yours — sharing is up to you." Delivers the "your answers will be waiting" promise already made in shipped copy; own-data only — partner solo answers never cross.

### Us — the couple's shared place (NEW screen, ui-ux §6.3)

| Element | Copy | Notes |
|---|---|---|
| Vessel hero caption | {count} days answered together | Count in Display tabular figures; Eastern Arabic numerals when the AR setting is on |
| Milestone track | 7 · 30 · 100 | Achieved markers in Gold; no labels needed — the numbers are the language |
| Mercy status (available) | 1 mercy day available this week. | Sage leaf glyph; respectful register in all languages |
| Mercy status (used) | Used {weekday} — your streak is safe. | |
| Past-days list | (date + question first line) | Tapping opens the frozen pair of answers, read-only |
| Empty state (zero seeds) | Your first seed arrives the first day you both answer. | Canonical vessel-empty line (also used on the paired-home strip) — honest: a seed needs both answers |
| Solo-history header | Your first seven days | Sub-line above |

---

## Empty, error, and success states

### Empty states

| Screen | State | Copy |
|---|---|---|
| Paired home | No day yet | Title: **No question yet today.** Body: Today's question is on its way — it arrives shortly after your midnight. (keep; add Nightbloom illustration) |
| Paired home | Pack lag | Title: **Update Hayati.** Body: Today's question needs a newer version of the app. (keep) |
| Coach | Empty transcript | Ask anything — from a hard conversation to a date idea. (keep) Add caption: Conversations here aren't saved after you leave. — makes ephemerality a promise instead of a surprise |
| Pack selection (premium) | No packs yet | Title: **Starter collection.** Body: Your daily questions come from the starter collection. Caption: New packs are on the way. (keep — honest filler until W9) |
| Export | Loading | Gathering your data… |
| Streak vessel | Zero seeds | Your first seed arrives the first day you both answer. (honest: a seed needs both answers, not one) |

### Error states, by failure mode

| Mode | Where | Copy |
|---|---|---|
| Offline (detected) | Any fetch surface | You're offline. Hayati will catch up the moment you're back. |
| Offline (answer save) | Paired/solo home | Your answer couldn't be saved — you're offline. It's still here; try again when you're connected. |
| Auth failure | Sign-in | Title: That didn't go through. Detail per cause (network / generic, above). |
| Sync failure (stream error) | Paired home | We couldn't load today. Pull to try again — nothing you've written is lost. |
| Save conflict / server refuse | Answer save | That couldn't be saved. Your words are still in the box — try again. |
| Payment failure (store unavailable) | Paywall | The store isn't available right now. Please try again in a moment. (keep) |
| Payment failure (purchase error) | Paywall | The purchase didn't complete and you weren't charged. You can try again whenever you like. |
| Payment cancelled | Paywall | No message. Cancelling a sheet is a decision, not an error. |
| Restore found nothing | Paywall | No previous purchase found for this Apple ID. |
| Webhook lag | Paywall banner | Purchase received — unlocking for both of you… (keep; durable until mirror flips) |
| Coach outage | Coach | The coach isn't available right now. Please try again in a moment. (keep) |
| Coach rate limit | Coach | That's quick! Give it a few seconds and try again. (keep) |
| Coach daily cap | Coach | You've reached today's message limit. It resets tomorrow. (keep) |
| Coach monthly cap | Coach | You've reached this month's shared limit for you two. (keep) |
| Invite create failure | Invite share | We couldn't create your invite. Please try again. (keep) |
| Settings toggle failure | Settings | That setting couldn't be changed. Please try again. (keep — with per-row honest variants already shipped) |

### Success & celebration states

| Moment | Copy | Notes |
|---|---|---|
| Pairing complete (NEW, one-time banner on first paired home — carried by the `branches-meet` one-shot, creative-assets §6.5; never a separate route, per the ui-ux navigation inventory) | Title: **You two are in.** Body: From tonight, one question a day. Sealed until you both answer. | No CTA — today's question is already on the screen. TR: "Artık ikiniz varsınız." AR: "صرتما معًا هنا." |
| Reveal (daily) | No new copy — the choreography, seed drop, and haptic carry it; "You both showed up today." is the only line | Restraint: the answers are the content |
| Purchase success (entitled) | You're Premium. / Premium is active for both of you. (keep both) | |
| Export copied | Copied to your clipboard. (keep) | |
| PIN set (NEW caption on settings return) | Your PIN is on. Hayati locks when you leave it. | Confirms protection actually persisted — honesty rule |

---

## Push notification library

All notifications are composed server-side (`functions/src/notifications/`), never carry question or answer text in payloads, respect quiet hours 22:00–08:00 couple-local, and collapse to the discreet variant when discreet notifications are on (AR default, non-overridable in v1). System font renders these — no styling assumptions.

**Anti-spam constitution:** hard cap 2 notifications per user per day; reveal supersedes partner-answered if both would fire within 30 min; streak-at-risk fires at 20:00 local only if neither partner has answered and never two days in a row; milestone pushes fire at most once per milestone, in the morning window; no notification ever fires about the partner's inactivity in a way the partner can be blamed for (DV rule: the notified user must never learn "your partner ignored you" from us).

| # | Trigger | Title | Body | Cadence rule |
|---|---|---|---|---|
| 1 | Daily question assigned (rollover) | Today's question is here | Five minutes, just for you two. | Max 1/day, morning window 08:00–10:00 local; skipped if either already answered |
| 2 | Partner answered (you haven't) | {name} answered today | Their answer unfolds when you write yours. | Max 1/day; suppressed by #3; never sent after 21:30 |
| 3 | Reveal ready (both answered) | Your answers are open | Tonight's unfold is waiting. | Immediate on reveal; supersedes #2 |
| 4 | Streak at risk | Your seed for today | One answer keeps the streak whole. No rush — you have until midnight. | 20:00 local; never consecutive days; never mentions the partner |
| 5 | Partner joined (inviter) | {name} is in | You're paired. The first question is ready. | Immediate, once ever |
| 6 | Mercy day consumed | Your streak is safe | A mercy day covered yesterday. See you tonight. | Morning after; max 1/week by definition |
| 7 | Milestone (7/30/100) | {count} seeds | {count} days of showing up for each other. | Morning window; once per milestone |
| 8 | Trial ending (T-2 days) | Your trial ends {weekday} | Premium stays on for both of you unless you cancel — no surprises. | Once per trial; respectful register always |
| 9 | Solo weekly reflection (evergreen) | A quiet question for you | This week's solo reflection is ready. | Max 1/week, only for unpaired users |

**Discreet variants (all of the above collapse to):** Title: "Hayati" → Body: "Something new is waiting." — TR: "Yeni bir şey var." AR: "هناك جديد بانتظارك." No names, no counts, no relationship vocabulary. The discreet variant of #8 (billing) keeps its full text — money surprises are worse than discretion here, and it contains nothing relational.

TR renderings sample (#1): "Bugünün sorusu geldi" / "Beş dakika, sadece ikinize." AR (#3): "إجاباتكما مفتوحة الآن" / "لحظتكما الليلة بانتظاركما."

**Pre-permission prompt (NEW card on Today, shown once after the first saved answer — ui-ux §6.8; the iOS system dialog fires only after "Turn them on"):**

| Element | Copy | Notes |
|---|---|---|
| Title | Want a gentle nudge when {name} answers? | Fallback "…when your partner answers?" |
| Body | One quiet notification — never the answer itself, and nothing after 22:00. | Both claims are code-true (no-content payloads; quiet hours) — honesty rule |
| Primary CTA | Turn them on | Triggers the system permission dialog |
| Secondary CTA | Not now | Never re-prompts on a cadence; Settings remains the home of this control |

---

## Paywall & premium copy

### Paywall — `paywall_screen.dart`

| Element | Current | New copy | Notes |
|---|---|---|---|
| Title | Hayati Premium | Hayati Premium | Keep |
| Pitch | One subscription. Premium for both of you. | Keep | The differentiator, already perfect |
| Benefit list (NEW) | — | Every question pack, present and future · The coach — advice, date ideas, gifts · One purchase covers you both | Three lines max, Phosphor seed bullets; only claims that are true at ship time — if coach/packs aren't live, that line ships as "coming first to Premium" or not at all (honesty rule) |
| Annual badge | Best value | Best value | Keep; one of two gold uses |
| Annual sub-label | ≈ ₺74,99/month | Keep pattern (≈ {price}/month) | Verbatim store prices, never re-formatted |
| Lifetime card (NEW, TR storefront) | — | Label: **Yours forever** · Sub-label: Pay once. Both of you, for good. | TR one-time-purchase culture (feasibility §6); TR: "Bir kez öde, ikiniz için sonsuza dek." |
| Trial banner | Start with a 7-day free trial | Keep pattern | Store-derived |
| Trial honesty (NEW caption) | — | Nothing is charged until the trial ends. Cancel anytime in your App Store settings. | Radical honesty as conversion tool — trust is the product |
| CTA (trial) | Start your free trial | Keep | |
| CTA (no trial) | Continue | Subscribe | "Continue" hides intent; say the true verb |
| Free reassurance | Your daily question and streak stay free, always. | Keep | Load-bearing promise; never remove |
| Restore | Restore purchases | Keep | |
| Entitled view | You're Premium / Premium is active for both of you. / Manage your subscription in your App Store settings. | Keep all three | |
| Processing banners | Purchase received — unlocking for both of you… / Restore processed — syncing… | Keep both | |
| Store unavailable | The store isn't available right now. Please try again in a moment. | Keep | Fail-closed truth |

### Pack selection & gates — `pack_selection_screen.dart`, `premium_gate.dart`

| Element | Current | New copy |
|---|---|---|
| Locked title | Unlock every pack | Keep |
| Locked body | Premium opens every question pack — for both of you. | Keep |
| Locked CTA | See Premium | Keep |
| Coach gated title | The coach is a Premium feature | Keep |
| Coach gated body / CTA | One subscription unlocks it for both of you. / See Premium | Keep both |

No overclaiming anywhere: while premium contents are thin (pre-W9), the paywall never promises specific pack counts or "hundreds of questions."

---

## Settings & privacy-lock microcopy

The shipped settings copy is the best writing in the app — safety-literate and honest. Verdict: keep nearly everything; changes are additive structure (section headers, now possible with Mist/Veil tokens) and three small touches.

**New section headers (Mist, all-locale respectful register):** "Privacy" (lock, PIN, biometric, discreet icon, discreet notifications) · "Your data" (download, privacy & terms, delete) · "Account" (sign out).

| Element | Current | New copy | Notes |
|---|---|---|---|
| Lock subtitle (off) | Protect Hayati with a 6-digit PIN. | Keep Hayati just for you — add a 6-digit PIN. | "Protect" is faintly alarmist; "just for you" is the warm truth |
| Lock subtitle (on) | Hayati asks for your PIN when you open it, and again if you've been away for more than a minute. | Keep | Must disclose the grace window (ADR-018) |
| Biometric title/subtitle | Unlock with Face ID or Touch ID / A shortcut only — your PIN always works. | Keep both | |
| Biometric warning | Before you turn this on / Anyone whose face or fingerprint is saved on this phone can unlock Hayati. Your PIN stays private to you. / I understand | Keep all | DV-critical; do not touch |
| Discreet icon subtitle | Shows a plain icon on your home screen. The app's name still appears under it. | Keep | The honest iOS bound |
| Discreet notifications subtitle | Hide message content in notifications, showing only that something new arrived. | Keep (+ shipped AR variant) | |
| Sign out subtitle | Signing out also removes the PIN from this phone. | Keep | |
| Export row | Download my data / See and copy the data Hayati holds for you. | Keep both | |
| Delete row | Delete account & data / Permanently remove your account and everything in it. | Keep both | |
| All PIN setup/change strings | (see ARB) | Keep every one | "The lock is still off." / "Your old PIN is still in place." are model honesty |

**Lock screen (Class F — parity only):** every string keeps verbatim: "Hayati is locked," "Enter your 6-digit PIN," the tiered wrong-PIN and cooldown strings, "Face ID changed on this phone — enter your PIN," "Forgot PIN? Sign out," and the inline recovery panel ("This signs you out on this phone and removes the PIN. Your answers are safe — sign back in to see them again."). No new copy may require an Overlay widget (sentinel-enforced).

**Privacy shield:** stays a plain Night (`#231A33`) surface, zero copy, zero brand, forever — by ADR.

---

## Legal-adjacent & data-rights copy

| Surface | Disposition |
|---|---|
| Legal hub (`legal_screen.dart`) | **KEEP VERBATIM**: consent status line ("Consented on {date}, version {n}."), Privacy Policy / Terms tiles, Withdraw consent action and its prospective-reading dialog (data remains stored until deleted). Relayout with Veil dividers only. |
| Legal documents (`legal_document_screen.dart`) | Content is byte-synced from `docs/legal/` — owned by the legal gate, not this document. |
| Export (`export_screen.dart`) | Keep: "This is your data, as Hayati holds it. Copy it anywhere you like." + Copy / Copied to your clipboard. Add loading state (above). |
| Delete account (`delete_account_screen.dart`) | **KEEP VERBATIM** — all pinned sentences: "This can't be undone." · "It permanently deletes your account, your private reflections, and the entire shared space — both sides of every answer." · "Your partner will see that the shared space was closed, but not why." · "This does not cancel an App Store subscription. Manage that in your App Store settings." · "Download your data first?" · retry copy says "couldn't be confirmed," never "failed." |
| Couple-ended notice | **KEEP VERBATIM** — actor-unattributed by DV decision: "The shared space has been closed and its content permanently deleted." · "Your own private reflections are untouched and remain yours." · "You can pair again whenever you choose." |
| Coach disclaimer / help / paused | **KEEP VERBATIM** (Class G+★): the "gentle note" disclaimer, "We're here for you" help card, "This conversation is paused to keep you safe." The help-card structural distinction and help-latch survive any redesign. Hotline numbers remain founder-gated. |

## Confirmation dialogs (destructive actions)

All destructive confirms follow one shape: plain-truth title (question form) → scope in one sentence → destructive action named by consequence (never "OK/Yes") → Cancel always present, always the safe default.

| Dialog | Title | Body | Actions |
|---|---|---|---|
| Delete account (no lock) | Delete everything? | Keep shipped body (pinned sentences above). | **Delete permanently** / Cancel |
| Delete account (lock on) | Enter your PIN | (PIN verify replaces the dialog — shipped flow, keep) | — |
| Withdraw consent | Withdraw consent? | **KEEP VERBATIM** (prospective reading; stored data remains until deleted). | Withdraw / Cancel |
| Turn off app lock | Enter your PIN | Failure: That PIN didn't match. The lock is still on. (keep) | Confirm / Cancel |
| Biometric enable | Before you turn this on | (DV warning, keep verbatim) | I understand / Cancel |
| Lock-screen recovery | Sign out to reset your PIN | (inline panel, keep verbatim — never a dialog) | Sign out / Cancel |
| Coach new conversation (NEW confirm, only when transcript non-empty) | Start fresh? | This conversation isn't saved anywhere and can't be brought back. | Start new / Keep talking |

---

## Localization & register notes

- **TR-playful chrome** applies only to: home captions, streak/milestone lines, empty states, nudges, notification bodies, and the answer hint. It never touches: auth, consent, legal, lock, settings, delete, coach safety. Playful means warm brevity ("Bugün de buradasınız. Güzel."), never flirt-at-the-app, never slang that ages.
- **AR register** is Gulf-respectful everywhere in v1: formal-warm, family-safe, modest-romantic. Dual forms (كما/تما) are used deliberately — Arabic grammar gives us "you two" natively; use it. No terms of endearment beyond what the name Hayati itself carries. Never neon-dating vocabulary (إعجاب، مطابقة), never saccharine.
- **RTL mechanics:** all copy must survive the six-cell golden matrix; no directional punctuation assumptions; ellipsis is "…" in all locales; numerals follow the Eastern Arabic setting for AR when it ships.
- **Names in copy:** every `{name}` slot falls back gracefully ("your partner" / "partnerin" / "شريكك" — AR falls back to the neutral-respectful form) and is capped for layout at 20 chars with ellipsis.
- **Governance:** new keys land in `app_en.arb` with `@description` intent notes (the shipped convention — keep it; those descriptions are why this audit was possible). Nothing merges without native register-owner sign-off; ★ strings additionally re-run the crisis-review gate.

---

## What this rewrite deliberately did not do

It did not reword a single frozen sentence, did not add urgency mechanics to streaks, did not put the brand name or relationship vocabulary into discreet notifications, and did not let the paywall promise contents that don't exist yet. The shipped copy's two signatures — warmth and radical honesty — were the strongest asset in the codebase; this document extends them to the surfaces that were missing them (onboarding, celebration, notifications) rather than replacing them anywhere.
