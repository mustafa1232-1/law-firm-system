/* eslint-disable no-console */
const mongoose = require('mongoose');

function numericArticle(value) {
  return Number.parseInt(String(value ?? '0').replace(/[^\d]/g, ''), 10) || 0;
}

function hasMojibake(value) {
  return /[ØÙ]/.test(String(value ?? ''));
}

function hasObviousTruncation(value) {
  const text = String(value ?? '').trim();
  return text.endsWith('...') || text.endsWith('…');
}

async function main() {
  const uri = process.env.MONGODB_URI || process.env.MONGO_URL || process.env.MONGO_PUBLIC_URL;
  if (!uri) {
    throw new Error('Missing MongoDB URI in env (MONGODB_URI/MONGO_URL/MONGO_PUBLIC_URL).');
  }

  await mongoose.connect(uri);
  const db = mongoose.connection.db;

  const lawDocs = await db
    .collection('law_documents')
    .find({}, { projection: { title: 1, lawNumber: 1 } })
    .toArray();

  const perLaw = [];
  for (const law of lawDocs) {
    const articles = await db
      .collection('law_articles')
      .find({ lawId: law._id }, { projection: { articleNumber: 1, text: 1 } })
      .toArray();

    perLaw.push({
      title: law.title,
      lawNumber: law.lawNumber,
      articlesCount: articles.length,
      maxArticleNumber: Math.max(0, ...articles.map((item) => numericArticle(item.articleNumber))),
      emptyTextCount: articles.filter((item) => !(item.text || '').trim()).length,
      shortTextCount: articles.filter((item) => (item.text || '').trim().length < 25).length,
      mojibakeCount: articles.filter((item) => hasMojibake(item.text)).length,
      truncationHintCount: articles.filter((item) => hasObviousTruncation(item.text)).length,
    });
  }

  const constitutionArticles = await db
    .collection('constitution_articles')
    .find({}, { projection: { articleNumber: 1, text: 1 } })
    .toArray();

  const constitution = {
    total: constitutionArticles.length,
    maxArticleNumber: Math.max(
      0,
      ...constitutionArticles.map((item) => numericArticle(item.articleNumber)),
    ),
    emptyTextCount: constitutionArticles.filter((item) => !(item.text || '').trim()).length,
    shortTextCount: constitutionArticles.filter((item) => (item.text || '').trim().length < 25)
      .length,
    mojibakeCount: constitutionArticles.filter((item) => hasMojibake(item.text)).length,
    truncationHintCount: constitutionArticles.filter((item) => hasObviousTruncation(item.text))
      .length,
  };

  const summary = {
    generatedAt: new Date().toISOString(),
    collections: {
      lawDocuments: lawDocs.length,
      lawArticles: perLaw.reduce((acc, item) => acc + item.articlesCount, 0),
      constitutionArticles: constitution.total,
    },
    perLaw,
    constitution,
    notes: [
      'This report checks structural integrity and obvious truncation indicators.',
      'It does not certify legal completeness against official gazette editions.',
    ],
  };

  console.log(JSON.stringify(summary, null, 2));
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
