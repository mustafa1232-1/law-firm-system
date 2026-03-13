/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const DEFAULT_USER_SOURCE_TEXT_PATH = path.join(
  __dirname,
  '..',
  'tmp_personal_status_from_user_norm.txt',
);
const LAWS_SEED_PATH = path.join(__dirname, '..', 'data', 'public', 'laws.seed.json');

const USER_SOURCE_URL =
  'https://www.cawtarclearinghouse.org/storage/4232/%D9%82%D8%A7%D9%86%D9%88%D9%86-%D8%A7%D9%84%D8%A7%D8%AD%D9%88%D8%A7%D9%84-%D8%A7%D9%84%D8%B4%D8%AE%D8%B5%D9%8A%D8%A9-%D9%84%D8%B9%D8%A7%D9%85-1959.pdf';

function ensureFileExists(filePath, name) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`${name} not found: ${filePath}`);
  }
}

function resolveArg(flag, fallback) {
  const index = process.argv.indexOf(flag);
  if (index === -1 || index + 1 >= process.argv.length) {
    return fallback;
  }

  return process.argv[index + 1];
}

function normalizeWhitespace(value) {
  return `${value ?? ''}`
    .replace(/\u00a0/g, ' ')
    .replace(/\u200f/g, '')
    .replace(/\u200e/g, '')
    .replace(/\r/g, '\n')
    .replace(/[ \t]+/g, ' ')
    .replace(/[ \t]*\n[ \t]*/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function extractHeadings(text) {
  const headingMatches = text.matchAll(/(?:المادة|ألمادة|ادة)\s*([^:\n]{1,140})\s*[:：]/g);
  return Array.from(headingMatches, (match) => ({
    label: match[1]
      .replace(/\s+/g, ' ')
      .replace(/\s+و\s+/g, ' و ')
      .trim(),
    headingStart: match.index,
    headingLength: match[0].length,
  }));
}

function isNoiseLine(line) {
  const compact = line.replace(/\s+/g, ' ').trim();
  if (!compact) {
    return true;
  }

  if (/^\d+$/.test(compact)) {
    return true;
  }

  return (
    /^قانون الاحوال الشخصية لعام\s*1959$/u.test(compact) ||
    /^قانون الأحوال الشخصية$/u.test(compact) ||
    /^رقم\s*188.*1959.*$/u.test(compact) ||
    /^وتعديلاته$/u.test(compact) ||
    /^قانون$/u.test(compact) ||
    /^الباب\s+/u.test(compact) ||
    /^الفصل\s+/u.test(compact) ||
    /^الأحكام العامة$/u.test(compact) ||
    /^الأحكام الختامية$/u.test(compact)
  );
}

function splitInlineList(value) {
  const prepared = value
    .replace(/\s+(?=(?:\d+\s*[-–—]))/g, '\n')
    .replace(/\s+(?=(?:[أ-ي]\s*[-–—]))/g, '\n')
    .replace(
      /\s+(?=(?:أولا|اولا|أولاً|ثانيا|ثانياً|ثالثا|ثالثاً|رابعا|رابعاً|خامسا|خامساً|سادسا|سادساً|سابعا|سابعاً|ثامنا|ثامناً|تاسعا|تاسعاً|عاشرا|عاشراً)\s*[:\-])/gu,
      '\n',
    );

  return prepared
    .split('\n')
    .map((part) => part.trim())
    .filter(Boolean);
}

function cleanArticleBody(rawBody) {
  const normalized = normalizeWhitespace(rawBody)
    .replace(/كتب ببغداد[\s\S]*$/u, '')
    .replace(/الأسباب الموجبة[\s\S]*$/u, '')
    .trim();
  if (!normalized) {
    return { text: '', paragraphs: [] };
  }

  const lines = normalized
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => !isNoiseLine(line));

  const markerRegex =
    /^(?:\d+\s*[-–—]|[أ-ي]\s*[-–—]|(?:أولا|اولا|أولاً|ثانيا|ثانياً|ثالثا|ثالثاً|رابعا|رابعاً|خامسا|خامساً|سادسا|سادساً|سابعا|سابعاً|ثامنا|ثامناً|تاسعا|تاسعاً|عاشرا|عاشراً)\s*[:\-])/u;

  const merged = [];
  let current = '';

  for (const line of lines) {
    if (markerRegex.test(line)) {
      if (current) {
        merged.push(current.trim());
      }
      current = line;
      continue;
    }

    if (!current) {
      current = line;
      continue;
    }

    if (/[.؟!؛:]\s*$/u.test(current)) {
      merged.push(current.trim());
      current = line;
      continue;
    }

    current = `${current} ${line}`.trim();
  }

  if (current) {
    merged.push(current.trim());
  }

  const baseParagraphs = merged.length
    ? merged
    : lines.length
      ? lines
      : splitInlineList(normalized);

  const paragraphs = [];
  for (const paragraph of baseParagraphs) {
    const expanded = splitInlineList(paragraph);
    if (expanded.length > 1) {
      paragraphs.push(...expanded);
    } else {
      paragraphs.push(paragraph.trim());
    }
  }

  const finalParagraphs = paragraphs
    .map((entry) =>
      entry
        .replace(/\s+في أحكام الميراث\s+/gu, ' ')
        .replace(/\s+(?:س|ص)ة\s+والعشرون\s*$/u, '')
        .replace(/\s+/g, ' ')
        .trim(),
    )
    .filter(Boolean);

  return {
    text: finalParagraphs.join('\n'),
    paragraphs: finalParagraphs,
  };
}

function main() {
  const sourcePath = resolveArg('--input', DEFAULT_USER_SOURCE_TEXT_PATH);
  ensureFileExists(sourcePath, 'Personal status source text');
  ensureFileExists(LAWS_SEED_PATH, 'Laws seed');

  const sourceText = fs.readFileSync(sourcePath, 'utf8');
  const lawsSeed = JSON.parse(fs.readFileSync(LAWS_SEED_PATH, 'utf8'));

  const extractedHeadings = extractHeadings(sourceText);
  if (extractedHeadings.length !== 94) {
    throw new Error(`Expected 94 extracted article headings, got ${extractedHeadings.length}`);
  }

  const headingEntries = extractedHeadings.map((heading, index) => ({
    articleOrder: index + 1,
    articleNumber: String(index + 1),
    label: heading.label,
    headingStart: heading.headingStart,
    headingLength: heading.headingLength,
  }));

  const articles = headingEntries.map((heading, index) => {
    const start = heading.headingStart + heading.headingLength;
    const end =
      index < headingEntries.length - 1
        ? headingEntries[index + 1].headingStart
        : sourceText.length;

    const body = sourceText.slice(start, end);
    const cleaned = cleanArticleBody(body);

    if (!cleaned.text) {
      throw new Error(`Empty text extracted for article ${heading.articleNumber}`);
    }

    return {
      articleNumber: heading.articleNumber,
      articleOrder: heading.articleOrder,
      text: cleaned.text,
      paragraphs: cleaned.paragraphs,
      keywords: [],
    };
  });

  const personalStatusLaw = lawsSeed.find((entry) => entry?.document?.lawNumber === '188');
  if (!personalStatusLaw) {
    throw new Error('Could not find lawNumber=188 in laws.seed.json');
  }

  personalStatusLaw.document = {
    ...personalStatusLaw.document,
    title: 'قانون الأحوال الشخصية العراقي رقم 188 لسنة 1959',
    lawNumber: '188',
    year: 1959,
    issuingBody: personalStatusLaw.document.issuingBody ?? 'مجلس السيادة',
    legalDomain: 'أحوال شخصية',
    sourceName: 'cawtarclearinghouse.org',
    sourceUrl: USER_SOURCE_URL,
  };

  personalStatusLaw.articles = articles;

  fs.writeFileSync(LAWS_SEED_PATH, `${JSON.stringify(lawsSeed, null, 2)}\n`, 'utf8');

  console.log(
    JSON.stringify(
      {
        lawNumber: '188',
        source: USER_SOURCE_URL,
        sourceTextPath: sourcePath,
        articles: articles.length,
        minParagraphs: Math.min(...articles.map((item) => item.paragraphs.length)),
        maxParagraphs: Math.max(...articles.map((item) => item.paragraphs.length)),
        firstArticlePreview: articles[0].text.slice(0, 180),
        article83Preview: articles[82].text.slice(0, 180),
        article85Preview: articles[84].text.slice(0, 180),
        lastArticlePreview: articles[articles.length - 1].text.slice(0, 180),
      },
      null,
      2,
    ),
  );
}

main();
