const arabicDiacritics = /[\u0610-\u061A\u064B-\u065F\u06D6-\u06ED]/g;

export function normalizeArabic(input: string): string {
  const value = input ?? '';

  return value
    .replace(arabicDiacritics, '')
    .replace(/[\u0625\u0623\u0622\u0627]/g, '\u0627') // all alef forms -> alef
    .replace(/\u0649/g, '\u064A') // alef maqsura -> ya
    .replace(/\u0624/g, '\u0648') // waw hamza -> waw
    .replace(/\u0626/g, '\u064A') // ya hamza -> ya
    .replace(/\u0629/g, '\u0647') // ta marbuta -> ha
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}
