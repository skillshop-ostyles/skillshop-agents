# SHOP-BIBEL — Skill-Shop

Masterspezifikation für den Skill-Shop. Erbt `ops/BIBEL.md` vollständig — alles dort
gilt auch hier (lokal-only, Schutzregel `~/.claude/`, Karpathy, Sprachstil, Sprint-
und Test-Protokoll, DoD, Eskalation). Dieses Dokument ergänzt die shop-spezifischen
Regeln. Bei Widerspruch zwischen Sprint-File und dieser Bibel gilt diese Bibel; bei
Widerspruch zwischen dieser und `ops/BIBEL.md` gilt `ops/BIBEL.md`.

Ausführendes Modell: **Sonnet**, Sprints 21-25.

---

## 1. Vision & Positionierung

**"Skill is the hero."** — Der Shop ist Marktplatz und Fachgeschäft in einem:

- **Marktplatz**: Breite, facettierte Navigation, Volltextsuche — jeder Skill über
  viele Wege findbar (Usecase, Thema, Stichwort, Ziel, Branche, Tätigkeit).
- **Fachgeschäft**: Kuratierung, Beratung, Bundles mit Story — der Shop empfiehlt
  wie ein erfahrener Kollege, nicht wie ein Algorithmus-Karussell.

Produkt ist der Skill. Jede Produktseite verkauft die LÖSUNG eines echten
Entwickler-Schmerzes, nicht ein Feature-Datenblatt.

Tonalität: simpel, modern, minimalistisch, konkret. Kein Marketing-Geschwurbel —
die Problem/Nutzen-Texte der Sprint-Files sind die Copy-Quelle, sie sind bereits
ehrlich und präzise. UI-Sprache: Deutsch. Kauf-Metapher konsequent durchziehen
(Regal, Warenkorb, Kasse, Bibliothek), aber nie albern.

---

## 2. Shop-Regeln (ergänzend zur BIBEL)

1. **Dependency-Inseln**: npm-Dependencies NUR innerhalb `shop/` (dort package.json
   + package-lock.json). Der Rest des Repos bleibt toolfrei. Erlaubte Runtime-Deps:
   `express`, `better-sqlite3`, `compression` (seit Produktionsparitaet-Härtung,
   siehe `ops/sprints/sprint-27-produktionsparitaet.md` — Gzip/Brotli-Kompression
   der Auslieferung, wie ein echter Static-Host sie hätte). Keine Frontend-
   Frameworks, kein Build-Schritt — Frontend ist statisches HTML/CSS/Vanilla-JS
   aus `shop/public/`.
2. **DB ist abgeleitet**: Die SQLite-DB (`shop/data/shop.db`) ist jederzeit per
   Importer aus den Dateien reproduzierbar (Skill-Ordner + `shop/catalog/` +
   `ops/tracking.md`). DB-Datei und `node_modules/` sind gitignored. Quelle der
   Wahrheit sind IMMER die Dateien — niemals Katalogdaten nur in der DB pflegen.
   Ausnahme: Bewegungsdaten (orders, watchlist) leben nur in der DB; ihr Verlust
   ist verkraftbar und wird dokumentiert.
3. **Installer-Schutzregel**: Installationsziel niemals `~/.claude/` (Guard aus
   BIBEL § 2.2, in JS portiert: Pfad-Normalisierung + Vergleich, Test Pflicht).
   Installation erfolgt nach `<zielprojekt>/.claude/skills/<skill-name>/`
   (Claude-Code-Projekt-Skills). Das Zielprojekt muss existieren; der Installer
   legt nur den `.claude/skills/`-Unterbaum an. Überschreiben eines vorhandenen
   Skills im Ziel nur nach explizitem Re-Install-Befehl des Users (UI fragt).
4. **Localhost-only**: Server bindet an `127.0.0.1`. Keine Telemetrie, keine
   externen HTTP-Calls zur Laufzeit, keine CDN-Assets (alles lokal ausgeliefert).
5. **Ehrlichkeits-Prinzip**: Status-Badges kommen aus `ops/tracking.md`
   (`fertig` → `verfuegbar`, sonst `in-entwicklung`). Nur `verfuegbar`-Skills sind
   installierbar. In Entwicklung = anschaubar + Merkliste, niemals installierbar,
   kein Fake-Bestand, keine Fake-Reviews, keine erfundenen Zahlen.
6. **Monetarisierung vorbereitet, nicht aktiv**: Preis-/Lizenz-Felder existieren im
   Datenmodell ab Sprint 21; Phase 1 ist alles kostenlos (amount 0), Preis-Anzeige
   hinter Feature-Flag (`SHOP_PRICING=on`, Default off). Keine Zahlungsintegration
   in den Sprints 21-25.

---

## 3. Produkt-Modell

### 3.1 Skill als Produkt

Ein Produkt entsteht aus zwei Quellen:

1. **Technische Quelle** (automatisch, Importer): Skill-Ordner unter `AGENTS\` —
   SKILL.md-Frontmatter (`name`, `description`, `trigger`), Datei-Hash des Ordners
   (für Update-Erkennung), Status aus tracking.md.
2. **Kuratierte Quelle** (Hand-gepflegt): `shop/catalog/skills/<name>.json`:

```json
{
  "name": "intent-archaeologie",
  "claim": "Warum existiert dieser Code? Dein Repo erinnert sich.",
  "short": "Rekonstruiert die Absichts-Geschichte einer Datei aus der Git-Historie - mit Commit-Belegen.",
  "long": "<3-6 Saetze, destilliert aus Sprint-File Problem+Nutzen>",
  "terms": { "usecase": ["legacy-verstehen"], "thema": ["git-forensik"], "stichwort": ["blame","historie","warum"], "ziel": ["wissen-sichern"], "branche": ["alle"], "taetigkeit": ["entwickeln","reviewen"], "level": ["alle"], "risiko": ["read-only"] },
  "priceTier": "single",
  "related": ["wissens-testament", "totpfad-bestatter"]
}
```

Fehlt die kuratierte Datei zu einem existierenden Skill-Ordner, bricht der Import
NICHT ab: Produkt erscheint mit Frontmatter-Daten + Flag `uncurated` (Warnung in
der Import-Zusammenfassung). Kuratierte Datei ohne Skill-Ordner → Import-Warnung
"Geisterprodukt", Produkt wird NICHT angelegt.

### 3.2 Bundles

`shop/catalog/bundles/<id>.json`: `id`, `title`, `claim`, `story` (3-5 Sätze:
welches Gesamtproblem löst die Kombination — mehr als die Summe der Teile),
`skills` (Array existierender Skill-Namen), `priceTier`. Start-Bundles (Sprint 21,
Inhalt darf Sonnet feinjustieren, Anzahl ≥ 6):

| Bundle | Skills | Story-Kern |
|---|---|---|
| legacy-rettung | intent-archaeologie, totpfad-bestatter, wissens-testament, konsistenz-enforcer | Altsystem verstehen, entrümpeln, Wissen sichern |
| security-audit | berechtigungs-roentgen, datenspuren-verfolger, konfig-kartograf, ausfall-simulant | Angriffsfläche + Datenflüsse + Resilienz in einem Zug |
| release-guard | api-vertrags-waechter, seiteneffekt-radar, test-luecken-kartograf, doku-drift-detektor | Vor jedem Release: Verträge, Blast-Radius, Lücken, Doku |
| onboarding-kit | onboarding-pfadfinder, vokabular-waechter, doku-drift-detektor | Neue Devs in Tagen statt Wochen produktiv |
| prod-wahrheit | prod-spiegel, ausfall-simulant, zeitbomben-scanner | Was das System WIRKLICH tut - und was als Nächstes knallt |
| qualitaets-fundament | elevate, test-luecken-kartograf, konsistenz-enforcer | Projekt auf Enterprise-Niveau heben und halten |

---

## 4. Taxonomie-System

`shop/catalog/taxonomy.json` — Dimensionen mit Start-Termen (erweiterbar, aber nur
per Datei-Edit + Re-Import; nie ad hoc in der DB):

| Dimension | Start-Terme (Beispiele) |
|---|---|
| usecase | legacy-verstehen, release-absichern, incident-aufklaeren, onboarding, audit-vorbereiten, aufraeumen, neu-starten |
| thema | git-forensik, testing, security, datenschutz, api, konfiguration, doku, resilienz, datenbank, wissens-management |
| stichwort | frei, pro Skill kuratiert (blame, coverage, breaking-change, pii, ...) |
| ziel | risiko-senken, zeit-sparen, wissen-sichern, qualitaet-heben, kosten-senken, compliance |
| branche | alle, e-commerce, fintech, saas, agentur, enterprise-it |
| taetigkeit | entwickeln, reviewen, architektur, devops, qa, product, security |
| level | einsteiger, fortgeschritten, alle |
| risiko | read-only, schreibend-mit-freigabe |

Jeder Skill wird in JEDER Dimension mindestens einmal zugeordnet (Kurations-Pflicht;
`branche: alle` ist zulässig und oft ehrlich). Facetten-Navigation zeigt nur Terme
mit ≥ 1 Produkt.

---

## 5. Datenmodell (SQLite, Schema-Kern)

```sql
skills(id, name UNIQUE, trigger, description, claim, short, long, status,
       risk, price_tier, uncurated, folder_hash, imported_at)
taxonomy_terms(id, dimension, term, UNIQUE(dimension, term))
skill_terms(skill_id, term_id, PRIMARY KEY(skill_id, term_id))
bundles(id, slug UNIQUE, title, claim, story, price_tier)
bundle_skills(bundle_id, skill_id)
prices(id, ref_type CHECK(ref_type IN ('skill','bundle')), ref_id,
       tier, amount_cents DEFAULT 0, currency DEFAULT 'EUR')
install_targets(id, path UNIQUE, label, created_at)
orders(id, target_id, created_at, license TEXT NULL)
order_items(order_id, skill_id, folder_hash_at_install)
watchlist(skill_id, added_at)
-- FTS5:
skills_fts(name, claim, short, long, terms_flat)  -- content-synced beim Import
```

Der Importer ist idempotent (Upsert über `name`/`slug`); orders/watchlist überleben
Re-Imports (skill_id-Referenzen über stabile names auflösen).

---

## 6. API-Contract (REST, JSON, Präfix `/api`)

| Endpoint | Methode | Zweck |
|---|---|---|
| `/api/skills` | GET | Liste; Query: `q` (FTS), `dimension=term` (mehrfach, AND zwischen Dimensionen, OR innerhalb), `status` |
| `/api/skills/:name` | GET | Produkt-Detail inkl. Terme, Bundles-Zugehörigkeit, related, Preis (nur bei Pricing-Flag) |
| `/api/facets` | GET | Dimensionen + Terme + Produkt-Zählung (für aktive Filterlage) |
| `/api/bundles` / `/api/bundles/:slug` | GET | Bundles mit Skills + Status-Aggregat |
| `/api/checkout` | POST | `{ targetPath, items: [names] }` → validiert (Existenz, Guard, nur verfuegbar) → installiert → Order |
| `/api/library` | GET | Bestand je Ziel: installierte Skills, Update-Flag (hash-Vergleich aktuell vs. installiert) |
| `/api/library/reinstall` | POST | Re-Install eines Skills in ein Ziel (explizit) |
| `/api/watchlist` | GET/POST/DELETE | Merkliste |
| `/api/advisor` | POST | Antworten der Berater-Fragen → Empfehlungs-Liste mit Begründungen (Sprint 24) |

Fehler-Konvention: HTTP-Status + `{ error: "<klartext deutsch>" }`. Der Warenkorb
selbst ist clientseitig (localStorage) — der Server kennt nur den Checkout.

---

## 7. UX-Konzept (Seiten & Prinzipien)

Seiten (Vanilla-JS, eine `app.css`, System-Fonts, hell/dunkel via
`prefers-color-scheme`):

1. **Landing** — Hero: "Skill is the hero." + Subline + EIN Suchfeld. Darunter
   kuratierte Regale (horizontal scrollbare Karten-Reihen): "Neu im Regal",
   je 1 Regal pro Top-Usecase, 1 Bundle-Regal. Keine Slider-Automatik, kein Lärm.
2. **Katalog** — Facetten links (Dimensionen einklappbar, Terme mit Zählung),
   Karten rechts (Claim, short, Status-Badge, Risiko-Badge, Trigger als
   Code-Chip). Aktive Filter als entfernbare Chips oben.
3. **Produktseite** — Hero-Zone (Name, Claim, Install-CTA bzw. "bald verfügbar" +
   Merken), dann: Das Problem / Das bekommst du (aus long), Evidenz-Versprechen
   ("Jede Aussage mit Beleg" — der USP aller Skills, BIBEL § 4), Enthalten in
   Bundles, Verwandte Skills, technische Fakten (Trigger, Risiko, Skripte).
4. **Bundle-Seite** — Story zuerst, dann die enthaltenen Skills als Karten,
   Gesamt-Status ("4 von 4 verfügbar" / "2 verfügbar, 2 in Entwicklung"),
   Bundle-CTA installiert die verfügbaren, merkt die restlichen.
5. **Warenkorb/Kasse** — Items, Zielprojekt wählen (Pfad-Eingabe + zuletzt
   verwendete Ziele aus install_targets), Validierungs-Feedback, Erfolgs-Seite
   mit "Was jetzt?" (Trigger-Liste der installierten Skills zum Ausprobieren).
6. **Bibliothek** — pro Ziel: installierte Skills, Version/Hash-Stand,
   Update-Badge, Re-Install.
7. **Berater** — max. 3 Fragen (Was schmerzt gerade? / Wobei? Kontext / Wie viel
   darf der Skill anfassen?), dann Empfehlung: 1-3 Skills oder 1 Bundle, je mit
   Ein-Satz-Begründung. Regelbasiert (Taxonomie-Mapping), kein LLM-Call.

Prinzipien: max. 2 Klicks von Landing zu jedem Produkt; jede Seite funktioniert
ohne JS-Framework; Ladezeit lokal < 100 ms; leere Zustände sind gestaltet
("Noch nichts gemerkt — stöbere im Katalog"); keine Cookies/Accounts.

---

## 8. Sprint- & Test-Protokoll (Ergänzungen)

- BIBEL § 5 (Ablauf), § 7 (DoD), § 8 (Eskalation) gelten unverändert.
- Tests mit eingebautem `node:test` + `node --test` (kein zusätzliches Framework).
- Jeder Sprint endet lauffähig: `npm start` in `shop/` → Shop auf
  `http://127.0.0.1:4711` (Port fix, dokumentiert).
- Smoke je Sprint: `npm run import` fehlerfrei + die im Sprint-File genannten
  API-/UI-Prüfungen. Akzeptanz-Ziel ist der Shop selbst (kein dreamzzz-Bezug);
  End-zu-End-Installationstests gegen ein Wegwerf-Zielprojekt im Scratch-Ordner.
- Frontend-Prüfung: curl-basierte API-Tests + manuelle Browser-Prüfliste im
  Sprint-File (dokumentierte Screenshots optional).

---

## 9. Ausblick Phase 2 (nicht jetzt, bewusst vorgemerkt)

Entscheidung (2026-07-21): Phase 1 bleibt wie sie ist — Vanilla-JS/Express/
better-sqlite3, kein Build-Schritt, kein Frontend-Framework (§ 2.1 gilt
unverändert). Ein Umbau auf **Astro** (https://astro.build/) wurde geprüft
und bewusst zurückgestellt, weil seine Kernvorteile (SEO, Netzwerk-Performance,
Content-Skalierung, Islands für komplexe Interaktivität) erst greifen, wenn
der Shop Phase 1 verlässt: öffentlicher Deploy + echte Zahlungsintegration
(Stripe/PayPal o.ä.) statt „vorbereitet, nicht aktiv" (§ 2.6).

Wenn Phase 2 ansteht (User-Entscheidung, kein Termin): Astro-Frage erneut
aufgreifen, bevor weiter in Vanilla-JS-Eigenbau investiert wird. Zwei Optionen
im Kopf behalten:
- **Nur als Seiten-Compiler**: `astro build` → `dist/`, Express+SQLite-API
  bleibt unangetastet (niedrigstes Risiko, bestehende Tests bleiben gültig).
- **Voller Umbau inkl. SSR/API-Routen**: nur sinnvoll, wenn öffentlicher
  Deploy + echte Zahlungslogik ohnehin einen Architektur-Cut nötig machen.

Zahlungsintegration selbst ist frameworkunabhängig — kein Astro-spezifischer
Vorteil dort, nur bessere DX für die Checkout-UI-Komponenten.
