'use strict';

const express = require('express');
const { skillToJson } = require('./skills');
const { CARD_FIELDS, attachTerms } = require('../catalogQuery');
const { getPrice } = require('../pricing');

function bundleRow(db, row, pricingEnabled) {
  const skills = db
    .prepare(`
      SELECT ${CARD_FIELDS} FROM bundle_skills bs
      JOIN skills s ON s.id = bs.skill_id
      WHERE bs.bundle_id = ?
      ORDER BY CASE WHEN s.status = 'verfuegbar' THEN 0 ELSE 1 END, s.name ASC
    `)
    .all(row.id);
  attachTerms(db, skills);
  const verfuegbar = skills.filter((s) => s.status === 'verfuegbar').length;
  const json = {
    slug: row.slug,
    title: row.title,
    claim: row.claim,
    story: row.story,
    priceTier: row.price_tier,
    skills: skills.map((s) => skillToJson(s, { db, pricingEnabled })),
    status: { verfuegbar, total: skills.length },
  };
  if (pricingEnabled) {
    json.price = getPrice(db, 'bundle', row.id);
  }
  return json;
}

function router(getDb, pricingEnabled = false) {
  const r = express.Router();

  r.get('/bundles', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const rows = db.prepare('SELECT id, slug, title, claim, story, price_tier FROM bundles ORDER BY title').all();
    res.json(rows.map((row) => bundleRow(db, row, pricingEnabled)));
  });

  r.get('/bundles/:slug', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const row = db
      .prepare('SELECT id, slug, title, claim, story, price_tier FROM bundles WHERE slug = ?')
      .get(req.params.slug);
    if (!row) return res.status(404).json({ error: `Bundle '${req.params.slug}' nicht gefunden` });
    res.json(bundleRow(db, row, pricingEnabled));
  });

  return r;
}

module.exports = { router };
