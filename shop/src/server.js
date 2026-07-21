'use strict';

const path = require('node:path');
const fs = require('node:fs');
const express = require('express');
const { openDb } = require('./db');
const skillsApi = require('./api/skills');
const bundlesApi = require('./api/bundles');

const HOST = '127.0.0.1';
const PORT = 4711;

/**
 * Creates the shop Express app. The DB is opened lazily on each request via
 * getDb() so a missing data/shop.db results in a clean 503 instead of a
 * startup crash (SHOP-BIBEL/Sprint-22 edge case: "DB fehlt beim Start").
 */
function createApp({ dbPath, publicDir } = {}) {
  const app = express();
  let db = null;
  let dbOpenAttempted = false;

  function getDb() {
    if (db) return db;
    if (dbOpenAttempted && !fs.existsSync(dbPath)) return null;
    if (!fs.existsSync(dbPath)) {
      dbOpenAttempted = true;
      return null;
    }
    db = openDb(dbPath);
    return db;
  }

  app.use(express.json());
  app.use('/api', skillsApi.router(getDb));
  app.use('/api', bundlesApi.router(getDb));
  app.use(express.static(publicDir));

  app.close = () => {
    if (db) db.close();
  };

  return app;
}

function main() {
  const shopDir = path.resolve(__dirname, '..');
  const dbPath = path.join(shopDir, 'data', 'shop.db');
  const publicDir = path.join(shopDir, 'public');
  const app = createApp({ dbPath, publicDir });

  const server = app.listen(PORT, HOST, () => {
    console.log(`Skill-Shop laeuft auf http://${HOST}:${PORT}`);
  });
  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`Port ${PORT} ist bereits belegt - Shop kann nicht starten.`);
    } else {
      console.error(`Serverfehler: ${err.message}`);
    }
    process.exit(1);
  });
}

if (require.main === module) {
  main();
}

module.exports = { createApp, HOST, PORT };
