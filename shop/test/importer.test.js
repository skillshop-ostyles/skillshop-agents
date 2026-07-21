'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  runImport,
  ImportError,
  parseFrontmatter,
  parseTrackingTable,
  computeFolderHash,
} = require('../src/importer');
const { openDb } = require('../src/db');

const FIXTURE_ROOT = path.join(__dirname, 'fixture', 'root');
const CATALOG_OK = path.join(__dirname, 'fixture', 'catalog');
const CATALOG_BAD_TERM = path.join(__dirname, 'fixture', 'catalog-bad-term');
const CATALOG_BAD_BUNDLE = path.join(__dirname, 'fixture', 'catalog-bad-bundle');

const MINIMAL_ADVISOR_RULES = JSON.stringify({
  q1: { question: 'q1', required: true, options: [{ id: 'a', label: 'A' }] },
  q2: { question: 'q2', required: false, options: [{ id: 'a', label: 'A' }] },
  q3: { question: 'q3', required: true, options: [{ id: 'a', label: 'A', filter: null }] },
});

function tmpDbPath() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'shop-test-'));
  return path.join(dir, 'shop.db');
}

test('happy path: imports curated skills, skips geisterprodukt', () => {
  const dbPath = tmpDbPath();
  const summary = runImport({ rootDir: FIXTURE_ROOT, catalogDir: CATALOG_OK, dbPath });

  assert.equal(summary.skills.total, 3, 'ghost-skill darf nicht mitgezaehlt werden (a, b, c = 3)');
  assert.equal(summary.skills.verfuegbar, 2, 'demo-skill-a (kein Tracking-Eintrag) + demo-skill-b (fertig)');
  assert.equal(summary.skills.inEntwicklung, 1, 'demo-skill-c (offen, kein Ordner)');
  assert.equal(summary.skills.uncurated, 0);
  assert.equal(summary.bundles, 1);
  assert.ok(
    summary.warnings.some((w) => w.includes('Geisterprodukt') && w.includes('ghost-skill')),
    'Geisterprodukt-Warnung fuer ghost-skill erwartet'
  );

  const db = openDb(dbPath);
  const names = db.prepare('SELECT name, status FROM skills ORDER BY name').all();
  assert.deepEqual(
    names,
    [
      { name: 'demo-skill-a', status: 'verfuegbar' },
      { name: 'demo-skill-b', status: 'verfuegbar' },
      { name: 'demo-skill-c', status: 'in-entwicklung' },
    ]
  );
  db.close();
});

test('import is idempotent: second run does not duplicate rows', () => {
  const dbPath = tmpDbPath();
  const first = runImport({ rootDir: FIXTURE_ROOT, catalogDir: CATALOG_OK, dbPath });
  const second = runImport({ rootDir: FIXTURE_ROOT, catalogDir: CATALOG_OK, dbPath });

  assert.deepEqual(first.skills, second.skills);
  assert.equal(first.bundles, second.bundles);

  const db = openDb(dbPath);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM skills').get().n, 3);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM bundles').get().n, 1);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM bundle_skills').get().n, 2);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM skills_fts').get().n, 3);
  db.close();
});

test('unknown taxonomy term raises ImportError', () => {
  const dbPath = tmpDbPath();
  assert.throws(
    () => runImport({ rootDir: FIXTURE_ROOT, catalogDir: CATALOG_BAD_TERM, dbPath }),
    ImportError
  );
});

test('bundle referencing unknown skill raises ImportError', () => {
  const dbPath = tmpDbPath();
  assert.throws(
    () => runImport({ rootDir: FIXTURE_ROOT, catalogDir: CATALOG_BAD_BUNDLE, dbPath }),
    ImportError
  );
});

test('skill folder without curated catalog entry is marked uncurated', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'shop-test-root-'));
  const catalog = fs.mkdtempSync(path.join(os.tmpdir(), 'shop-test-catalog-'));
  fs.mkdirSync(path.join(root, 'ops'), { recursive: true });
  fs.writeFileSync(
    path.join(root, 'ops', 'tracking.md'),
    '| Sprint | Skill | Status | Datum | Blocker |\n|---|---|---|---|---|\n'
  );
  fs.mkdirSync(path.join(root, 'lonely-skill'), { recursive: true });
  fs.writeFileSync(
    path.join(root, 'lonely-skill', 'SKILL.md'),
    '---\nname: lonely-skill\ndescription: "Ohne Katalog. Trigger: /lonely"\ntrigger: /lonely\n---\n'
  );
  fs.mkdirSync(path.join(catalog, 'skills'), { recursive: true });
  fs.mkdirSync(path.join(catalog, 'bundles'), { recursive: true });
  fs.writeFileSync(
    path.join(catalog, 'taxonomy.json'),
    JSON.stringify({
      usecase: [], thema: [], stichwort: [], ziel: [], branche: [], taetigkeit: [], level: [], risiko: [],
    })
  );
  fs.writeFileSync(path.join(catalog, 'advisor-rules.json'), MINIMAL_ADVISOR_RULES);

  const dbPath = tmpDbPath();
  const summary = runImport({ rootDir: root, catalogDir: catalog, dbPath });

  assert.equal(summary.skills.total, 1);
  assert.equal(summary.skills.uncurated, 1);
  assert.equal(summary.skills.verfuegbar, 1, 'kein Tracking-Eintrag + Ordner vorhanden => verfuegbar');
  assert.ok(summary.warnings.some((w) => w.includes('Unkuratiert') && w.includes('lonely-skill')));
});

test('frontmatter name mismatch with folder name raises ImportError', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'shop-test-mismatch-'));
  fs.mkdirSync(path.join(root, 'ops'), { recursive: true });
  fs.writeFileSync(path.join(root, 'ops', 'tracking.md'), '');
  fs.mkdirSync(path.join(root, 'folder-name'), { recursive: true });
  fs.writeFileSync(
    path.join(root, 'folder-name', 'SKILL.md'),
    '---\nname: different-name\ndescription: "x"\ntrigger: /x\n---\n'
  );
  assert.throws(
    () => runImport({ rootDir: root, catalogDir: CATALOG_OK, dbPath: tmpDbPath() }),
    ImportError
  );
});

test('unreadable tracking.md falls back to in-entwicklung for everyone, with warning', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'shop-test-notrack-'));
  fs.mkdirSync(path.join(root, 'ops'), { recursive: true });
  fs.writeFileSync(path.join(root, 'ops', 'tracking.md'), 'kein Tabellen-Header hier');
  fs.mkdirSync(path.join(root, 'demo-skill-a'), { recursive: true });
  fs.writeFileSync(
    path.join(root, 'demo-skill-a', 'SKILL.md'),
    '---\nname: demo-skill-a\ndescription: "x"\ntrigger: /demo-a\n---\n'
  );

  const summary = runImport({ rootDir: root, catalogDir: CATALOG_OK, dbPath: tmpDbPath() });
  assert.equal(summary.skills.verfuegbar, 0);
  assert.ok(summary.warnings.some((w) => w.includes('tracking.md nicht lesbar')));
});

test('parseFrontmatter extracts name/description/trigger', () => {
  const text = '---\nname: foo\ndescription: "Bar baz. Trigger: /foo"\ntrigger: /foo\n---\nBody';
  const fm = parseFrontmatter(text, 'test.md');
  assert.equal(fm.name, 'foo');
  assert.equal(fm.trigger, '/foo');
  assert.equal(fm.description, 'Bar baz. Trigger: /foo');
});

test('parseFrontmatter throws on missing frontmatter', () => {
  assert.throws(() => parseFrontmatter('no frontmatter here', 'test.md'), ImportError);
});

test('parseTrackingTable finds header by column name, tolerates layout changes', () => {
  const text = [
    '# Some other table above',
    '| A | B |',
    '|---|---|',
    '| 1 | 2 |',
    '',
    '| Extra | Skill | Notes | Status |',
    '|---|---|---|---|',
    '| x | my-skill | note | fertig |',
  ].join('\n');
  const result = parseTrackingTable(text);
  assert.equal(result.ok, true);
  assert.equal(result.statusByName.get('my-skill'), 'fertig');
});

test('parseTrackingTable reports not-ok when no header matches', () => {
  const result = parseTrackingTable('irgendein Text ohne Tabelle');
  assert.equal(result.ok, false);
});

test('computeFolderHash is deterministic and change-sensitive', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'shop-test-hash-'));
  fs.writeFileSync(path.join(dir, 'a.txt'), 'hello');
  const h1 = computeFolderHash(dir);
  const h2 = computeFolderHash(dir);
  assert.equal(h1, h2);
  fs.writeFileSync(path.join(dir, 'a.txt'), 'hello world');
  const h3 = computeFolderHash(dir);
  assert.notEqual(h1, h3);
});
