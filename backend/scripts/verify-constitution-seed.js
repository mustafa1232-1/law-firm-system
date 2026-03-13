/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const SEED_PATH = path.join(__dirname, '..', 'data', 'public', 'constitution_articles.seed.json');

function containsBrokenText(value) {
  const text = `${value ?? ''}`;
  return /[\u00D8\u00D9\u00C3\u00C2]|[?]{3,}/.test(text);
}

function main() {
  const payload = JSON.parse(fs.readFileSync(SEED_PATH, 'utf8'));
  if (!Array.isArray(payload)) {
    throw new Error('constitution seed must be an array');
  }

  const orders = payload
    .map((item) => Number(item.articleOrder ?? `${item.articleNumber ?? ''}`.replace(/[^\d]/g, '')))
    .filter((value) => Number.isFinite(value) && value > 0)
    .sort((a, b) => a - b);

  const uniqueOrders = [...new Set(orders)];
  const missing = [];
  for (let i = 1; i <= 144; i += 1) {
    if (!uniqueOrders.includes(i)) {
      missing.push(i);
    }
  }

  const empty = payload.filter((item) => !`${item.text ?? ''}`.trim()).map((item) => item.articleNumber);
  const broken = payload
    .filter((item) => containsBrokenText(item.text) || containsBrokenText(item.chapter) || containsBrokenText(item.section))
    .map((item) => item.articleNumber);
  const withoutParagraphs = payload
    .filter((item) => !Array.isArray(item.paragraphs) || item.paragraphs.length === 0)
    .map((item) => item.articleNumber);

  const report = {
    path: SEED_PATH,
    count: payload.length,
    min: uniqueOrders[0] ?? null,
    max: uniqueOrders[uniqueOrders.length - 1] ?? null,
    missing,
    emptyArticles: empty,
    brokenEncodingArticles: broken,
    noParagraphArticles: withoutParagraphs,
    valid: payload.length === 144 && missing.length === 0 && empty.length === 0 && broken.length === 0,
  };

  console.log(JSON.stringify(report, null, 2));
  if (!report.valid) {
    process.exitCode = 1;
  }
}

main();
