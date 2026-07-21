'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const { execFileSync } = require('node:child_process');

const { withServer, withImportedDb, tmpDir } = require('./helpers');

const FIXTURE_ROOT = path.join(__dirname, 'fixture', 'root');
const CATALOG_OK = path.join(__dirname, 'fixture', 'catalog');

function importedServer() {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  return withServer({ dbPath, rootDir: FIXTURE_ROOT });
}

// fetch() forbids setting the Host header, so we use raw http to actually send it.
function rawRequest(base, { method = 'GET', pathName = '/', host, body } = {}) {
  const url = new URL(base);
  return new Promise((resolve, reject) => {
    const headers = { Host: host };
    if (body) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(body);
    }
    const req = http.request(
      { hostname: url.hostname, port: url.port, path: pathName, method, headers },
      (res) => {
        let data = '';
        res.on('data', (c) => { data += c; });
        res.on('end', () => resolve({ status: res.statusCode, body: data }));
      }
    );
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

// A4: mutating endpoints must reject a non-localhost Host header.
test('A4: POST /api/checkout with a foreign Host header is rejected 403', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-sec-target-');
  try {
    const res = await rawRequest(base, {
      method: 'POST',
      pathName: '/api/checkout',
      host: 'evil.example.com',
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-a'] }),
    });
    assert.equal(res.status, 403);
    assert.match(res.body, /localhost/);
    assert.deepEqual(fs.readdirSync(target), [], 'nichts darf geschrieben worden sein');
  } finally {
    await close();
  }
});

test('A4: a localhost Host header passes the guard (POST reaches the handler)', async () => {
  const { base, close } = await importedServer();
  const target = tmpDir('shop-sec-target-');
  try {
    const res = await rawRequest(base, {
      method: 'POST',
      pathName: '/api/checkout',
      host: '127.0.0.1',
      body: JSON.stringify({ targetPath: target, items: ['demo-skill-a'] }),
    });
    assert.equal(res.status, 200); // guard passed, real handler ran
  } finally {
    await close();
  }
});

test('A4: GET requests are NOT blocked by the host guard (read-only)', async () => {
  const { base, close } = await importedServer();
  try {
    const res = await rawRequest(base, { method: 'GET', pathName: '/api/skills', host: 'evil.example.com' });
    assert.equal(res.status, 200);
  } finally {
    await close();
  }
});

test('A4: DELETE /api/watchlist with a foreign Host header is rejected 403', async () => {
  const { base, close } = await importedServer();
  try {
    const res = await rawRequest(base, { method: 'DELETE', pathName: '/api/watchlist/demo-skill-a', host: 'evil.example.com' });
    assert.equal(res.status, 403);
  } finally {
    await close();
  }
});

// B3: bin/stats.js against a missing DB must exit 1 and NOT create an empty file.
test('B3: stats.js against a missing DB exits 1 without creating a file', () => {
  const missing = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'shop-stats-nodb-')), 'shop.db');
  const statsScript = path.join(__dirname, '..', 'bin', 'stats.js');
  let exitCode = 0;
  try {
    execFileSync(process.execPath, [statsScript, missing], { stdio: 'pipe' });
  } catch (err) {
    exitCode = err.status;
  }
  assert.equal(exitCode, 1);
  assert.equal(fs.existsSync(missing), false, 'stats.js darf keine leere DB anlegen');
});
