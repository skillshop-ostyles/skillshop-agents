'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const { withServer, withImportedDb, tmpDir, postJson } = require('./helpers');
const { generateLicense } = require('../src/pricing');

const FIXTURE_ROOT = path.join(__dirname, 'fixture', 'root');
const CATALOG_OK = path.join(__dirname, 'fixture', 'catalog');

function server(pricingEnabled) {
  const dbPath = withImportedDb(FIXTURE_ROOT, CATALOG_OK);
  return withServer({ dbPath, rootDir: FIXTURE_ROOT, pricingEnabled });
}

test('pricing flag off (default): API responses carry no price field', async () => {
  const { base, close } = await server(false);
  try {
    const skills = await (await fetch(`${base}/api/skills`)).json();
    assert.ok(!('price' in skills[0]));

    const skill = await (await fetch(`${base}/api/skills/demo-skill-a`)).json();
    assert.ok(!('price' in skill));

    const bundles = await (await fetch(`${base}/api/bundles`)).json();
    assert.ok(!('price' in bundles[0]));
    assert.ok(!('price' in bundles[0].skills[0]));

    const bundle = await (await fetch(`${base}/api/bundles/demo-bundle`)).json();
    assert.ok(!('price' in bundle));
  } finally {
    await close();
  }
});

test('pricing flag on: API responses carry a price field (amount 0 = kostenlos in Phase 1)', async () => {
  const { base, close } = await server(true);
  try {
    const skills = await (await fetch(`${base}/api/skills`)).json();
    assert.deepEqual(skills[0].price, { tier: 'single', amountCents: 0, currency: 'EUR' });

    const skill = await (await fetch(`${base}/api/skills/demo-skill-a`)).json();
    assert.deepEqual(skill.price, { tier: 'single', amountCents: 0, currency: 'EUR' });

    const bundles = await (await fetch(`${base}/api/bundles`)).json();
    assert.equal(bundles[0].price.tier, 'bundle');
    assert.equal(bundles[0].price.amountCents, 0);
    assert.ok(bundles[0].skills[0].price);

    const bundle = await (await fetch(`${base}/api/bundles/demo-bundle`)).json();
    assert.equal(bundle.price.tier, 'bundle');
  } finally {
    await close();
  }
});

test('checkout: license stays null when pricing is off', async () => {
  const { base, close } = await server(false);
  const target = tmpDir('shop-pricing-target-');
  try {
    const { body } = await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-a'] });
    assert.equal(body.license, null);
  } finally {
    await close();
  }
});

test('checkout: a LIC-<date>-<hex> license is generated when pricing is on', async () => {
  const { base, close } = await server(true);
  const target = tmpDir('shop-pricing-target-');
  try {
    const { body } = await postJson(base, '/api/checkout', { targetPath: target, items: ['demo-skill-a'] });
    assert.match(body.license, /^LIC-\d{8}-[0-9a-f]{6}$/);
  } finally {
    await close();
  }
});

test('generateLicense: format is stable and varies per call', () => {
  const a = generateLicense(new Date('2026-07-21T00:00:00Z'));
  const b = generateLicense(new Date('2026-07-21T00:00:00Z'));
  assert.match(a, /^LIC-20260721-[0-9a-f]{6}$/);
  assert.match(b, /^LIC-20260721-[0-9a-f]{6}$/);
  assert.notEqual(a, b, 'random suffix should differ between calls');
});
