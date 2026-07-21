'use strict';

const express = require('express');
const { skillToJson } = require('./skills');
const { CARD_FIELDS, attachTerms } = require('../catalogQuery');

function bundleRow(db, row) {
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
  return {
    slug: row.slug,
    title: row.title,
    claim: row.claim,
    story: row.story,
    priceTier: row.price_tier,
    skills: skills.map(skillToJson),
    status: { verfuegbar, total: skills.length },
  };
}

function router(getDb) {
  const r = express.Router();

  r.get('/bundles', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const rows = db.prepare('SELECT id, slug, title, claim, story, price_tier FROM bundles ORDER BY title').all();
    res.json(rows.map((row) => bundleRow(db, row)));
  });

  r.get('/bundles/:slug', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const row = db
      .prepare('SELECT id, slug, title, claim, story, price_tier FROM bundles WHERE slug = ?')
      .get(req.params.slug);
    if (!row) return res.status(404).json({ error: `Bundle '${req.params.slug}' nicht gefunden` });
    res.json(bundleRow(db, row));
  });

  return r;
}

module.exports = { router };
