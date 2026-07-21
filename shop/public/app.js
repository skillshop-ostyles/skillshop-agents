'use strict';

// Shared helpers for all shop pages. Plain script (no build step, no framework).
// Every page mounts itself from the URL - the URL is the only state that matters
// (SHOP-BIBEL-Sprint-22: "kein SPA-State").
window.Shop = (function () {
  const DIMENSIONS = ['usecase', 'thema', 'stichwort', 'ziel', 'branche', 'taetigkeit', 'level', 'risiko'];
  const DIMENSION_LABELS = {
    usecase: 'Usecase',
    thema: 'Thema',
    stichwort: 'Stichwort',
    ziel: 'Ziel',
    branche: 'Branche',
    taetigkeit: 'Taetigkeit',
    level: 'Level',
    risiko: 'Risiko',
  };

  function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    })[c]);
  }

  async function fetchJson(url) {
    const res = await fetch(url);
    if (res.status === 503) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || 'Datenbank nicht verfuegbar');
    }
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || `Fehler ${res.status}`);
    }
    return res.json();
  }

  function statusBadge(status) {
    return status === 'verfuegbar'
      ? '<span class="badge status-ok">verfuegbar</span>'
      : '<span class="badge status-soon">bald verfuegbar</span>';
  }

  function riskBadge(risk) {
    const write = risk === 'schreibend-mit-freigabe';
    return `<span class="badge ${write ? 'risk-write' : 'risk-read'}">${write ? 'schreibend' : 'read-only'}</span>`;
  }

  function triggerChip(trigger) {
    return `<span class="chip">${escapeHtml(trigger)}</span>`;
  }

  function card(skill) {
    const badges = [statusBadge(skill.status), riskBadge(skill.risk)];
    if (skill.uncurated) badges.push('<span class="badge uncurated">unkuratiert</span>');
    return `
      <a class="card" href="skill.html?name=${encodeURIComponent(skill.name)}">
        <h3>${escapeHtml(skill.name)}</h3>
        <p class="claim">${escapeHtml(skill.claim)}</p>
        <div class="card-badges">${badges.join('')}${triggerChip(skill.trigger)}</div>
      </a>
    `;
  }

  function bundleCard(bundle) {
    return `
      <a class="card" href="bundle.html?slug=${encodeURIComponent(bundle.slug)}">
        <h3>${escapeHtml(bundle.title)}</h3>
        <p class="claim">${escapeHtml(bundle.claim)}</p>
        <div class="card-badges">
          <span class="badge status-ok">${bundle.status.verfuegbar} von ${bundle.status.total} verfuegbar</span>
        </div>
      </a>
    `;
  }

  function renderShelf(container, title, itemsHtml) {
    if (itemsHtml.length === 0) return;
    const section = document.createElement('section');
    section.className = 'shelf';
    section.innerHTML = `<h2>${escapeHtml(title)}</h2><div class="shelf-row">${itemsHtml.join('')}</div>`;
    container.appendChild(section);
  }

  function currentParams() {
    return new URLSearchParams(window.location.search);
  }

  function apiUrlFromParams(base, params) {
    const qs = params.toString();
    return qs ? `${base}?${qs}` : base;
  }

  // ---------- Warenkorb (localStorage, robust gegen vollen/defekten Storage) ----------

  const CART_KEY = 'shop-cart';

  const cart = {
    get() {
      try {
        const raw = window.localStorage.getItem(CART_KEY);
        const parsed = raw ? JSON.parse(raw) : [];
        return Array.isArray(parsed) ? parsed : [];
      } catch (err) {
        return [];
      }
    },
    set(names) {
      try {
        window.localStorage.setItem(CART_KEY, JSON.stringify([...new Set(names)]));
      } catch (err) {
        // localStorage voll/deaktiviert - Korb bleibt fuer diese Session leer statt zu crashen.
      }
    },
    add(name) {
      const names = cart.get();
      if (!names.includes(name)) names.push(name);
      cart.set(names);
      cart.updateBadge();
    },
    remove(name) {
      cart.set(cart.get().filter((n) => n !== name));
      cart.updateBadge();
    },
    clear() {
      cart.set([]);
      cart.updateBadge();
    },
    count() {
      return cart.get().length;
    },
    updateBadge() {
      const el = document.getElementById('cart-count');
      if (el) el.textContent = String(cart.count());
    },
  };

  return {
    DIMENSIONS, DIMENSION_LABELS, escapeHtml, fetchJson,
    statusBadge, riskBadge, triggerChip, card, bundleCard, renderShelf,
    currentParams, apiUrlFromParams, cart,
  };
})();

document.addEventListener('DOMContentLoaded', () => window.Shop.cart.updateBadge());
