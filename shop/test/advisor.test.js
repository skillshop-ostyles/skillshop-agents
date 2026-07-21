'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { withServer, withImportedDb, postJson } = require('./helpers');

// Dedicated fixture (test/fixture/advisor/) - NOT the real shop/catalog. This
// keeps the advisor algorithm tests stable across catalog curation changes
// (SHOP-BIBEL/Sprint-25: "Tests haengen NICHT am echten Katalog"). Terms:
//   skill-alpha:  usecase=alpha, taetigkeit=dev,        risiko=read-only
//   skill-alpha2: usecase=alpha, thema=theta, taetigkeit=dev+ops, risiko=read-only
//   skill-write:  usecase=beta,                         risiko=schreibend-mit-freigabe
// bundle-a covers [skill-alpha, skill-alpha2].
const ADVISOR_ROOT = path.join(__dirname, 'fixture', 'advisor', 'root');
const ADVISOR_CATALOG = path.join(__dirname, 'fixture', 'advisor', 'catalog');

function advisorServer() {
  const dbPath = withImportedDb(ADVISOR_ROOT, ADVISOR_CATALOG);
  return withServer({ dbPath, catalogDir: ADVISOR_CATALOG });
}

test('advisor: compound q1 term match scores higher than a single-term match', async () => {
  const { base, close } = await advisorServer();
  try {
    // q1 "alpha-compound" matches usecase+thema for skill-alpha2 (+4) but only
    // usecase for skill-alpha (+2) - alpha2 must rank first.
    const { status, body } = await postJson(base, '/api/advisor', { q1: 'alpha-compound', q3: 'egal' });
    assert.equal(status, 200);
    assert.deepEqual(body.recommendations.map((r) => r.name), ['skill-alpha2', 'skill-alpha']);
    assert.equal(body.recommendations[0].score, 4);
    assert.equal(body.recommendations[1].score, 2);
  } finally {
    await close();
  }
});

test('advisor: optional q2 adds weight without being required', async () => {
  const { base, close } = await advisorServer();
  try {
    const withQ2 = await postJson(base, '/api/advisor', { q1: 'alpha-compound', q2: 'ops', q3: 'egal' });
    // only skill-alpha2 has taetigkeit=ops -> +1 there, skill-alpha unaffected
    assert.equal(withQ2.body.recommendations.find((r) => r.name === 'skill-alpha2').score, 5);
    assert.equal(withQ2.body.recommendations.find((r) => r.name === 'skill-alpha').score, 2);

    const withoutQ2 = await postJson(base, '/api/advisor', { q1: 'alpha-compound', q3: 'egal' });
    assert.equal(withoutQ2.body.question2, null);
  } finally {
    await close();
  }
});

test('advisor: bundle becomes the primary recommendation once it covers >= 2 of the top 3', async () => {
  const { base, close } = await advisorServer();
  try {
    const { body } = await postJson(base, '/api/advisor', { q1: 'alpha-compound', q3: 'egal' });
    assert.equal(body.primaryBundle?.slug, 'bundle-a');
  } finally {
    await close();
  }
});

test('advisor: hard risk filter empties the candidate set and triggers the honest fallback', async () => {
  const { base, close } = await advisorServer();
  try {
    const { body } = await postJson(base, '/api/advisor', { q1: 'beta', q3: 'readonly' });
    // skill-write is the only usecase=beta match, but it's schreibend-mit-freigabe -
    // filtering to read-only empties the strict result. The fallback must still
    // surface it (marked wouldFitButTouches), never a silent empty response.
    assert.ok(body.fallbackNotice, 'fallbackNotice must explain the filtered-out result');
    assert.deepEqual(body.recommendations.map((r) => r.name), ['skill-write']);
    assert.equal(body.recommendations[0].wouldFitButTouches, true);
  } finally {
    await close();
  }
});

test('advisor: without the risk filter, skill-write is a normal candidate', async () => {
  const { base, close } = await advisorServer();
  try {
    const { body } = await postJson(base, '/api/advisor', { q1: 'beta', q3: 'egal' });
    assert.deepEqual(body.recommendations.map((r) => r.name), ['skill-write']);
    assert.equal(body.recommendations[0].wouldFitButTouches, false);
    assert.equal(body.fallbackNotice, null);
  } finally {
    await close();
  }
});

test('advisor: is deterministic - identical requests yield identical responses', async () => {
  const { base, close } = await advisorServer();
  try {
    const first = await postJson(base, '/api/advisor', { q1: 'alpha-compound', q2: 'dev', q3: 'readonly' });
    const second = await postJson(base, '/api/advisor', { q1: 'alpha-compound', q2: 'dev', q3: 'readonly' });
    assert.deepEqual(first.body, second.body);
  } finally {
    await close();
  }
});

test('advisor: rejects unknown option ids with 400', async () => {
  const { base, close } = await advisorServer();
  try {
    const { status, body } = await postJson(base, '/api/advisor', { q1: 'phantasie', q3: 'readonly' });
    assert.equal(status, 400);
    assert.match(body.error, /Unbekannte Option/);
  } finally {
    await close();
  }
});

test('advisor: rejects a missing required field with 400', async () => {
  const { base, close } = await advisorServer();
  try {
    const { status, body } = await postJson(base, '/api/advisor', { q3: 'readonly' });
    assert.equal(status, 400);
    assert.match(body.error, /erforderlich/);
  } finally {
    await close();
  }
});

test('GET /api/advisor/rules returns the question set', async () => {
  const { base, close } = await advisorServer();
  try {
    const res = await fetch(`${base}/api/advisor/rules`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.ok(body.q1 && body.q2 && body.q3);
    assert.ok(body.q1.options.some((o) => o.id === 'alpha-compound'));
  } finally {
    await close();
  }
});

test('advisor rules validation rejects a rules file referencing an unknown term', () => {
  const { loadAdvisorRules, loadTaxonomy, ImportError } = require('../src/importer');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'shop-advisor-badterm-'));
  fs.writeFileSync(
    path.join(dir, 'taxonomy.json'),
    JSON.stringify({ usecase: ['a'], thema: [], stichwort: [], ziel: [], branche: [], taetigkeit: [], level: [], risiko: [] })
  );
  fs.writeFileSync(
    path.join(dir, 'advisor-rules.json'),
    JSON.stringify({
      q1: { question: 'q', required: true, options: [{ id: 'x', label: 'X', terms: { usecase: ['does-not-exist'] } }] },
      q2: { question: 'q', required: false, options: [{ id: 'x', label: 'X' }] },
      q3: { question: 'q', required: true, options: [{ id: 'x', label: 'X', filter: null }] },
    })
  );
  const taxonomy = loadTaxonomy(dir);
  assert.throws(() => loadAdvisorRules(dir, taxonomy), ImportError);
});
