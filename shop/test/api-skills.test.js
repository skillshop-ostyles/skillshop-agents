'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { tmpDbPath, withServer, withImportedDb } = require('./helpers');

const FIXTURE_ROOT = path.join(__dirname, 'fixture', 'root');
const CATALOG_OK = path.join(__dirname, 'fixture', 'catalog');

test('GET /api/skills returns 503 with clear error when db is missing', async () => {
  const dbPath = tmpDbPath('shop-server-nodb-'); // never created
  const { base, close } = await withServer({ dbPath });
  try {
    const res = await fetch(`${base}/api/skills`);
    assert.equal(res.status, 503);
    const body = await res.json();
    assert.match(body.error, /Datenbank/);
  } finally {
    await close();
  }
});

test('GET /api/skills filters: AND across dimensions, OR within a dimension', async () => {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  const { base, close } = await withServer({ dbPath });
  try {
    const all = await (await fetch(`${base}/api/skills`)).json();
    assert.equal(all.length, 3);

    const byUsecase = await (await fetch(`${base}/api/skills?usecase=testen`)).json();
    assert.equal(byUsecase.length, 3, 'alle Demo-Skills teilen usecase=testen');

    const byUnknownTerm = await (await fetch(`${base}/api/skills?usecase=does-not-exist`)).json();
    assert.equal(byUnknownTerm.length, 0);

    const byQ = await (await fetch(`${base}/api/skills?q=Demo+A`)).json();
    assert.deepEqual(byQ.map((s) => s.name), ['demo-skill-a']);
  } finally {
    await close();
  }
});

test('GET /api/skills sorts verfuegbar before in-entwicklung, then alphabetically', async () => {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  const { base, close } = await withServer({ dbPath });
  try {
    const rows = await (await fetch(`${base}/api/skills`)).json();
    assert.deepEqual(rows.map((r) => r.name), ['demo-skill-a', 'demo-skill-b', 'demo-skill-c']);
    assert.deepEqual(rows.map((r) => r.status), ['verfuegbar', 'verfuegbar', 'in-entwicklung']);
  } finally {
    await close();
  }
});

test('GET /api/skills escapes FTS special characters without 500', async () => {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  const { base, close } = await withServer({ dbPath });
  try {
    const res = await fetch(`${base}/api/skills?${new URLSearchParams({ q: '"weird" AND OR NOT (' }).toString()}`);
    assert.equal(res.status, 200);
  } finally {
    await close();
  }
});

test('GET /api/skills/:name returns bundles and related, 404 for unknown', async () => {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  const { base, close } = await withServer({ dbPath });
  try {
    const res = await fetch(`${base}/api/skills/demo-skill-b`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.name, 'demo-skill-b');
    assert.deepEqual(body.bundles.map((b) => b.slug), ['demo-bundle']);
    assert.deepEqual(body.related.map((r) => r.name), ['demo-skill-a']);
    assert.equal(body.related[0].status, 'verfuegbar');

    const missing = await fetch(`${base}/api/skills/phantasie-skill`);
    assert.equal(missing.status, 404);
    const missingBody = await missing.json();
    assert.match(missingBody.error, /nicht gefunden/);
  } finally {
    await close();
  }
});

test('GET /api/facets excludes zero-count terms and respects other-dimension filters', async () => {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  const { base, close } = await withServer({ dbPath });
  try {
    const facets = await (await fetch(`${base}/api/facets`)).json();
    assert.deepEqual(facets.usecase, [{ term: 'testen', count: 3 }]);

    const filtered = await (await fetch(`${base}/api/facets?q=Demo+A`)).json();
    assert.deepEqual(filtered.usecase, [{ term: 'testen', count: 1 }]);
  } finally {
    await close();
  }
});

test('GET /api/facets returns 503 with clear error when db is missing', async () => {
  const dbPath = tmpDbPath('shop-facets-nodb-');
  const { base, close } = await withServer({ dbPath });
  try {
    const res = await fetch(`${base}/api/facets`);
    assert.equal(res.status, 503);
  } finally {
    await close();
  }
});

test('GET /api/bundles lists all bundles with status aggregates', async () => {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  const { base, close } = await withServer({ dbPath });
  try {
    const res = await fetch(`${base}/api/bundles`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.deepEqual(body.map((b) => b.slug), ['demo-bundle']);
    assert.equal(body[0].status.verfuegbar, 2);
    assert.equal(body[0].status.total, 2);
  } finally {
    await close();
  }
});

test('GET /api/bundles returns 503 with clear error when db is missing', async () => {
  const dbPath = tmpDbPath('shop-bundles-nodb-');
  const { base, close } = await withServer({ dbPath });
  try {
    const res = await fetch(`${base}/api/bundles`);
    assert.equal(res.status, 503);
  } finally {
    await close();
  }
});

test('GET /api/bundles/:slug returns status aggregate and skills, 404 for unknown', async () => {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  const { base, close } = await withServer({ dbPath });
  try {
    const res = await fetch(`${base}/api/bundles/demo-bundle`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.status.verfuegbar, 2);
    assert.equal(body.status.total, 2);
    assert.deepEqual(body.skills.map((s) => s.name).sort(), ['demo-skill-a', 'demo-skill-b']);

    const missing = await fetch(`${base}/api/bundles/phantasie-bundle`);
    assert.equal(missing.status, 404);
  } finally {
    await close();
  }
});

test('static frontend files are served', async () => {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  const { base, close } = await withServer({ dbPath });
  try {
    const res = await fetch(`${base}/index.html`);
    assert.equal(res.status, 200);
    const text = await res.text();
    assert.match(text, /Skill is the hero/);
  } finally {
    await close();
  }
});
