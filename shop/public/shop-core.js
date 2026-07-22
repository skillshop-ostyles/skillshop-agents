/* shop-core.js — reine, DOM-freie Logik des Shops.
 * UMD: laedt sowohl im Browser (window.ShopCore) als auch via require() in node:test.
 * Alles hier ist ohne Browser testbar (D2). Kein fetch, kein document, kein window. */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.ShopCore = factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }

  /** Rohes localStorage-Array in die kanonische Form [{name, fromBundle}] bringen.
   *  Alte Eintraege (reine Namens-Strings, Sprint 23) werden migriert statt verworfen. */
  function normalizeCartEntries(parsed) {
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map((entry) => {
        if (typeof entry === 'string') return { name: entry, fromBundle: null };
        if (entry && typeof entry === 'object' && typeof entry.name === 'string') {
          return { name: entry.name, fromBundle: entry.fromBundle || null };
        }
        return null;
      })
      .filter(Boolean);
  }

  /** Doppelte Namen entfernen (letzter gewinnt bei fromBundle). */
  function dedupeCartEntries(entries) {
    const byName = new Map();
    for (const e of entries) byName.set(e.name, e);
    return [...byName.values()];
  }

  /** Ein Preis-Objekt {amountCents, currency} formatieren. 0 -> "kostenlos". */
  function formatPrice(price) {
    if (!price) return '';
    if (price.amountCents === 0) return 'kostenlos';
    return `${(price.amountCents / 100).toFixed(2)} ${price.currency}`;
  }

  /** Summe mehrerer Preise. Null, wenn ein Preis fehlt (dann keine Summe zeigen). */
  function sumPrices(prices) {
    if (prices.length === 0 || prices.some((p) => !p)) return null;
    const amountCents = prices.reduce((s, p) => s + p.amountCents, 0);
    return { amountCents, currency: prices[0].currency };
  }

  const DIMENSIONS = ['usecase', 'thema', 'stichwort', 'ziel', 'branche', 'taetigkeit', 'level', 'risiko'];

  /** Sortiert eine Skill-Liste fuer die Katalog-Ansicht (rein clientseitig,
   *  kein API-Query-Param). 'relevanz' laesst die vom Server gelieferte
   *  Reihenfolge unveraendert. */
  function sortSkills(skills, mode) {
    const list = skills.slice();
    if (mode === 'name') {
      list.sort((a, b) => a.name.localeCompare(b.name));
    } else if (mode === 'status') {
      const rank = (s) => (s.status === 'verfuegbar' ? 0 : 1);
      list.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
    }
    return list;
  }

  return { escapeHtml, normalizeCartEntries, dedupeCartEntries, formatPrice, sumPrices, sortSkills, DIMENSIONS };
});
