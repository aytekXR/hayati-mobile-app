// Pure push-payload policy for M3.4 (ADR-012 decision 3, PRD F6 privacy pack,
// brandkit §8 "Voice & tone": warm, second-person, never preachy; notifications
// read like a considerate friend; streak-at-risk copy is invitational, not
// shaming). composePush maps (kind, recipient language, discreet flag) to the
// {title, body} that the trigger/sweep hands the MessagingPort.
//
// ABSOLUTE PRIVACY INVARIANT (PRD F6, M3.3 handoff): NO payload string in ANY
// mode ever contains question text or answer text — lock screens are not
// couple-private. This is true BY CONSTRUCTION: composePush has no question/
// answer parameter, so there is nothing to leak. The unit tests assert it as a
// standing audit of the copy surface, but the type signature is the guarantee.
//
// Two axes (ADR-012):
//   - kind: which event (all FOUR localized in TR/AR/EN by the RECIPIENT's
//     users.contentLanguage, resolved upstream in recipients.ts).
//   - discreet: when ON, the payload is fully generic — no partner name, no
//     event specifics, no streak digits, title is the app name only. Default is
//     ON in the AR locale (F6); see resolveDiscreet.

import { sanitizePushName } from './sanitize-push-name';

export type PushKind = 'partnerAnswered' | 'reveal' | 'streakAtRisk' | 'dailyQuestion';
export type PushLanguage = 'tr' | 'ar' | 'en';

export interface PushPayload {
  title: string;
  body: string;
}

// The neutral title used in EVERY discreet payload — "the app name at most"
// (ADR-012). Kept latin across all three languages so a shoulder-surfed lock
// screen reveals nothing about the app's nature; "ikimiz" is an ordinary
// Turkish word ("the two of us"), so it gives even less away than a coined
// brand would — but note it is NOT neutral to a Turkish reader, which is a
// property ADR-012's discretion argument should be re-checked against if the
// discreet-notification promise is ever restated (ADR-035 D5).
const APP_NAME = 'ikimiz';

// Discreet body: identical regardless of kind, name, or streak — the whole point
// is that NO event specific leaks. "Something is waiting" and nothing more.
const DISCREET_BODY: Record<PushLanguage, string> = {
  en: 'Something is waiting for you in ikimiz.',
  tr: 'ikimiz\'de seni bekleyen bir şey var.',
  ar: 'هناك ما ينتظرك في ikimiz.',
};

// partnerAnswered fires only POST-first-answer, to the member who has not
// answered (ADR-012 / M3.3 handoff): naming the partner and saying "answered" in
// NORMAL mode is deliberate and permitted — it is a push, never a loosened read
// rule, and it exposes no answer content. partnerName sits in SUBJECT position in
// all three languages (no possessive/case suffix attaches to it), so an arbitrary
// name interpolates cleanly; AR uses a masculine-default verb for a named third
// party, matching the shipped `دعاك {name}` precedent (invitePreviewInvitedBy).
//
// ⚠️ THE NAME MUST NEVER BE THE FIRST STRONG CHARACTER (ADR-059 D1, issue #136).
// The placement above was reasoned about for GRAMMAR and not for DIRECTION, and
// the two want different things. A first-strong renderer takes the paragraph
// direction from the first strong character (UAX #9 P2/P3) — so while `${name}`
// led the EN and TR strings, an Arabic-named partner laid the whole English
// sentence out right-to-left, with its final stop at the head of the line
// (measured with FriBidi; see `tool/bidi_visual.py`):
//
//     أيلين answered today's question. …
//       ->  .answered today's question. … ﻦﻴﻠﻳﺃ
//
// So EN and TR now open with the copy's own word — which makes the named string
// the name-free sentence with a name dropped into it, and the two variants read
// as one family. The Arabic needed no change: it is verb-first, as Arabic VSO
// order makes natural. `sanitize-push-name.ts` handles the other half — a
// neutral the NAME carries, which no arrangement of OUR words can reach.
function partnerAnsweredNormal(language: PushLanguage, partnerName?: string): PushPayload {
  const name = sanitizePushName(partnerName, language);
  if (name) {
    switch (language) {
      case 'en':
        return {
          title: `Your partner ${name} answered`,
          body: `Your partner ${name} answered today's question. Open ikimiz to add yours.`,
        };
      case 'tr':
        return {
          title: `Partnerin ${name} cevapladı`,
          body: `Partnerin ${name} bugünün sorusunu cevapladı. ikimiz'de sen de cevapla.`,
        };
      case 'ar':
        return { title: `أجاب ${name}`, body: `أجاب ${name} عن سؤال اليوم. افتح ikimiz وأضف إجابتك.` };
    }
  }
  // Degrade gracefully when no partner name resolved — name-free copy, never an
  // 'undefined' interpolation (M3.4 rule).
  switch (language) {
    case 'en':
      return { title: 'Your partner answered', body: `Your partner answered today's question. Open ikimiz to add yours.` };
    case 'tr':
      return { title: 'Partnerin cevapladı', body: 'Partnerin bugünün sorusunu cevapladı. ikimiz\'de sen de cevapla.' };
    case 'ar':
      return { title: 'أجاب شريكك', body: 'أجاب شريكك عن سؤال اليوم. افتح ikimiz وأضف إجابتك.' };
  }
}

// reveal fires to the FIRST answerer once both have answered (ADR-012): the day
// is complete and both answers are now mutually visible. Name-free by design —
// the partner's answer is referenced ("read it together"), its text never is.
function revealNormal(language: PushLanguage): PushPayload {
  switch (language) {
    case 'en':
      return { title: 'You both answered', body: `You both answered today's question. Open ikimiz to read it together.` };
    case 'tr':
      return { title: 'İkiniz de cevapladınız', body: 'Bugünün sorusunu ikiniz de cevapladınız. Partnerinin cevabını görmek için ikimiz\'i aç.' };
    case 'ar':
      return { title: 'أجبتما كلاكما', body: 'أجبتما عن سؤال اليوم. افتح ikimiz لتقرآ إجابتيكما معًا.' };
  }
}

// dailyQuestion is the hour-8 sweep push (ADR-042 D3) — the founder's first ask,
// verbatim: "It needs to be send new questions at 08.00 TSI with a question."
//
// It announces that a question EXISTS. The question itself never travels, and
// that is structural rather than a copy rule: composePush has no question
// parameter, so there is nothing here to leak even by mistake.
//
// Name-free and streak-free by design. At the couple's local 08:00 the day doc
// was created eight hours earlier at local midnight and, in the ordinary case,
// nobody has answered yet — so there is no partner action to report and no
// streak state worth putting on a lock screen. A caller that passes partnerName
// or streakCount for this kind is ignored, which the tests pin.
function dailyQuestionNormal(language: PushLanguage): PushPayload {
  switch (language) {
    case 'en':
      return {
        title: "Today's question is here",
        body: 'A new question is waiting in ikimiz. Answer it whenever today suits you.',
      };
    case 'tr':
      return {
        title: 'Bugünün sorusu geldi',
        body: 'ikimiz\'de yeni bir soru seni bekliyor. Bugün sana uyan bir vakitte cevapla.',
      };
    case 'ar':
      return {
        title: 'وصل سؤال اليوم',
        body: 'سؤال جديد ينتظرك في ikimiz. أجب عنه في الوقت الذي يناسبك اليوم.',
      };
  }
}

// The no-streak afternoon nudge (ADR-042 D4). D4 drops the streak.count > 0 gate
// so the 16:00 push reaches couples who have no streak at all — which is most
// couples in week one and every couple that ever broke one. That population is
// the REASON for the change, so the copy they receive cannot talk about a streak:
// "your streak is still alive" is simply FALSE for them, and telling someone
// their streak is alive when they have none is worse than saying nothing.
//
// So this is a different message, not a degraded one. It protects the
// relationship rather than the counter — the founder's own words were "so that
// your partner dont get angry" — and it stays invitational, never shaming
// (brandkit §8): it says the day is still open, not that the reader is late.
function unansweredNudgeNormal(language: PushLanguage): PushPayload {
  switch (language) {
    case 'en':
      return {
        title: 'Your partner is waiting',
        body: "Today's question is still open in ikimiz. There is time before the day ends.",
      };
    case 'tr':
      return {
        title: 'Partnerin seni bekliyor',
        body: 'Bugünün sorusu ikimiz\'de hâlâ açık. Gün bitmeden vaktin var.',
      };
    case 'ar':
      return {
        title: 'شريكك بانتظارك',
        body: 'سؤال اليوم ما زال مفتوحًا في ikimiz. لديك وقت قبل أن ينتهي اليوم.',
      };
  }
}

// streakAtRisk with a live streak is the hour-16 sweep push (ADR-012 D3, re-pointed
// from hour 20 by ADR-042 D4) to a couple whose day is still unrevealed.
// INVITATIONAL, never shaming (brandkit §8). Without a positive count it falls
// through to unansweredNudgeNormal above rather than to a streak-free variant of
// streak copy. AR numeral-noun agreement is approximated with the tamyiz
// (accusative) form `يومًا`, the single form that reads acceptably across counts in
// app microcopy; revisit with native review.
function streakAtRiskNormal(language: PushLanguage, streakCount?: number): PushPayload {
  const count =
    typeof streakCount === 'number' && Number.isFinite(streakCount) && streakCount > 0
      ? Math.floor(streakCount)
      : undefined;
  if (count !== undefined) {
    switch (language) {
      case 'en':
        return { title: 'Keep your streak going', body: `You're on a ${count}-day streak together. Answer today's question in ikimiz before midnight to keep it.` };
      case 'tr':
        return { title: 'Serinizi sürdürün', body: `${count} günlük seriniz sürüyor. Gece yarısından önce ikimiz'de bugünün sorusunu cevaplayıp devam ettirin.` };
      case 'ar':
        return { title: 'حافِظا على تتابعكما', body: `تتابعكما بلغ ${count} يومًا. أجيبا عن سؤال اليوم في ikimiz قبل منتصف الليل لتحافظا عليه.` };
    }
  }
  // No live streak: a DIFFERENT message, not a streak message with the digits
  // removed. See unansweredNudgeNormal for why that distinction is load-bearing.
  return unansweredNudgeNormal(language);
}

/**
 * The localized {title, body} for a push. In discreet mode the kind, partnerName
 * and streakCount are ignored entirely (nothing event-specific may leak); in
 * normal mode partnerName tunes only `partnerAnswered` and streakCount only
 * `streakAtRisk` — both degrade to generic copy when absent.
 */
export function composePush(input: {
  kind: PushKind;
  language: PushLanguage;
  discreet: boolean;
  partnerName?: string;
  streakCount?: number;
}): PushPayload {
  if (input.discreet) {
    return { title: APP_NAME, body: DISCREET_BODY[input.language] };
  }
  switch (input.kind) {
    case 'partnerAnswered':
      return partnerAnsweredNormal(input.language, input.partnerName);
    case 'reveal':
      return revealNormal(input.language);
    case 'streakAtRisk':
      return streakAtRiskNormal(input.language, input.streakCount);
    case 'dailyQuestion':
      // partnerName and streakCount are deliberately not forwarded: at 08:00
      // there is no partner action and no streak state worth announcing.
      return dailyQuestionNormal(input.language);
  }
}
