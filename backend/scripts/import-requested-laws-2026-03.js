/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const LAWS_SEED_PATH = path.join(__dirname, '..', 'data', 'public', 'laws.seed.json');
const SOURCES_DIR = path.join(__dirname, '..', 'tmp_laws_sources');

const SOURCES = {
  penalHtml: path.join(SOURCES_DIR, 'penal-20706.html'),
  disciplineHtml: path.join(SOURCES_DIR, 'discipline-13754.html'),
  realEstateHtml: path.join(SOURCES_DIR, 'realestate-4937.html'),
  electionsText: path.join(SOURCES_DIR, 'elections4603.norm.txt'),
  militaryText: path.join(SOURCES_DIR, 'military-proc-4444.norm.txt'),
  treatiesText: path.join(SOURCES_DIR, 'treaties-article-2025.norm.txt'),
};

const URLS = {
  penal: 'https://www.rwi.uzh.ch/dam/jcr:00000000-0c03-6a0c-ffff-ffff96be3560/penalcode1969.pdf',
  discipline:
    'https://almashuora.com/wp-content/uploads/2022/10/%D9%82%D8%A7%D9%86%D9%88%D9%86-%D8%A7%D9%86%D8%B6%D8%A8%D8%A7%D8%B7-%D9%85%D9%88%D8%B8%D9%81%D9%8A-%D8%A7%D9%84%D8%AF%D9%88%D9%84%D8%A9.pdf',
  realEstate: 'https://wiki.dorar-aliraq.net/iraqilaws/law/4937.html',
  elections: 'https://moj.gov.iq/upload/pdf/4603.pdf',
  military: 'https://www.moj.gov.iq/upload/pdf/4444.pdf',
  treaties:
    'https://iasj.rdd.edu.iq/journals/uploads/2025/01/19/21c238a0e17b03f2ba803b9499e9b2be.pdf',
};

function ensureFileExists(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Source file not found: ${filePath}`);
  }
}

function decodeHtmlEntities(value) {
  return `${value ?? ''}`
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/&#([0-9]+);/g, (_, dec) => String.fromCharCode(parseInt(dec, 10)))
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function toLatinDigits(value) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const easternArabicIndic = '۰۱۲۳۴۵۶۷۸۹';

  return `${value ?? ''}`
    .replace(/[٠-٩]/g, (char) => String(arabicIndic.indexOf(char)))
    .replace(/[۰-۹]/g, (char) => String(easternArabicIndic.indexOf(char)));
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

function splitParagraphs(text) {
  const normalized = normalizeWhitespace(text);
  if (!normalized) {
    return [];
  }

  const prepared = normalized
    .replace(/\s+(?=(?:\d+)\s*[-–—])/g, '\n')
    .replace(/\s+(?=(?:[أ-ي])\s*[-–—])/g, '\n')
    .replace(
      /\s+(?=(?:أولا|اولا|أولاً|ثانيا|ثانياً|ثالثا|ثالثاً|رابعا|رابعاً|خامسا|خامساً|سادسا|سادساً|سابعا|سابعاً|ثامنا|ثامناً|تاسعا|تاسعاً|عاشرا|عاشراً)\s*[:\-])/gu,
      '\n',
    );

  return prepared
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean);
}

function shouldDropNoiseLine(line) {
  const value = line.trim();
  if (!value) {
    return true;
  }

  return (
    /^رقم التشريع\s*:/u.test(value) ||
    /^سنة التشريع\s*:/u.test(value) ||
    /^تاريخ التشريع\s*:/u.test(value) ||
    /^\d{4}-\d{2}-\d{2}/u.test(value) ||
    /^\(adsbygoogle/u.test(value) ||
    /^googletag/u.test(value) ||
    /^المحتوى\s+\d+/u.test(value) ||
    /^تشريعات وقوانين من/u.test(value) ||
    /^تصف.?ح المقالات/u.test(value) ||
    /^عودة الى الأعلى/u.test(value) ||
    /القوانين والتشريعات العراقية/u.test(value)
  );
}

function cleanBodyText(text) {
  const lines = normalizeWhitespace(text)
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => !shouldDropNoiseLine(line));

  return normalizeWhitespace(lines.join('\n'));
}

function htmlLawToArticles(html) {
  const bodyStartMarker = "<div class='post-body iPostBody' id='post-body'>";
  const bodyEndMarker = '<script>iqraaTOC();</script>';

  const bodyStart = html.indexOf(bodyStartMarker);
  const bodyEnd = html.indexOf(bodyEndMarker, bodyStart + bodyStartMarker.length);
  const sliced =
    bodyStart !== -1 && bodyEnd !== -1
      ? html.slice(bodyStart + bodyStartMarker.length, bodyEnd)
      : html;

  const text = normalizeWhitespace(
    toLatinDigits(
      decodeHtmlEntities(
        sliced
          .replace(/<br\s*\/?>/gi, '\n')
          .replace(/<[^>]+>/g, '\n'),
      ),
    ),
  );

  const lines = text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  const headingOnly = /^(?:المادة|مادة)\s*\(?\s*(\d{1,4})\s*\)?\s*[:：\-]?$/u;
  const headingInline =
    /^(?:المادة|مادة)\s*\(?\s*(\d{1,4})\s*\)?\s*[:：\-]\s*([\s\S]+)$/u;

  const markers = [];

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const inlineMatch = line.match(headingInline);
    if (inlineMatch) {
      markers.push({
        lineIndex: i,
        articleNumber: inlineMatch[1],
        initialText: inlineMatch[2].trim(),
      });
      continue;
    }

    const onlyMatch = line.match(headingOnly);
    if (onlyMatch) {
      markers.push({
        lineIndex: i,
        articleNumber: onlyMatch[1],
        initialText: '',
      });
    }
  }

  const articles = [];
  for (let i = 0; i < markers.length; i += 1) {
    const current = markers[i];
    const next = markers[i + 1];
    const start = current.lineIndex + 1;
    const end = next ? next.lineIndex : lines.length;

    const contentLines = [];
    if (current.initialText) {
      contentLines.push(current.initialText);
    }
    for (let j = start; j < end; j += 1) {
      contentLines.push(lines[j]);
    }

    const textBody = cleanBodyText(contentLines.join('\n'));
    if (!textBody) {
      continue;
    }

    const articleOrder = Number(current.articleNumber);
    if (!Number.isFinite(articleOrder) || articleOrder < 1) {
      continue;
    }

    const paragraphs = splitParagraphs(textBody);
    articles.push({
      articleNumber: String(articleOrder),
      articleOrder,
      text: paragraphs.length ? paragraphs.join('\n') : textBody,
      paragraphs: paragraphs.length ? paragraphs : [textBody],
      keywords: [],
    });
  }

  return articles;
}

function parseRawNumberToken(token) {
  const latin = toLatinDigits(token).replace(/[^\d]/g, '');
  if (!latin) {
    return [];
  }

  const options = new Set();
  options.add(Number(latin));
  if (latin.length > 1) {
    options.add(Number(latin.split('').reverse().join('')));
  }

  return Array.from(options).filter((n) => Number.isFinite(n) && n > 0 && n < 2000);
}

function chooseBestNumber(options, prev) {
  if (!options.length) {
    return null;
  }

  if (prev <= 0) {
    if (options.includes(1)) {
      return 1;
    }
    return Math.min(...options);
  }

  let best = null;
  let bestScore = Number.POSITIVE_INFINITY;

  for (const option of options) {
    if (option < prev) {
      continue;
    }

    const score = Math.abs(option - (prev + 1));
    if (score < bestScore) {
      bestScore = score;
      best = option;
    } else if (score === bestScore && best !== null && option < best) {
      best = option;
    }
  }

  if (best !== null) {
    return best;
  }

  return Math.max(...options);
}

function extractArticlesFromMaterialText(
  text,
  headingRegex,
  config = {
    breakOnResetAfter: 80,
    maxJump: 6,
  },
) {
  const matches = Array.from(text.matchAll(headingRegex)).map((match) => ({
    index: match.index ?? 0,
    headingLength: match[0].length,
    token: match[1] ?? '',
  }));

  if (!matches.length) {
    return [];
  }

  const accepted = [];
  let prev = 0;

  for (const item of matches) {
    const options = parseRawNumberToken(item.token);
    const chosen = chooseBestNumber(options, prev);
    if (!chosen) {
      continue;
    }

    if (chosen === prev) {
      continue;
    }

    if (chosen < prev) {
      if (prev >= config.breakOnResetAfter && chosen <= 5) {
        break;
      }
      continue;
    }

    if (prev > 0 && chosen - prev > config.maxJump) {
      continue;
    }

    accepted.push({
      articleNumber: String(chosen),
      articleOrder: chosen,
      start: item.index,
      headingLength: item.headingLength,
    });
    prev = chosen;
  }

  if (!accepted.length) {
    return [];
  }

  const uniqueByNumber = [];
  const seen = new Set();
  for (const item of accepted) {
    if (seen.has(item.articleOrder)) {
      continue;
    }
    seen.add(item.articleOrder);
    uniqueByNumber.push(item);
  }

  const articles = [];
  for (let i = 0; i < uniqueByNumber.length; i += 1) {
    const current = uniqueByNumber[i];
    const next = uniqueByNumber[i + 1];
    const start = current.start + current.headingLength;
    const end = next ? next.start : text.length;
    const body = normalizeWhitespace(text.slice(start, end));
    if (!body) {
      continue;
    }

    const paragraphs = splitParagraphs(body);
    articles.push({
      articleNumber: current.articleNumber,
      articleOrder: current.articleOrder,
      text: paragraphs.length ? paragraphs.join('\n') : body,
      paragraphs: paragraphs.length ? paragraphs : [body],
      keywords: [],
    });
  }

  return articles;
}

function chunkTextToArticles(text, chunkSize = 1200) {
  const cleaned = normalizeWhitespace(text)
    .replace(/\nمجلة\s*\nالعدد\/\d+\n/gu, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  const paragraphs = cleaned
    .split(/\n+/)
    .map((line) => line.trim())
    .filter((line) => line.length >= 20);

  const chunks = [];
  let current = '';
  for (const paragraph of paragraphs) {
    const next = current ? `${current}\n${paragraph}` : paragraph;
    if (next.length > chunkSize && current) {
      chunks.push(current);
      current = paragraph;
    } else {
      current = next;
    }
  }
  if (current) {
    chunks.push(current);
  }

  return chunks.map((chunk, index) => ({
    articleNumber: String(index + 1),
    articleOrder: index + 1,
    text: chunk,
    paragraphs: chunk.split('\n').map((line) => line.trim()).filter(Boolean),
    keywords: [],
  }));
}

function sliceByMarkers(text, startRegex, endRegex) {
  const startMatch = text.match(startRegex);
  if (!startMatch || startMatch.index === undefined) {
    return text;
  }

  const start = startMatch.index;
  const afterStart = text.slice(start);
  const endMatch = afterStart.match(endRegex);

  if (!endMatch || endMatch.index === undefined) {
    return afterStart;
  }

  return afterStart.slice(0, endMatch.index);
}

function replaceOrAddLaw(seed, lawNumber, document, articles) {
  const deduped = new Map();
  for (const article of articles) {
    const order = Number(article.articleOrder);
    if (!Number.isFinite(order) || order < 1) {
      continue;
    }

    const text = cleanBodyText(article.text ?? '');
    if (!text) {
      continue;
    }

    const paragraphs = splitParagraphs(text);
    const prepared = {
      articleNumber: String(order),
      articleOrder: order,
      text: paragraphs.length ? paragraphs.join('\n') : text,
      paragraphs: paragraphs.length ? paragraphs : [text],
      keywords: [],
    };

    const existing = deduped.get(order);
    if (!existing || prepared.text.length > existing.text.length) {
      deduped.set(order, prepared);
    }
  }

  const normalizedArticles = Array.from(deduped.values()).sort(
    (a, b) => a.articleOrder - b.articleOrder,
  );

  const payload = {
    document,
    articles: normalizedArticles,
  };

  const index = seed.findIndex((entry) => entry?.document?.lawNumber === lawNumber);
  if (index === -1) {
    seed.push(payload);
  } else {
    seed[index] = payload;
  }
}

function main() {
  ensureFileExists(LAWS_SEED_PATH);
  Object.values(SOURCES).forEach(ensureFileExists);

  const lawsSeed = JSON.parse(fs.readFileSync(LAWS_SEED_PATH, 'utf8'));
  if (!Array.isArray(lawsSeed)) {
    throw new Error('laws.seed.json must be an array');
  }

  const penalArticles = htmlLawToArticles(fs.readFileSync(SOURCES.penalHtml, 'utf8'));
  const disciplineArticles = htmlLawToArticles(
    fs.readFileSync(SOURCES.disciplineHtml, 'utf8'),
  );
  const realEstateArticles = htmlLawToArticles(
    fs.readFileSync(SOURCES.realEstateHtml, 'utf8'),
  );

  const electionsText = fs.readFileSync(SOURCES.electionsText, 'utf8');
  const electionsSection = sliceByMarkers(
    electionsText,
    /قانون\s+انتخابات\s+مجلس\s+النواب/u,
    /الأسباب\s+الموجبة/u,
  );
  const electionsArticles = extractArticlesFromMaterialText(
    electionsSection,
    /^\s*المادة\s*[-–—]?\s*([٠-٩۰-۹0-9]{1,3})\s*[-–—]?\s*[:：]?/gmu,
    {
      breakOnResetAfter: 40,
      maxJump: 4,
    },
  );

  const militaryText = fs.readFileSync(SOURCES.militaryText, 'utf8');
  const militaryArticles = extractArticlesFromMaterialText(
    militaryText,
    /[\-–—]\s*([٠-٩۰-۹0-9]{1,4})\s*[\-–—]\s*المادة/gmu,
    {
      breakOnResetAfter: 90,
      maxJump: 5,
    },
  );

  if (militaryArticles.length) {
    militaryArticles[0].text = cleanBodyText(militaryArticles[0].text).replace(
      /^[\s\S]*?(?=تسري احكام هذا القانون)/u,
      '',
    );
    if (!militaryArticles[0].text.trim()) {
      militaryArticles[0].text = cleanBodyText(militaryArticles[0].text).replace(
        /^[\s\S]*?(?=تشكل بموجب احكام هذا القانون)/u,
        '',
      );
    }
    militaryArticles[0].text = militaryArticles[0].text
      .replace(/^[\s\S]*?(?=تشكل بموجب احكام هذا القانون)/u, '')
      .trim();
    militaryArticles[0].paragraphs = splitParagraphs(militaryArticles[0].text);
  }

  if (disciplineArticles.length) {
    const last = disciplineArticles[disciplineArticles.length - 1];
    last.text = cleanBodyText(last.text).replace(/قانون التعديل[\s\S]*$/u, '').trim();
    last.paragraphs = splitParagraphs(last.text);
  }

  const treatiesText = fs.readFileSync(SOURCES.treatiesText, 'utf8');
  const treatiesArticles = chunkTextToArticles(treatiesText, 1400);

  replaceOrAddLaw(
    lawsSeed,
    '111',
    {
      title: 'قانون العقوبات العراقي رقم 111 لسنة 1969',
      lawNumber: '111',
      year: 1969,
      issuingBody: 'مجلس قيادة الثورة',
      legalDomain: 'عقوبات',
      keywords: ['قانون العقوبات', 'جرائم', 'عقوبات', 'جنايات', 'جنح'],
      sourceName: 'wiki.dorar-aliraq.net',
      sourceUrl: URLS.penal,
    },
    penalArticles,
  );

  replaceOrAddLaw(
    lawsSeed,
    '14',
    {
      title: 'قانون انضباط موظفي الدولة والقطاع العام رقم 14 لسنة 1991',
      lawNumber: '14',
      year: 1991,
      issuingBody: 'مجلس قيادة الثورة',
      legalDomain: 'إداري',
      keywords: ['انضباط وظيفي', 'وظائف عامة', 'عقوبات انضباطية', 'الموظف العام'],
      sourceName: 'wiki.dorar-aliraq.net',
      sourceUrl: URLS.discipline,
    },
    disciplineArticles,
  );

  replaceOrAddLaw(
    lawsSeed,
    '43',
    {
      title: 'قانون التسجيل العقاري رقم 43 لسنة 1971',
      lawNumber: '43',
      year: 1971,
      issuingBody: 'السلطة التشريعية العراقية',
      legalDomain: 'عقارات',
      keywords: ['تسجيل عقاري', 'عقار', 'قيود عقارية', 'الملكية العقارية'],
      sourceName: 'wiki.dorar-aliraq.net',
      sourceUrl: URLS.realEstate,
    },
    realEstateArticles,
  );

  replaceOrAddLaw(
    lawsSeed,
    '9',
    {
      title: 'قانون انتخابات مجلس النواب العراقي رقم 9 لسنة 2020',
      lawNumber: '9',
      year: 2020,
      issuingBody: 'مجلس النواب العراقي',
      legalDomain: 'دستوري',
      keywords: ['انتخابات', 'مجلس النواب', 'المفوضية', 'دوائر انتخابية'],
      sourceName: 'moj.gov.iq',
      sourceUrl: URLS.elections,
    },
    electionsArticles,
  );

  replaceOrAddLaw(
    lawsSeed,
    '22',
    {
      title: 'قانون أصول المحاكمات العسكرية رقم 22 لسنة 2016',
      lawNumber: '22',
      year: 2016,
      issuingBody: 'مجلس النواب العراقي',
      legalDomain: 'أصول محاكمات',
      keywords: ['محاكمات عسكرية', 'إجراءات جزائية عسكرية', 'دعوى جزائية'],
      sourceName: 'moj.gov.iq',
      sourceUrl: URLS.military,
    },
    militaryArticles,
  );

  replaceOrAddLaw(
    lawsSeed,
    'R-2025-44',
    {
      title: 'النظام القانوني للمعاهدات الدولية في القانون العراقي (مرجع بحثي)',
      lawNumber: 'R-2025-44',
      year: 2025,
      issuingBody: 'مجلة علمية قانونية',
      legalDomain: 'دولي',
      keywords: ['معاهدات دولية', 'قانون دولي', 'القانون العراقي', 'مرجع بحثي'],
      sourceName: 'iasj.rdd.edu.iq',
      sourceUrl: URLS.treaties,
    },
    treatiesArticles,
  );

  fs.writeFileSync(LAWS_SEED_PATH, `${JSON.stringify(lawsSeed, null, 2)}\n`, 'utf8');

  console.log(
    JSON.stringify(
      {
        updated: true,
        laws: {
          law111: penalArticles.length,
          law14: disciplineArticles.length,
          law43: realEstateArticles.length,
          law9: electionsArticles.length,
          law22: militaryArticles.length,
          ref2025: treatiesArticles.length,
        },
      },
      null,
      2,
    ),
  );
}

main();
