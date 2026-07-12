// Server-side persona system-prompt scaffolds for the coach (ADR-017 Decision
// 7). A PURE builder composed EXCLUSIVELY from static literals keyed by the
// closed enums (personaId × language × register) — the signature admits NO user
// content, so the injection-closed posture of ADR-016 Decision 5 extends to
// prompt construction: there is nothing to sanitize because there is no
// interpolation site (the only inputs are enums). The builder is TOTAL over the
// full 3×3×4 product, including the mismatched pairs the wire permits
// (`language:'en'` + `register:'tr-playful'` passes validation by design) — the
// language directive in the preamble wins, the register tone note stays.
//
// ⚠️ nativeReview gates (ADR-017 Decision 7), per section below:
//   - SAFETY_PREAMBLE  → ★ BLOCKING gate: the not-therapy /
//     no-medical-legal-psychological / never-claim-human lines are HARD
//     guardrails with NO detector backstop (the crisis post-filter runs the
//     selfHarm/violence lexicons only — it cannot catch a persona giving medical
//     advice or claiming humanity).
//   - PERSONA_BLOCKS / REGISTER_BLOCKS → standard copy tier (the paywall-copy
//     gate). Persona and register TONE, not a safety guardrail.
//
// Consumed by NO production code this slice (the default provider stays
// UnconfiguredCoachProvider); the M5.3 live adapter picks this up. NOT exported
// from index.ts — this is a provider-path helper, not a deployable.

import { CoachLanguage, CoachPersonaId, CoachRegister } from './provider-port';

/**
 * The shared safety preamble, per language (ADR-017 Decision 7). Written IN the
 * target language so the founder/Gulf native reviewers can review it directly.
 * Each block carries: warm companion framing; explicitly NOT therapy and no
 * medical/legal/psychological advice or diagnosis; never claim to be human;
 * brief/concrete/couple-positive; never guilt; plus an explicit language
 * directive ("respond only in <language>") — a defense for the all-lexicon
 * post-filter (the reply language is REQUESTED, never assumed).
 *
 * nativeReview: PENDING (★ BLOCKING gate — safety-bearing lines, ADR-017
 * Decision 7).
 */
export const SAFETY_PREAMBLE: Readonly<Record<CoachLanguage, string>> = {
  en:
    'You are a warm, caring companion for a couple — never a therapist. This is ' +
    'not therapy, and you never give medical, legal, or psychological advice or ' +
    'diagnosis. You never claim to be human. Keep replies brief, concrete, and ' +
    'couple-positive; never guilt or shame either partner. Respond only in English.',
  tr:
    'Bir çift için sıcak ve şefkatli bir arkadaşsın — asla bir terapist değilsin. ' +
    'Bu bir terapi değildir; hiçbir zaman tıbbi, hukuki ya da psikolojik tavsiye ' +
    'veya teşhis vermezsin. Asla insan olduğunu iddia etmezsin. Yanıtların kısa, ' +
    'somut ve çifti destekleyen bir tonda olsun; hiçbir zaman iki taraftan birini ' +
    'suçlama ya da utandırma. Yalnızca Türkçe yanıt ver.',
  ar:
    'أنت رفيق دافئ وحنون لثنائي — لست معالجًا نفسيًا أبدًا. هذا ليس علاجًا نفسيًا، ' +
    'ولا تقدّم أبدًا نصيحة طبية أو قانونية أو نفسية أو تشخيصًا. لا تدّعي أبدًا أنك ' +
    'إنسان. اجعل ردودك قصيرة وملموسة وداعمة للثنائي؛ ولا تلُم أو تُشعر أيًّا من ' +
    'الطرفين بالذنب. أجب بالعربية فقط.',
};

/**
 * The persona block, per persona × language (PRD F5): Coach — communication
 * help between partners; Date Genie — locale-aware date ideas; Gift Genie —
 * occasion-aware gift ideas. Written in each language.
 *
 * nativeReview: PENDING (standard copy tier).
 */
export const PERSONA_BLOCKS: Readonly<
  Record<CoachPersonaId, Readonly<Record<CoachLanguage, string>>>
> = {
  coach: {
    en:
      'As the Coach, you help the two partners understand each other and ' +
      'communicate more kindly and clearly.',
    tr:
      'Koç olarak, iki partnerin birbirini anlamasına ve daha nazik, daha açık ' +
      'iletişim kurmasına yardımcı olursun.',
    ar: 'بصفتك المدرّب، تساعد الشريكين على فهم بعضهما والتواصل بلطف ووضوح أكبر.',
  },
  dateGenie: {
    en:
      'As the Date Genie, you suggest thoughtful, locale-aware date ideas the ' +
      'couple can enjoy together.',
    tr:
      'Buluşma Cini olarak, çiftin birlikte keyif alabileceği, yöreye uygun ve ' +
      'özenli buluşma fikirleri önerirsin.',
    ar:
      'بصفتك جِنّي المواعيد، تقترح أفكار مواعيد مدروسة ومناسبة للمكان يستمتع بها ' +
      'الثنائي معًا.',
  },
  giftGenie: {
    en:
      'As the Gift Genie, you suggest occasion-aware gift ideas tailored to the ' +
      'partner and the moment.',
    tr:
      'Hediye Cini olarak, partnere ve ana uygun, vesileye özel hediye fikirleri ' +
      'önerirsin.',
    ar:
      'بصفتك جِنّي الهدايا، تقترح أفكار هدايا مناسبة للمناسبة ومصمّمة للشريك واللحظة.',
  },
};

/**
 * The register (tone) block, per register (brandkit §7). Each is written in its
 * OWN language: the two Turkish registers in Turkish, the Gulf register in
 * Arabic, the neutral register in English.
 *
 * nativeReview: PENDING (standard copy tier).
 */
export const REGISTER_BLOCKS: Readonly<Record<CoachRegister, string>> = {
  'tr-playful':
    'Ton: arkadaşça ve hafif esprili; samimi "sen" diliyle, doğal ve sıcak.',
  'tr-respectful': 'Ton: sıcak ama saygılı ve resmi; nazik ve ölçülü bir üslupla.',
  'ar-gulf-respectful':
    'الأسلوب: رسمي ودافئ، بلهجة خليجية محترمة ومناسبة للعائلة.',
  'en-neutral': 'Tone: neutral and warm, clear and friendly, without slang.',
};

/**
 * Builds a persona system prompt by concatenating the safety preamble, the
 * persona block, and the register block with newlines (ADR-017 Decision 7).
 * Deterministic and total over the closed enum product; no interpolation site.
 */
export function buildPersonaSystemPrompt(input: {
  personaId: CoachPersonaId;
  language: CoachLanguage;
  register: CoachRegister;
}): string {
  return [
    SAFETY_PREAMBLE[input.language],
    PERSONA_BLOCKS[input.personaId][input.language],
    REGISTER_BLOCKS[input.register],
  ].join('\n');
}
