/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const decisionsPath = path.join(__dirname, '..', 'data', 'public', 'judicial_decisions.seed.json');

function hasBrokenText(value) {
  if (typeof value !== 'string') {
    return false;
  }
  return /[?]{3,}/.test(value);
}

function cleanArray(values, fallback = []) {
  if (!Array.isArray(values)) {
    return fallback;
  }
  const cleaned = values
    .map((value) => `${value ?? ''}`.trim())
    .filter(Boolean)
    .filter((value) => !hasBrokenText(value));
  return cleaned.length ? cleaned : fallback;
}

function sanitizeDecision(decision) {
  const number = `${decision.decisionNumber ?? '-'}`
    .replace(/[^\d/-]/g, '')
    .trim();
  const withFallback = { ...decision };

  if (hasBrokenText(withFallback.courtName)) {
    withFallback.courtName = 'محكمة عراقية';
  }
  if (hasBrokenText(withFallback.caseType)) {
    withFallback.caseType = 'مدنية';
  }
  if (hasBrokenText(withFallback.legalDomain)) {
    withFallback.legalDomain = 'قانون مدني';
  }
  if (hasBrokenText(withFallback.summary)) {
    withFallback.summary = `ملخص القرار رقم ${number || '-'} غير متاح بالكامل في المصدر الحالي ويحتاج مراجعة يدوية.`;
  }
  if (hasBrokenText(withFallback.fullText)) {
    withFallback.fullText =
      'النص الكامل غير متاح في بيانات البذور الحالية. يرجى الرجوع إلى المصدر الرسمي للقرار قبل الاعتماد القانوني.';
  }
  if (hasBrokenText(withFallback.factsSummary)) {
    withFallback.factsSummary =
      'وقائع القرار غير مكتملة في المصدر الحالي وتحتاج تدقيقاً من المرجع الرسمي.';
  }
  if (hasBrokenText(withFallback.reasoningSummary)) {
    withFallback.reasoningSummary =
      'تسبيب القرار غير مكتمل في هذه النسخة من البيانات ويحتاج مراجعة يدوية.';
  }
  if (hasBrokenText(withFallback.outcome)) {
    withFallback.outcome = 'نتيجة الحكم غير محددة في السجل الحالي.';
  }

  withFallback.extractedCitations = cleanArray(withFallback.extractedCitations, []);
  withFallback.constitutionalReferences = cleanArray(withFallback.constitutionalReferences, []);
  withFallback.legalArticleReferences = cleanArray(withFallback.legalArticleReferences, []);
  withFallback.legalKeywords = cleanArray(withFallback.legalKeywords, ['قرار قضائي', 'اجتهاد']);
  withFallback.tags = cleanArray(withFallback.tags, ['needs-review']);

  return withFallback;
}

function main() {
  const decisions = JSON.parse(fs.readFileSync(decisionsPath, 'utf8'));
  if (!Array.isArray(decisions)) {
    throw new Error('judicial decisions seed must be an array');
  }

  let touched = 0;
  const sanitized = decisions.map((decision) => {
    const before = JSON.stringify(decision);
    const cleaned = sanitizeDecision(decision);
    const after = JSON.stringify(cleaned);
    if (before !== after) {
      touched += 1;
    }
    return cleaned;
  });

  const remainingBroken = sanitized.filter((decision) =>
    /[?]{3,}/.test(JSON.stringify(decision)),
  ).length;

  fs.writeFileSync(decisionsPath, `${JSON.stringify(sanitized, null, 2)}\n`, 'utf8');

  console.log(
    JSON.stringify(
      {
        file: decisionsPath,
        total: decisions.length,
        sanitized: touched,
        remainingBroken,
      },
      null,
      2,
    ),
  );

  if (remainingBroken > 0) {
    process.exitCode = 1;
  }
}

main();
