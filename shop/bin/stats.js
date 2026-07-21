#!/usr/bin/env node
'use strict';

const path = require('node:path');
const { openDb } = require('../src/db');

function main() {
  const shopDir = path.resolve(__dirname, '..');
  const dbPath = path.join(shopDir, 'data', 'shop.db');
  const db = openDb(dbPath);

  const skillCounts = db
    .prepare('SELECT status, COUNT(*) AS n FROM skills GROUP BY status')
    .all();
  const bundleCount = db.prepare('SELECT COUNT(*) AS n FROM bundles').get().n;
  const termCounts = db
    .prepare('SELECT dimension, COUNT(*) AS n FROM taxonomy_terms GROUP BY dimension')
    .all();
  const uncurated = db.prepare('SELECT COUNT(*) AS n FROM skills WHERE uncurated = 1').get().n;

  console.log('=== SHOP STATS ===');
  console.log('Skills nach Status:');
  for (const row of skillCounts) console.log(`  ${row.status}: ${row.n}`);
  console.log(`Unkuratiert: ${uncurated}`);
  console.log(`Bundles: ${bundleCount}`);
  console.log('Taxonomie-Terme:');
  for (const row of termCounts) console.log(`  ${row.dimension}: ${row.n}`);

  db.close();
}

main();
