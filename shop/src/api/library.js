'use strict';

const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const { scanSkillFolders } = require('../importer');
const { install, InstallError, assertAllowedTarget } = require('../installer');

function router(getDb, rootDir) {
  const r = express.Router();

  r.get('/library', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });

    const rows = db
      .prepare(`
        SELECT * FROM (
          SELECT
            t.id AS targetId, t.path AS targetPath, t.label AS targetLabel,
            s.name AS skillName, s.trigger_cmd AS trigger, s.status AS status,
            oi.folder_hash_at_install AS hashAtInstall, o.created_at AS installedAt,
            ROW_NUMBER() OVER (PARTITION BY t.id, s.id ORDER BY o.created_at DESC, oi.rowid DESC) AS rn
          FROM order_items oi
          JOIN orders o ON o.id = oi.order_id
          JOIN install_targets t ON t.id = o.target_id
          JOIN skills s ON s.id = oi.skill_id
        )
        WHERE rn = 1
        ORDER BY targetPath, skillName
      `)
      .all();

    const currentFolders = scanSkillFolders(rootDir);

    const byTarget = new Map();
    for (const row of rows) {
      if (!byTarget.has(row.targetId)) {
        byTarget.set(row.targetId, { path: row.targetPath, label: row.targetLabel, skills: [] });
      }
      const destDir = path.join(row.targetPath, '.claude', 'skills', row.skillName);
      const present = fs.existsSync(destDir);
      const currentHash = currentFolders.get(row.skillName)?.folderHash || null;
      const updateAvailable = present && currentHash !== null && currentHash !== row.hashAtInstall;
      byTarget.get(row.targetId).skills.push({
        name: row.skillName,
        trigger: row.trigger,
        status: row.status,
        installedAt: row.installedAt,
        present,
        updateAvailable,
      });
    }

    res.json([...byTarget.values()]);
  });

  r.post('/library/reinstall', (req, res) => {
    const db = getDb();
    if (!db) return res.status(503).json({ error: 'Datenbank fehlt - bitte "npm run import" ausfuehren' });

    const { targetPath, skillName } = req.body || {};
    if (!targetPath || !skillName) {
      return res.status(400).json({ error: 'targetPath und skillName sind erforderlich' });
    }

    const skillRow = db.prepare('SELECT id, status, trigger_cmd AS trigger FROM skills WHERE name = ?').get(skillName);
    if (!skillRow) return res.status(400).json({ error: `Skill '${skillName}' unbekannt` });
    if (skillRow.status !== 'verfuegbar') {
      return res.status(400).json({ error: `Skill '${skillName}' ist nicht verfuegbar` });
    }

    let normTarget;
    try {
      normTarget = assertAllowedTarget(targetPath, rootDir);
    } catch (err) {
      if (err instanceof InstallError) return res.status(400).json({ error: err.message });
      throw err;
    }

    const targetRow = db.prepare('SELECT id FROM install_targets WHERE path = ?').get(normTarget);
    if (!targetRow) {
      return res.status(400).json({ error: `Ziel '${normTarget}' ist nicht in der Bibliothek bekannt` });
    }

    let result;
    try {
      result = install({ skillName, targetPath: normTarget, rootDir, overwrite: true });
    } catch (err) {
      if (err instanceof InstallError) return res.status(400).json({ error: err.message });
      throw err;
    }

    const now = new Date().toISOString();
    const orderId = db.prepare('INSERT INTO orders (target_id, created_at, license) VALUES (?, ?, NULL)').run(targetRow.id, now).lastInsertRowid;
    db.prepare('INSERT INTO order_items (order_id, skill_id, folder_hash_at_install) VALUES (?, ?, ?)').run(orderId, skillRow.id, result.folderHash);

    res.json({ name: skillName, destDir: result.destDir, trigger: skillRow.trigger });
  });

  return r;
}

module.exports = { router };
