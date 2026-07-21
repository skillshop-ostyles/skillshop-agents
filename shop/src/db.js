'use strict';

const path = require('node:path');
const fs = require('node:fs');
const Database = require('better-sqlite3');

const SCHEMA = `
CREATE TABLE IF NOT EXISTS skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  trigger_cmd TEXT NOT NULL,
  description TEXT NOT NULL,
  claim TEXT NOT NULL,
  short TEXT NOT NULL,
  long TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('verfuegbar', 'in-entwicklung')),
  risk TEXT NOT NULL,
  price_tier TEXT NOT NULL,
  uncurated INTEGER NOT NULL DEFAULT 0,
  folder_hash TEXT,
  imported_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS taxonomy_terms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dimension TEXT NOT NULL,
  term TEXT NOT NULL,
  UNIQUE(dimension, term)
);

CREATE TABLE IF NOT EXISTS skill_terms (
  skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  term_id INTEGER NOT NULL REFERENCES taxonomy_terms(id) ON DELETE CASCADE,
  PRIMARY KEY(skill_id, term_id)
);

CREATE TABLE IF NOT EXISTS bundles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  claim TEXT NOT NULL,
  story TEXT NOT NULL,
  price_tier TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS bundle_skills (
  bundle_id INTEGER NOT NULL REFERENCES bundles(id) ON DELETE CASCADE,
  skill_id INTEGER NOT NULL REFERENCES skills(id) ON DELETE CASCADE,
  PRIMARY KEY(bundle_id, skill_id)
);

CREATE TABLE IF NOT EXISTS prices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ref_type TEXT NOT NULL CHECK(ref_type IN ('skill', 'bundle')),
  ref_id INTEGER NOT NULL,
  tier TEXT NOT NULL,
  amount_cents INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'EUR'
);

CREATE TABLE IF NOT EXISTS install_targets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  path TEXT UNIQUE NOT NULL,
  label TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  target_id INTEGER NOT NULL REFERENCES install_targets(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  license TEXT
);

CREATE TABLE IF NOT EXISTS order_items (
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  skill_id INTEGER REFERENCES skills(id) ON DELETE SET NULL,
  folder_hash_at_install TEXT,
  bundle_id INTEGER REFERENCES bundles(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS watchlist (
  skill_id INTEGER PRIMARY KEY REFERENCES skills(id) ON DELETE CASCADE,
  added_at TEXT NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS skills_fts USING fts5(
  name, claim, short, long, terms_flat
);
`;

/**
 * Opens (creating if needed) the shop SQLite database and ensures the schema exists.
 * @param {string} dbPath absolute path to the .db file
 * @returns {import('better-sqlite3').Database}
 */
function openDb(dbPath) {
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.exec(SCHEMA);
  return db;
}

module.exports = { openDb, SCHEMA };
