// Seed crisis lexicons for the M5.1 coach safety spine (ADR-016 Decision 3).
//
// ⚠️ CONTENT WARNING: this file necessarily contains self-harm and
// partner-violence vocabulary in TR/AR/EN. Entries are kept MINIMAL and
// NON-GRAPHIC — enough to route a person in crisis to the professional-help
// path, never more.
//
// ⚠️ nativeReview: PENDING — BLOCKING before the coach ships to ANY device
// (ADR-016 Decision 3, operator-expected.md). These phrases are AI-DRAFTED. The
// TR list is gated on founder review; the AR list (BOTH the Arabic-script track
// AND the Arabizi/Franco-Arabic track) is gated on the Gulf-dialect native
// reviewer. ADR-007 (personal-use-first) lets the MECHANISM ship now; the
// lexicon QUALITY gate is human and native, and it is a release blocker.
//
// Design (ADR-016 Decision 3):
//   - Evasion resistance comes from NORMALIZATION (normalize.ts), never from
//     lexicon secrecy — this file is committed to a public repo BY DESIGN.
//   - Seeding is deliberately CONSERVATIVE (over-triggering): a missed crisis is
//     dangerous, a spurious help path merely costs a persona reply.
//   - `substring` entries match against both normalized forms and both leet
//     variants. `token` entries (the single per-entry concession to
//     false-positive control) match only as a whole-word run — used ONLY where a
//     substring seed would fire inside common benign words. Short, ambiguous
//     tokens that collide with a common benign word AFTER folding (e.g. TR "öl",
//     which the ç/ö-fold collapses onto the very common "ol" = "be!") are
//     deliberately OMITTED — their false-positive rate is unacceptable even
//     under the over-trigger posture.

export type CrisisCategory = 'selfHarm' | 'violence';
export type CrisisMatchMode = 'substring' | 'token';

export interface CrisisSeed {
  /** The seed phrase, in its natural script — normalized identically to input. */
  phrase: string;
  /** `substring` (default) or `token` (whole-word run only). */
  matchMode: CrisisMatchMode;
  category: CrisisCategory;
}

/** Turkish (Latin script). Founder native review pending. */
export const CRISIS_LEXICON_TR: readonly CrisisSeed[] = [
  { phrase: 'kendimi öldüreceğim', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'intihar', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'yaşamak istemiyorum', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'canıma kıyacağım', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'kendime zarar vereceğim', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'ölmek istiyorum', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'beni öldürecek', matchMode: 'substring', category: 'violence' },
  { phrase: 'beni dövüyor', matchMode: 'substring', category: 'violence' },
  { phrase: 'bana vuruyor', matchMode: 'substring', category: 'violence' },
];

/**
 * Arabic. TWO tracks, both gated on the Gulf-dialect native reviewer:
 *   1. Arabic-script entries (folded by normalize.ts's Arabic pipeline).
 *   2. ARABIZI (Franco-Arabic — Arabic written in Latin script with digit-letters
 *      3=ع, 7=ح, 5=خ). These stay UNFOLDED at match time (the leet fold is a
 *      separate variant), so a digit-letter seed keeps matching digit-letter input.
 */
export const CRISIS_LEXICON_AR: readonly CrisisSeed[] = [
  // --- Arabic script ---
  { phrase: 'انتحار', matchMode: 'substring', category: 'selfHarm' }, // suicide
  { phrase: 'سأقتل نفسي', matchMode: 'substring', category: 'selfHarm' }, // I will kill myself
  { phrase: 'أريد أن أموت', matchMode: 'substring', category: 'selfHarm' }, // I want to die
  { phrase: 'أؤذي نفسي', matchMode: 'substring', category: 'selfHarm' }, // I hurt myself
  { phrase: 'لا أريد أن أعيش', matchMode: 'substring', category: 'selfHarm' }, // I don't want to live
  { phrase: 'سيقتلني', matchMode: 'substring', category: 'violence' }, // he will kill me
  { phrase: 'يضربني', matchMode: 'substring', category: 'violence' }, // he beats me
  // --- ARABIZI (Latin-script Arabic; native review flagged) ---
  { phrase: '3ayez amout', matchMode: 'substring', category: 'selfHarm' }, // عايز أموت
  { phrase: 'abi amout', matchMode: 'substring', category: 'selfHarm' }, // أبي أموت (Gulf)
  { phrase: 'bidi mout', matchMode: 'substring', category: 'selfHarm' }, // بدي موت (Levantine)
  { phrase: 'aktol nafsi', matchMode: 'substring', category: 'selfHarm' }, // أقتل نفسي
  { phrase: 'entihar', matchMode: 'substring', category: 'selfHarm' }, // انتحار
];

/** English. */
export const CRISIS_LEXICON_EN: readonly CrisisSeed[] = [
  { phrase: 'kill myself', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'suicide', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'self harm', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'end my life', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'hurt myself', matchMode: 'substring', category: 'selfHarm' },
  { phrase: 'want to die', matchMode: 'substring', category: 'selfHarm' },
  // The one TOKEN entry: bare "die" as a substring would fire inside diet/died/
  // studied/soldier; token mode requires a whole-word run, so "die" and "d i e"
  // HIT while "diet"/"died" do not — the genuine, non-colliding token use case.
  { phrase: 'die', matchMode: 'token', category: 'selfHarm' },
  { phrase: 'he will kill me', matchMode: 'substring', category: 'violence' },
  { phrase: 'he beats me', matchMode: 'substring', category: 'violence' },
  { phrase: 'he hits me', matchMode: 'substring', category: 'violence' },
];

/** Every seed from all three languages (+ the Arabizi track), flattened. */
export const ALL_CRISIS_SEEDS: readonly CrisisSeed[] = [
  ...CRISIS_LEXICON_TR,
  ...CRISIS_LEXICON_AR,
  ...CRISIS_LEXICON_EN,
];
