/* eslint-disable no-console */
const mongoose = require('mongoose');

const SJC_BASE_URL = 'https://sjc.iq';

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

  return Array.from(refs).slice(0, 20);
}

function extractConstitutionalRefs(text) {
  const refs = new Set();
  const pattern = /الدستور[\s\S]{0,25}?المادة\s*\(?\s*([0-9٠-٩]+)\s*\)?/g;

  for (const match of text.matchAll(pattern)) {
    const n = toWesternDigits(match[1]);
    if (n) {
      refs.add(n);
    }
  }

  return Array.from(refs).slice(0, 12);
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
  ).slice(0, 16);
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

function extractRows(html) {
  const rows = [];
  const pattern =
    /<a href="#" class="badge text-bg-warning mb-2"><i[^>]*><\/i>([^<]+)<\/a>[\s\S]*?<h6 class="course-title[^"]*"><a href="#">([^<]*)<\/a><\/h6>[\s\S]*?<p>([\s\S]*?)<a href="(\/qview\.\d+\/)"[\s\S]*?<h6 class="course-title[^"]*"><a href="#">(\d{4})<\/a><\/h6>/gi;

  for (const match of html.matchAll(pattern)) {
    const decisionNumber = cleanText(match[1]);
    const caseTypeRaw = cleanText(match[2]);
    const summary = cleanText(match[3]);
    const detailPath = (match[4] ?? '').trim();
    const year = Number(match[5]);

    if (!decisionNumber || !summary || !detailPath) {
      continue;
    }

    rows.push({
      decisionNumber,
      caseTypeRaw,
      summary,
      detailPath,
      year,
    });
  }

  return rows;
}

async function collectDecisions({ startId, endId, concurrency, maxDecisions, mode }) {
  let nextId = startId;
  let scannedPages = 0;
  let failedPages = 0;
  const bySource = new Map();

  async function worker() {
    while (nextId <= endId && bySource.size < maxDecisions) {
      const currentId = nextId;
      nextId += 1;

      try {
        const html = await fetchHtml(`${SJC_BASE_URL}/qview.${currentId}/`);
        scannedPages += 1;

        const rows = extractRows(html);
        for (const row of rows) {
          if (bySource.size >= maxDecisions) {
            break;
          }

          const normalizedSummary = normalizeArabic(row.summary);
          if (mode === 'appellate' && !looksAppellateOrCassation(normalizedSummary)) {
            continue;
          }

          const source = `${SJC_BASE_URL}${row.detailPath}`;
          if (bySource.has(source)) {
            continue;
          }

          const caseType = mapCaseType(row.caseTypeRaw, row.summary);
          const legalDomain = mapLegalDomain(caseType);
          const courtLevel = normalizedSummary.includes('تمييز')
            ? 'cassation'
            : 'appellate';
          const courtName =
            courtLevel === 'cassation'
              ? 'محكمة التمييز الاتحادية'
              : 'محكمة الاستئناف العراقية';

          const parsedYear = Number.isFinite(row.year) && row.year >= 1900 ? row.year : 2026;

          bySource.set(source, {
            source,
            sourceType: 'public_web_scrape',
            courtName,
            courtLevel,
            decisionNumber: row.decisionNumber,
            decisionDate: new Date(Date.UTC(parsedYear, 0, 1)),
            caseType,
            legalDomain,
            summary: row.summary,
            fullText: row.summary,
            extractedCitations: [],
            constitutionalReferences: extractConstitutionalRefs(row.summary),
            legalArticleReferences: extractLegalArticleRefs(row.summary),
            legalKeywords: extractKeywords(`${caseType} ${row.summary}`),
            outcome:
              'مستخرج من مصدر علني ويحتاج مراجعة محامٍ بشري قبل الاعتماد المهني النهائي.',
            precedentWeight: 0.62,
            confidenceScore: 0.58,
            tags: [
              'sjc-sync',
              'public-source',
              'review-required',
              row.caseTypeRaw ? `raw-type:${row.caseTypeRaw}` : 'raw-type:unknown',
            ],
            reviewStatus: 'pending',
            ingestionStatus: 'published',
            normalizedText: normalizeArabic(row.summary),
          });
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
  const endId = Number(process.env.SJC_END_ID ?? '4200');
  const concurrency = Number(process.env.SJC_CONCURRENCY ?? '20');
  const maxDecisions = Number(process.env.SJC_MAX_DECISIONS ?? '1200');
  const mode = process.env.SJC_MODE === 'all' ? 'all' : 'appellate';
  const dryRun = String(process.env.SJC_DRY_RUN ?? 'false').toLowerCase() === 'true';

  await mongoose.connect(mongoUri);
  const decisionsCollection = mongoose.connection.db.collection('judicial_decisions');

  const collected = await collectDecisions({
    startId,
    endId,
    concurrency,
    maxDecisions,
    mode,
  });

  if (dryRun) {
    console.log(
      JSON.stringify(
        {
          dryRun: true,
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
