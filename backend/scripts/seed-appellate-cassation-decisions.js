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

async function main() {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    throw new Error('MONGODB_URI is required');
  }

  const seedPath = path.join(
    __dirname,
    '..',
    'data',
    'public',
    'judicial_decisions_appellate_cassation.seed.json',
  );
  if (!fs.existsSync(seedPath)) {
    throw new Error(`Seed file not found: ${seedPath}`);
  }

  const raw = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
  if (!Array.isArray(raw)) {
    throw new Error('Seed file must be an array');
  }

  await mongoose.connect(uri);
  const col = mongoose.connection.db.collection('judicial_decisions');

  const operations = raw
    .filter((item) => `${item?.source ?? ''}`.trim())
    .map((item) => ({
      updateOne: {
        filter: { source: item.source },
        update: {
          $set: {
            ...item,
            decisionDate: new Date(item.decisionDate),
            publicationDate: item.publicationDate
              ? new Date(item.publicationDate)
              : undefined,
            extractedCitations: item.extractedCitations ?? [],
            constitutionalReferences: item.constitutionalReferences ?? [],
            legalArticleReferences: item.legalArticleReferences ?? [],
            legalKeywords: item.legalKeywords ?? [],
            tags: item.tags ?? [],
            similarityEmbedding: [],
            normalizedText: normalizeArabic(
              `${item.summary ?? ''} ${item.fullText ?? ''}`,
            ),
            reviewStatus: item.reviewStatus ?? 'pending',
            ingestionStatus: item.ingestionStatus ?? 'published',
          },
          $setOnInsert: {
            createdAt: new Date(),
          },
        },
        upsert: true,
      },
    }));

  if (!operations.length) {
    console.log(JSON.stringify({ inserted: 0, updated: 0, totalSeed: 0 }, null, 2));
    await mongoose.disconnect();
    return;
  }

  const result = await col.bulkWrite(operations, { ordered: false });
  console.log(
    JSON.stringify(
      {
        totalSeed: raw.length,
        inserted: result.upsertedCount ?? 0,
        updated: result.modifiedCount ?? 0,
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
