// Static, localized help-path copy for the M5.1 coach safety spine (ADR-016
// Decision 4). The help path is STATIC content, never model output — the
// provider is never called on a crisis hit. Brandkit voice (frontend-brandkit.md
// §8): warm, direct, a considerate friend — never clinical, never guilt ("we are
// not therapy"). Localized TR/AR/EN with EN as the fallback for a junk/unknown
// language field.
//
// The "not therapy" DISCLAIMER moved to the app's ARB files (ADR-017 Decision 4,
// ADR-010 single-home spirit): the M5.2 UI is its only consumer, and two
// AI-drafted homes for one safety string would drift through native review. The
// `disclaimer()` export + DISCLAIMER table were removed in that same commit; the
// no-phone-number hard rule survives app-side over the `coach*` ARB values.
//
// ⚠️ nativeReview: PENDING — this copy is AI-DRAFTED; founder native review is
// flagged (same operator gate as the lexicon, ADR-016).
//
// HARD RULE (ADR-016 Decision 4): NO specific hotline phone numbers ship in this
// slice — a wrong or stale crisis number is actively dangerous. The copy names
// the universal route ("your local emergency number") in words; a country-verified
// numbers table is a founder-verified operator addition, not shipped here. The
// unit suite asserts no phone-number-shaped digit run is present.

import { CoachLanguage } from './provider-port';

/** The known coach languages, plus the EN fallback for anything else. */
const HELP_LANGUAGES: readonly CoachLanguage[] = ['tr', 'ar', 'en'];

/**
 * Narrow an untrusted language field to a known coach language, falling back to
 * EN (Decision 4). Accepts `unknown` so a junk client value routes to the
 * fallback instead of throwing.
 */
function resolveLanguage(language: unknown): CoachLanguage {
  return typeof language === 'string' && (HELP_LANGUAGES as readonly string[]).includes(language)
    ? (language as CoachLanguage)
    : 'en';
}

const HELP_RESPONSE: Readonly<Record<CoachLanguage, string>> = {
  en:
    "It sounds like you're carrying something really heavy right now, and I'm glad you " +
    "said it out loud. This is bigger than I can hold with you here. Please reach out " +
    'to your local emergency number, or to someone trained to help, right away — a doctor, ' +
    'a mental-health professional, or a crisis line in your country. If you can, tell ' +
    "someone you trust what you're going through, and let them stay with you. You matter, " +
    "and you don't have to carry this alone.",
  tr:
    'Şu anda çok ağır bir şey taşıyor gibisin ve bunu söyleyebildiğine sevindim. Bu, ' +
    'burada seninle birlikte taşıyabileceğimden daha büyük. Lütfen hemen yerel acil ' +
    'yardım numaranı ara ya da yardım edebilecek birine ulaş — bir doktor, bir ruh ' +
    'sağlığı uzmanı ya da ülkendeki bir kriz destek hattı. Mümkünse güvendiğin birine ' +
    'neler yaşadığını anlat ve yanında kalmasını iste. Sen değerlisin ve bunu tek başına ' +
    'taşımak zorunda değilsin.',
  ar:
    'يبدو أنك تحمل شيئًا ثقيلًا جدًا الآن، وأنا سعيد لأنك قلته بصوت عالٍ. هذا أكبر مما ' +
    'أستطيع أن أحمله معك هنا. أرجوك تواصل فورًا مع رقم الطوارئ المحلي لديك، أو مع شخص ' +
    'مؤهل لمساعدتك — طبيب، أو مختص في الصحة النفسية، أو خط دعم للأزمات في بلدك. وإن ' +
    'استطعت، أخبر شخصًا تثق به بما تمر به، ودعه يبقى بجانبك. أنت مهم، ولست مضطرًا أن ' +
    'تحمل هذا وحدك.',
};

/**
 * The static help-path text for a (possibly junk) language field — the response
 * returned on ANY crisis hit (pre- or post-filter). EN on fallback.
 */
export function helpResponse(language: unknown): string {
  return HELP_RESPONSE[resolveLanguage(language)];
}
