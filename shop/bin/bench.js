#!/usr/bin/env node
'use strict';

// Performance-Nachweis (Sprint 25): /api/skills und /api/facets je 20x messen,
// Median muss < 100ms sein (lokal, gegen den echten Katalog).

const path = require('node:path');
const { createApp } = require('../src/server');

const RUNS = 20;
const THRESHOLD_MS = 100;

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

async function timeRequests(base, urlPath, runs) {
  const times = [];
  for (let i = 0; i < runs; i += 1) {
    const start = performance.now();
    const res = await fetch(`${base}${urlPath}`);
    await res.json();
    times.push(performance.now() - start);
  }
  return times;
}

async function main() {
  const shopDir = path.resolve(__dirname, '..');
  const dbPath = path.join(shopDir, 'data', 'shop.db');
  if (!require('node:fs').existsSync(dbPath)) {
    console.error('Datenbank fehlt - bitte zuerst "npm run import" ausfuehren.');
    process.exit(1);
  }
  const publicDir = path.join(shopDir, 'public');
  const rootDir = path.resolve(shopDir, '..');
  const catalogDir = path.join(shopDir, 'catalog');
  const app = createApp({ dbPath, publicDir, rootDir, catalogDir });

  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;

  let failed = false;
  for (const route of ['/api/skills', '/api/facets']) {
    const times = await timeRequests(base, route, RUNS);
    const m = median(times);
    const status = m < THRESHOLD_MS ? 'OK' : 'FAIL';
    if (m >= THRESHOLD_MS) failed = true;
    console.log(
      `${route}: median=${m.toFixed(2)}ms min=${Math.min(...times).toFixed(2)}ms max=${Math.max(...times).toFixed(2)}ms [${status}]`
    );
  }

  await new Promise((resolve) => server.close(resolve));
  if (failed) {
    console.error(`Performance-Kriterium verfehlt (Median >= ${THRESHOLD_MS}ms).`);
    process.exit(1);
  }
}

main();
