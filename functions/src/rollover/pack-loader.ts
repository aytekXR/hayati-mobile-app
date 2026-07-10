// Question-pack consumption edge for the M3.2 rollover (ADR-011). The build
// bundles content/packs/ into lib/content/packs/ (scripts/bundle-packs.mjs),
// and this module reads + strictly parses a pack from there. The validator
// (content/validator/) remains the single content GATE — CI has already
// proven every bundled pack — so this parser is defense-in-depth at the
// consumption point, mirroring the app's loud questionPackFromJson
// (question_pack_dto.dart): any deviation from
// content/schema/question-pack.schema.json throws, nothing is coerced.
import { readFileSync } from 'node:fs';
import * as path from 'node:path';

export const PACK_LOCALES = ['tr', 'ar', 'en'] as const;
export const PACK_REGISTERS = ['playful', 'respectful', 'msa_gulf', 'neutral'] as const;
export const QUESTION_CATEGORIES = ['fun', 'deep', 'memories', 'future', 'gratitude'] as const;

export type PackLocale = (typeof PACK_LOCALES)[number];
export type PackRegister = (typeof PACK_REGISTERS)[number];
export type QuestionCategory = (typeof QUESTION_CATEGORIES)[number];

export interface Question {
  readonly id: string;
  readonly category: QuestionCategory;
  readonly depth: number;
  readonly text: string;
  /** Verbatim seasonal tag (e.g. 'ramadan'); undefined = evergreen. */
  readonly seasonalWindow: string | undefined;
}

export interface QuestionPack {
  readonly packId: string;
  readonly version: number;
  readonly locale: PackLocale;
  readonly register: PackRegister;
  readonly questions: readonly Question[];
}

/** A pack file exists but its content violates the pack schema. */
export class PackParseError extends Error {
  constructor(source: string, detail: string) {
    super(`question pack ${source}: ${detail}`);
    this.name = 'PackParseError';
  }
}

/** No bundled pack file exists for the requested packId. */
export class UnknownPackError extends Error {
  constructor(packId: string, packsDir: string) {
    super(`no bundled question pack '${packId}' under ${packsDir}`);
    this.name = 'UnknownPackError';
  }
}

const ID_PATTERN = /^[a-z0-9_]+$/;
const PACK_FIELDS = new Set(['packId', 'version', 'locale', 'register', 'reviewedBy', 'questions']);
const QUESTION_FIELDS = new Set(['id', 'category', 'depth', 'text', 'seasonalWindow']);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function parseQuestion(value: unknown, index: number, source: string): Question {
  if (!isRecord(value)) {
    throw new PackParseError(source, `questions[${index}] is not a JSON object`);
  }
  for (const key of Object.keys(value)) {
    if (!QUESTION_FIELDS.has(key)) {
      throw new PackParseError(source, `unknown question field '${key}' at questions[${index}]`);
    }
  }
  const { id, category, depth, text, seasonalWindow } = value;
  if (typeof id !== 'string' || !ID_PATTERN.test(id)) {
    throw new PackParseError(source, `bad question id at questions[${index}]`);
  }
  if (typeof category !== 'string' || !(QUESTION_CATEGORIES as readonly string[]).includes(category)) {
    throw new PackParseError(source, `bad category for question '${id}'`);
  }
  if (typeof depth !== 'number' || !Number.isInteger(depth) || depth < 1 || depth > 5) {
    throw new PackParseError(source, `bad depth for question '${id}' (integer 1..5 required)`);
  }
  if (typeof text !== 'string' || text.length === 0) {
    throw new PackParseError(source, `bad text for question '${id}'`);
  }
  if (seasonalWindow !== undefined && (typeof seasonalWindow !== 'string' || seasonalWindow.length === 0)) {
    throw new PackParseError(source, `bad seasonalWindow for question '${id}'`);
  }
  return {
    id,
    category: category as QuestionCategory,
    depth,
    text,
    seasonalWindow: seasonalWindow as string | undefined,
  };
}

/** Strictly parses one pack JSON value; throws PackParseError on any deviation. */
export function parseQuestionPack(value: unknown, source: string): QuestionPack {
  if (!isRecord(value)) {
    throw new PackParseError(source, 'root is not a JSON object');
  }
  for (const key of Object.keys(value)) {
    if (!PACK_FIELDS.has(key)) {
      throw new PackParseError(source, `unknown pack field '${key}'`);
    }
  }
  const { packId, version, locale, register, reviewedBy, questions } = value;
  if (typeof packId !== 'string' || !ID_PATTERN.test(packId)) {
    throw new PackParseError(source, 'bad packId');
  }
  if (typeof version !== 'number' || !Number.isInteger(version) || version < 1) {
    throw new PackParseError(source, 'bad version (integer >= 1 required)');
  }
  if (typeof locale !== 'string' || !(PACK_LOCALES as readonly string[]).includes(locale)) {
    throw new PackParseError(source, 'bad locale');
  }
  if (typeof register !== 'string' || !(PACK_REGISTERS as readonly string[]).includes(register)) {
    throw new PackParseError(source, 'bad register');
  }
  if (reviewedBy !== undefined && typeof reviewedBy !== 'string') {
    throw new PackParseError(source, 'bad reviewedBy');
  }
  if (!Array.isArray(questions) || questions.length === 0) {
    throw new PackParseError(source, 'bad questions (non-empty array required)');
  }
  const parsed = questions.map((question, index) => parseQuestion(question, index, source));
  const seen = new Set<string>();
  for (const question of parsed) {
    if (seen.has(question.id)) {
      throw new PackParseError(source, `duplicate question id '${question.id}'`);
    }
    seen.add(question.id);
  }
  return {
    packId,
    version,
    locale: locale as PackLocale,
    register: register as PackRegister,
    questions: parsed,
  };
}

/**
 * The bundled packs directory produced by scripts/bundle-packs.mjs at build
 * time: <functions root>/lib/content/packs. Resolved from the functions root
 * (two levels above this module) rather than the module's own tree so the
 * SAME path works compiled (lib/rollover/../../lib/content/packs) and under
 * vitest (src/rollover/../../lib/content/packs) — the suite always runs
 * after a build (the functions emulator require()s lib/index.js).
 */
export function bundledPacksDir(): string {
  return path.join(__dirname, '..', '..', 'lib', 'content', 'packs');
}

/** Reads and strictly parses the pack `<packsDir>/<packId>.json`. */
export function loadQuestionPack(packId: string, packsDir = bundledPacksDir()): QuestionPack {
  const source = `${packId}.json`;
  let raw: string;
  try {
    raw = readFileSync(path.join(packsDir, source), 'utf8');
  } catch {
    throw new UnknownPackError(packId, packsDir);
  }
  let json: unknown;
  try {
    json = JSON.parse(raw);
  } catch {
    throw new PackParseError(source, 'invalid JSON');
  }
  const pack = parseQuestionPack(json, source);
  if (pack.packId !== packId) {
    throw new PackParseError(source, `declares packId '${pack.packId}' (filename contract broken)`);
  }
  return pack;
}
