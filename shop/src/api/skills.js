'use strict';

const express = require('express');
const { parseFilters, queryProducts, attachTerms, computeFacets, CARD_FIELDS } = require('../catalogQuery');
const { getPrice } = require('../pricing');

/**
 * @param {object} row skill row (with .terms attached)
 * @param {object} opts
 * @param {import('better-sqlite3').Database} [opts.db]
 * @param {boolean} [opts.pricingEnabled]
 * @param {Map<number, object>} [opts.priceMap] optional batched skillId->price map
 *   (C2: lets callers that render many skills avoid one getPrice query per skill).
 */
function skillToJson(row, { db, pricingEnabled, priceMap } = {}) {
  const json = {
    name: row.name,
    trigger: row.trigger,
    description: row.description,
    claim: row.claim,
    short: row.short,
    long: row.long,
    status: row.status,
    risk: row.risk,
    priceTier: row.priceTier,
    uncurated: !!row.uncurated,
    terms: row.terms || {},
  };
  if (pricingEnabled) {
    json.price = priceMap ? (priceMap.get(row.id) || null) : (db ? getPrice(db, 'skill', row.id) : null);
  }
  return json;
}

function router(getDb, pricingEnabled = false) {
  const r = express.Router();

  r.get('/skills', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const filters = parseFilters(req.query);
    const rows = attachTerms(db, queryProducts(db, filters));
    res.json(rows.map((row) => skillToJson(row, { db, pricingEnabled })));
  });

  r.get('/skills/:name', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const row = db
      .prepare(`SELECT ${CARD_FIELDS} FROM skills s WHERE s.name = ?`)
      .get(req.params.name);
    if (!row) return res.status(404).json({ error: `Skill '${req.params.name}' nicht gefunden` });
    attachTerms(db, [row]);

    const bundles = db
      .prepare(`
        SELECT b.slug AS slug, b.title AS title
        FROM bundle_skills bs JOIN bundles b ON b.id = bs.bundle_id
        WHERE bs.skill_id = ?
        ORDER BY b.title
      `)
      .all(row.id);

    const related = db
      .prepare(`
        SELECT s2.name AS name, s2.claim AS claim, s2.status AS status
        FROM skill_related sr JOIN skills s2 ON s2.name = sr.related_name
        WHERE sr.skill_id = ?
        ORDER BY s2.name
      `)
      .all(row.id);

    res.json({ ...skillToJson(row, { db, pricingEnabled }), bundles, related });
  });

  r.get('/facets', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const filters = parseFilters(req.query);
    res.json(computeFacets(db, filters));
  });

  return r;
}

module.exports = { router, skillToJson };
