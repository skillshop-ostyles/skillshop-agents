'use strict';

// Shared helpers for all shop pages. Plain script (no build step, no framework).
// Reine, DOM-freie Logik liegt in shop-core.js (dort auch getestet); app.js macht
// nur das DOM-nahe Drumherum: Header rendern, Theme, Karten, Warenkorb-UI.
window.Shop = (function () {
  const Core = window.ShopCore;

  const DIMENSIONS = Core.DIMENSIONS;
  const DIMENSION_LABELS = {
    usecase: 'Usecase',
    thema: 'Thema',
    stichwort: 'Stichwort',
    ziel: 'Ziel',
    branche: 'Branche',
    taetigkeit: 'Tätigkeit',
    level: 'Level',
    risiko: 'Risiko',
  };

  const escapeHtml = Core.escapeHtml;

  // Freundliche Anzeige-Labels fuer die kebab-case Usecase-Terme (Datenwerte bleiben unveraendert).
  const USECASE_LABELS = {
    'legacy-verstehen': 'Alt-Code verstehen',
    'release-absichern': 'Releases absichern',
    'incident-aufklaeren': 'Incidents aufklären',
    'onboarding': 'Onboarding beschleunigen',
    'audit-vorbereiten': 'Audits vorbereiten',
    'aufraeumen': 'Aufräumen',
    'neu-starten': 'Neu starten',
    'qualitaet-heben': 'Qualität heben',
    'migration-planen': 'Migration planen',
  };
  function usecaseLabel(term) { return USECASE_LABELS[term] || term; }

  async function fetchJson(url) {
    const res = await fetch(url);
    if (res.status === 503) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || 'Datenbank nicht verfügbar');
    }
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || `Fehler ${res.status}`);
    }
    return res.json();
  }

  // Voller Status-Badge mit Punkt (Produkt-/Detailseiten).
  function statusBadge(status) {
    return status === 'verfuegbar'
      ? '<span class="badge status-ok">verfügbar</span>'
      : '<span class="badge status-soon">bald verfügbar</span>';
  }

  function riskBadge(risk) {
    const write = risk === 'schreibend-mit-freigabe';
    return `<span class="badge ${write ? 'risk-write' : 'risk-read'}">${write ? 'schreibend' : 'read-only'}</span>`;
  }

  function triggerChip(trigger) {
    return `<span class="chip">${escapeHtml(trigger)}</span>`;
  }

  // Preis nur wenn das Pricing-Flag serverseitig aktiv ist (API liefert `price` erst dann).
  function priceLabel(price) {
    const text = Core.formatPrice(price);
    return text ? `<span class="tag tag-price">${escapeHtml(text)}</span>` : '';
  }

  // Kompakte Karten-Bausteine: Status als Punkt, Risiko/Preis als dezente Tags.
  function statusDot(status) {
    return status === 'verfuegbar'
      ? '<span class="status-dot is-ok">verfügbar</span>'
      : '<span class="status-dot is-soon">bald</span>';
  }
  function riskTag(risk) {
    const write = risk === 'schreibend-mit-freigabe';
    return `<span class="tag ${write ? 'tag-risk-write' : ''}">${write ? 'schreibend' : 'read-only'}</span>`;
  }

  function card(skill) {
    const foot = [riskTag(skill.risk)];
    if (skill.uncurated) foot.push('<span class="tag tag-muted">unkuratiert</span>');
    if (skill.price) foot.push(priceLabel(skill.price));
    return `
      <a class="card" href="skill.html?name=${encodeURIComponent(skill.name)}">
        <div class="card-head">
          <code class="card-cmd">${escapeHtml(skill.trigger)}</code>
          ${statusDot(skill.status)}
        </div>
        <h3 class="card-title">${escapeHtml(skill.name)}</h3>
        <p class="claim">${escapeHtml(skill.claim)}</p>
        <div class="card-foot">${foot.join('')}</div>
      </a>
    `;
  }

  function bundleCard(bundle) {
    const ok = bundle.status.verfuegbar;
    const total = bundle.status.total;
    return `
      <a class="card card-bundle" href="bundle.html?slug=${encodeURIComponent(bundle.slug)}">
        <div class="card-head">
          <span class="tag">◆ Bundle</span>
          ${priceLabel(bundle.price)}
        </div>
        <h3 class="card-title">${escapeHtml(bundle.title)}</h3>
        <p class="claim">${escapeHtml(bundle.claim)}</p>
        <div class="card-foot">
          <span class="status-dot ${ok > 0 ? 'is-ok' : 'is-soon'}">${ok} von ${total} verfügbar</span>
        </div>
      </a>
    `;
  }

  function renderShelf(container, title, itemsHtml, moreHref) {
    if (itemsHtml.length === 0) return;
    const section = document.createElement('section');
    section.className = 'shelf';
    const more = moreHref ? `<a href="${moreHref}">Alle ansehen →</a>` : '';
    section.innerHTML = `<div class="shelf-head"><h2>${escapeHtml(title)}</h2>${more}</div><div class="shelf-row">${itemsHtml.join('')}</div>`;
    container.appendChild(section);
  }

  function currentParams() {
    return new URLSearchParams(window.location.search);
  }

  function apiUrlFromParams(base, params) {
    const qs = params.toString();
    return qs ? `${base}?${qs}` : base;
  }

  // ---------- Theme (D4: Hell/Dunkel/System, im localStorage, live umschaltbar) ----------

  const THEME_KEY = 'shop-theme';
  const THEMES = ['system', 'light', 'dark'];
  const THEME_LABEL = { system: 'System', light: 'Hell', dark: 'Dunkel' };

  function getTheme() {
    try { return window.localStorage.getItem(THEME_KEY) || 'system'; } catch (e) { return 'system'; }
  }
  function applyTheme(t) {
    const html = document.documentElement;
    if (t === 'system') html.removeAttribute('data-theme');
    else html.setAttribute('data-theme', t);
  }
  function setTheme(t) {
    try { window.localStorage.setItem(THEME_KEY, t); } catch (e) { /* ignore */ }
    applyTheme(t);
    updateThemeToggleLabel();
  }
  function cycleTheme() {
    const next = THEMES[(THEMES.indexOf(getTheme()) + 1) % THEMES.length];
    setTheme(next);
  }
  function updateThemeToggleLabel() {
    const b = document.getElementById('theme-toggle');
    if (b) b.textContent = `Design: ${THEME_LABEL[getTheme()]}`;
  }

  // ---------- Kopfzeile (C1: EINE Quelle statt 8x kopiertem HTML) ----------

  const NAV = [
    { href: 'katalog.html', label: 'Katalog' },
    { href: 'berater.html', label: 'Berater' },
    { href: 'warenkorb.html', label: 'Warenkorb', cart: true },
    { href: 'bibliothek.html', label: 'Bibliothek' },
    { href: 'merkliste.html', label: 'Merkliste' },
  ];

  function currentPage() {
    return window.location.pathname.split('/').pop() || 'index.html';
  }

  function renderHeader() {
    const host = document.getElementById('site-header');
    if (!host) return;
    const active = currentPage();
    const links = NAV.map((n) => {
      const isActive = n.href === active ? ' aria-current="page"' : '';
      const label = n.cart ? `${n.label} (<span id="cart-count">0</span>)` : n.label;
      return `<a href="${n.href}"${isActive}>${label}</a>`;
    }).join('');
    host.className = 'site-header';
    host.innerHTML = `
      <div class="container">
        <a class="brand" href="index.html"><span class="brand-mark">/</span>Skill-Shop</a>
        <nav class="nav-links">
          ${links}
          <button type="button" id="theme-toggle" class="btn secondary theme-toggle"></button>
        </nav>
      </div>`;
    document.getElementById('theme-toggle').addEventListener('click', cycleTheme);
    updateThemeToggleLabel();
    cart.updateBadge();
  }

  // Fusszeile aus einer Quelle (gleicher Grund wie renderHeader: C1 - der
  // Nav-Header war 8x kopiert, das darf der Fusszeile nicht nochmal passieren).
  function renderFooter() {
    const host = document.getElementById('site-footer');
    if (!host) return;
    host.className = 'site-footer';
    host.innerHTML = `
      <div class="container">
        <span class="foot-brand"><span class="brand-mark">/</span> Skill-Shop</span>
        <span>Lokal, ohne Telemetrie · „Skill is the hero." · <a href="transparenz.html">Transparenz</a></span>
      </div>`;
  }

  // ---------- Warenkorb (localStorage, robust gegen vollen/defekten Storage) ----------
  // Einträge sind { name, fromBundle } - fromBundle ist der Bundle-Slug, falls der
  // Skill über "Bundle in den Warenkorb" hinzugefügt wurde, sonst null.

  const CART_KEY = 'shop-cart';

  const cart = {
    get() {
      try {
        const raw = window.localStorage.getItem(CART_KEY);
        return Core.normalizeCartEntries(raw ? JSON.parse(raw) : []);
      } catch (err) {
        return [];
      }
    },
    set(entries) {
      try {
        window.localStorage.setItem(CART_KEY, JSON.stringify(Core.dedupeCartEntries(entries)));
      } catch (err) {
        // localStorage voll/deaktiviert - Korb bleibt für diese Session leer statt zu crashen.
      }
    },
    add(name, fromBundle = null) {
      const entries = cart.get();
      const existing = entries.find((e) => e.name === name);
      if (existing) {
        if (fromBundle) existing.fromBundle = fromBundle;
      } else {
        entries.push({ name, fromBundle });
      }
      cart.set(entries);
      cart.updateBadge();
    },
    remove(name) {
      cart.set(cart.get().filter((e) => e.name !== name));
      cart.updateBadge();
    },
    names() {
      return cart.get().map((e) => e.name);
    },
    has(name) {
      return cart.get().some((e) => e.name === name);
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

  // Theme sofort anwenden (vor DOMContentLoaded), damit kein Flash entsteht.
  applyTheme(getTheme());

  return {
    DIMENSIONS, DIMENSION_LABELS, escapeHtml, fetchJson,
    statusBadge, riskBadge, triggerChip, priceLabel, statusDot, riskTag, card, bundleCard, renderShelf,
    currentParams, apiUrlFromParams, cart, renderHeader, renderFooter, usecaseLabel,
    sumPrices: Core.sumPrices, formatPrice: Core.formatPrice, sortSkills: Core.sortSkills,
  };
})();

document.addEventListener('DOMContentLoaded', () => {
  window.Shop.renderHeader();
  window.Shop.renderFooter();
});
