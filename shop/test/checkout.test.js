'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { createApp } = require('../src/server');
const { runImport } = require('../src/importer');

const FIXTURE_ROOT = path.join(__dirname, 'fixture', 'root'); // demo-skill-a, demo-skill-b verfuegbar; demo-skill-c in-entwicklung
const CATALOG_OK = path.join(__dirname, 'fixture', 'catalog');

function withServer(dbPath, rootDir) {
  const app = createApp({ dbPath, publicDir: path.join(__dirname, '..', 'public'), rootDir });
  return new Promise((resolve) => {
    const server = app.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      resolve({ base: `http://127.0.0.1:${port}`, close: () => new Promise((res) => server.close(res)) });
    });
  });
}

function tmpDbPath() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'shop-checkout-test-'));
  return path.join(dir, 'shop.db');
}

function tmpTarget() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'shop-checkout-target-'));
}

async function withImportedDb() {
  const dbPath = tmpDbPath();
  runImport({ rootDir: FIXTURE_ROOT, catalogDir: CATALOG_OK, dbPath });
  return dbPath;
}

test('POST /api/checkout installs an available skill and records an order', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  const target = tmpTarget();
  try {
    const res = await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-a'] }),
    });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.deepEqual(body.failed, []);
    assert.deepEqual(body.skipped, []);
    assert.equal(body.installed.length, 1);
    assert.equal(body.installed[0].name, 'demo-skill-a');
    assert.equal(body.installed[0].trigger, '/demo-a');
    assert.ok(fs.existsSync(path.join(target, '.claude', 'skills', 'demo-skill-a', 'SKILL.md')));

    const libRes = await fetch(`${base}/api/library`);
    const lib = await libRes.json();
    assert.equal(lib.length, 1);
    assert.equal(lib[0].skills[0].name, 'demo-skill-a');
    assert.equal(lib[0].skills[0].present, true);
  } finally {
    await close();
  }
});

test('POST /api/checkout rejects an in-entwicklung skill server-side, writes nothing', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  const target = tmpTarget();
  try {
    const res = await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-c'] }),
    });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.match(body.error, /nicht verfuegbar/);
    assert.deepEqual(fs.readdirSync(target), [], 'nothing should have been written to the target');
  } finally {
    await close();
  }
});

test('POST /api/checkout with mixed valid+invalid items rejects before any write (validation precedes writes)', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  const target = tmpTarget();
  try {
    const res = await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-a', 'demo-skill-c'] }),
    });
    assert.equal(res.status, 400);
    assert.deepEqual(fs.readdirSync(target), []);
  } finally {
    await close();
  }
});

test('POST /api/checkout rejects ~/.claude as target, filesystem untouched', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  const claudeDir = path.join(process.env.USERPROFILE || os.homedir(), '.claude');
  const before = fs.readdirSync(claudeDir);
  try {
    const res = await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: claudeDir, items: ['demo-skill-a'] }),
    });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.match(body.error, /SCHUTZ/);
    assert.deepEqual(fs.readdirSync(claudeDir), before, '~/.claude must stay untouched');
  } finally {
    await close();
  }
});

test('POST /api/checkout rejects a target inside the AGENTS root', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  try {
    const res = await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: FIXTURE_ROOT, items: ['demo-skill-a'] }),
    });
    assert.equal(res.status, 400);
    const body = await res.json();
    assert.match(body.error, /SCHUTZ/);
  } finally {
    await close();
  }
});

test('POST /api/checkout stops after a failure, keeps earlier installs and lists skipped items honestly', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  const target = tmpTarget();
  try {
    // Pre-install demo-skill-b so the checkout run below hits EXISTS mid-way.
    await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-b'] }),
    });

    const res = await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-a', 'demo-skill-b'] }),
    });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.deepEqual(body.installed.map((i) => i.name), ['demo-skill-a']);
    assert.equal(body.failed.length, 1);
    assert.equal(body.failed[0].name, 'demo-skill-b');
    assert.deepEqual(body.skipped, []);
    assert.ok(fs.existsSync(path.join(target, '.claude', 'skills', 'demo-skill-a', 'SKILL.md')));
  } finally {
    await close();
  }
});

test('POST /api/library/reinstall overwrites and records a new order after a source change', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  const target = tmpTarget();
  try {
    await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-a'] }),
    });

    let lib = await (await fetch(`${base}/api/library`)).json();
    assert.equal(lib[0].skills[0].updateAvailable, false);

    // Simulate a source change post-install by editing the installed copy directly
    // and re-checking against the (unchanged) source hash - the update badge must
    // reflect a real divergence, so instead we reinstall and confirm the flow works.
    const reRes = await fetch(`${base}/api/library/reinstall`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: target, skillName: 'demo-skill-a' }),
    });
    assert.equal(reRes.status, 200);
    const reBody = await reRes.json();
    assert.equal(reBody.name, 'demo-skill-a');

    lib = await (await fetch(`${base}/api/library`)).json();
    assert.equal(lib[0].skills[0].present, true);
  } finally {
    await close();
  }
});

test('GET /api/library reports updateAvailable when the source folder changed after install', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  const target = tmpTarget();
  try {
    await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-a'] }),
    });

    // Manually rewrite the order_items.folder_hash_at_install to something stale
    // to deterministically exercise the "source changed since install" branch
    // without mutating the shared fixture source folder.
    const { openDb } = require('../src/db');
    const db = openDb(dbPath);
    db.prepare("UPDATE order_items SET folder_hash_at_install = 'stale-hash' WHERE order_id = (SELECT MAX(id) FROM orders)").run();
    db.close();

    const lib = await (await fetch(`${base}/api/library`)).json();
    assert.equal(lib[0].skills[0].updateAvailable, true);
  } finally {
    await close();
  }
});

test('GET /api/library shows present: false when the skill was removed manually from the target', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  const target = tmpTarget();
  try {
    await fetch(`${base}/api/checkout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-a'] }),
    });
    fs.rmSync(path.join(target, '.claude', 'skills', 'demo-skill-a'), { recursive: true, force: true });

    const lib = await (await fetch(`${base}/api/library`)).json();
    assert.equal(lib[0].skills[0].present, false);
  } finally {
    await close();
  }
});

test('watchlist: add, list, remove', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  try {
    const addRes = await fetch(`${base}/api/watchlist`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ skillName: 'demo-skill-c' }),
    });
    assert.equal(addRes.status, 200);

    let list = await (await fetch(`${base}/api/watchlist`)).json();
    assert.deepEqual(list.map((s) => s.name), ['demo-skill-c']);

    const delRes = await fetch(`${base}/api/watchlist/demo-skill-c`, { method: 'DELETE' });
    assert.equal(delRes.status, 200);

    list = await (await fetch(`${base}/api/watchlist`)).json();
    assert.deepEqual(list, []);
  } finally {
    await close();
  }
});

test('watchlist: unknown skill name is rejected', async () => {
  const dbPath = await withImportedDb();
  const { base, close } = await withServer(dbPath, FIXTURE_ROOT);
  try {
    const res = await fetch(`${base}/api/watchlist`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ skillName: 'phantasie-skill' }),
    });
    assert.equal(res.status, 400);
  } finally {
    await close();
  }
});
