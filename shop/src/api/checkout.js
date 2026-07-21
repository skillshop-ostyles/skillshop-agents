'use strict';

const express = require('express');
const { install, InstallError, assertAllowedTarget } = require('../installer');
const { generateLicense } = require('../pricing');

function router(getDb, rootDir, pricingEnabled = false) {
  const r = express.Router();

  r.post('/checkout', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });

    const { targetPath, label, items } = req.body || {};
    if (!targetPath || typeof targetPath !== 'string') {
      return res.status(400).json({ error: 'targetPath fehlt' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items fehlt oder ist leer' });
    }

    // Validate ALL items before any write happens (BIBEL/Sprint-23: alles-oder-nichts
    // auf Validierungsebene). Manipulated requests (e.g. an in-entwicklung skill
    // smuggled into the cart) are rejected here, server-side, regardless of the UI.
    const skillRows = [];
    for (const name of items) {
      const row = db.prepare('SELECT id, name, status, trigger_cmd AS trigger FROM skills WHERE name = ?').get(name);
      if (!row) return res.status(400).json({ error: `Skill '${name}' unbekannt` });
      if (row.status !== 'verfuegbar') {
        return res.status(400).json({ error: `Skill '${name}' ist noch nicht verfuegbar und kann nicht installiert werden` });
      }
      skillRows.push(row);
    }

    let normTarget;
    try {
      normTarget = assertAllowedTarget(targetPath, rootDir);
    } catch (err) {
      if (err instanceof InstallError) return res.status(400).json({ error: err.message });
      throw err;
    }

    const now = new Date().toISOString();
    db.prepare(`
      INSERT INTO install_targets (path, label, created_at) VALUES (?, ?, ?)
      ON CONFLICT(path) DO UPDATE SET label = COALESCE(excluded.label, install_targets.label)
    `).run(normTarget, label || null, now);
    const targetRow = db.prepare('SELECT id FROM install_targets WHERE path = ?').get(normTarget);

    const license = pricingEnabled ? generateLicense() : null;
    const orderId = db.prepare('INSERT INTO orders (target_id, created_at, license) VALUES (?, ?, ?)').run(targetRow.id, now, license).lastInsertRowid;
    const insertItem = db.prepare('INSERT INTO order_items (order_id, skill_id, folder_hash_at_install) VALUES (?, ?, ?)');

    const installed = [];
    const failed = [];
    const skipped = [];
    let stopped = false;

    for (const skillRow of skillRows) {
      if (stopped) {
        skipped.push(skillRow.name);
        continue;
      }
      try {
        const result = install({ skillName: skillRow.name, targetPath: normTarget, rootDir, overwrite: false });
        insertItem.run(orderId, skillRow.id, result.folderHash);
        installed.push({ name: skillRow.name, trigger: skillRow.trigger, destDir: result.destDir });
      } catch (err) {
        if (err instanceof InstallError) {
          failed.push({ name: skillRow.name, error: err.message });
          stopped = true;
        } else {
          throw err;
        }
      }
    }

    res.json({ targetPath: normTarget, installed, failed, skipped, license });
  });

  return r;
}

module.exports = { router };
