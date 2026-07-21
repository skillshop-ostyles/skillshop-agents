'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { openDb } = require('../src/db');
const { tmpDir, withServer, withImportedDb, postJson } = require('./helpers');

const FIXTURE_ROOT = path.join(__dirname, 'fixture', 'root'); // demo-skill-a, demo-skill-b verfuegbar; demo-skill-c in-entwicklung
const CATALOG_OK = path.join(__dirname, 'fixture', 'catalog');

function importedServer() {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  return withServer({ dbPath, rootDir: FIXTURE_ROOT }).then((server) => ({ ...server, dbPath }));
}

test('POST /api/checkout installs an available skill and records an order', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    const { status, body } = await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-a'] });
    assert.equal(status, 200);
    assert.deepEqual(body.failed, []);
    assert.deepEqual(body.skipped, []);
    assert.equal(body.installed.length, 1);
    assert.equal(body.installed[0].name, 'demo-skill-a');
    assert.equal(body.installed[0].trigger, '/demo-a');
    assert.ok(fs.existsSync(path.join(target, '.claude', 'skills', 'demo-skill-a', 'SKILL.md')));

    const lib = await (await fetch(`${base}/api/library`)).json();
    assert.equal(lib.length, 1);
    assert.equal(lib[0].skills[0].name, 'demo-skill-a');
    assert.equal(lib[0].skills[0].present, true);
  } finally {
    await close();
  }
});

test('POST /api/checkout rejects an in-entwicklung skill server-side, writes nothing', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    const { status, body } = await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-c'] });
    assert.equal(status, 400);
    assert.match(body.error, /nicht verfuegbar/);
    assert.deepEqual(fs.readdirSync(target), [], 'nothing should have been written to the target');
  } finally {
    await close();
  }
});

test('POST /api/checkout rejects an unknown skill name', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    const { status, body } = await postJson(base, '/api/checkout', { targetPath: target, items: ['phantasie-skill'] });
    assert.equal(status, 400);
    assert.match(body.error, /unbekannt/);
  } finally {
    await close();
  }
});

test('POST /api/checkout rejects a missing targetPath', async () => {
  const { base, close } = await importedServer();
  try {
    const { status, body } = await postJson(base, '/api/checkout', { items: ['demo-skill-a'] });
    assert.equal(status, 400);
    assert.match(body.error, /targetPath/);
  } finally {
    await close();
  }
});

test('POST /api/checkout rejects missing or empty items', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    const missing = await postJson(base, '/api/checkout', { targetPath: target });
    assert.equal(missing.status, 400);
    const empty = await postJson(base, '/api/checkout', { targetPath: target, items: [] });
    assert.equal(empty.status, 400);
  } finally {
    await close();
  }
});

test('POST /api/checkout with mixed valid+invalid items rejects before any write (validation precedes writes)', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    const { status } = await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-a', 'demo-skill-c'] });
    assert.equal(status, 400);
    assert.deepEqual(fs.readdirSync(target), []);
  } finally {
    await close();
  }
});

test('POST /api/checkout rejects ~/.claude as target, filesystem untouched', async () => {
  const { base, close } = await importedServer();
  const claudeDir = path.join(process.env.USERPROFILE || os.homedir(), '.claude');
  const before = fs.readdirSync(claudeDir);
  try {
    const { status, body } = await postJson(base, '/api/checkout', { targetPath: claudeDir, items: ['demo-skill-a'] });
    assert.equal(status, 400);
    assert.match(body.error, /SCHUTZ/);
    assert.deepEqual(fs.readdirSync(claudeDir), before, '~/.claude must stay untouched');
  } finally {
    await close();
  }
});

test('POST /api/checkout rejects a target inside the AGENTS root', async () => {
  const { base, close } = await importedServer();
  try {
    const { status, body } = await postJson(base, '/api/checkout', { targetPath: FIXTURE_ROOT, items: ['demo-skill-a'] });
    assert.equal(status, 400);
    assert.match(body.error, /SCHUTZ/);
  } finally {
    await close();
  }
});

test('POST /api/checkout stops after a failure, keeps earlier installs and lists skipped items honestly', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    // Pre-install demo-skill-b so the checkout run below hits EXISTS mid-way.
    await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-b'] });

    const { status, body } = await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-a', 'demo-skill-b'] });
    assert.equal(status, 200);
    assert.deepEqual(body.installed.map((i) => i.name), ['demo-skill-a']);
    assert.equal(body.failed.length, 1);
    assert.equal(body.failed[0].name, 'demo-skill-b');
    assert.deepEqual(body.skipped, []);
    assert.ok(fs.existsSync(path.join(target, '.claude', 'skills', 'demo-skill-a', 'SKILL.md')));
  } finally {
    await close();
  }
});

test('POST /api/library/reinstall overwrites and records a new order', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-a'] });

    let lib = await (await fetch(`${base}/api/library`)).json();
    assert.equal(lib[0].skills[0].updateAvailable, false);

    const { status, body } = await postJson(base, '/api/library/reinstall', { targetPath: target, skillName: 'demo-skill-a' });
    assert.equal(status, 200);
    assert.equal(body.name, 'demo-skill-a');

    lib = await (await fetch(`${base}/api/library`)).json();
    assert.equal(lib[0].skills[0].present, true);
  } finally {
    await close();
  }
});

test('POST /api/library/reinstall rejects an unknown skill name', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-a'] });
    const { status, body } = await postJson(base, '/api/library/reinstall', { targetPath: target, skillName: 'phantasie-skill' });
    assert.equal(status, 400);
    assert.match(body.error, /unbekannt/);
  } finally {
    await close();
  }
});

test('POST /api/library/reinstall rejects a target that is not in the library yet', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-'); // exists on disk, but was never checked out into
  try {
    const { status, body } = await postJson(base, '/api/library/reinstall', { targetPath: target, skillName: 'demo-skill-a' });
    assert.equal(status, 400);
    assert.match(body.error, /Bibliothek/);
  } finally {
    await close();
  }
});

test('GET /api/library reports updateAvailable when the source folder changed after install', async () => {
  const { base, close, dbPath } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-a'] });

    const libBefore = await (await fetch(`${base}/api/library`)).json();
    assert.equal(libBefore[0].skills[0].updateAvailable, false);

    // Manually rewrite the order_items.folder_hash_at_install to something stale
    // to deterministically exercise the "source changed since install" branch
    // without mutating the shared fixture source folder.
    const db = openDb(dbPath);
    db.prepare("UPDATE order_items SET folder_hash_at_install = 'stale-hash' WHERE order_id = (SELECT MAX(id) FROM orders)").run();
    db.close();

    const libAfter = await (await fetch(`${base}/api/library`)).json();
    assert.equal(libAfter[0].skills[0].updateAvailable, true);
  } finally {
    await close();
  }
});

test('GET /api/library shows present: false when the skill was removed manually from the target', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-checkout-target-');
  try {
    await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-a'] });
    fs.rmSync(path.join(target, '.claude', 'skills', 'demo-skill-a'), { recursive: true, force: true });

    const lib = await (await fetch(`${base}/api/library`)).json();
    assert.equal(lib[0].skills[0].present, false);
  } finally {
    await close();
  }
});

test('watchlist: add, list, remove', async () => {
  const { base, close } = await importedServer();
  try {
    const { status } = await postJson(base, '/api/watchlist', { skillName: 'demo-skill-c' });
    assert.equal(status, 200);

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

test('watchlist: unknown skill name is rejected on add', async () => {
  const { base, close } = await importedServer();
  try {
    const { status } = await postJson(base, '/api/watchlist', { skillName: 'phantasie-skill' });
    assert.equal(status, 400);
  } finally {
    await close();
  }
});

test('watchlist: unknown skill name is rejected on remove', async () => {
  const { base, close } = await importedServer();
  try {
    const res = await fetch(`${base}/api/watchlist/phantasie-skill`, { method: 'DELETE' });
    assert.equal(res.status, 404);
  } finally {
    await close();
  }
});
