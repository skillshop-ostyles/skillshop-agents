#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { openDb } = require('../src/db');

function main() {
  const shopDir = path.resolve(__dirname, '..');
  // Optionaler DB-Pfad als argv[2] (fuer Tests); sonst der echte Pfad.
  const dbPath = process.argv[2] || path.join(shopDir, 'data', 'shop.db');
  // B3: openDb() wuerde die Datei anlegen - eine leere DB waere ein Footgun
  // (Server liefert danach leeren Katalog statt 503). Erst pruefen, dann oeffnen.
  if (!fs.existsSync(dbPath)) {
    console.error('Datenbank fehlt - bitte zuerst "npm run import" ausfuehren.');
    process.exit(1);
  }
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
