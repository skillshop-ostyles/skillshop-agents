# Skill-Shop

Marktplatz und Fachgeschäft für die Claude-Code-Skills aus dem AGENTS-Repo.
Vollständiges Konzept: `../ops/SHOP-BIBEL.md`. Sprint-Historie: `../ops/sprints/sprint-2*.md`.

## Setup

Voraussetzung: Node.js (getestet mit v24). Kein globaler Install nötig.

```powershell
cd shop
npm install
npm run import   # baut data/shop.db aus den Skill-Ordnern + catalog/
npm start        # Shop laeuft auf http://127.0.0.1:4711
```

## Betrieb

- **Port**: fest `4711`, Host `127.0.0.1` (nie extern erreichbar).
- **Pricing-Feature-Flag**: `SHOP_PRICING=on npm start` aktiviert die Preis-Anzeige
  (Phase 1: alles `kostenlos`, `orders.license` bekommt eine Platzhalter-ID
  `LIC-<datum>-<hex>`). Das Flag wird nur beim Start gelesen — Änderungen brauchen
  einen Neustart des Servers.
- **DB-Reset**: `data/shop.db` (+ `-wal`/`-shm`) löschen, dann `npm run import`
  neu ausführen. Die DB ist vollständig abgeleitet — nichts geht dauerhaft
  verloren außer Bewegungsdaten (Orders/Watchlist), die per Definition lokale
  Test-/Nutzungsdaten sind.
- **Tests**: `npm test` (node:test, kein Zusatz-Framework). Läuft komplett gegen
  Test-Fixtures unter `test/fixture/` — nicht gegen den echten Katalog, damit eine
  Kurations-Änderung an einem Skill niemals die Test-Suite bricht.

## Architektur (Kurzüberblick)

```
Skill-Ordner (../<skill>/SKILL.md)  ─┐
catalog/*.json (Kuration)           ─┼─► npm run import ─► data/shop.db (SQLite + FTS5)
ops/tracking.md (Status)            ─┘                           │
                                                                   ▼
                                                        src/server.js (Express)
                                                        src/api/*.js (Routen)
                                                                   │
                                                                   ▼
                                                        public/*.html (Vanilla JS/CSS)
```

Die Datei-Ebene (Skill-Ordner, `catalog/`, `ops/tracking.md`) ist die einzige
Quelle der Wahrheit. Die DB ist eine reine Projektion davon (`npm run import`
ist idempotent). Details zu Datenmodell, API-Contract und UX-Konzept: siehe
`../ops/SHOP-BIBEL.md`.

## Katalog-Pflege: einen Skill kuratieren

1. Skill-Ordner unter `AGENTS\<skill-name>\` mit `SKILL.md` (Frontmatter:
   `name`, `description`, `trigger`) muss existieren — oder, falls der Skill nur
   geplant ist, eine Zeile in `../ops/tracking.md`.
2. `catalog/skills/<skill-name>.json` anlegen: `name`, `claim`, `short`, `long`,
   `terms` (alle 8 Dimensionen, siehe `catalog/taxonomy.json` für gültige Terme),
   `priceTier`, `related`. Existiert noch kein Ordner, zusätzlich `trigger` +
   `description` direkt in der JSON angeben.
3. Optional: Skill in ein Bundle aufnehmen (`catalog/bundles/<bundle>.json`,
   Feld `skills`) oder `related` auf andere Skills setzen.
4. `npm run import` ausführen — Warnungen (Kurations-Lücken, unkuratiert)
   und Fehler (unbekannter Term, Geisterprodukt) erscheinen in der Konsole.

## Troubleshooting

| Symptom | Ursache | Lösung |
|---|---|---|
| API antwortet 503 "Datenbank fehlt" | `data/shop.db` existiert nicht | `npm run import` ausführen |
| `Port 4711 ist bereits belegt` | Ein anderer Shop-Prozess läuft schon | Den anderen Prozess beenden oder warten |
| Checkout: `SCHUTZ: Zielverzeichnis liegt unter ...` | Zielpfad ist `~/.claude` oder das AGENTS-Repo selbst | Anderes Zielverzeichnis wählen — das ist Absicht, keine Fehlkonfiguration |
| `npm run import` bricht mit "unbekannter Term" ab | Tippfehler in einer `catalog/*.json`-Datei | Term gegen `catalog/taxonomy.json` prüfen |
| `npm run import` meldet "Geisterprodukt" | Katalog-Datei ohne Ordner UND ohne tracking.md-Zeile | Datei löschen oder `ops/tracking.md`-Zeile ergänzen |

## Grenzen (Phase 1, bewusst)

- Keine echte Zahlungsintegration — das Pricing-Flag ist vorbereitet, nicht live.
- Keine Deinstallation über den Shop — nur additive Installation, siehe
  Hinweistext in der Bibliothek-Seite.
- Kein Berater-LLM-Call — die Empfehlungslogik ist regelbasiert und deterministisch
  (`catalog/advisor-rules.json` + `src/advisor.js`).
