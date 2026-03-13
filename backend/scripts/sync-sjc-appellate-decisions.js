/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const mongoose = require('mongoose');

const SJC_BASE_URL = 'https://www.sjc.iq';

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

function normalizeArabic(value) {
  return `${value ?? ''}`
    .replace(/[\u0610-\u061A\u064B-\u065F\u06D6-\u06ED]/g, '')
    .replace(/[\u0625\u0623\u0622\u0627]/g, '\u0627')
    .replace(/\u0649/g, '\u064A')
    .replace(/\u0624/g, '\u0648')
    .replace(/\u0626/g, '\u064A')
    .replace(/\u0629/g, '\u0647')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

function toWesternDigits(value) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  const easternDigits = '۰۱۲۳۴۵۶۷۸۹';

  return `${value ?? ''}`
    .replace(/[٠-٩]/g, (char) => String(arabicDigits.indexOf(char)))
    .replace(/[۰-۹]/g, (char) => String(easternDigits.indexOf(char)))
    .replace(/[^0-9]/g, '')
    .trim();
}

function cleanText(value) {
  return decodeHtmlEntities(value)
    .replace(/<[^>]+>/g, ' ')
    .replace(/\u200f|\u200e|\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function mapCaseType(rawCaseType, contextText) {
  const normalized = normalizeArabic(
    [rawCaseType ?? '', contextText ?? ''].filter(Boolean).join(' '),
  );

  if (!normalized) {
    return 'أخرى';
  }

  if (normalized.includes('مدني')) {
    return 'مدني';
  }
  if (
    normalized.includes('جزايي') ||
    normalized.includes('جزاي') ||
    normalized.includes('جنايي') ||
    normalized.includes('جنايه') ||
    normalized.includes('جناي')
  ) {
    return 'جزائي';
  }
  if (
    normalized.includes('احوال شخصيه') ||
    normalized.includes('احوال') ||
    normalized.includes('مواد شخص') ||
    normalized.includes('طلاق') ||
    normalized.includes('زواج') ||
    normalized.includes('نفقه') ||
    normalized.includes('مهر') ||
    normalized.includes('حضانه') ||
    normalized.includes('مطاوعه')
  ) {
    return 'أحوال شخصية';
  }
  if (normalized.includes('تجاري') || normalized.includes('شركه') || normalized.includes('كمبياله')) {
    return 'تجاري';
  }
  if (normalized.includes('اداري') || normalized.includes('انضباط') || normalized.includes('موظفي الدوله')) {
    return 'إداري';
  }
  if (normalized.includes('عمال') || normalized.includes('اجور') || normalized.includes('تعويض عمالي')) {
    return 'عمالي';
  }
  if (normalized.includes('عقار') || normalized.includes('ايجار') || normalized.includes('تسجيل عقاري')) {
    return 'عقاري';
  }
  if (normalized.includes('تنفيذ')) {
    return 'تنفيذ';
  }
  if (normalized.includes('دستور') || normalized.includes('دستوري')) {
    return 'دستوري';
  }
  if (normalized.includes('اثبات') || normalized.includes('يمين حاسمه')) {
    return 'إثبات';
  }
  if (normalized.includes('مرافعات') || normalized.includes('اصول محاكمات')) {
    return 'إجرائي';
  }
  if (normalized.includes('وقف')) {
    return 'وقف';
  }

  return 'أخرى';
}

function mapLegalDomain(caseType) {
  switch (caseType) {
    case 'مدني':
      return 'مدني';
    case 'جزائي':
      return 'عقوبات';
    case 'أحوال شخصية':
      return 'أحوال شخصية';
    case 'تجاري':
      return 'تجاري';
    case 'إداري':
      return 'إداري';
    case 'عمالي':
      return 'عمل';
    case 'عقاري':
      return 'عقارات';
    case 'تنفيذ':
      return 'تنفيذ';
    case 'دستوري':
      return 'دستوري';
    case 'إثبات':
      return 'أدلة / إثبات';
    case 'إجرائي':
      return 'أصول محاكمات';
    default:
      return 'أخرى';
  }
}

function extractLegalArticleRefs(text) {
  const refs = new Set();
  const pattern = /المادة\s*\(?\s*([0-9٠-٩]+)\s*\)?/g;

  for (const match of text.matchAll(pattern)) {
    const n = toWesternDigits(match[1]);
    if (n) {
      refs.add(n);
    }
  }

  return Array.from(refs).slice(0, 40);
}

function extractConstitutionalRefs(text) {
  const refs = new Set();
  const pattern = /الدستور[\s\S]{0,35}?المادة\s*\(?\s*([0-9٠-٩]+)\s*\)?/g;

  for (const match of text.matchAll(pattern)) {
    const n = toWesternDigits(match[1]);
    if (n) {
      refs.add(n);
    }
  }

  return Array.from(refs).slice(0, 20);
}

function extractKeywords(value) {
  return Array.from(
    new Set(
      `${value ?? ''}`
        .replace(/[.,;:!?()[\]{}\-_/\\]/g, ' ')
        .split(/\s+/)
        .map((token) => token.trim())
        .filter((token) => token.length >= 2),
    ),
  ).slice(0, 32);
}

function looksAppellateOrCassation(normalizedSummary) {
  return (
    normalizedSummary.includes('استيناف') ||
    normalizedSummary.includes('الاستيناف') ||
    normalizedSummary.includes('تمييز') ||
    normalizedSummary.includes('محكمه')
  );
}

async function fetchHtml(url, timeoutMs = 9000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'accept-language': 'ar-IQ,ar;q=0.9,en;q=0.8',
      },
    });

    if (!response.ok) {
      throw new Error(`Request failed: ${response.status}`);
    }

    return response.text();
  } finally {
    clearTimeout(timeout);
  }
}

function extractMetaSegmentFromDecisionPage(html) {
  const match = html.match(
    /<div class="col-md-9 mt-4 mt-md-0 border-start">([\s\S]*?)<\/div>\s*<\/div>\s*<\/div>\s*<\/section>/i,
  );
  return cleanText(match?.[1] ?? '');
}

function extractBetweenLabels(text, startLabel, endLabel) {
  const start = text.indexOf(startLabel);
  if (start < 0) {
    return '';
  }
  const from = text.slice(start + startLabel.length);
  const end = from.indexOf(endLabel);
  return (end >= 0 ? from.slice(0, end) : from).trim();
}

function extractAfterLabel(text, label) {
  const index = text.indexOf(label);
  if (index < 0) {
    return '';
  }
  return text.slice(index + label.length).trim();
}

function escapeRegex(value) {
  return `${value ?? ''}`.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function extractDecisionSection(html, sectionTitle, nextSectionTitle) {
  const escapedTitle = escapeRegex(sectionTitle);
  const escapedNext = escapeRegex(nextSectionTitle);
  const pattern = new RegExp(
    `<div[^>]*text-bg-secondary[^>]*>\\s*${escapedTitle}\\s*<\\/div>([\\s\\S]*?)(?=<div[^>]*text-bg-secondary[^>]*>\\s*${escapedNext}\\s*<\\/div>|$)`,
    'i',
  );
  const match = html.match(pattern);
  return cleanText(match?.[1] ?? '');
}

function parseDecisionDate(rawDate, decisionNumber) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  const easternDigits = '۰۱۲۳۴۵۶۷۸۹';

  const dateText = `${rawDate ?? ''}`
    .replace(/[٠-٩]/g, (char) => String(arabicDigits.indexOf(char)))
    .replace(/[۰-۹]/g, (char) => String(easternDigits.indexOf(char)));

  const match = dateText.match(/(\d{1,2})\D+(\d{1,2})\D+(\d{2,4})/);
  if (match) {
    const day = Number(match[1]);
    const month = Number(match[2]);
    const yearRaw = Number(match[3]);
    const year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;

    if (year >= 1900 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return new Date(Date.UTC(year, month - 1, day));
    }
  }

  const fallbackYear = `${decisionNumber ?? ''}`.match(/(19|20)\d{2}/)?.[0];
  if (fallbackYear) {
    return new Date(Date.UTC(Number(fallbackYear), 0, 1));
  }

  return new Date(Date.UTC(2026, 0, 1));
}

function extractDecisionFromSjcPage(html, qviewId, mode) {
  const metaSegment = extractMetaSegmentFromDecisionPage(html);
  const caseTypeRaw = extractBetweenLabels(metaSegment, 'نوع القرار ::', 'رقم القرار ::');
  const decisionNumberRaw = extractBetweenLabels(
    metaSegment,
    'رقم القرار ::',
    'تاريخ اصدار القرار ::',
  );
  const decisionDateRaw = extractBetweenLabels(
    metaSegment,
    'تاريخ اصدار القرار ::',
    'جهة الاصدار::',
  );
  const courtNameRaw = extractAfterLabel(metaSegment, 'جهة الاصدار::');

  const principle = extractDecisionSection(html, 'مبدأ القرار', 'نص القرار');
  const fullTextSection = extractDecisionSection(html, 'نص القرار', 'قرارات ذات علاقة');
  const fullText = fullTextSection || principle;
  const summary = principle || fullTextSection;
  const decisionNumber = cleanText(decisionNumberRaw).replace(/\s*\/\s*/g, '/');
  const courtName = cleanText(courtNameRaw) || 'محكمة عراقية';

  if (!decisionNumber || !summary || !fullText) {
    return null;
  }

  const caseType = mapCaseType(caseTypeRaw, `${summary} ${fullText} ${courtName}`);
  const legalDomain = mapLegalDomain(caseType);
  const normalizedContext = normalizeArabic(
    `${courtName} ${caseTypeRaw} ${decisionNumber} ${summary} ${fullText}`,
  );

  if (mode === 'appellate' && !looksAppellateOrCassation(normalizedContext)) {
    return null;
  }

  const courtLevel = normalizedContext.includes('تمييز') ? 'cassation' : 'appellate';
  const decisionDate = parseDecisionDate(decisionDateRaw, decisionNumber);
  const source = `${SJC_BASE_URL}/qview.${qviewId}/`;

  return {
    source,
    sourceType: 'public_web_scrape',
    courtName,
    courtLevel,
    decisionNumber,
    decisionDate,
    caseType,
    legalDomain,
    summary,
    fullText,
    extractedCitations: [],
    constitutionalReferences: extractConstitutionalRefs(fullText),
    legalArticleReferences: extractLegalArticleRefs(fullText),
    legalKeywords: extractKeywords(`${caseType} ${summary} ${decisionNumber}`),
    outcome:
      'مستخرج من مصدر علني ويحتاج مراجعة محامٍ بشري قبل الاعتماد المهني النهائي.',
    precedentWeight: 0.72,
    confidenceScore: 0.68,
    tags: [
      'sjc-sync',
      'public-source',
      'full-text',
      'review-required',
      caseTypeRaw ? `raw-type:${cleanText(caseTypeRaw)}` : 'raw-type:unknown',
    ],
    reviewStatus: 'pending',
    ingestionStatus: 'published',
    normalizedText: normalizeArabic(fullText),
  };
}

async function collectDecisions({ startId, endId, concurrency, maxDecisions, mode }) {
  let nextId = startId;
  let scannedPages = 0;
  let failedPages = 0;
  let emptyPages = 0;
  const bySource = new Map();

  async function worker() {
    while (nextId <= endId && bySource.size < maxDecisions) {
      const currentId = nextId;
      nextId += 1;

      try {
        const html = await fetchHtml(`${SJC_BASE_URL}/qview.${currentId}/`);
        scannedPages += 1;

        const decision = extractDecisionFromSjcPage(html, currentId, mode);
        if (!decision) {
          emptyPages += 1;
          continue;
        }

        if (!bySource.has(decision.source)) {
          bySource.set(decision.source, decision);
        }
      } catch (_) {
        failedPages += 1;
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()));

  const decisions = Array.from(bySource.values()).sort(
    (a, b) => b.decisionDate.getTime() - a.decisionDate.getTime(),
  );

  const byCaseType = {};
  for (const item of decisions) {
    byCaseType[item.caseType] = (byCaseType[item.caseType] ?? 0) + 1;
  }

  return {
    scannedPages,
    failedPages,
    emptyPages,
    collectedCount: decisions.length,
    byCaseType,
    decisions,
  };
}

async function main() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error('MONGODB_URI is required');
  }

  const startId = Number(process.env.SJC_START_ID ?? '1');
  const endId = Number(process.env.SJC_END_ID ?? '12000');
  const concurrency = Number(process.env.SJC_CONCURRENCY ?? '20');
  const maxDecisions = Number(process.env.SJC_MAX_DECISIONS ?? '5000');
  const mode = process.env.SJC_MODE === 'appellate' ? 'appellate' : 'all';
  const dryRun = String(process.env.SJC_DRY_RUN ?? 'false').toLowerCase() === 'true';
  const writeSeed = String(process.env.SJC_WRITE_SEED ?? 'false').toLowerCase() === 'true';
  const seedPath =
    process.env.SJC_SEED_OUTPUT_PATH ||
    path.join(__dirname, '..', 'data', 'public', 'judicial_decisions_appellate_cassation.seed.json');

  await mongoose.connect(mongoUri);
  const decisionsCollection = mongoose.connection.db.collection('judicial_decisions');

  const collected = await collectDecisions({
    startId,
    endId,
    concurrency,
    maxDecisions,
    mode,
  });

  if (writeSeed) {
    fs.writeFileSync(seedPath, `${JSON.stringify(collected.decisions, null, 2)}\n`, 'utf8');
  }

  if (dryRun) {
    console.log(
      JSON.stringify(
        {
          dryRun: true,
          writeSeed,
          seedPath: writeSeed ? seedPath : null,
          ...collected,
          preview: collected.decisions.slice(0, 20),
        },
        null,
        2,
      ),
    );
    await mongoose.disconnect();
    return;
  }

  if (!collected.decisions.length) {
    console.log(
      JSON.stringify(
        {
          ...collected,
          insertedCount: 0,
          updatedCount: 0,
          message: 'No decisions collected from the requested range.',
        },
        null,
        2,
      ),
    );
    await mongoose.disconnect();
    return;
  }

  const operations = collected.decisions.map((doc) => ({
    updateOne: {
      filter: { source: doc.source },
      update: {
        $set: doc,
        $setOnInsert: { similarityEmbedding: [] },
      },
      upsert: true,
    },
  }));

  const result = await decisionsCollection.bulkWrite(operations, { ordered: false });

  console.log(
    JSON.stringify(
      {
        ...collected,
        writeSeed,
        seedPath: writeSeed ? seedPath : null,
        insertedCount: result.upsertedCount ?? 0,
        updatedCount: result.modifiedCount ?? 0,
      },
      null,
      2,
    ),
  );

  await mongoose.disconnect();
}

main().catch(async (error) => {
  console.error(error);
  try {
    await mongoose.disconnect();
  } catch (_) {
    // ignore
  }
  process.exit(1);
});
