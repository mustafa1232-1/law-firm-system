import { normalizeArabic } from './arabic-normalization.util';
import { escapeRegex } from './regex.util';

const STOP_WORDS = new Set([
  'في',
  'من',
  'على',
  'الى',
  'إلى',
  'عن',
  'مع',
  'هذا',
  'هذه',
  'ذلك',
  'التي',
  'الذي',
  'ال',
  'the',
  'and',
  'or',
  'for',
  'with',
  'from',
  'to',
  'a',
  'an',
]);

export interface SearchTerms {
  rawQuery: string;
  normalizedQuery: string;
  escapedRawQuery: string;
  escapedNormalizedQuery: string;
  rawTokens: string[];
  normalizedTokens: string[];
}

export function buildSearchTerms(input?: string | null): SearchTerms {
  const rawQuery = (input ?? '').trim();
  const normalizedQuery = normalizeArabic(rawQuery);

  return {
    rawQuery,
    normalizedQuery,
    escapedRawQuery: escapeRegex(rawQuery),
    escapedNormalizedQuery: escapeRegex(normalizedQuery),
    rawTokens: tokenize(rawQuery),
    normalizedTokens: tokenize(normalizedQuery),
  };
}

export function buildTokenRegexConditions(field: string, escapedTokens: string[]) {
  return escapedTokens.map((token) => ({
    [field]: { $regex: token, $options: 'i' },
  }));
}

function tokenize(value: string) {
  if (!value) {
    return [];
  }

  const tokens = value
    .split(/\s+/)
    .map((token) => token.replace(/[^\p{L}\p{N}]/gu, '').trim())
    .filter((token) => isUsefulToken(token))
    .slice(0, 8)
    .map((token) => escapeRegex(token));

  return Array.from(new Set(tokens));
}

function isUsefulToken(token: string) {
  if (!token) {
    return false;
  }

  const isNumber = /^\d+$/.test(token);
  if (isNumber) {
    return true;
  }

  if (token.length < 2) {
    return false;
  }

  return !STOP_WORDS.has(token.toLowerCase());
}
