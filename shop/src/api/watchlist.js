'use strict';

const express = require('express');
const { skillToJson } = require('./skills');
const { CARD_FIELDS, attachTerms } = require('../catalogQuery');

function router(getDb) {
  const r = express.Router();

  r.get('/watchlist', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const rows = db
      .prepare(`
        SELECT ${CARD_FIELDS} FROM watchlist w
        JOIN skills s ON s.id = w.skill_id
        ORDER BY w.added_at DESC
      `)
      .all();
    attachTerms(db, rows);
    res.json(rows.map(skillToJson));
  });

  r.post('/watchlist', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const { skillName } = req.body || {};
    if (!skillName) return res.status(400).json({ error: 'skillName fehlt' });
    const skillRow = db.prepare('SELECT id FROM skills WHERE name = ?').get(skillName);
    if (!skillRow) return res.status(400).json({ error: `Skill '${skillName}' unbekannt` });
    db.prepare(`
      INSERT INTO watchlist (skill_id, added_at) VALUES (?, ?)
      ON CONFLICT(skill_id) DO NOTHING
    `).run(skillRow.id, new Date().toISOString());
    res.json({ ok: true });
  });

  r.delete('/watchlist/:name', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });
    const skillRow = db.prepare('SELECT id FROM skills WHERE name = ?').get(req.params.name);
    if (!skillRow) return res.status(404).json({ error: `Skill '${req.params.name}' unbekannt` });
    db.prepare('DELETE FROM watchlist WHERE skill_id = ?').run(skillRow.id);
    res.json({ ok: true });
  });

  return r;
}

module.exports = { router };
