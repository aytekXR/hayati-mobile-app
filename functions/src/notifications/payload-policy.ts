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
//   - kind: which event (all three localized in TR/AR/EN by the RECIPIENT's
//     users.contentLanguage, resolved upstream in recipients.ts).
//   - discreet: when ON, the payload is fully generic — no partner name, no
//     event specifics, no streak digits, title is the app name only. Default is
//     ON in the AR locale (F6); see resolveDiscreet.

export type PushKind = 'partnerAnswered' | 'reveal' | 'streakAtRisk';
export type PushLanguage = 'tr' | 'ar' | 'en';

export interface PushPayload {
  title: string;
  body: string;
}

// The neutral title used in EVERY discreet payload — "the app name at most"
// (ADR-012). Kept latin across all three languages so a shoulder-surfed lock
// screen reveals nothing about the app's nature; "Hayati" reads as any app name.
const APP_NAME = 'Hayati';

// Discreet body: identical regardless of kind, name, or streak — the whole point
// is that NO event specific leaks. "Something is waiting" and nothing more.
const DISCREET_BODY: Record<PushLanguage, string> = {
  en: 'Something is waiting for you in Hayati.',
  tr: 'Hayati\'de seni bekleyen bir şey var.',
  ar: 'هناك ما ينتظرك في Hayati.',
};

// partnerAnswered fires only POST-first-answer, to the member who has not
// answered (ADR-012 / M3.3 handoff): naming the partner and saying "answered" in
// NORMAL mode is deliberate and permitted — it is a push, never a loosened read
// rule, and it exposes no answer content. partnerName sits in SUBJECT position in
// all three languages (no possessive/case suffix attaches to it), so an arbitrary
// name interpolates cleanly; AR uses a masculine-default verb for a named third
// party, matching the shipped `دعاك {name}` precedent (invitePreviewInvitedBy).
function partnerAnsweredNormal(language: PushLanguage, partnerName?: string): PushPayload {
  const name = partnerName?.trim();
  if (name) {
    switch (language) {
      case 'en':
        return { title: `${name} answered`, body: `${name} answered today's question. Open Hayati to add yours.` };
      case 'tr':
        return { title: `${name} cevapladı`, body: `${name} bugünün sorusunu cevapladı. Hayati'de sen de cevapla.` };
      case 'ar':
        return { title: `أجاب ${name}`, body: `أجاب ${name} عن سؤال اليوم. افتح Hayati وأضف إجابتك.` };
    }
  }
  // Degrade gracefully when no partner name resolved — name-free copy, never an
  // 'undefined' interpolation (M3.4 rule).
  switch (language) {
    case 'en':
      return { title: 'Your partner answered', body: `Your partner answered today's question. Open Hayati to add yours.` };
    case 'tr':
      return { title: 'Partnerin cevapladı', body: 'Partnerin bugünün sorusunu cevapladı. Hayati\'de sen de cevapla.' };
    case 'ar':
      return { title: 'أجاب شريكك', body: 'أجاب شريكك عن سؤال اليوم. افتح Hayati وأضف إجابتك.' };
  }
}

// reveal fires to the FIRST answerer once both have answered (ADR-012): the day
// is complete and both answers are now mutually visible. Name-free by design —
// the partner's answer is referenced ("read it together"), its text never is.
function revealNormal(language: PushLanguage): PushPayload {
  switch (language) {
    case 'en':
      return { title: 'You both answered', body: `You both answered today's question. Open Hayati to read it together.` };
    case 'tr':
      return { title: 'İkiniz de cevapladınız', body: 'Bugünün sorusunu ikiniz de cevapladınız. Partnerinin cevabını görmek için Hayati\'yi aç.' };
    case 'ar':
      return { title: 'أجبتما كلاكما', body: 'أجبتما عن سؤال اليوم. افتح Hayati لتقرآ إجابتيكما معًا.' };
  }
}

// streakAtRisk is the hour-20 sweep push (ADR-012) to a couple with count > 0
// whose day is still unrevealed. INVITATIONAL, never shaming (brandkit §8). The
// count is degraded to a count-free variant when the caller passes no positive
// streak, so 'undefined' never reaches the copy. AR numeral-noun agreement is
// approximated with the tamyiz (accusative) form `يومًا`, the single form that
// reads acceptably across counts in app microcopy; revisit with native review.
function streakAtRiskNormal(language: PushLanguage, streakCount?: number): PushPayload {
  const count =
    typeof streakCount === 'number' && Number.isFinite(streakCount) && streakCount > 0
      ? Math.floor(streakCount)
      : undefined;
  if (count !== undefined) {
    switch (language) {
      case 'en':
        return { title: 'Keep your streak going', body: `You're on a ${count}-day streak together. Answer today's question in Hayati before midnight to keep it.` };
      case 'tr':
        return { title: 'Serinizi sürdürün', body: `${count} günlük seriniz sürüyor. Gece yarısından önce Hayati'de bugünün sorusunu cevaplayıp devam ettirin.` };
      case 'ar':
        return { title: 'حافِظا على تتابعكما', body: `تتابعكما بلغ ${count} يومًا. أجيبا عن سؤال اليوم في Hayati قبل منتصف الليل لتحافظا عليه.` };
    }
  }
  switch (language) {
    case 'en':
      return { title: 'Keep your streak going', body: `Your streak together is still alive. Answer today's question in Hayati before midnight to keep it.` };
    case 'tr':
      return { title: 'Serinizi sürdürün', body: 'Seriniz hâlâ sürüyor. Gece yarısından önce Hayati\'de bugünün sorusunu cevaplayıp devam ettirin.' };
    case 'ar':
      return { title: 'حافِظا على تتابعكما', body: 'تتابعكما ما زال مستمرًا. أجيبا عن سؤال اليوم في Hayati قبل منتصف الليل لتحافظا عليه.' };
  }
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
  }
}
