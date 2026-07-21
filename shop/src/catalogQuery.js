'use strict';

const { DIMENSIONS } = require('./importer');

/** Escapes free text into a safe FTS5 phrase query (avoids FTS5 operator injection). */
function escapeFtsQuery(q) {
  return `"${String(q).replace(/"/g, '""')}"`;
}

/**
 * Parses an Express req.query object into a normalized filter shape.
 * @returns {{status: string|null, q: string|null, dims: Record<string,string[]>}}
 */
function parseFilters(query) {
  const dims = {};
  for (const dim of DIMENSIONS) {
    if (query[dim] === undefined) continue;
    const values = Array.isArray(query[dim]) ? query[dim] : [query[dim]];
    dims[dim] = values.filter((v) => typeof v === 'string' && v.length > 0);
  }
  const status = typeof query.status === 'string' && query.status.length > 0 ? query.status : null;
  const q = typeof query.q === 'string' && query.q.trim().length > 0 ? query.q.trim() : null;
  return { status, q, dims };
}

/**
 * Builds the WHERE-clause fragments + params for the current filter set.
 * @param {object} filters from parseFilters()
 * @param {string[]} excludeDims dimensions to skip (used by facet counting)
 */
function buildWhere(filters, excludeDims = []) {
  const clauses = [];
  const params = [];

  if (filters.status) {
    clauses.push('s.status = ?');
    params.push(filters.status);
  }

  if (filters.q) {
    clauses.push('s.id IN (SELECT rowid FROM skills_fts WHERE skills_fts MATCH ?)');
    params.push(escapeFtsQuery(filters.q));
  }

  for (const [dim, terms] of Object.entries(filters.dims)) {
    if (excludeDims.includes(dim)) continue;
    if (!terms || terms.length === 0) continue;
    const placeholders = terms.map(() => '?').join(', ');
    clauses.push(`
      s.id IN (
        SELECT st.skill_id FROM skill_terms st
        JOIN taxonomy_terms tt ON tt.id = st.term_id
        WHERE tt.dimension = ? AND tt.term IN (${placeholders})
      )
    `);
    params.push(dim, ...terms);
  }

  return {
    sql: clauses.length > 0 ? `WHERE ${clauses.join(' AND ')}` : '',
    params,
  };
}

const CARD_FIELDS = 'id, name, trigger_cmd AS trigger, description, claim, short, long, status, risk, price_tier AS priceTier, uncurated';

/**
 * Returns the filtered + sorted product list (card fields only, no terms attached).
 */
function queryProducts(db, filters) {
  const { sql, params } = buildWhere(filters);
  const rows = db
    .prepare(`
      SELECT ${CARD_FIELDS} FROM skills s
      ${sql}
      ORDER BY CASE WHEN status = 'verfuegbar' THEN 0 ELSE 1 END, name ASC
    `)
    .all(...params);
  return rows;
}

/** Attaches `terms: {dimension: [term, ...]}` to each skill row (mutates + returns). */
function attachTerms(db, skillRows) {
  if (skillRows.length === 0) return skillRows;
  const byId = new Map(skillRows.map((r) => [r.id, r]));
  for (const row of skillRows) row.terms = {};
  const placeholders = skillRows.map(() => '?').join(', ');
  const rows = db
    .prepare(`
      SELECT st.skill_id AS skillId, tt.dimension AS dimension, tt.term AS term
      FROM skill_terms st JOIN taxonomy_terms tt ON tt.id = st.term_id
      WHERE st.skill_id IN (${placeholders})
    `)
    .all(...skillRows.map((r) => r.id));
  for (const row of rows) {
    const skill = byId.get(row.skillId);
    if (!skill.terms[row.dimension]) skill.terms[row.dimension] = [];
    skill.terms[row.dimension].push(row.term);
  }
  return skillRows;
}

/**
 * Computes term counts per dimension under the current filter, excluding each
 * dimension's own filter so users can still see (and change) their selection
 * within that facet - the standard faceted-navigation pattern.
 */
function computeFacets(db, filters) {
  const result = {};
  for (const dim of DIMENSIONS) {
    const { sql, params } = buildWhere(filters, [dim]);
    const rows = db
      .prepare(`
        SELECT tt.term AS term, COUNT(DISTINCT s.id) AS count
        FROM skills s
        JOIN skill_terms st ON st.skill_id = s.id
        JOIN taxonomy_terms tt ON tt.id = st.term_id AND tt.dimension = ?
        ${sql}
        GROUP BY tt.term
        HAVING COUNT(DISTINCT s.id) > 0
        ORDER BY count DESC, term ASC
      `)
      .all(dim, ...params);
    result[dim] = rows;
  }
  return result;
}

module.exports = { escapeFtsQuery, parseFilters, buildWhere, queryProducts, attachTerms, computeFacets, CARD_FIELDS };
