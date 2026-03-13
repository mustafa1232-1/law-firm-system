/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const PAGE_PATH = path.join(__dirname, '..', 'tmp_civil_code_page.html');
const LAWS_SEED_PATH = path.join(__dirname, '..', 'data', 'public', 'laws.seed.json');

function decodeHtmlEntities(value) {
  return value
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/&#([0-9]+);/g, (_, dec) => String.fromCharCode(parseInt(dec, 10)))
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function normalizeDigits(value) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const easternArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
  return value
    .replace(/[٠-٩]/g, (digit) => String(arabicIndic.indexOf(digit)))
    .replace(/[۰-۹]/g, (digit) => String(easternArabicIndic.indexOf(digit)));
}

function normalizeWhitespace(value) {
  return value
    .replace(/\u00a0/g, ' ')
    .replace(/\u200f/g, '')
    .replace(/\u200e/g, '')
    .replace(/\r/g, '')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function cleanArticleText(value) {
  return normalizeWhitespace(
    value
      .replace(/^[:：\-\s]+/, '')
      .replace(/^مادة\s+\d+\s*/g, '')
      .replace(/^المادة\s*\(\d+\)\s*/g, ''),
  );
}

function splitParagraphs(text) {
  const prepared = normalizeWhitespace(
    text
      .replace(/(?<!^)\s+(?=(?:\d+)\s*[–-]\s+)/g, '\n')
      .replace(/(?<!^)\s+(?=(?:[أ-ي])\s*[–-]\s+)/g, '\n')
      .replace(
        /(?<!^)\s+(?=(?:أولاً|ثانياً|ثالثاً|رابعاً|خامساً|سادساً|سابعاً|ثامناً|تاسعاً|عاشراً)\s*[:\-])/g,
        '\n',
      ),
  );

  const lines = prepared
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean);

  return lines.length ? lines : [text.trim()];
}

function extractArticleTextByNumber(html) {
  const normalizedHtml = normalizeDigits(html);
  const bodyStartMarker = "<div class='post-body iPostBody' id='post-body'>";
  const bodyEndMarker = '<script>iqraaTOC();</script>';

  const bodyStart = normalizedHtml.indexOf(bodyStartMarker);
  const bodyEnd = normalizedHtml.indexOf(bodyEndMarker, bodyStart + bodyStartMarker.length);

  let sliced;
  if (bodyStart !== -1 && bodyEnd !== -1) {
    sliced = normalizedHtml.slice(bodyStart + bodyStartMarker.length, bodyEnd);
  } else {
    const start = normalizedHtml.indexOf('المادة (1)');
    const end = normalizedHtml.lastIndexOf('المادة (1383)');
    if (start === -1 || end === -1) {
      throw new Error('Could not find expected article boundaries المادة (1) .. المادة (1383)');
    }
    sliced = normalizedHtml.slice(start, end + 5000);
  }

  const text = normalizeWhitespace(
    normalizeDigits(
      decodeHtmlEntities(
      sliced
        .replace(/<br\s*\/?>/gi, '\n')
        .replace(/<[^>]+>/g, '\n'),
      ),
    ),
  );

  const matches = text.matchAll(
    /(?:المادة|مادة)\s*\(?\s*(\d{1,4})\s*\)?\s*([\s\S]*?)(?=(?:المادة|مادة)\s*\(?\s*\d{1,4}\s*\)?|$)/g,
  );
  const map = new Map();

  for (const match of matches) {
    const number = parseInt(match[1], 10);
    if (!Number.isFinite(number) || number < 1 || number > 1383) {
      continue;
    }

    const articleText = cleanArticleText(match[2]);
    if (!articleText) {
      continue;
    }

    const existing = map.get(number) || '';
    if (articleText.length > existing.length) {
      map.set(number, articleText);
    }
  }

  return map;
}

function ensureContinuity(articleMap, max = 1383) {
  const missing = [];
  const empty = [];
  for (let i = 1; i <= max; i += 1) {
    if (!articleMap.has(i)) {
      missing.push(i);
      continue;
    }
    if (!articleMap.get(i).trim()) {
      empty.push(i);
    }
  }

  if (missing.length || empty.length) {
    throw new Error(
      `Integrity check failed. Missing: ${missing.length}, Empty: ${empty.length}. ` +
        `Sample missing: ${missing.slice(0, 10).join(', ') || 'none'}`,
    );
  }
}

function buildArticles(articleMap, max = 1383) {
  const items = [];
  for (let i = 1; i <= max; i += 1) {
    const paragraphs = splitParagraphs(articleMap.get(i));
    const text = paragraphs.join('\n');

    items.push({
      articleNumber: String(i),
      articleOrder: i,
      text,
      paragraphs,
      keywords: [],
    });
  }
  return items;
}

function main() {
  if (!fs.existsSync(PAGE_PATH)) {
    throw new Error(`Source HTML not found: ${PAGE_PATH}`);
  }
  if (!fs.existsSync(LAWS_SEED_PATH)) {
    throw new Error(`Laws seed not found: ${LAWS_SEED_PATH}`);
  }

  const html = fs.readFileSync(PAGE_PATH, 'utf8');
  const articleMap = extractArticleTextByNumber(html);
  ensureContinuity(articleMap, 1383);
  const fullArticles = buildArticles(articleMap, 1383);

  const lawsSeed = JSON.parse(fs.readFileSync(LAWS_SEED_PATH, 'utf8'));
  if (!Array.isArray(lawsSeed)) {
    throw new Error('laws.seed.json must be an array');
  }

  const civilLaw = lawsSeed.find((entry) => entry?.document?.lawNumber === '40');
  if (!civilLaw) {
    throw new Error('Could not find lawNumber=40 in laws.seed.json');
  }

  civilLaw.document.title = 'القانون المدني العراقي رقم 40 لسنة 1951 المعدل';
  civilLaw.document.lawNumber = '40';
  civilLaw.document.year = 1951;
  civilLaw.document.legalDomain = 'مدني';
  civilLaw.document.sourceName = 'almashuora.com';
  civilLaw.document.sourceUrl =
    'https://almashuora.com/wp-content/uploads/2022/10/%D9%82%D8%A7%D9%86%D9%88%D9%86-%D9%85%D8%AF%D9%86%D9%8A.pdf';
  civilLaw.articles = fullArticles;

  fs.writeFileSync(LAWS_SEED_PATH, `${JSON.stringify(lawsSeed, null, 2)}\n`, 'utf8');

  const summary = {
    source: PAGE_PATH,
    target: LAWS_SEED_PATH,
    lawNumber: '40',
    articleCount: fullArticles.length,
    multiParagraphArticles: fullArticles.filter((item) => item.paragraphs.length > 1).length,
    firstArticlePreview: fullArticles[0].text.slice(0, 180),
    lastArticlePreview: fullArticles[fullArticles.length - 1].text.slice(0, 180),
  };

  console.log(JSON.stringify(summary, null, 2));
}

main();
