'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const { openDb } = require('./db');

const DIMENSIONS = [
  'usecase', 'thema', 'stichwort', 'ziel', 'branche', 'taetigkeit', 'level', 'risiko',
];

const EXCLUDED_TOP_LEVEL = new Set(['shop', 'ops', '.git', 'node_modules']);

class ImportError extends Error {}

/**
 * Parses the YAML-ish frontmatter block of a SKILL.md file.
 * @param {string} text full SKILL.md content
 * @param {string} sourcePath for error messages
 * @returns {{name: string, description: string, trigger: string}}
 */
function parseFrontmatter(text, sourcePath) {
  const lines = text.split(/\r?\n/);
  if (lines[0] !== '---') {
    throw new ImportError(`SKILL.md ohne Frontmatter: ${sourcePath}`);
  }
  const endIdx = lines.indexOf('---', 1);
  if (endIdx === -1) {
    throw new ImportError(`SKILL.md Frontmatter nicht geschlossen: ${sourcePath}`);
  }
  const fields = {};
  for (const raw of lines.slice(1, endIdx)) {
    const m = raw.match(/^([a-zA-Z_]+):\s*(.*)$/);
    if (!m) continue;
    let value = m[2].trim();
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      value = value.slice(1, -1);
    }
    fields[m[1]] = value;
  }
  if (!fields.name) {
    throw new ImportError(`SKILL.md ohne 'name' im Frontmatter: ${sourcePath}`);
  }
  if (!fields.trigger) {
    throw new ImportError(`SKILL.md ohne 'trigger' im Frontmatter: ${sourcePath}`);
  }
  return {
    name: fields.name,
    description: fields.description || '',
    trigger: fields.trigger,
  };
}

/** Recursively lists files under dir, returning POSIX-style relative paths, sorted. */
function listFilesSorted(dir) {
  const out = [];
  function walk(current, rel) {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const abs = path.join(current, entry.name);
      const relPath = rel ? `${rel}/${entry.name}` : entry.name;
      if (entry.isDirectory()) {
        walk(abs, relPath);
      } else if (entry.isFile()) {
        out.push(relPath);
      }
    }
  }
  walk(dir, '');
  out.sort();
  return out;
}

/** SHA-256 over sorted (relPath, content) pairs of every file in a skill folder. */
function computeFolderHash(folderPath) {
  const hash = crypto.createHash('sha256');
  for (const relPath of listFilesSorted(folderPath)) {
    hash.update(relPath, 'utf8');
    hash.update('\0');
    hash.update(fs.readFileSync(path.join(folderPath, relPath)));
    hash.update('\0');
  }
  return hash.digest('hex');
}

/**
 * Scans rootDir for skill folders (any direct subfolder containing SKILL.md,
 * excluding shop/ops/.git/node_modules).
 * @returns {Map<string, {folderPath: string, frontmatter: object, folderHash: string}>}
 */
function scanSkillFolders(rootDir) {
  const result = new Map();
  let entries;
  try {
    entries = fs.readdirSync(rootDir, { withFileTypes: true });
  } catch (err) {
    throw new ImportError(`ProjectDir nicht lesbar: ${rootDir} (${err.message})`);
  }
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (EXCLUDED_TOP_LEVEL.has(entry.name) || entry.name.startsWith('.')) continue;
    const folderPath = path.join(rootDir, entry.name);
    const skillMdPath = path.join(folderPath, 'SKILL.md');
    if (!fs.existsSync(skillMdPath)) continue;
    const text = fs.readFileSync(skillMdPath, 'utf8');
    const frontmatter = parseFrontmatter(text, skillMdPath);
    if (frontmatter.name !== entry.name) {
      throw new ImportError(
        `Skill-Ordnername '${entry.name}' weicht vom Frontmatter-name '${frontmatter.name}' ab (${skillMdPath})`
      );
    }
    if (result.has(frontmatter.name)) {
      throw new ImportError(`Doppelter Skill-Name '${frontmatter.name}' in Ordner-Scan`);
    }
    result.set(frontmatter.name, {
      folderPath,
      frontmatter,
      folderHash: computeFolderHash(folderPath),
    });
  }
  return result;
}

/**
 * Tolerantly parses the sprint-status table in ops/tracking.md.
 * Finds the header row via column names ("Skill", "Status") rather than fixed indices.
 * @returns {{ok: boolean, statusByName: Map<string,string>}}
 */
function parseTrackingTable(text) {
  const lines = text.split(/\r?\n/);
  let skillCol = -1;
  let statusCol = -1;
  let headerLineIdx = -1;
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i].trim();
    if (!line.startsWith('|')) continue;
    const cells = line.split('|').map((c) => c.trim());
    const sIdx = cells.findIndex((c) => c.toLowerCase() === 'skill');
    const stIdx = cells.findIndex((c) => c.toLowerCase() === 'status');
    if (sIdx !== -1 && stIdx !== -1) {
      skillCol = sIdx;
      statusCol = stIdx;
      headerLineIdx = i;
      break;
    }
  }
  if (headerLineIdx === -1) {
    return { ok: false, statusByName: new Map() };
  }
  const statusByName = new Map();
  for (let i = headerLineIdx + 1; i < lines.length; i += 1) {
    const line = lines[i].trim();
    if (!line.startsWith('|')) break;
    const cells = line.split('|').map((c) => c.trim());
    if (cells.every((c) => /^:?-+:?$/.test(c) || c === '')) continue; // separator row
    const name = cells[skillCol];
    const status = cells[statusCol];
    if (name) statusByName.set(name, status);
  }
  return { ok: true, statusByName };
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

/** Loads catalog/taxonomy.json as { dimension: Set<term> }. */
function loadTaxonomy(catalogDir) {
  const taxonomyPath = path.join(catalogDir, 'taxonomy.json');
  if (!fs.existsSync(taxonomyPath)) {
    throw new ImportError(`taxonomy.json fehlt: ${taxonomyPath}`);
  }
  const raw = readJson(taxonomyPath);
  const taxonomy = {};
  for (const dim of DIMENSIONS) {
    if (!Array.isArray(raw[dim])) {
      throw new ImportError(`taxonomy.json: Dimension '${dim}' fehlt oder ist kein Array`);
    }
    taxonomy[dim] = new Set(raw[dim]);
  }
  return taxonomy;
}

/** Loads catalog/skills/*.json as Map<name, json>. */
function loadCatalogSkills(catalogDir) {
  const dir = path.join(catalogDir, 'skills');
  const result = new Map();
  if (!fs.existsSync(dir)) return result;
  for (const file of fs.readdirSync(dir)) {
    if (!file.endsWith('.json')) continue;
    const json = readJson(path.join(dir, file));
    const expectedName = file.slice(0, -'.json'.length);
    if (json.name !== expectedName) {
      throw new ImportError(
        `Katalog-Datei '${file}': name-Feld '${json.name}' passt nicht zum Dateinamen`
      );
    }
    result.set(json.name, json);
  }
  return result;
}

/** Loads catalog/bundles/*.json as an array. */
function loadCatalogBundles(catalogDir) {
  const dir = path.join(catalogDir, 'bundles');
  const result = [];
  if (!fs.existsSync(dir)) return result;
  for (const file of fs.readdirSync(dir)) {
    if (!file.endsWith('.json')) continue;
    const json = readJson(path.join(dir, file));
    const expectedId = file.slice(0, -'.json'.length);
    if (json.id !== expectedId) {
      throw new ImportError(
        `Bundle-Datei '${file}': id-Feld '${json.id}' passt nicht zum Dateinamen`
      );
    }
    result.push(json);
  }
  return result;
}

/**
 * Runs a full, idempotent import: files -> SQLite.
 * @param {{rootDir: string, catalogDir: string, dbPath: string}} opts
 * @returns {{skills: {verfuegbar: number, inEntwicklung: number, uncurated: number},
 *            bundles: number, termsByDimension: Record<string, number>,
 *            warnings: string[]}}
 */
function runImport({ rootDir, catalogDir, dbPath }) {
  const warnings = [];
  const folders = scanSkillFolders(rootDir);
  const taxonomy = loadTaxonomy(catalogDir);
  const catalogSkills = loadCatalogSkills(catalogDir);
  const catalogBundles = loadCatalogBundles(catalogDir);

  const trackingPath = path.join(rootDir, 'ops', 'tracking.md');
  let tracking = { ok: false, statusByName: new Map() };
  if (fs.existsSync(trackingPath)) {
    tracking = parseTrackingTable(fs.readFileSync(trackingPath, 'utf8'));
  }
  if (!tracking.ok) {
    warnings.push('tracking.md nicht lesbar/kein Statusfeld gefunden - alle Skills als in-entwicklung markiert');
  }

  // Union of names discovered via folders and via curated catalog entries.
  const allNames = new Set([...folders.keys(), ...catalogSkills.keys()]);

  const products = [];
  for (const name of allNames) {
    const folder = folders.get(name);
    const catalog = catalogSkills.get(name);

    if (!catalog && !folder) continue; // impossible (name came from one of the two sets)

    if (!folder && !catalog) continue;

    if (!folder && catalog) {
      // Planned skill, not yet built. Only a real product if tracking.md knows it
      // (a recognized sprint) OR tracking is unreadable (safety net keeps it visible).
      const known = !tracking.ok || tracking.statusByName.has(name);
      if (!known) {
        warnings.push(`Geisterprodukt: Katalog-Eintrag '${name}' hat weder Ordner noch tracking.md-Zeile - uebersprungen`);
        continue;
      }
    }

    if (folder && !catalog) {
      warnings.push(`Unkuratiert: Skill-Ordner '${name}' hat keine Katalog-Datei`);
    }

    let status = 'in-entwicklung';
    if (!folder) {
      status = 'in-entwicklung';
    } else if (!tracking.ok) {
      status = 'in-entwicklung';
    } else if (tracking.statusByName.has(name)) {
      status = tracking.statusByName.get(name) === 'fertig' ? 'verfuegbar' : 'in-entwicklung';
    } else {
      status = 'verfuegbar'; // implemented, no sprint tracking row (e.g. elevate, project-init)
    }

    const trigger = folder ? folder.frontmatter.trigger : catalog?.trigger;
    const description = folder ? folder.frontmatter.description : catalog?.description;
    if (!trigger) {
      throw new ImportError(`Skill '${name}': kein trigger verfuegbar (weder Ordner noch Katalog)`);
    }

    const terms = catalog?.terms || {};
    for (const dim of Object.keys(terms)) {
      if (!DIMENSIONS.includes(dim)) {
        throw new ImportError(`Skill '${name}': unbekannte Taxonomie-Dimension '${dim}'`);
      }
      for (const term of terms[dim]) {
        if (!taxonomy[dim].has(term)) {
          throw new ImportError(`Skill '${name}': unbekannter Term '${term}' in Dimension '${dim}'`);
        }
      }
    }
    const missingDims = catalog
      ? DIMENSIONS.filter((dim) => !(terms[dim] && terms[dim].length > 0))
      : [];
    if (catalog && missingDims.length > 0) {
      warnings.push(`Kurations-Luecke: Skill '${name}' ohne Term in Dimension(en): ${missingDims.join(', ')}`);
    }

    products.push({
      name,
      trigger,
      description: description || '',
      claim: catalog?.claim || description || name,
      short: catalog?.short || description || '',
      long: catalog?.long || description || '',
      status,
      risk: (terms.risiko && terms.risiko[0]) || 'unbekannt',
      priceTier: catalog?.priceTier || 'single',
      uncurated: catalog ? 0 : 1,
      folderHash: folder ? folder.folderHash : null,
      terms,
      related: catalog?.related || [],
    });
  }

  // Bundle referential integrity.
  const productNames = new Set(products.map((p) => p.name));
  for (const bundle of catalogBundles) {
    for (const skillName of bundle.skills || []) {
      if (!productNames.has(skillName)) {
        throw new ImportError(`Bundle '${bundle.id}': unbekannter Skill '${skillName}'`);
      }
    }
  }

  // Related-skill referential integrity.
  for (const p of products) {
    for (const relatedName of p.related) {
      if (!productNames.has(relatedName)) {
        throw new ImportError(`Skill '${p.name}': unbekannter related-Skill '${relatedName}'`);
      }
    }
  }

  const db = openDb(dbPath);
  const now = new Date().toISOString();

  const writeAll = db.transaction(() => {
    const existing = db.prepare('SELECT id, name FROM skills').all();
    const currentNames = new Set(products.map((p) => p.name));
    const orphans = existing.filter((row) => !currentNames.has(row.name));
    for (const orphan of orphans) {
      db.prepare('DELETE FROM skills WHERE id = ?').run(orphan.id);
      warnings.push(`Waise entfernt: Skill '${orphan.name}' nicht mehr in Dateien gefunden`);
    }

    const upsertSkill = db.prepare(`
      INSERT INTO skills (name, trigger_cmd, description, claim, short, long, status, risk, price_tier, uncurated, folder_hash, imported_at)
      VALUES (@name, @trigger, @description, @claim, @short, @long, @status, @risk, @priceTier, @uncurated, @folderHash, @importedAt)
      ON CONFLICT(name) DO UPDATE SET
        trigger_cmd=excluded.trigger_cmd, description=excluded.description, claim=excluded.claim,
        short=excluded.short, long=excluded.long, status=excluded.status, risk=excluded.risk,
        price_tier=excluded.price_tier, uncurated=excluded.uncurated, folder_hash=excluded.folder_hash,
        imported_at=excluded.imported_at
    `);
    const getSkillId = db.prepare('SELECT id FROM skills WHERE name = ?');
    const upsertTerm = db.prepare(`
      INSERT INTO taxonomy_terms (dimension, term) VALUES (?, ?)
      ON CONFLICT(dimension, term) DO NOTHING
    `);
    const getTermId = db.prepare('SELECT id FROM taxonomy_terms WHERE dimension = ? AND term = ?');
    const clearSkillTerms = db.prepare('DELETE FROM skill_terms WHERE skill_id = ?');
    const insertSkillTerm = db.prepare('INSERT INTO skill_terms (skill_id, term_id) VALUES (?, ?)');
    const clearPrices = db.prepare("DELETE FROM prices WHERE ref_type = 'skill' AND ref_id = ?");
    const insertPrice = db.prepare(`
      INSERT INTO prices (ref_type, ref_id, tier, amount_cents, currency) VALUES ('skill', ?, ?, 0, 'EUR')
    `);
    const clearFts = db.prepare('DELETE FROM skills_fts');
    const clearRelated = db.prepare('DELETE FROM skill_related WHERE skill_id = ?');
    const insertRelated = db.prepare('INSERT INTO skill_related (skill_id, related_name) VALUES (?, ?)');

    for (const [dim, terms] of Object.entries(taxonomy)) {
      for (const term of terms) upsertTerm.run(dim, term);
    }

    for (const p of products) {
      upsertSkill.run({
        name: p.name, trigger: p.trigger, description: p.description, claim: p.claim,
        short: p.short, long: p.long, status: p.status, risk: p.risk,
        priceTier: p.priceTier, uncurated: p.uncurated ? 1 : 0, folderHash: p.folderHash,
        importedAt: now,
      });
      const skillId = getSkillId.get(p.name).id;
      clearSkillTerms.run(skillId);
      const flatTerms = [];
      for (const [dim, terms] of Object.entries(p.terms)) {
        for (const term of terms) {
          const row = getTermId.get(dim, term);
          insertSkillTerm.run(skillId, row.id);
          flatTerms.push(term);
        }
      }
      clearPrices.run(skillId);
      insertPrice.run(skillId, p.priceTier);
      clearRelated.run(skillId);
      for (const relatedName of p.related) {
        insertRelated.run(skillId, relatedName);
      }
    }

    // FTS rebuild (all products).
    clearFts.run();
    const insertFts = db.prepare(
      'INSERT INTO skills_fts (rowid, name, claim, short, long, terms_flat) VALUES (@rowid, @name, @claim, @short, @long, @termsFlat)'
    );
    for (const p of products) {
      const skillId = getSkillId.get(p.name).id;
      const flat = Object.values(p.terms).flat().join(' ');
      insertFts.run({ rowid: skillId, name: p.name, claim: p.claim, short: p.short, long: p.long, termsFlat: flat });
    }

    // Bundles.
    const existingBundles = db.prepare('SELECT id, slug FROM bundles').all();
    const currentSlugs = new Set(catalogBundles.map((b) => b.id));
    for (const row of existingBundles) {
      if (!currentSlugs.has(row.slug)) {
        db.prepare('DELETE FROM bundles WHERE id = ?').run(row.id);
        warnings.push(`Bundle entfernt: '${row.slug}' nicht mehr in catalog/bundles gefunden`);
      }
    }
    const upsertBundle = db.prepare(`
      INSERT INTO bundles (slug, title, claim, story, price_tier) VALUES (@slug, @title, @claim, @story, @priceTier)
      ON CONFLICT(slug) DO UPDATE SET title=excluded.title, claim=excluded.claim, story=excluded.story, price_tier=excluded.price_tier
    `);
    const getBundleId = db.prepare('SELECT id FROM bundles WHERE slug = ?');
    const clearBundleSkills = db.prepare('DELETE FROM bundle_skills WHERE bundle_id = ?');
    const insertBundleSkill = db.prepare('INSERT INTO bundle_skills (bundle_id, skill_id) VALUES (?, ?)');
    const clearBundlePrices = db.prepare("DELETE FROM prices WHERE ref_type = 'bundle' AND ref_id = ?");
    const insertBundlePrice = db.prepare(`
      INSERT INTO prices (ref_type, ref_id, tier, amount_cents, currency) VALUES ('bundle', ?, ?, 0, 'EUR')
    `);

    for (const b of catalogBundles) {
      upsertBundle.run({
        slug: b.id, title: b.title, claim: b.claim, story: b.story,
        priceTier: b.priceTier || 'bundle',
      });
      const bundleId = getBundleId.get(b.id).id;
      clearBundleSkills.run(bundleId);
      for (const skillName of b.skills || []) {
        const skillId = getSkillId.get(skillName).id;
        insertBundleSkill.run(bundleId, skillId);
      }
      clearBundlePrices.run(bundleId);
      insertBundlePrice.run(bundleId, b.priceTier || 'bundle');
    }
  });

  writeAll();
  db.close();

  const verfuegbar = products.filter((p) => p.status === 'verfuegbar').length;
  const inEntwicklung = products.filter((p) => p.status === 'in-entwicklung').length;
  const uncurated = products.filter((p) => p.uncurated).length;
  const termsByDimension = {};
  for (const dim of DIMENSIONS) termsByDimension[dim] = taxonomy[dim].size;

  return {
    skills: { verfuegbar, inEntwicklung, uncurated, total: products.length },
    bundles: catalogBundles.length,
    termsByDimension,
    warnings,
  };
}

module.exports = {
  ImportError,
  parseFrontmatter,
  computeFolderHash,
  listFilesSorted,
  scanSkillFolders,
  parseTrackingTable,
  loadTaxonomy,
  loadCatalogSkills,
  loadCatalogBundles,
  runImport,
  DIMENSIONS,
};
