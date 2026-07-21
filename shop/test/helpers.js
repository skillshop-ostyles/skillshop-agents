'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { createApp } = require('../src/server');
const { runImport } = require('../src/importer');

/** Fresh temp path for a shop.db file (parent dir created, file itself not). */
function tmpDbPath(prefix = 'shop-test-') {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  return path.join(dir, 'shop.db');
}

/** Fresh empty temp directory, e.g. for use as an install target. */
function tmpDir(prefix = 'shop-test-dir-') {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

/**
 * Starts a shop server on a random free port against the given dbPath/rootDir.
 * @returns {Promise<{base: string, close: () => Promise<void>}>}
 */
function withServer(opts) {
  const app = createApp({ publicDir: path.join(__dirname, '..', 'public'), ...opts });
  return new Promise((resolve) => {
    const server = app.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      resolve({
        base: `http://127.0.0.1:${port}`,
        close: () => new Promise((res) => server.close(res)),
      });
    });
  });
}

/** Imports rootDir+catalogDir into a fresh temp DB, returns the dbPath. */
function withImportedDb(rootDir, catalogDir) {
  const dbPath = tmpDbPath();
  runImport({ rootDir, catalogDir, dbPath });
  return dbPath;
}

async function postJson(base, urlPath, body) {
  const res = await fetch(`${base}${urlPath}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

module.exports = { tmpDbPath, tmpDir, withServer, withImportedDb, postJson };
