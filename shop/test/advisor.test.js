'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { createApp } = require('../src/server');
const { runImport } = require('../src/importer');

const REAL_ROOT = path.resolve(__dirname, '..', '..'); // AGENTS repo root
const REAL_CATALOG = path.join(__dirname, '..', 'catalog');

async function withRealServer() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'shop-advisor-test-'));
  const dbPath = path.join(dir, 'shop.db');
  runImport({ rootDir: REAL_ROOT, catalogDir: REAL_CATALOG, dbPath });
  const app = createApp({ dbPath, publicDir: path.join(__dirname, '..', 'public'), catalogDir: REAL_CATALOG });
  return new Promise((resolve) => {
    const server = app.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      resolve({ base: `http://127.0.0.1:${port}`, close: () => new Promise((res) => server.close(res)) });
    });
  });
}

async function ask(base, body) {
  const res = await fetch(`${base}/api/advisor`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

// Contract table from ops/sprints/sprint-24-shop-berater-bundles.md § 6.
// The rules-as-data file (catalog/advisor-rules.json) is tested as a CONTRACT here:
// if a future edit to it silently changes recommendations, this must fail.
test('advisor contract: legacy -> intent-archaeologie in top3, legacy-rettung as primary bundle', async () => {
  const { base, close } = await withRealServer();
  try {
    const { status, body } = await ask(base, { q1: 'legacy', q3: 'readonly' });
    assert.equal(status, 200);
    assert.ok(body.recommendations.some((r) => r.name === 'intent-archaeologie'));
    assert.equal(body.primaryBundle?.slug, 'legacy-rettung');
  } finally {
    await close();
  }
});

test('advisor contract: release+qa -> test-luecken-kartograf and api-vertrags-waechter in top3, release-guard as primary bundle', async () => {
  const { base, close } = await withRealServer();
  try {
    const { status, body } = await ask(base, { q1: 'release', q2: 'qa', q3: 'readonly' });
    assert.equal(status, 200);
    const names = body.recommendations.map((r) => r.name);
    assert.ok(names.includes('test-luecken-kartograf'));
    assert.ok(names.includes('api-vertrags-waechter'));
    assert.equal(body.primaryBundle?.slug, 'release-guard');
  } finally {
    await close();
  }
});

test('advisor contract: security+security -> berechtigungs-roentgen top 1 or 2, security-audit as primary bundle', async () => {
  const { base, close } = await withRealServer();
  try {
    const { status, body } = await ask(base, { q1: 'security', q2: 'security', q3: 'egal' });
    assert.equal(status, 200);
    const idx = body.recommendations.findIndex((r) => r.name === 'berechtigungs-roentgen');
    assert.ok(idx === 0 || idx === 1, `expected top 1 or 2, got index ${idx}`);
    assert.equal(body.primaryBundle?.slug, 'security-audit');
  } finally {
    await close();
  }
});

test('advisor contract: neu-starten -> project-init in top3, verfuegbar', async () => {
  const { base, close } = await withRealServer();
  try {
    const { status, body } = await ask(base, { q1: 'neu-starten', q3: 'egal' });
    assert.equal(status, 200);
    const rec = body.recommendations.find((r) => r.name === 'project-init');
    assert.ok(rec);
    assert.equal(rec.status, 'verfuegbar');
  } finally {
    await close();
  }
});

test('advisor contract: prod+devops -> prod-spiegel and ausfall-simulant represented', async () => {
  const { base, close } = await withRealServer();
  try {
    const { status, body } = await ask(base, { q1: 'prod', q2: 'devops', q3: 'readonly' });
    assert.equal(status, 200);
    const names = body.recommendations.map((r) => r.name);
    assert.ok(names.includes('prod-spiegel') || names.includes('ausfall-simulant'));
  } finally {
    await close();
  }
});

test('advisor: risk filter zeroing out all candidates triggers the honest fallback', async () => {
  const { base, close } = await withRealServer();
  try {
    // neu-starten only matches project-init, which is schreibend-mit-freigabe -
    // filtering to read-only must empty the result and surface a fallback notice
    // instead of silently returning nothing.
    const { status, body } = await ask(base, { q1: 'neu-starten', q3: 'readonly' });
    assert.equal(status, 200);
    assert.ok(body.fallbackNotice, 'fallbackNotice must be set when the risk filter empties the candidate set');
    assert.ok(body.recommendations.every((r) => r.wouldFitButTouches));
  } finally {
    await close();
  }
});

test('advisor: q2 is optional', async () => {
  const { base, close } = await withRealServer();
  try {
    const { status, body } = await ask(base, { q1: 'legacy', q3: 'readonly' });
    assert.equal(status, 200);
    assert.equal(body.question2, null);
  } finally {
    await close();
  }
});

test('advisor: is deterministic - identical requests yield identical responses', async () => {
  const { base, close } = await withRealServer();
  try {
    const first = await ask(base, { q1: 'security', q2: 'security', q3: 'egal' });
    const second = await ask(base, { q1: 'security', q2: 'security', q3: 'egal' });
    assert.deepEqual(first.body, second.body);
  } finally {
    await close();
  }
});

test('advisor: rejects unknown option ids with 400', async () => {
  const { base, close } = await withRealServer();
  try {
    const { status, body } = await ask(base, { q1: 'phantasie', q3: 'readonly' });
    assert.equal(status, 400);
    assert.match(body.error, /Unbekannte Option/);
  } finally {
    await close();
  }
});

test('advisor: rejects a missing required field with 400', async () => {
  const { base, close } = await withRealServer();
  try {
    const { status, body } = await ask(base, { q3: 'readonly' });
    assert.equal(status, 400);
    assert.match(body.error, /erforderlich/);
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
