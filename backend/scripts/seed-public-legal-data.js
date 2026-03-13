/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

function normalizeArabic(input) {
  const value = input ?? '';
  return value
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

function toArticleOrder(articleNumber) {
  const value = `${articleNumber ?? ''}`;
  const numeric = Number(value.replace(/[^\d]/g, ''));
  return Number.isFinite(numeric) && numeric > 0 ? numeric : 0;
}

function extractParagraphs(text) {
  const value = `${text ?? ''}`.trim();
  if (!value) {
    return [];
  }

  const markerSplitRegex =
    /(?=(?:^|\s)(?:\(?\d+\)?[-.)]|[A-Za-z]\)|[\u0660-\u0669]+\)|[\u06F0-\u06F9]+\)))/g;

  const chunks = value
    .split(markerSplitRegex)
    .map((entry) => entry.trim())
    .filter(Boolean);

  if (chunks.length > 1) {
    return chunks;
  }

  return value
    .split(/(?<=[\.؛!?])\s+/)
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function readJson(relativePath) {
  const abs = path.join(__dirname, '..', relativePath);
  return JSON.parse(fs.readFileSync(abs, 'utf8'));
}

function readJsonIfExists(relativePath, fallback = []) {
  const abs = path.join(__dirname, '..', relativePath);
  if (!fs.existsSync(abs)) {
    return fallback;
  }
  return JSON.parse(fs.readFileSync(abs, 'utf8'));
}

function mergeDecisionSeeds(...seedLists) {
  const mergedBySource = new Map();
  for (const list of seedLists) {
    if (!Array.isArray(list)) {
      continue;
    }
    for (const item of list) {
      const source = `${item?.source ?? ''}`.trim();
      if (!source) {
        continue;
      }
      const previous = mergedBySource.get(source);
      if (!previous || item?.sourceType === 'public_web_scrape') {
        mergedBySource.set(source, item);
      }
    }
  }
  return Array.from(mergedBySource.values());
}

async function main() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    throw new Error('MONGODB_URI is required');
  }

  const replaceData = (process.env.SEED_REPLACE ?? 'true').toLowerCase() === 'true';

  await mongoose.connect(uri);
  const db = mongoose.connection.db;

  const constitutionCollection = db.collection('constitution_articles');
  const lawDocumentsCollection = db.collection('law_documents');
  const lawArticlesCollection = db.collection('law_articles');
  const decisionsCollection = db.collection('judicial_decisions');
  const courtsCollection = db.collection('courts');

  const constitutionSeed = readJson('data/public/constitution_articles.seed.json');
  const lawsSeed = readJson('data/public/laws.seed.json');
  const decisionsSeed = readJson('data/public/judicial_decisions.seed.json');
  const appellateCassationDecisionsSeed = readJsonIfExists(
    'data/public/judicial_decisions_appellate_cassation.seed.json',
    [],
  );
  const electionAppealDecisionsSeed = readJsonIfExists(
    'data/public/judicial_decisions_election_appeal.seed.json',
    [],
  );
  const newsDecisionsSeed = readJsonIfExists('data/public/judicial_decisions_news.seed.json', []);
  const mergedDecisionsSeed = mergeDecisionSeeds(
    decisionsSeed,
    appellateCassationDecisionsSeed,
    electionAppealDecisionsSeed,
    newsDecisionsSeed,
  );
  const courtsSeed = readJson('data/public/iraqi_courts.seed.json');

  if (replaceData) {
    await Promise.all([
      constitutionCollection.deleteMany({}),
      lawArticlesCollection.deleteMany({}),
      lawDocumentsCollection.deleteMany({}),
      decisionsCollection.deleteMany({}),
      courtsCollection.deleteMany({}),
    ]);
    console.log('Existing legal reference data replaced.');
  }

  const constitutionDocs = constitutionSeed.map((item) => ({
    ...item,
    articleOrder: item.articleOrder ?? toArticleOrder(item.articleNumber),
    paragraphs:
      Array.isArray(item.paragraphs) && item.paragraphs.length
        ? item.paragraphs
        : extractParagraphs(item.text),
    normalizedText: normalizeArabic(item.text),
    linkedLawArticleIds: item.linkedLawArticleIds ?? [],
    linkedDecisionIds: item.linkedDecisionIds ?? [],
    createdAt: new Date(),
    updatedAt: new Date(),
  }));

  if (constitutionDocs.length) {
    await constitutionCollection.insertMany(constitutionDocs, { ordered: false });
  }

  for (const lawSeed of lawsSeed) {
    const lawDoc = {
      ...lawSeed.document,
      linkedConstitutionTopics: lawSeed.document.linkedConstitutionTopics ?? [],
      linkedDecisionIds: lawSeed.document.linkedDecisionIds ?? [],
      repealStatus: lawSeed.document.repealStatus ?? 'active',
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const insertedLaw = await lawDocumentsCollection.insertOne(lawDoc);
    const lawId = insertedLaw.insertedId;

    const lawArticles = (lawSeed.articles ?? []).map((article) => {
      const parsedOrder = Number(article.articleOrder);
      const articleOrder =
        Number.isFinite(parsedOrder) && parsedOrder > 0
          ? parsedOrder
          : toArticleOrder(article.articleNumber);

      return {
        lawId,
        articleNumber: article.articleNumber,
        articleOrder,
        text: article.text,
        normalizedText: normalizeArabic(article.text),
        paragraphs: article.paragraphs ?? [],
        keywords: article.keywords ?? [],
        createdAt: new Date(),
        updatedAt: new Date(),
      };
    });

    if (lawArticles.length) {
      await lawArticlesCollection.insertMany(lawArticles, { ordered: false });
    }
  }

  const decisionDocs = mergedDecisionsSeed.map((item) => ({
    ...item,
    decisionDate: new Date(item.decisionDate),
    publicationDate: item.publicationDate ? new Date(item.publicationDate) : undefined,
    extractedCitations: item.extractedCitations ?? [],
    constitutionalReferences: item.constitutionalReferences ?? [],
    legalArticleReferences: item.legalArticleReferences ?? [],
    legalKeywords: item.legalKeywords ?? [],
    tags: item.tags ?? [],
    similarityEmbedding: [],
    normalizedText: normalizeArabic(`${item.summary ?? ''} ${item.fullText ?? ''}`),
    createdAt: new Date(),
    updatedAt: new Date(),
  }));

  if (decisionDocs.length) {
    await decisionsCollection.insertMany(decisionDocs, { ordered: false });
  }

  const courtDocs = courtsSeed.map((item) => ({
    ...item,
    name:
      item.name ??
      item.nameAr ??
      item.nameEn ??
      '\u0645\u062d\u0643\u0645\u0629 \u063a\u064a\u0631 \u0645\u0633\u0645\u0627\u0629',
    source: item.source ?? 'openstreetmap',
    sourceType: item.sourceType ?? 'osm_amenity_courthouse',
    tags: item.tags ?? {},
    createdAt: new Date(),
    updatedAt: new Date(),
  }));

  if (courtDocs.length) {
    await courtsCollection.insertMany(courtDocs, { ordered: false });
  }

  console.log(
    JSON.stringify(
      {
        seeded: true,
        constitutionArticles: constitutionDocs.length,
        lawDocuments: lawsSeed.length,
        lawArticles: lawsSeed.reduce((acc, item) => acc + (item.articles?.length ?? 0), 0),
        judicialDecisions: decisionDocs.length,
        courts: courtDocs.length,
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
