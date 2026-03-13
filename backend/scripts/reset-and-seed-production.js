/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

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

  const chunks = value
    .split(
      RegExp(
        '(?=\\b(?:اولا|أولا|اولاً|أولاً|ثانيا|ثانياً|ثالثا|ثالثاً|رابعا|رابعاً|خامسا|خامساً|سادسا|سادساً|سابعا|سابعاً|ثامنا|ثامناً|تاسعا|تاسعاً|عاشرا|عاشراً)\\b)',
      ),
    )
    .map((entry) => entry.trim())
    .filter(Boolean);

  if (chunks.length > 1) {
    return chunks;
  }

  return value
    .split(/(?<=[\.؛])\s+/)
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function readJson(fileName) {
  const abs = path.join(__dirname, '..', 'data', 'public', fileName);
  return JSON.parse(fs.readFileSync(abs, 'utf8'));
}

function readJsonIfExists(fileName, fallback = []) {
  const abs = path.join(__dirname, '..', 'data', 'public', fileName);
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

async function seedLegalData(db) {
  const constitutionCollection = db.collection('constitution_articles');
  const lawDocumentsCollection = db.collection('law_documents');
  const lawArticlesCollection = db.collection('law_articles');
  const decisionsCollection = db.collection('judicial_decisions');
  const courtsCollection = db.collection('courts');

  const constitutionSeed = readJson('constitution_articles.seed.json');
  const lawsSeed = readJson('laws.seed.json');
  const decisionsSeed = readJson('judicial_decisions.seed.json');
  const appellateCassationDecisionsSeed = readJsonIfExists(
    'judicial_decisions_appellate_cassation.seed.json',
    [],
  );
  const mergedDecisionsSeed = mergeDecisionSeeds(
    decisionsSeed,
    appellateCassationDecisionsSeed,
  );
  const courtsSeed = readJson('iraqi_courts.seed.json');

  const constitutionDocs = constitutionSeed.map((item) => ({
    ...item,
    articleOrder: item.articleOrder ?? toArticleOrder(item.articleNumber),
    paragraphs:
      Array.isArray(item.paragraphs) && item.paragraphs.length
        ? item.paragraphs
        : extractParagraphs(item.text),
    normalizedText: normalizeArabic(item.text ?? ''),
    linkedLawArticleIds: item.linkedLawArticleIds ?? [],
    linkedDecisionIds: item.linkedDecisionIds ?? [],
    createdAt: new Date(),
    updatedAt: new Date(),
  }));

  await constitutionCollection.insertMany(constitutionDocs, { ordered: false });

  let lawArticles = 0;
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

    const articles = (lawSeed.articles ?? []).map((article) => ({
      lawId: insertedLaw.insertedId,
      articleNumber: article.articleNumber,
      articleOrder:
        Number.isFinite(Number(article.articleOrder)) && Number(article.articleOrder) > 0
          ? Number(article.articleOrder)
          : toArticleOrder(article.articleNumber),
      text: article.text,
      normalizedText: normalizeArabic(article.text ?? ''),
      paragraphs:
        Array.isArray(article.paragraphs) && article.paragraphs.length
          ? article.paragraphs
          : extractParagraphs(article.text ?? ''),
      keywords: article.keywords ?? [],
      createdAt: new Date(),
      updatedAt: new Date(),
    }));

    if (articles.length) {
      lawArticles += articles.length;
      await lawArticlesCollection.insertMany(articles, { ordered: false });
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
    name: item.name ?? item.nameAr ?? item.nameEn ?? 'محكمة غير مسماة',
    source: item.source ?? 'openstreetmap',
    sourceType: item.sourceType ?? 'osm_amenity_courthouse',
    tags: item.tags ?? {},
    createdAt: new Date(),
    updatedAt: new Date(),
  }));

  if (courtDocs.length) {
    await courtsCollection.insertMany(courtDocs, { ordered: false });
  }

  return {
    constitutionArticles: constitutionDocs.length,
    lawDocuments: lawsSeed.length,
    lawArticles,
    judicialDecisions: decisionDocs.length,
    courts: courtDocs.length,
  };
}

async function main() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    throw new Error('MONGODB_URI is required');
  }

  const superAdminEmail = process.env.SUPER_ADMIN_EMAIL ?? 'mustafa@1.net';
  const superAdminPassword = process.env.SUPER_ADMIN_PASSWORD ?? '12345678';
  const superAdminName = process.env.SUPER_ADMIN_NAME ?? 'Mustafa Super Admin';

  await mongoose.connect(uri);
  const db = mongoose.connection.db;

  const shouldDrop = (process.env.RESET_DROP_DATABASE ?? 'true').toLowerCase() === 'true';
  if (shouldDrop) {
    await db.dropDatabase();
  } else {
    const collections = await db.collections();
    for (const collection of collections) {
      await collection.deleteMany({});
    }
  }

  const passwordHash = await bcrypt.hash(superAdminPassword, 10);

  await db.collection('users').insertOne({
    fullName: superAdminName,
    email: superAdminEmail.toLowerCase().trim(),
    passwordHash,
    roles: ['SUPER_ADMIN'],
    permissions: [],
    locale: 'ar-IQ',
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  await db.collection('permissions').insertMany(
    [
      { key: 'cases.read', name: 'Read cases' },
      { key: 'cases.write', name: 'Write cases' },
      { key: 'research.read', name: 'Read research' },
      { key: 'billing.manage', name: 'Manage billing' },
      { key: 'admin.manage', name: 'Manage admin settings' },
    ].map((item) => ({ ...item, createdAt: new Date(), updatedAt: new Date() })),
  );

  await db.collection('roles').insertMany(
    [
      {
        key: 'SUPER_ADMIN',
        name: 'Super Admin',
        permissions: ['cases.read', 'cases.write', 'research.read', 'billing.manage', 'admin.manage'],
      },
      {
        key: 'FIRM_ADMIN',
        name: 'Firm Admin',
        permissions: ['cases.read', 'cases.write', 'research.read', 'billing.manage'],
      },
      {
        key: 'LAWYER',
        name: 'Lawyer',
        permissions: ['cases.read', 'cases.write', 'research.read'],
      },
      {
        key: 'RESEARCHER',
        name: 'Researcher',
        permissions: ['research.read'],
      },
      {
        key: 'READ_ONLY_VIEWER',
        name: 'Read-only Viewer',
        permissions: ['cases.read'],
      },
    ].map((item) => ({ ...item, createdAt: new Date(), updatedAt: new Date() })),
  );

  const legal = await seedLegalData(db);

  const result = {
    reset: true,
    superAdmin: {
      email: superAdminEmail,
      password: superAdminPassword,
      roles: ['SUPER_ADMIN'],
    },
    legal,
  };

  console.log(JSON.stringify(result, null, 2));
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
