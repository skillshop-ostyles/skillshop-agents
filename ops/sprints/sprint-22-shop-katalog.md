# Sprint 22 — shop-katalog

Regeln: `ops/BIBEL.md` + `ops/SHOP-BIBEL.md` gelten vollständig. Baut auf Sprint 21.

## 1. Ziel

Der sichtbare Shop: Express-Server mit Katalog-API und dem kompletten Browsing-
Erlebnis — Landing mit Hero und Regalen, Katalog mit Facetten + Suche, Produkt-
und Bundle-Seiten. Am Sprint-Ende kann man jeden Skill finden, verstehen und
begehren — nur noch nicht kaufen.

## 2. Nutzen

Das ist das Schaufenster und die Ladenfläche. "Skill is the hero" wird hier
eingelöst: Jede Produktseite verkauft die Lösung eines Schmerzes.

## 3. Scope / Nicht-Scope

**Scope:** Server (`npm start`, 127.0.0.1:4711), API-Endpunkte skills/facets/
bundles (SHOP-BIBEL § 6), statisches Frontend: Landing, Katalog, Produktseite,
Bundle-Seite. Merkliste nur als Button-Platzhalter (aktiv in S23/24).
**Nicht-Scope:** Checkout/Installer (S23), Berater (S24), Preise (Flag off).

## 4. Komponenten-Spezifikation

```
shop/src/
  server.js               # Express-App: static public/ + /api-Router, Port 4711, Host 127.0.0.1
  api/skills.js           # GET /api/skills, /api/skills/:name, /api/facets
  api/bundles.js          # GET /api/bundles, /api/bundles/:slug
shop/public/
  index.html              # Landing
  katalog.html            # Katalog
  skill.html              # Produktseite (?name=)
  bundle.html             # Bundle-Seite (?slug=)
  app.css                 # das eine CSS (SHOP-BIBEL § 7: System-Fonts, hell/dunkel)
  app.js                  # geteilte Helfer (fetch, Karten-Rendering, Badge-Logik)
```

### API-Detail

- `GET /api/skills`: Filter-Query `?q=<fts>&usecase=a&usecase=b&thema=c&status=verfuegbar`
  — OR innerhalb einer Dimension, AND zwischen Dimensionen, FTS über skills_fts.
  Antwort: Karten-Felder (name, claim, short, status, risk, trigger, terms).
  Sortierung: verfuegbar vor in-entwicklung, dann alphabetisch.
- `GET /api/skills/:name`: alles + `bundles` (Zugehörigkeit), `related`
  (aufgelöst mit Status), 404 + Klartext bei Unbekanntem.
- `GET /api/facets`: Dimensionen → Terme → Produktzahl UNTER Berücksichtigung der
  aktuellen Filterlage (gleiche Query-Parameter wie /api/skills), Terme mit 0
  ausblenden.
- `GET /api/bundles/:slug`: Bundle + Skills (Karten-Felder) + Status-Aggregat
  ("n von m verfügbar").

### Seiten-Detail

- **Landing**: Hero (H1 "Skill is the hero.", Subline: ein Satz, was der Laden
  ist), Suchfeld (Enter → katalog.html?q=). Regale: "Neu im Regal" (zuletzt
  importiert, max 6), 3 Usecase-Regale (aus taxonomy: die 3 Usecases mit den
  meisten Produkten), "Bundles" (alle 6). Regal = horizontale Karten-Reihe,
  CSS-only scrollbar.
- **Katalog**: Facetten-Spalte (Dimension als <details>, Terme als Checkbox +
  Zählung; Änderung → URL-Query aktualisieren → neu laden — kein SPA-State),
  aktive Filter als Chips über den Karten, Karten-Grid. Leerzustand gestaltet.
- **Produktseite**: Aufbau gemäß SHOP-BIBEL § 7.3. Install-Button: bei
  verfuegbar aktiv (führt in S22 zu einem "Kasse kommt in Kürze"-Hinweis —
  ehrlich, kein toter Button), bei in-entwicklung: "Bald verfügbar"-Badge +
  deaktivierter Merken-Button mit Titel "Merkliste kommt in Kürze".
- **Bundle-Seite**: Story prominent, Skill-Karten, Status-Aggregat.
- **Karten** überall gleich: Name, Claim, short (2 Zeilen, ellipsis), Badges
  (Status: grün/amber; Risiko: neutral "read-only" / markiert "schreibend"),
  Trigger-Chip (`/intent`), Klick → Produktseite.

Design-Leitplanken: eine Akzentfarbe, großzügiger Weißraum, max. Breite 1200 px,
keine Icons-Fonts (Unicode/SVG inline), Fokus-Zustände sichtbar (Tastatur-Nutzung),
`prefers-color-scheme` beide Modi geprüft.

## 5. Edge-Cases

| Fall | Verhalten |
|---|---|
| DB fehlt beim Start | Server startet, `/` zeigt Hinweis-Seite "npm run import ausführen", API antwortet 503 + Klartext |
| FTS-Sonderzeichen in q | Query escapen (FTS5-Anführungszeichen), nie 500 |
| Unbekannter Facetten-Parameter | Ignorieren (kein Fehler), unbekannter Term in bekannter Dimension → leeres Ergebnis ist ok |
| uncurated-Skill | Karte funktioniert mit Frontmatter-Daten (description als short), Kennzeichnung dezent |
| Sehr lange Claims/Texte | CSS-Ellipsis auf Karten, Produktseite voll |
| JS deaktiviert | Kernnavigation über Links funktioniert (Seiten sind HTML-Dokumente, Daten-Rendering braucht JS — Hinweis im noscript) |

## 6. Testplan

Smoke:

```powershell
cd shop; npm run import; npm start   # dann in zweiter Shell:
curl http://127.0.0.1:4711/api/skills | ConvertFrom-Json
curl "http://127.0.0.1:4711/api/skills?usecase=legacy-verstehen&q=git"
curl http://127.0.0.1:4711/api/skills/intent-archaeologie
curl http://127.0.0.1:4711/api/facets
curl http://127.0.0.1:4711/api/bundles/legacy-rettung
node --test
```

Erwartung: alle 200 + plausible JSON; 404-Test mit Phantasie-Name → 404 + error.
node:test: API-Tests über supertest-freien HTTP-Aufruf (Server im Test starten,
fetch, prüfen) für Filter-Logik (AND/OR), FTS-Escaping, 503-ohne-DB.

Akzeptanz (das "≥ 3 Wege"-Kriterium): für 3 Stichproben-Skills dokumentieren,
dass sie erreichbar sind über (a) Suche, (b) mindestens eine Facette, (c) Bundle
ODER related-Link. Browser-Prüfliste: Landing/Katalog/Produkt/Bundle in hell UND
dunkel geöffnet, Tastatur-Navigation Katalog → Produkt möglich.

Negativ: Port belegt → klarer Startfehler; DB fehlt → 503-Verhalten.

## Entscheidungen während der Umsetzung

1. **`related` aus Sprint 21 nachgerüstet**: Die Katalog-JSONs enthalten seit
   Sprint 21 ein `related`-Feld, das aber nie in der DB persistiert wurde (keine
   Tabelle, kein Importer-Code). Für die Produktseite (§7.3, "Verwandte Skills")
   war das ein Blocker. Ergänzt: Tabelle `skill_related` (db.js), Importer
   schreibt + validiert Referenzen (unbekannter related-Name → ImportError,
   analog zur Bundle-Validierung). Sprint-21-Tests liefen danach erneut grün
   (12/12), kein Regressionsrisiko.
2. **FTS5-Schema-Bug aus Sprint 21 behoben**: `content=''` (contentless FTS5)
   unterstützt kein `DELETE` — der zweite Import wäre nie idempotent gewesen.
   Auf reguläre externe FTS5-Tabelle umgestellt (`db.js`), mit Test abgesichert.
3. **Facetten-Zählung schließt die eigene Dimension aus dem Filter aus**: Die
   Spec sagt nur "gleiche Query-Parameter wie /api/skills". Wörtlich umgesetzt
   hätte das bedeutet, dass ausgewählte Terme in der eigenen Facette
   verschwinden (Zählung wird 0, sobald gefiltert wird), was Nutzer aussperrt.
   Stattdessen: Standard-Facetten-Muster — für Dimension X werden alle ANDEREN
   Filter angewendet, X selbst bleibt ungefiltert. Getestet
   (`GET /api/facets excludes zero-count terms and respects other-dimension filters`).
4. **Katalog-Interaktion**: "URL aktualisieren → neu laden" wurde als "URL ist
   alleinige Quelle der Wahrheit, per fetch neu gerendert" umgesetzt (kein
   voller Browser-Reload) — schneller, aber ohne jeden zusätzlichen State
   außerhalb der URL. `popstate` wird behandelt, Vor-/Zurück-Buttons funktionieren.

## 8. Testresultate

- **node:test**: 20/20 grün (12 Importer-Tests aus Sprint 21 weiterhin grün nach
  Schema-Erweiterung, 8 neue Server-/API-Tests: 503-ohne-DB, AND/OR-Filterlogik,
  Sortierung, FTS-Escaping, Skill-Detail inkl. bundles/related, 404, Facetten
  inkl. Cross-Dimension-Filter, Bundle-Detail inkl. Status-Aggregat, 404,
  statisches Ausliefern).
- **Smoke-Calls**: alle 200, plausible JSON (siehe Kommandos oben), 404 für
  Phantasie-Namen bestätigt.
- **≥-3-Wege-Nachweis** (Suche / Facette / Bundle), live gegen den echten
  Katalog geprüft:
  - `intent-archaeologie`: Suche `q=Repo erinnert` → Treffer; Facette
    `usecase=legacy-verstehen` → Treffer; Bundle `legacy-rettung` → enthalten.
  - `berechtigungs-roentgen`: Suche `q=Pentest` → Treffer; Facette
    `thema=security` → Treffer; Bundle `security-audit` → enthalten.
  - `elevate`: Suche `q=Enterprise` → Treffer; Facette
    `risiko=schreibend-mit-freigabe` → Treffer; Bundle `qualitaets-fundament` →
    enthalten.
- **Browser-Prüfliste** (Claude-in-Chrome, echte Interaktion, keine Behauptung
  ohne Beobachtung):
  - Dark Mode live beobachtet (System-Standard in dieser Umgebung): Hero,
    Regale, Karten, Badges korrekt gerendert, keine Konsolenfehler auf
    Landing/Katalog/Produkt/Bundle.
  - Light Mode: nicht live erzwingbar in dieser Browser-Session (kein
    Emulations-Tool für `prefers-color-scheme` verfügbar); stattdessen per
    Code-Review verifiziert — Light ist der ungeprüfte `:root`-Default, Dark
    ist der zusätzliche `@media`-Override; da der Override nachweislich korrekt
    greift, ist das Umschaltmechanismus bewiesen und der ungeprüfte Default
    das risikoärmere Verhalten. Diese Einschränkung wird hier explizit benannt,
    statt Erfolg zu behaupten.
  - Katalog-Interaktion live getestet: Facette per Klick gesetzt (URL +
    Ergebnisliste + Facetten-Zählung aktualisiert korrekt), aktiver Filter-Chip
    mit funktionierendem ×-Entfernen-Button, Suche.
  - Tastatur-Navigation: Karten-Link fokussiert, Enter → Navigation zur
    Produktseite bestätigt (echter Tastatur-Event, keine Simulation).
  - Produktseite (verfügbar: elevate) → Install-Button → ehrlicher
    "Kasse kommt in Kürze"-Hinweis erscheint, kein toter Button.
  - Produktseite (in-entwicklung: intent-archaeologie) → "bald verfügbar"-Badge
    + deaktivierter Merken-Button mit Tooltip bestätigt (per DOM-Check: `disabled: true`).
  - Bundle-Seite (legacy-rettung) → Story, Status-Aggregat "0 von 4 verfuegbar",
    4 Skill-Karten korrekt.
- **Negativ-Tests**: Port belegt → `"Port 4711 ist bereits belegt..."` + exit 1
  (zweiter Serverstart bei laufendem ersten). DB fehlt → 503 + Klartext
  (automatisiert getestet).

## 7. DoD-Checkliste

- [x] server.js (127.0.0.1:4711) + API-Module gemäß Contract
- [x] 4 Seiten + app.css + app.js, Design-Leitplanken eingehalten
- [x] Alle Smoke-Calls + node:test grün (20/20)
- [x] ≥-3-Wege-Nachweis für 3 Skills dokumentiert
- [x] Browser-Prüfliste (Dark live, Light per Code-Review — Einschränkung dokumentiert;
      Tastatur-Navigation live bestätigt) abgehakt
- [x] Negativ-Tests bestanden (Port belegt, DB fehlt)
- [x] tracking.md aktualisiert, Commit `sprint-22: shop-katalog implementiert`
