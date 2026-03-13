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

function cleanText(value) {
  return decodeHtmlEntities(value)
    .replace(/<[^>]+>/g, ' ')
    .replace(/\u200f|\u200e|\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
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
  return `${value ?? ''}`
    .replace(/[٠-٩]/g, (char) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(char)))
    .replace(/[۰-۹]/g, (char) => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(char)));
}

async function fetchHtml(url, timeoutMs = 15000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
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

function extractMaxNewsPage(homeHtml) {
  const values = [];
  for (const match of homeHtml.matchAll(/\/news\/page_(\d+)\//gi)) {
    const page = Number(match[1]);
    if (Number.isFinite(page)) {
      values.push(page);
    }
  }
  return values.length ? Math.max(...values) : 0;
}

function extractNewsViewLinks(newsHtml) {
  const links = new Set();
  for (const match of newsHtml.matchAll(/href="(\/view\.(\d+)\/)"/gi)) {
    links.add(match[1]);
  }
  return Array.from(links);
}

function extractViewId(viewLink) {
  return Number((`${viewLink ?? ''}`.match(/\/view\.(\d+)\//)?.[1] ?? '0').trim());
}

function extractArticleTitle(viewHtml) {
  const titleMatch = viewHtml.match(/<h2[^>]*class="display-4"[^>]*>([\s\S]*?)<\/h2>/i);
  return cleanText(titleMatch?.[1] ?? '');
}

function extractArticleBody(viewHtml) {
  const sectionMatch = viewHtml.match(/<section class="pt-0">([\s\S]*?)<\/section>/i);
  return cleanText(sectionMatch?.[1] ?? '');
}

function extractArticleDate(viewHtml) {
  const dateMatch = viewHtml.match(/fa-clock[\s\S]*?(\d{4}-\d{2}-\d{2}(?:\s+\d{2}:\d{2}:\d{2})?)/i);
  return `${dateMatch?.[1] ?? ''}`.trim();
}

function parseDecisionDate(rawDate) {
  const cleaned = `${rawDate ?? ''}`.trim();
  if (!cleaned) {
    return new Date(Date.UTC(2026, 0, 1));
  }
  const fixed = toWesternDigits(cleaned);
  const isoMatch = fixed.match(
    /^(\d{4})-(\d{2})-(\d{2})(?:\s+(\d{2}):(\d{2})(?::(\d{2}))?)?$/,
  );
  if (!isoMatch) {
    return new Date(Date.UTC(2026, 0, 1));
  }
  const year = Number(isoMatch[1]);
  const month = Number(isoMatch[2]);
  const day = Number(isoMatch[3]);
  if (!year || month < 1 || month > 12 || day < 1 || day > 31) {
    return new Date(Date.UTC(2026, 0, 1));
  }
  return new Date(Date.UTC(year, month - 1, day));
}

function extractPrimaryImage(viewHtml) {
  const imageMatch = viewHtml.match(
    /<img[^>]*src="(https?:\/\/[^"]+|\/[^"]+)"[^>]*class="[^"]*rounded[^"]*"[^>]*>/i,
  );
  if (!imageMatch?.[1]) {
    return null;
  }
  const source = imageMatch[1].trim();
  if (!source) {
    return null;
  }
  return source.startsWith('http') ? source : `${SJC_BASE_URL}${source}`;
}

function extractLegalArticleRefs(text) {
  const refs = new Set();
  for (const match of `${text ?? ''}`.matchAll(/المادة\s*\(?\s*([0-9٠-٩]+)\s*\)?/g)) {
    const normalized = toWesternDigits(match[1]).replace(/[^\d]/g, '');
    if (normalized) {
      refs.add(normalized);
    }
  }
  return Array.from(refs).slice(0, 40);
}

function extractConstitutionalRefs(text) {
  const refs = new Set();
  for (const match of `${text ?? ''}`.matchAll(/الدستور[\s\S]{0,40}?المادة\s*\(?\s*([0-9٠-٩]+)\s*\)?/g)) {
    const normalized = toWesternDigits(match[1]).replace(/[^\d]/g, '');
    if (normalized) {
      refs.add(normalized);
    }
  }
  return Array.from(refs).slice(0, 20);
}

function extractDecisionNumber(title, body, viewId, year) {
  const combined = `${title ?? ''} ${body ?? ''}`;
  const explicitMatch = combined.match(
    /(?:رقم\s*(?:القرار)?|القرار)\s*[:：\-]?\s*([0-9٠-٩\s\/-]{2,40})/u,
  );
  if (explicitMatch?.[1]) {
    const normalized = toWesternDigits(explicitMatch[1])
      .replace(/[^\d/\-]/g, '')
      .replace(/\/{2,}/g, '/')
      .replace(/-{2,}/g, '-')
      .replace(/^\W+|\W+$/g, '');
    if (normalized.length >= 2) {
      return normalized;
    }
  }
  return `${viewId}/SJC-NEWS/${year}`;
}

function extractKeywords(text) {
  return Array.from(
    new Set(
      `${text ?? ''}`
        .replace(/[.,;:!?()[\]{}\-_/\\]/g, ' ')
        .split(/\s+/)
        .map((token) => token.trim())
        .filter((token) => token.length >= 2),
    ),
  ).slice(0, 32);
}

function escapeRegex(value) {
  return `${value ?? ''}`.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function hasTerm(text, term) {
  if (!text || !term) {
    return false;
  }
  const pattern = new RegExp(
    `(^|[^\\u0600-\\u06FF0-9])${escapeRegex(term)}([^\\u0600-\\u06FF0-9]|$)`,
  );
  return pattern.test(text);
}

function hasAny(text, terms) {
  return terms.some((term) => hasTerm(text, term));
}

function isDecisionLike(title, body) {
  const normalized = normalizeArabic(`${title ?? ''} ${body ?? ''}`);
  if (!normalized) {
    return false;
  }

  const outcomeSignals = [
    'الاعدام',
    'السجن',
    'الحبس',
    'المؤبد',
    'الموبد',
    'حكما',
    'حكمان',
    'الحكم',
    'ادانه',
    'ادانة',
    'الهيئه القضائيه للانتخابات',
    'الطعن',
    'طعنا',
    'طعون',
    'نقض',
    'فسخ',
    'تمييز',
    'القبض',
    'استرد',
    'استرداد',
    'ضبطت',
    'ضبط',
  ];

  const administrativeNoise = [
    'يودون اليمين القانونيه',
    'اداء اليمين القانونيه',
    'يؤدون اليمين القانونية',
    'يستقبل',
    'استقبل',
    'تنظم',
    'ورشه',
    'ندوه',
    'اجتماع',
    'يكرم',
    'تكريم',
    'يفتتح',
    'افتتاح',
    'زياره',
    'زيارة',
    'يحضر',
    'دوره',
    'تهنئه',
    'تعزيه',
    'احصائيه',
    'احصائية',
    'يعلن انجاز',
    'لقاء',
    'مباحثات',
    'بحث التعاون',
    'تكريم موظفيها',
    'المحالين الي التقاعد',
    'ينظم ورشه',
    'تنظيم ورشة',
    'تنظم اجتماعا',
    'يفتتح قاعه',
    'تحضيري',
    'الخطه التدريبيه',
    'اليوم العالمي للقاضيات',
    'يوم القاضي العراقي',
    'المحالين للتقاعد',
    'المحالين الي التقاعد',
    'ورشه عمل',
    'ورشتي عمل',
    'ينظم اجتماع',
    'تنظم اجتماع',
    'تنظم ورشة',
  ];

  const editorialNoise = ['قراءه تحليليه', 'مقال', 'رأي', 'افتتاحيه'];

  const hasOutcomeSignal = hasAny(normalized, outcomeSignals);
  const hasForumSignal = hasAny(normalized, [
    'محكمه',
    'جنايات',
    'جنح',
    'تحقيق',
    'تمييز',
    'استيناف',
    'هيئه قضائيه',
    'الجنائيه المركزيه',
  ]);
  const hasAdministrativeNoise = hasAny(normalized, administrativeNoise);
  const hasEditorialNoise = hasAny(normalized, editorialNoise);

  if (hasEditorialNoise) {
    return false;
  }

  if (!hasOutcomeSignal || !hasForumSignal) {
    return false;
  }

  if (hasAdministrativeNoise && !(normalized.includes('الهيئه القضائيه للانتخابات') || hasOutcomeSignal)) {
    return false;
  }

  return true;
}

function mapCaseType(title, body) {
  const normalized = normalizeArabic(`${title ?? ''} ${body ?? ''}`);

  if (
    hasAny(normalized, [
      'جنايات',
      'جنح',
      'الجنائيه المركزيه',
      'محكمه تحقيق',
      'ارهابي',
      'مخدر',
      'مدان',
      'الحبس',
      'الاعدام',
      'السجن',
    ])
  ) {
    return 'جزائي';
  }

  if (hasAny(normalized, ['احوال شخصيه', 'الطلاق', 'الزواج', 'النفقه', 'المهر', 'الحضانه'])) {
    return 'أحوال شخصية';
  }

  if (hasAny(normalized, ['تجاري', 'شركه', 'شركة', 'كمبياله', 'افلاس', 'مصرف'])) {
    return 'تجاري';
  }

  if (hasAny(normalized, ['انتخابات', 'الهيئه القضائيه للانتخابات', 'الطعن الانتخابي'])) {
    return 'إداري';
  }

  if (hasAny(normalized, ['عقاري', 'ايجار', 'تسجيل عقاري'])) {
    return 'عقاري';
  }

  if (hasAny(normalized, ['تنفيذ'])) {
    return 'تنفيذ';
  }

  if (hasAny(normalized, ['دستوري', 'الدستور'])) {
    return 'دستوري';
  }

  return 'مدني';
}

function mapLegalDomain(caseType) {
  switch (caseType) {
    case 'جزائي':
      return 'عقوبات';
    case 'أحوال شخصية':
      return 'أحوال شخصية';
    case 'تجاري':
      return 'تجاري';
    case 'إداري':
      return 'إدارة';
    case 'عقاري':
      return 'عقارات';
    case 'تنفيذ':
      return 'تنفيذ';
    case 'دستوري':
      return 'دستور';
    default:
      return 'مدني';
  }
}

function mapCourtLevel(title, body) {
  const normalized = normalizeArabic(`${title ?? ''} ${body ?? ''}`);
  if (normalized.includes('تمييز')) {
    return 'cassation';
  }
  if (normalized.includes('استيناف') || normalized.includes('الهيئه القضائيه للانتخابات')) {
    return 'appellate';
  }
  if (hasAny(normalized, ['جنايات', 'جنح', 'تحقيق'])) {
    return 'first-instance';
  }
  return 'appellate';
}

async function collectNewsLinks(maxPage, concurrency) {
  let cursor = 0;
  const links = new Set();
  let scannedPages = 0;
  let failedPages = 0;

  async function worker() {
    while (cursor <= maxPage) {
      const page = cursor;
      cursor += 1;
      const url = `${SJC_BASE_URL}/news/page_${page}/`;

      try {
        const html = await fetchHtml(url, 15000);
        scannedPages += 1;
        for (const link of extractNewsViewLinks(html)) {
          links.add(link);
        }
      } catch (_) {
        failedPages += 1;
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()));

  return {
    scannedPages,
    failedPages,
    viewLinks: Array.from(links),
  };
}

async function collectDecisions(viewLinks, concurrency) {
  let cursor = 0;
  let scannedViews = 0;
  let failedViews = 0;
  let filteredOut = 0;
  const decisions = [];

  async function worker() {
    while (cursor < viewLinks.length) {
      const index = cursor;
      cursor += 1;
      const viewLink = viewLinks[index];
      const source = `${SJC_BASE_URL}${viewLink}`;
      const viewId = extractViewId(viewLink);

      try {
        const html = await fetchHtml(source, 15000);
        scannedViews += 1;

        const title = extractArticleTitle(html);
        const body = extractArticleBody(html);

        if (!title || !body || !isDecisionLike(title, body)) {
          filteredOut += 1;
          continue;
        }

        const publishedAt = extractArticleDate(html);
        const decisionDate = parseDecisionDate(publishedAt);
        const year = `${decisionDate.getUTCFullYear() || 2026}`;
        const decisionNumber = extractDecisionNumber(title, body, viewId, year);
        const caseType = mapCaseType(title, body);
        const legalDomain = mapLegalDomain(caseType);
        const courtLevel = mapCourtLevel(title, body);
        const normalizedText = normalizeArabic(`${title} ${body}`);
        const imageUrl = extractPrimaryImage(html);

        decisions.push({
          source,
          sourceType: 'public_web_news',
          courtName: 'مجلس القضاء الأعلى العراقي',
          courtLevel,
          decisionNumber,
          decisionDate,
          publicationDate: decisionDate,
          caseType,
          legalDomain,
          summary: title,
          fullText: body,
          extractedCitations: [],
          constitutionalReferences: extractConstitutionalRefs(body),
          legalArticleReferences: extractLegalArticleRefs(body),
          legalKeywords: extractKeywords(`${title} ${body}`),
          outcome:
            'مستخرج من خبر قضائي منشور في مصدر عام ويحتاج مراجعة قانونية بشرية قبل الاعتماد المهني النهائي.',
          precedentWeight: 0.43,
          confidenceScore: 0.47,
          tags: ['sjc-news-judicial-updates', 'public-source', 'review-required'],
          reviewStatus: 'pending',
          ingestionStatus: 'published',
          normalizedText,
          attachmentStoragePath: imageUrl ?? undefined,
        });
      } catch (_) {
        failedViews += 1;
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()));

  const byCaseType = {};
  const byCourtLevel = {};
  for (const item of decisions) {
    byCaseType[item.caseType] = (byCaseType[item.caseType] ?? 0) + 1;
    byCourtLevel[item.courtLevel] = (byCourtLevel[item.courtLevel] ?? 0) + 1;
  }

  return {
    scannedViews,
    failedViews,
    filteredOut,
    collectedCount: decisions.length,
    byCaseType,
    byCourtLevel,
    decisions,
  };
}

async function main() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error('MONGODB_URI is required');
  }

  const dryRun = String(process.env.SJC_DRY_RUN ?? 'false').toLowerCase() === 'true';
  const writeSeed = String(process.env.SJC_WRITE_SEED ?? 'false').toLowerCase() === 'true';
  const seedPath =
    process.env.SJC_SEED_OUTPUT_PATH ||
    path.join(__dirname, '..', 'data', 'public', 'judicial_decisions_news.seed.json');
  const pageConcurrency = Math.min(30, Math.max(1, Number(process.env.SJC_PAGE_CONCURRENCY ?? '20')));
  const viewConcurrency = Math.min(30, Math.max(1, Number(process.env.SJC_VIEW_CONCURRENCY ?? '20')));

  await mongoose.connect(mongoUri);
  const decisionsCollection = mongoose.connection.db.collection('judicial_decisions');

  const newsHomeHtml = await fetchHtml(`${SJC_BASE_URL}/news/`, 15000);
  const discoveredMaxPage = extractMaxNewsPage(newsHomeHtml);
  const maxPageFromEnv = Number(process.env.SJC_NEWS_MAX_PAGE ?? '');
  const maxPage = Number.isFinite(maxPageFromEnv) && maxPageFromEnv >= 0 ? maxPageFromEnv : discoveredMaxPage;

  const newsLinksResult = await collectNewsLinks(maxPage, pageConcurrency);
  const collected = await collectDecisions(newsLinksResult.viewLinks, viewConcurrency);
  const { decisions, ...collectedStats } = collected;

  if (writeSeed) {
    fs.writeFileSync(seedPath, `${JSON.stringify(decisions, null, 2)}\n`, 'utf8');
  }

  if (dryRun) {
    console.log(
      JSON.stringify(
        {
          dryRun: true,
          maxPage,
          discoveredMaxPage,
          pageConcurrency,
          viewConcurrency,
          newsPages: {
            scanned: newsLinksResult.scannedPages,
            failed: newsLinksResult.failedPages,
          },
          discoveredViewLinks: newsLinksResult.viewLinks.length,
          ...collectedStats,
          writeSeed,
          seedPath: writeSeed ? seedPath : null,
          preview: decisions.slice(0, 20).map((item) => ({
            source: item.source,
            decisionNumber: item.decisionNumber,
            decisionDate: item.decisionDate,
            caseType: item.caseType,
            courtLevel: item.courtLevel,
            summary: item.summary,
          })),
        },
        null,
        2,
      ),
    );
    await mongoose.disconnect();
    return;
  }

  const operations = decisions.map((doc) => ({
    updateOne: {
      filter: { source: doc.source },
      update: { $set: doc, $setOnInsert: { similarityEmbedding: [] } },
      upsert: true,
    },
  }));

  const result = operations.length
    ? await decisionsCollection.bulkWrite(operations, { ordered: false })
    : { upsertedCount: 0, modifiedCount: 0 };

  console.log(
    JSON.stringify(
      {
        maxPage,
        discoveredMaxPage,
        pageConcurrency,
        viewConcurrency,
        newsPages: {
          scanned: newsLinksResult.scannedPages,
          failed: newsLinksResult.failedPages,
        },
        discoveredViewLinks: newsLinksResult.viewLinks.length,
        ...collectedStats,
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
    // ignore disconnect errors
  }
  process.exit(1);
});
