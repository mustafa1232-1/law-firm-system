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

async function fetchHtml(url, timeoutMs = 12000) {
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

function parseYears() {
  const raw = `${process.env.SJC_APPEAL_YEARS ?? ''}`.trim();
  if (!raw) {
    return [2021, 2022, 2023, 2024, 2025, 2026];
  }
  const years = raw
    .split(',')
    .map((item) => Number(item.trim()))
    .filter((item) => Number.isFinite(item) && item >= 2000 && item <= 2100);
  return years.length ? years : [2021, 2022, 2023, 2024, 2025, 2026];
}

function parseDecisionDateFromTitle(title) {
  const normalized = `${title ?? ''}`.replace(/[٠-٩]/g, (ch) =>
    String('٠١٢٣٤٥٦٧٨٩'.indexOf(ch)),
  );
  const match = normalized.match(/في\s+(\d{1,2})\s*\/\s*(\d{1,2})\s*\/\s*(\d{4})/);
  if (!match) {
    return null;
  }
  const day = Number(match[1]);
  const month = Number(match[2]);
  const year = Number(match[3]);
  if (!day || !month || !year) {
    return null;
  }
  return new Date(Date.UTC(year, month - 1, day));
}

function parseDecisionNumberFromTitle(title, viewId) {
  const cleaned = cleanText(title);
  const slashLike = cleaned.match(/^([0-9٠-٩]+)\s*\/\s*([^/]+)\s*\/\s*([0-9٠-٩]{4})/);
  if (slashLike) {
    return cleanText(slashLike[0]).replace(/\s*\/\s*/g, '/');
  }

  const rawDigits = cleaned.match(/[0-9٠-٩]{1,6}/)?.[0] ?? `${viewId}`;
  const year = cleaned.match(/(19|20)[0-9]{2}/)?.[0] ?? '2026';
  const number = rawDigits.replace(/[٠-٩]/g, (ch) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(ch)));
  return `${number}/الهيئة القضائية للانتخابات/${year}`;
}

function extractImageUrls(html) {
  const urls = [];
  const pattern = /<img[^>]*src="([^"]+)"[^>]*>/gi;
  for (const match of html.matchAll(pattern)) {
    const raw = `${match[1] ?? ''}`.trim();
    if (!raw) {
      continue;
    }
    const full = raw.startsWith('http')
      ? raw
      : `${SJC_BASE_URL}${raw.startsWith('/') ? '' : '/'}${raw}`;
    const normalized = full.toLowerCase();
    if (
      !(
        normalized.includes('/upload/') ||
        normalized.includes('/upload/external/') ||
        normalized.includes('/upload/images/')
      )
    ) {
      continue;
    }
    if (normalized.includes('98579_whatsapp%20image%202024-01-03%20at%201.31.10%20pm.jpeg')) {
      continue;
    }
    urls.push(full.replace('/../', '/'));
  }
  return Array.from(new Set(urls)).slice(0, 8);
}

function extractPageTitle(html) {
  const match = html.match(/<h2[^>]*class="display-4"[^>]*>([\s\S]*?)<\/h2>/i);
  return cleanText(match?.[1] ?? '');
}

async function collectAppealLinks(years) {
  const links = new Set();
  const stats = {};
  for (const year of years) {
    const url = `${SJC_BASE_URL}/allappeal-${year}.php`;
    const html = await fetchHtml(url, 15000);
    const yearly = new Set();
    for (const match of html.matchAll(/\/viewappeal\.(\d+)\//gi)) {
      yearly.add(`/viewappeal.${match[1]}/`);
      links.add(`/viewappeal.${match[1]}/`);
    }
    stats[year] = yearly.size;
  }
  return { links: Array.from(links), stats };
}

async function collectDecisions(links, concurrency) {
  let cursor = 0;
  let scannedPages = 0;
  let failedPages = 0;
  let emptyPages = 0;
  const decisions = [];

  async function worker() {
    while (cursor < links.length) {
      const idx = cursor;
      cursor += 1;
      const link = links[idx];
      const viewId = Number((link.match(/viewappeal\.(\d+)/)?.[1] ?? '0').trim());
      const source = `${SJC_BASE_URL}${link}`;

      try {
        const html = await fetchHtml(source, 15000);
        scannedPages += 1;
        const title = extractPageTitle(html);
        if (!title) {
          emptyPages += 1;
          continue;
        }

        const decisionNumber = parseDecisionNumberFromTitle(title, viewId);
        const decisionDate = parseDecisionDateFromTitle(title) ?? new Date(Date.UTC(2026, 0, 1));
        const imageUrls = extractImageUrls(html);

        const fullText = [
          title,
          imageUrls.length
            ? `نص القرار منشور بصيغة صورة في المصدر العام. روابط الصور: ${imageUrls.join(' | ')}`
            : 'نص القرار منشور بصيغة صورة في المصدر العام ويحتاج مراجعة بشرية.',
        ].join(' ');

        decisions.push({
          source,
          sourceType: 'public_web_scrape',
          courtName: 'الهيئة القضائية للانتخابات',
          courtLevel: 'appellate',
          decisionNumber,
          decisionDate,
          caseType: 'إداري',
          legalDomain: 'انتخابات',
          summary: title,
          fullText,
          extractedCitations: [],
          constitutionalReferences: [],
          legalArticleReferences: [],
          legalKeywords: Array.from(
            new Set(cleanText(title).split(/\s+/).filter((token) => token.length >= 2)),
          ).slice(0, 20),
          outcome:
            'قرار انتخابي منشور في مصدر عام ويحتاج مراجعة محامٍ بشري قبل الاعتماد المهني النهائي.',
          precedentWeight: 0.55,
          confidenceScore: 0.52,
          tags: ['sjc-election-appeal', 'public-source', 'image-based', 'review-required'],
          reviewStatus: 'pending',
          ingestionStatus: 'published',
          normalizedText: normalizeArabic(fullText),
          attachmentStoragePath: imageUrls[0],
        });
      } catch (_) {
        failedPages += 1;
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()));
  return {
    scannedPages,
    failedPages,
    emptyPages,
    collectedCount: decisions.length,
    decisions,
  };
}

async function main() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error('MONGODB_URI is required');
  }

  const years = parseYears();
  const concurrency = Math.min(30, Math.max(1, Number(process.env.SJC_CONCURRENCY ?? '10')));
  const dryRun = String(process.env.SJC_DRY_RUN ?? 'false').toLowerCase() === 'true';
  const writeSeed = String(process.env.SJC_WRITE_SEED ?? 'false').toLowerCase() === 'true';
  const seedPath =
    process.env.SJC_SEED_OUTPUT_PATH ||
    path.join(__dirname, '..', 'data', 'public', 'judicial_decisions_election_appeal.seed.json');

  await mongoose.connect(mongoUri);
  const decisionsCollection = mongoose.connection.db.collection('judicial_decisions');

  const { links, stats } = await collectAppealLinks(years);
  const collected = await collectDecisions(links, concurrency);

  if (writeSeed) {
    fs.writeFileSync(seedPath, `${JSON.stringify(collected.decisions, null, 2)}\n`, 'utf8');
  }

  if (dryRun) {
    console.log(
      JSON.stringify(
        {
          dryRun: true,
          years,
          linksDiscovered: links.length,
          yearlyLinks: stats,
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

  const operations = collected.decisions.map((doc) => ({
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
        years,
        linksDiscovered: links.length,
        yearlyLinks: stats,
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
