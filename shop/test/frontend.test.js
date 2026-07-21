'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

// D2: die reine Frontend-Logik ist ohne Browser testbar, weil sie in shop-core.js
// DOM-frei liegt. Genau dieselbe Datei laedt der Browser via <script>.
const ShopCore = require('../public/shop-core.js');

test('escapeHtml escapes the dangerous characters', () => {
  assert.equal(ShopCore.escapeHtml('<a href="x">&\'</a>'), '&lt;a href=&quot;x&quot;&gt;&amp;&#39;&lt;/a&gt;');
});

test('normalizeCartEntries migrates old string entries to {name, fromBundle}', () => {
  // Sprint-23-Format war ein reines Namens-Array.
  assert.deepEqual(
    ShopCore.normalizeCartEntries(['elevate', 'project-init']),
    [{ name: 'elevate', fromBundle: null }, { name: 'project-init', fromBundle: null }]
  );
});

test('normalizeCartEntries keeps object entries and drops junk', () => {
  const input = [{ name: 'a', fromBundle: 'bundle-x' }, { nope: 1 }, null, 42, 'b'];
  assert.deepEqual(ShopCore.normalizeCartEntries(input), [
    { name: 'a', fromBundle: 'bundle-x' },
    { name: 'b', fromBundle: null },
  ]);
});

test('normalizeCartEntries returns [] for non-arrays', () => {
  assert.deepEqual(ShopCore.normalizeCartEntries(null), []);
  assert.deepEqual(ShopCore.normalizeCartEntries('kaputt'), []);
});

test('dedupeCartEntries keeps the last entry per name', () => {
  const input = [{ name: 'a', fromBundle: null }, { name: 'a', fromBundle: 'b1' }];
  assert.deepEqual(ShopCore.dedupeCartEntries(input), [{ name: 'a', fromBundle: 'b1' }]);
});

test('formatPrice: 0 -> kostenlos, else amount + currency', () => {
  assert.equal(ShopCore.formatPrice({ amountCents: 0, currency: 'EUR' }), 'kostenlos');
  assert.equal(ShopCore.formatPrice({ amountCents: 1250, currency: 'EUR' }), '12.50 EUR');
  assert.equal(ShopCore.formatPrice(null), '');
});

test('sumPrices adds amounts, returns null when any price is missing', () => {
  assert.deepEqual(
    ShopCore.sumPrices([{ amountCents: 100, currency: 'EUR' }, { amountCents: 250, currency: 'EUR' }]),
    { amountCents: 350, currency: 'EUR' }
  );
  assert.equal(ShopCore.sumPrices([{ amountCents: 100, currency: 'EUR' }, null]), null);
  assert.equal(ShopCore.sumPrices([]), null);
});
