'use strict';

const crypto = require('node:crypto');

/** Reads the price row for a skill or bundle, or null if none exists. */
function getPrice(db, refType, refId) {
  const row = db
    .prepare('SELECT tier, amount_cents AS amountCents, currency FROM prices WHERE ref_type = ? AND ref_id = ?')
    .get(refType, refId);
  return row || null;
}

/** Generates a placeholder license id, e.g. LIC-20260721-a1b2c3. Not a real license system. */
function generateLicense(now = new Date()) {
  const dateStr = now.toISOString().slice(0, 10).replace(/-/g, '');
  const random = crypto.randomBytes(3).toString('hex');
  return `LIC-${dateStr}-${random}`;
}

module.exports = { getPrice, generateLicense };
