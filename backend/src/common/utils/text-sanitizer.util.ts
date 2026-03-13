const MOJIBAKE_MARKERS = /[�]|�\?|ï»¿|â€|â€”/;
const SUSPICIOUS_LATIN_GARBAGE = /[ÃÂÐØÙï]/g;

export function isLikelyCorruptedText(value?: string | null): boolean {
  const text = `${value ?? ''}`.trim();
  if (!text) {
    return false;
  }

  if (MOJIBAKE_MARKERS.test(text)) {
    return true;
  }

  if (/\?{3,}/.test(text)) {
    return true;
  }

  const suspiciousCharCount = (text.match(SUSPICIOUS_LATIN_GARBAGE) ?? []).length;
  if (suspiciousCharCount >= 2 && !/[A-Za-z]/.test(text)) {
    return true;
  }

  return false;
}

export function sanitizeHumanText(
  value?: string | null,
  fallback?: string | null,
): string | undefined {
  const normalized = `${value ?? ''}`
    .replace(/\u200f|\u200e|\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (normalized && !isLikelyCorruptedText(normalized)) {
    return normalized;
  }

  const normalizedFallback = `${fallback ?? ''}`
    .replace(/\u200f|\u200e|\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (normalizedFallback && !isLikelyCorruptedText(normalizedFallback)) {
    return normalizedFallback;
  }

  return undefined;
}

export function sanitizeStringArray(values: unknown): string[] {
  if (!Array.isArray(values)) {
    return [];
  }

  return values
    .map((entry) => sanitizeHumanText(`${entry ?? ''}`))
    .filter((entry): entry is string => Boolean(entry));
}

export function sanitizeLooseObject(
  value: Record<string, unknown> | null | undefined,
): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }

  const output: Record<string, unknown> = {};
  for (const [key, rawValue] of Object.entries(value)) {
    if (rawValue == null) {
      continue;
    }

    if (typeof rawValue === 'string') {
      const sanitized = sanitizeHumanText(rawValue);
      if (sanitized) {
        output[key] = sanitized;
      }
      continue;
    }

    output[key] = rawValue;
  }

  return output;
}
