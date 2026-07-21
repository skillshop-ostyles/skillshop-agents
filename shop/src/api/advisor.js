'use strict';

const path = require('node:path');
const express = require('express');
const { loadAdvisorRules, loadTaxonomy } = require('../importer');
const { recommend, AdvisorError } = require('../advisor');

function router(getDb, catalogDir) {
  const r = express.Router();

  // Loaded (and validated) once at router construction ("Startzeit-Validierung").
  const taxonomy = loadTaxonomy(catalogDir);
  const rules = loadAdvisorRules(catalogDir, taxonomy);

  r.get('/advisor/rules', (req, res) => {
    res.json(rules);
  });

  r.post('/advisor', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });

    const { q1, q2, q3 } = req.body || {};
    if (!q1 || !q3) {
      return res.status(400).json({ error: 'q1 und q3 sind erforderlich' });
    }
    try {
      const result = recommend(db, rules, { q1, q2, q3 });
      res.json(result);
    } catch (err) {
      if (err instanceof AdvisorError) return res.status(400).json({ error: err.message });
      throw err;
    }
  });

  return r;
}

module.exports = { router };
