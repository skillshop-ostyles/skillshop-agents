'use strict';

const path = require('node:path');
const fs = require('node:fs');
const express = require('express');
const compression = require('compression');
const { openDb } = require('./db');
const skillsApi = require('./api/skills');
const bundlesApi = require('./api/bundles');
const checkoutApi = require('./api/checkout');
const libraryApi = require('./api/library');
const watchlistApi = require('./api/watchlist');
const advisorApi = require('./api/advisor');

const HOST = '127.0.0.1';
const PORT = 4711;

/**
 * Creates the shop Express app. The DB is opened lazily on each request via
 * getDb() so a missing data/shop.db results in a clean 503 instead of a
 * startup crash (SHOP-BIBEL/Sprint-22 edge case: "DB fehlt beim Start").
 * rootDir is the AGENTS repo root - the source of truth for skill folders,
 * used by the installer (Sprint 23).
 */
function createApp({ dbPath, publicDir, rootDir, catalogDir, pricingEnabled = false } = {}) {
  const resolvedCatalogDir = catalogDir || path.join(path.resolve(__dirname, '..'), 'catalog');
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

  // Produktionsparitaet: kein Express-Fingerprint-Header, wie es auch ein
  // echter Remote-Host (z.B. GitHub Pages/Fastly) nicht preisgeben wuerde.
  app.disable('x-powered-by');
  app.use(compression());
  app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    next();
  });

  app.use(express.json());

  // A4: Der Server bindet zwar nur an 127.0.0.1, aber jeder lokale Prozess kann
  // trotzdem HTTP-Requests schicken. Fuer mutierende Endpunkte (POST/PUT/DELETE
  // unter /api) verlangen wir daher einen localhost-Host-Header - ein simpler,
  // aber wirksamer Schutz gegen DNS-Rebinding/versehentliche Cross-Origin-Zugriffe.
  app.use('/api', (req, res, next) => {
    if (req.method === 'GET' || req.method === 'HEAD') return next();
    const host = (req.headers.host || '').split(':')[0].toLowerCase();
    if (host === '127.0.0.1' || host === 'localhost' || host === '[::1]' || host === '::1') return next();
    return res.status(403).json({ error: 'Nur ueber localhost erreichbar' });
  });

  app.use('/api', skillsApi.router(getDb, pricingEnabled));
  app.use('/api', bundlesApi.router(getDb, pricingEnabled));
  app.use('/api', checkoutApi.router(getDb, rootDir, pricingEnabled));
  app.use('/api', libraryApi.router(getDb, rootDir));
  app.use('/api', watchlistApi.router(getDb));
  app.use('/api', advisorApi.router(getDb, resolvedCatalogDir));

  // Cache-Control + ETag/Last-Modified wie bei einem echten statischen Host:
  // 10 Minuten Browser-Cache, danach Revalidierung ueber ETag (304 statt Vollausliefeurng).
  app.use(express.static(publicDir, { etag: true, lastModified: true, maxAge: '10m' }));

  app.use('/api', (req, res) => res.status(404).json({ error: 'Endpunkt nicht gefunden' }));
  app.use((req, res) => res.status(404).sendFile(path.join(publicDir, '404.html')));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error(err);
    if (res.headersSent) return;
    res.status(500).json({ error: 'Interner Serverfehler' });
  });

  app.close = () => {
    if (db) db.close();
  };

  return app;
}

function main() {
  // Default auf production, sofern nicht explizit anders gesetzt: deaktiviert
  // Express' Verbose-Error-Views und View-Caching-Quirks, wie bei einem echten
  // deployten Server. npm test/require('./server') in Tests setzt das nicht -
  // dort bleibt NODE_ENV unberuehrt.
  process.env.NODE_ENV = process.env.NODE_ENV || 'production';

  const shopDir = path.resolve(__dirname, '..');
  const dbPath = path.join(shopDir, 'data', 'shop.db');
  const publicDir = path.join(shopDir, 'public');
  const rootDir = path.resolve(shopDir, '..');
  const catalogDir = path.join(shopDir, 'catalog');
  const pricingEnabled = process.env.SHOP_PRICING === 'on';
  const app = createApp({ dbPath, publicDir, rootDir, catalogDir, pricingEnabled });

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
