'use strict';

const { attachTerms, CARD_FIELDS } = require('./catalogQuery');

class AdvisorError extends Error {}

function findOption(question, optionId) {
  return question.options.find((o) => o.id === optionId);
}

/** Counts how many (dimension, term) pairs of termMap a skill's terms satisfy. */
function countMatches(skillTerms, termMap) {
  if (!termMap) return 0;
  let n = 0;
  for (const [dim, terms] of Object.entries(termMap)) {
    const skillDimTerms = skillTerms[dim] || [];
    for (const term of terms) {
      if (skillDimTerms.includes(term)) n += 1;
    }
  }
  return n;
}

function passesFilter(skillTerms, filterMap) {
  if (!filterMap) return true;
  for (const [dim, terms] of Object.entries(filterMap)) {
    const skillDimTerms = skillTerms[dim] || [];
    if (!terms.some((t) => skillDimTerms.includes(t))) return false;
  }
  return true;
}

function sortSkills(a, b) {
  if (b.score !== a.score) return b.score - a.score;
  const statusRank = (s) => (s.status === 'verfuegbar' ? 0 : 1);
  if (statusRank(a) !== statusRank(b)) return statusRank(a) - statusRank(b);
  return a.name.localeCompare(b.name);
}

function reasonFor(q1Option, skill) {
  return `Weil dich "${q1Option.label}" drückt: ${skill.claim}`;
}

/**
 * Deterministic, rule-based recommendation. No LLM call (SHOP-BIBEL/Sprint-24:
 * Phase 1 bewusst deterministisch) - same input always yields the same output.
 *
 * @param {import('better-sqlite3').Database} db
 * @param {object} rules from loadAdvisorRules()
 * @param {{q1: string, q2?: string, q3: string}} answers
 * @returns {object} recommendation payload (shape documented inline)
 */
function recommend(db, rules, answers) {
  const q1Option = findOption(rules.q1, answers.q1);
  if (!q1Option) throw new AdvisorError(`Unbekannte Option fuer q1: '${answers.q1}'`);
  let q2Option = null;
  if (answers.q2) {
    q2Option = findOption(rules.q2, answers.q2);
    if (!q2Option) throw new AdvisorError(`Unbekannte Option fuer q2: '${answers.q2}'`);
  }
  const q3Option = findOption(rules.q3, answers.q3);
  if (!q3Option) throw new AdvisorError(`Unbekannte Option fuer q3: '${answers.q3}'`);

  const allSkills = attachTerms(db, db.prepare(`SELECT ${CARD_FIELDS} FROM skills s`).all());

  // C4: Bewusste Gewichtung. Frage 1 ("Was schmerzt?") ist die Kernabsicht und
  // zaehlt DOPPELT (x2) pro Term-Treffer; Frage 2 (Kontext, optional) ist nur ein
  // Feinschliff und zaehlt EINFACH (x1). Dadurch dominiert immer der Haupt-Schmerz,
  // der Kontext verschiebt nur die Reihenfolge innerhalb gleich-relevanter Skills.
  // Diese Asymmetrie ist Vertrag (test/advisor.test.js kodiert +2/+1).
  const scoreAll = (skills) => skills.map((s) => ({
    ...s,
    score: 2 * countMatches(s.terms, q1Option.terms) + (q2Option ? countMatches(s.terms, q2Option.terms) : 0),
  }));

  const unfiltered = scoreAll(allSkills).filter((s) => s.score > 0).sort(sortSkills);
  const filtered = unfiltered.filter((s) => passesFilter(s.terms, q3Option.filter));

  let candidates = filtered;
  let fallbackNotice = null;
  if (filtered.length === 0 && unfiltered.length > 0) {
    fallbackNotice = q3Option.filter
      ? `Fuer "${q3Option.label}" gibt es hier noch nichts - das aendert sich. Die naechstbeste Empfehlung wuerde passen, fasst aber auch an.`
      : 'Aktuell gibt es dafuer noch keine Empfehlung.';
    candidates = unfiltered.slice(0, 3).map((s) => ({ ...s, wouldFitButTouches: true }));
  }

  const top3 = candidates.slice(0, 3);
  const topNames = new Set(top3.map((s) => s.name));

  const bundles = db.prepare('SELECT id, slug, title, claim FROM bundles').all();
  let primaryBundle = null;
  let bestCoverage = 1; // must cover >= 2 of the top 3 to become the primary recommendation
  for (const bundle of bundles) {
    const bundleSkillNames = db
      .prepare('SELECT s.name AS name FROM bundle_skills bs JOIN skills s ON s.id = bs.skill_id WHERE bs.bundle_id = ?')
      .all(bundle.id)
      .map((r) => r.name);
    const coverage = bundleSkillNames.filter((n) => topNames.has(n)).length;
    if (coverage > bestCoverage || (coverage === bestCoverage && primaryBundle && bundle.slug < primaryBundle.slug)) {
      bestCoverage = coverage;
      primaryBundle = { slug: bundle.slug, title: bundle.title, claim: bundle.claim, coverage };
    }
  }

  return {
    question1: { id: q1Option.id, label: q1Option.label },
    question2: q2Option ? { id: q2Option.id, label: q2Option.label } : null,
    question3: { id: q3Option.id, label: q3Option.label },
    recommendations: top3.map((s) => ({
      name: s.name,
      claim: s.claim,
      trigger: s.trigger,
      status: s.status,
      score: s.score,
      reason: reasonFor(q1Option, s),
      wouldFitButTouches: !!s.wouldFitButTouches,
    })),
    primaryBundle,
    empty: top3.length === 0,
    fallbackNotice,
  };
}

module.exports = { AdvisorError, recommend };
