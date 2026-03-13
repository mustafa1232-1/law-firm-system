/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const SOURCE_URL = 'https://www.sjc.iq/view.77/';
const PDF_REFERENCE_URL =
  'https://mofa.gov.iq/wp-content/uploads/sites/85/2019/11/%D8%AF%D8%B3%D8%AA%D9%88%D8%B1-%D8%AC%D9%85%D9%87%D9%88%D8%B1%D9%8A%D8%A9-%D8%A7%D9%84%D8%B9%D8%B1%D8%A7%D9%82.pdf';
const OUTPUT_PATH = path.join(__dirname, '..', 'data', 'public', 'constitution_articles.seed.json');
const MANUAL_ARTICLE_TEXT_OVERRIDES = {
  '20': 'للمواطنين، رجالاً ونساءً حق المشاركة في الشؤون العامة، والتمتع بالحقوق السياسية بما فيها حق التصويت والانتخاب والترشيح.',
  '89': 'تتكون السلطة القضائية الاتحادية من مجلس القضاء الاعلى، والمحكمة الاتحادية العليا، ومحكمة التمييز الاتحادية، وجهاز الادعاء العام، وهيئة الاشراف القضائي، والمحاكم الاتحادية الاخرى التي تنظم وفقا للقانون.',
  '90': 'يتولى مجلس القضاء الاعلى إدارة شؤون الهيئات القضائية، وينظم القانون طريقة تكوينه واختصاصاته وقواعد سير العمل فيه.',
  '105':
    'تؤسس هيئة عامة لضمان حقوق الاقاليم والمحافظات غير المنتظمة في اقليم في المشاركة العادلة في إدارة مؤسسات الدولة الاتحادية المختلفة والبعثات والزمالات الدراسية والوفود والمؤتمرات الاقليمية والدولية وتتكون من ممثلي الحكومة الاتحادية والاقاليم والمحافظات غير المنتظمة في اقليم وتنظم بقانون.',
};

function decodeHtmlEntities(value) {
  return `${value ?? ''}`
    .replace(/&#(\d+);/g, (_, dec) => String.fromCodePoint(Number(dec)))
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'");
}

function normalizeLine(line) {
  return `${line ?? ''}`
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t]+/g, ' ')
    .replace(/\s+([،.؛:])/g, '$1')
    .trim();
}

function splitParagraphs(text) {
  const normalized = `${text ?? ''}`
    .split('\n')
    .map((line) => normalizeLine(line))
    .filter(Boolean);

  if (normalized.length > 1) {
    return normalized;
  }

  const oneLine = normalized[0] ?? '';
  if (!oneLine) {
    return [];
  }

  const items = oneLine
    .split(
      RegExp(
        '(?=\\b(?:اولا|أولا|اولاً|أولاً|ثانيا|ثانياً|ثالثا|ثالثاً|رابعا|رابعاً|خامسا|خامساً|سادسا|سادساً|سابعا|سابعاً|ثامنا|ثامناً|تاسعا|تاسعاً|عاشرا|عاشراً|أ|ب|ج|د|هـ)\\b\\s*(?:[:\\-ـ]|\\s))',
      ),
    )
    .map((entry) => normalizeLine(entry))
    .filter(Boolean);

  if (items.length > 1) {
    return items;
  }

  return oneLine
    .split(/(?<=[.؛])\s+/)
    .map((entry) => normalizeLine(entry))
    .filter(Boolean);
}

function articleOrder(articleNumber) {
  const parsed = Number(`${articleNumber ?? ''}`.replace(/[^\d]/g, ''));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

function parseConstitutionArticles(html) {
  const firstMarker = 'المادة (1)';
  const lastMarker = 'المادة (144)';
  const contentEndMarker = '<!-- Main Content END -->';
  const firstIndex = html.indexOf(firstMarker);
  const lastIndex = html.lastIndexOf(lastMarker);
  const contentEndIndex = html.indexOf(contentEndMarker, firstIndex);

  if (firstIndex === -1 || lastIndex === -1 || lastIndex <= firstIndex) {
    throw new Error('Unable to locate full constitution text markers in source page.');
  }

  const start = Math.max(0, firstIndex - 30000);
  const end = contentEndIndex > lastIndex ? contentEndIndex : Math.min(html.length, lastIndex + 4000);
  const articleSegment = html.slice(start, end);

  const plain = decodeHtmlEntities(
    articleSegment
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
      .replace(/<!--[\s\S]*?-->/g, ' ')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n')
      .replace(/<[^>]+>/g, ' '),
  );

  const normalizedPlain = plain
    .replace(/\r/g, '\n')
    .replace(/\n{3,}/g, '\n\n');

  const chapterPattern = /(?:^|\n)\s*(الباب\s+[^\n]+)\s*(?=\n|$)/g;
  const sectionPattern = /(?:^|\n)\s*((?:الفصل|الفرع)\s+[^\n]+)\s*(?=\n|$)/g;
  const articlePattern =
    /(?:^|\n)\s*المادة\s*\((\d{1,3})\)\s*[:：]?\s*([\s\S]*?)(?=(?:\n\s*المادة\s*\(\d{1,3}\)\s*[:：]?)|$)/g;

  const ignoredFragments = [
    'الديباجة',
    'بسم الله الرحمن الرحيم',
    'ولقد كرمنا بني آدم',
    '...',
    'اتصل بنا',
    'مجلس القضاء الاعلى',
    'جميع الحقوق محفوظة',
    'وسائل الاتصال',
    'وسائل التواصل',
    'مشاركة',
    'نسخ الرابط',
    'إغلاق',
    'تم نسخ الرابط',
    '©',
    'View all',
    'Previous',
    'Next',
    'Back to top',
  ];

  function findLastHeading(prefix, pattern) {
    let match;
    let last = null;
    pattern.lastIndex = 0;
    while ((match = pattern.exec(prefix)) !== null) {
      last = normalizeLine(match[1]);
    }
    return last;
  }

  const normalizedArticles = [];
  let articleMatch;
  while ((articleMatch = articlePattern.exec(normalizedPlain)) !== null) {
    const number = articleMatch[1];
    const rawBody = articleMatch[2] ?? '';
    const before = normalizedPlain.slice(0, articleMatch.index);
    const chapter = findLastHeading(before, chapterPattern);
    const section = findLastHeading(before, sectionPattern);

    const bodyLines = rawBody
      .split('\n')
      .map((line) => normalizeLine(line))
      .filter(Boolean)
      .filter((line) => !/^(?:الباب|الفصل|الفرع)\b/.test(line))
      .filter((line) => !ignoredFragments.some((fragment) => line.includes(fragment)));

    const textCandidate = bodyLines.join('\n').trim();
    const text = textCandidate || MANUAL_ARTICLE_TEXT_OVERRIDES[number] || '';
    const paragraphs = splitParagraphs(text);

    normalizedArticles.push({
      sourceName: 'مجلس القضاء الأعلى العراقي (نص قابل للبحث) + مرجع PDF رسمي: وزارة الخارجية العراقية',
      sourceUrl: PDF_REFERENCE_URL,
      sourceType: 'official-reference+public-web',
      articleNumber: number,
      articleOrder: articleOrder(number),
      title: null,
      chapter: chapter || null,
      section: section || null,
      text,
      paragraphs,
      keywords: [],
      linkedLawArticleIds: [],
      linkedDecisionIds: [],
    });
  }

  const filteredArticles = normalizedArticles
    .filter((item) => item.articleOrder >= 1 && item.articleOrder <= 144)
    .sort((a, b) => a.articleOrder - b.articleOrder);

  const unique = new Map();
  for (const article of filteredArticles) {
    unique.set(article.articleOrder, article);
  }
  const result = [...unique.values()].sort((a, b) => a.articleOrder - b.articleOrder);

  const emptyArticles = result.filter((item) => !item.text.trim()).map((item) => item.articleOrder);

  if (result.length !== 144) {
    const present = new Set(result.map((item) => item.articleOrder));
    const missing = [];
    for (let i = 1; i <= 144; i += 1) {
      if (!present.has(i)) {
        missing.push(i);
      }
    }
    throw new Error(
      `Constitution parsing did not produce all 144 articles. Found=${result.length}, Missing=${missing.join(', ')}`,
    );
  }

  if (emptyArticles.length) {
    throw new Error(`Constitution parsing produced empty text for articles: ${emptyArticles.join(', ')}`);
  }

  return result;
}

async function main() {
  const response = await fetch(SOURCE_URL, {
    headers: {
      'user-agent': 'LexIQ-Iraq-Constitution-Sync/1.0',
      accept: 'text/html,application/xhtml+xml',
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch source: ${response.status} ${response.statusText}`);
  }

  const html = await response.text();
  const constitutionArticles = parseConstitutionArticles(html);

  fs.writeFileSync(OUTPUT_PATH, `${JSON.stringify(constitutionArticles, null, 2)}\n`, 'utf8');

  const first = constitutionArticles[0];
  const last = constitutionArticles[constitutionArticles.length - 1];
  console.log(
    JSON.stringify(
      {
        ok: true,
        source: SOURCE_URL,
        output: OUTPUT_PATH,
        articles: constitutionArticles.length,
        firstArticle: first.articleNumber,
        lastArticle: last.articleNumber,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
