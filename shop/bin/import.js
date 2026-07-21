#!/usr/bin/env node
'use strict';

const path = require('node:path');
const { runImport, ImportError } = require('../src/importer');

function parseArgs(argv) {
  const args = { root: null };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--root') {
      args.root = argv[i + 1];
      i += 1;
    }
  }
  return args;
}

function main() {
  const shopDir = path.resolve(__dirname, '..');
  const args = parseArgs(process.argv.slice(2));
  const rootDir = args.root ? path.resolve(args.root) : path.resolve(shopDir, '..');
  const catalogDir = path.join(shopDir, 'catalog');
  const dbPath = path.join(shopDir, 'data', 'shop.db');

  try {
    const summary = runImport({ rootDir, catalogDir, dbPath });
    console.log(`=== IMPORT: ${rootDir} ===`);
    console.log(
      `Skills: ${summary.skills.total} gesamt (${summary.skills.verfuegbar} verfuegbar, ${summary.skills.inEntwicklung} in-entwicklung, ${summary.skills.uncurated} unkuratiert)`
    );
    console.log(`Bundles: ${summary.bundles}`);
    console.log('Terme je Dimension:');
    for (const [dim, count] of Object.entries(summary.termsByDimension)) {
      console.log(`  ${dim}: ${count}`);
    }
    if (summary.warnings.length > 0) {
      console.log(`Warnungen (${summary.warnings.length}):`);
      for (const w of summary.warnings) console.log(`  - ${w}`);
    } else {
      console.log('Warnungen: keine');
    }
  } catch (err) {
    if (err instanceof ImportError) {
      console.error(`IMPORT-FEHLER: ${err.message}`);
    } else {
      console.error(`IMPORT-FEHLER (unerwartet): ${err.message}`);
    }
    process.exit(1);
  }
}

main();
