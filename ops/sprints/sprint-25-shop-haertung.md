# Sprint 25 — shop-haertung

Regeln: `ops/BIBEL.md` + `ops/SHOP-BIBEL.md` gelten vollständig. Abschluss-Sprint
des Shops: Härtung, Monetarisierungs-Vorbereitung, Doku, Gesamtabnahme.

## 1. Ziel

Aus dem funktionierenden Shop ein belastbares Produkt machen: vollständige
Test-Suite, aktivierbare (aber inaktive) Preis-Schicht, Betriebs-Dokumentation
und eine dokumentierte Gesamtabnahme gegen die SHOP-BIBEL.

## 2. Nutzen

Der Unterschied zwischen "läuft bei mir" und "kann man jemandem geben". Und: die
Monetarisierungs-Tür ist eingebaut und geprüft, bevor sie je gebraucht wird —
nachrüsten wäre zehnmal teurer.

## 3. Scope / Nicht-Scope

**Scope:** Test-Suite-Vervollständigung (Importer, alle APIs, Installer-Guard,
Advisor — Ziel: jeder Endpoint mindestens ein Positiv- + ein Negativ-Test),
Pricing-Feature-Flag end-zu-end, license-Feld nutzbar, shop/README.md,
Performance-Nachweis, Gesamtabnahme-Protokoll.
**Nicht-Scope:** Keine echte Zahlungsintegration (kein Stripe etc.). Keine neuen
Features. Kein Refactoring ohne Test-Rückendeckung (Karpathy: chirurgisch).

## 4. Komponenten-Spezifikation

### Test-Suite (node:test, `npm test` läuft ALLES)

- Struktur: `test/importer.test.js`, `test/api-skills.test.js`,
  `test/api-checkout.test.js`, `test/installer.test.js`, `test/advisor.test.js`,
  `test/pricing.test.js`. Gemeinsame Helfer (`test/helpers.js`): Test-DB in
  Temp-Verzeichnis, Server auf Zufallsport starten/stoppen, Fixture-Katalog
  (Mini-Variante mit 3 Skills, 1 Bundle — Tests hängen NICHT am echten Katalog,
  sonst bricht jede Kurations-Änderung die Suite).
- Lücken aus S21-24 schließen; Ziel-Metrik: jede API-Route ≥ 1 Positiv- und
  ≥ 1 Negativ-Test; installer.js-Guards vollständig; Advisor-Vertragstabelle
  läuft gegen Fixture-Regeln.

### Pricing-Feature-Flag (`SHOP_PRICING=on`)

- Flag off (Default): keine Preis-UI, API liefert keine price-Felder.
- Flag on: API liefert `price: { amountCents, currency, tier }` je Skill/Bundle;
  Karten + Produkt-/Bundle-Seiten zeigen Preis (bei amount 0: "kostenlos");
  Kasse zeigt Summe; Checkout schreibt `orders.license` = generierte
  Lizenz-Pseudo-ID (`LIC-<datum>-<zufall>` — Platzhalter-Format, dokumentiert).
- Tests: beide Flag-Zustände (API-Felder da/nicht da, Kasse rechnet Summe,
  license geschrieben/NULL).

### Betriebs-Doku (`shop/README.md`)

Setup (Node-Version, npm install, import, start), Betrieb (Port, Flag,
DB-Reset = data löschen + import), Architektur-Überblick (1 Diagramm-Absatz:
Dateien → Importer → SQLite → API → statisches Frontend; Verweis auf
SHOP-BIBEL für alles Weitere), Katalog-Pflege (neuen Skill kuratieren in 4
Schritten), Troubleshooting (503, Port belegt, Guard-Fehler).

### Performance-Nachweis

`/api/skills` (voller Katalog) und `/api/facets` je 20 Aufrufe messen
(einfaches Mess-Skript `bin/bench.js`), Median < 100 ms lokal. Bei Verfehlung:
Ursache finden (fehlender Index?) und beheben — Kriterium ist hart.

### Gesamtabnahme

Checkliste gegen SHOP-BIBEL § 1-8 durchgehen (jede Regel: erfüllt/Beleg), als
Abschnitt `## Abnahme-Protokoll` in DIESEM Sprint-File dokumentieren. Insbesondere:
localhost-Bindung nachgewiesen (netstat), keine externen Requests (Netzwerk-Tab/
Code-Durchsicht: kein fetch auf Nicht-localhost, keine CDN-Links im HTML),
Ehrlichkeits-Prinzip (kein installierbarer in-entwicklung-Skill — Test vorhanden).

## 5. Edge-Cases

| Fall | Verhalten |
|---|---|
| Tests parallel: DB-/Port-Kollisionen | Temp-DB + Zufallsport je Testdatei (helpers), keine geteilten Zustände |
| Flag zur Laufzeit geändert | Nicht unterstützt — Flag wird beim Start gelesen, README sagt: Neustart nötig |
| Bench auf langsamer Maschine | Median zählt, Ausreißer dokumentieren; bei systematischer Verfehlung optimieren, nicht das Kriterium weichspülen |
| Echter Katalog ändert sich später | Suite bleibt grün (Fixture-Katalog) — genau dafür |

## 6. Testplan

```powershell
cd shop
npm test                                  # komplette Suite, alle grün
$env:SHOP_PRICING='on'; npm start         # Flag-Sichtprüfung im Browser, danach Flag zurück
node bin/bench.js                         # Median < 100 ms
```

Akzeptanz: `npm test` grün (Anzahl Tests im Protokoll festhalten); Flag-Zustände
im Browser verifiziert (Screenshots optional); Bench-Werte im Abnahme-Protokoll;
Gesamtabnahme-Checkliste vollständig mit Belegen.

Negativ: gezielt einen Guard-Test temporär invertieren → Suite MUSS rot werden
(Probe, dass die Tests wirklich prüfen; danach zurück) — im Protokoll vermerken.

## Entscheidungen während der Umsetzung

1. **Datei-Umbenennungen**: `server.test.js` → `test/api-skills.test.js`,
   `checkout.test.js` → `test/api-checkout.test.js` (Inhalt weitgehend
   übernommen, auf `test/helpers.js` umgestellt). `importer.test.js` und
   `installer.test.js` behalten ihren Namen (entsprachen bereits der
   Sprint-Vorgabe). `test/pricing.test.js` neu.
2. **`test/helpers.js`**: `tmpDbPath`, `tmpDir`, `withServer`, `withImportedDb`,
   `postJson` — extrahiert aus den vier bestehenden Testdateien, die zuvor
   identischen Boilerplate-Code dupliziert hatten. Reine Dekomposition, keine
   Verhaltensänderung (alle vorher grünen Tests blieben grün).
3. **`advisor.test.js` komplett entkoppelt vom echten Katalog**: Die
   Sprint-24-Version testete den Berater gegen `shop/catalog` (echte
   Skill-Namen wie `intent-archaeologie`), was genau das Risiko ist, vor dem
   dieser Sprint warnt ("Tests hängen NICHT am echten Katalog"). Neue,
   dedizierte Fixture `test/fixture/advisor/` (3 Skills mit bewusst
   unterschiedlichen Termen, 1 Bundle) statt Wiederverwendung/Erweiterung der
   bestehenden `test/fixture/catalog`-Fixture — letztere wird von 4 anderen
   Testdateien mit spezifischen Erwartungen genutzt; eine eigene, kleine
   Fixture hat null Blast-Radius auf die bereits grünen Tests. Beim Schreiben
   dieser Fixture-Tests fiel ein echter Fehler in meiner eigenen ersten
   Testerwartung auf (siehe Testresultate) — die Entkopplung hat sich also
   sofort ausgezahlt.
4. **Lücken-Schließung nach Marke "jede Route ≥ 1 Positiv + 1 Negativ"**: neu
   hinzugekommen: `GET /api/bundles` (Liste) hatte bisher GAR keinen Test;
   `GET /api/facets` 503-Fall; `POST /api/checkout` fehlende
   targetPath/items/unbekannter-Skill-Fälle; `POST /api/library/reinstall`
   unbekannter Skill + Ziel-nicht-in-Bibliothek; `DELETE /api/watchlist/:name`
   für unbekannten Skill; `GET /api/advisor/rules`. Bewusst NICHT jede Route
   zusätzlich einzeln auf den 503-ohne-DB-Fall getestet (identischer
   Guard-Code in jedem Router, einmal an /api/skills UND jetzt zusätzlich an
   /api/bundles und /api/facets bewiesen reicht als Beleg für den Mechanismus –
   404/400-Fälle sind pro Route dagegen echte, unterschiedliche
   Geschäftslogik und wurden überall abgedeckt).
5. **Pricing-Architektur**: `src/pricing.js` (`getPrice`, `generateLicense`) als
   kleines gemeinsames Modul; `skillToJson`/`bundleRow` nehmen jetzt optional
   `{ db, pricingEnabled }` entgegen und hängen `price` nur an, wenn das Flag
   aktiv ist — Antwortform ändert sich also nicht additiv (kein `price: null`
   im Aus-Zustand, das Feld fehlt komplett, wie spezifiziert). `orders.license`
   wird pro Order einmal generiert (unabhängig vom Erfolg einzelner Items),
   wenn das Flag aktiv ist.
6. **Rot-Probe korrigiert während der Durchführung**: Der erste Versuch
   deaktivierte den echten `~/.claude`-Schutz in `src/installer.js` und wurde
   vom Auto-Mode-Classifier zu Recht blockiert (Sicherheits-Guard + Testlauf
   gleichzeitig). Zweiter, korrekter Versuch gemäß Wortlaut des Testplans
   ("einen Guard-**Test**... invertieren"): die TEST-Assertion in
   `assertAllowedTarget rejects ~/.claude itself` auf `assert.doesNotThrow`
   gestellt, volle Suite gelaufen → 1 Test rot (mit dem echten SCHUTZ-Fehler
   als Beweis in der Fehlermeldung), danach zurückgesetzt. Der echte Guard
   wurde zu keinem Zeitpunkt in einem lauffähigen Zustand verändert.
7. **`importer.test.js`/`installer.test.js` nicht auf helpers.js umgestellt**:
   beide waren bereits eigenständig funktionsfähig und grün; ein Umbau nur für
   Konsistenz hätte Risiko ohne Nutzen bedeutet (Karpathy: chirurgisch, kein
   Refactoring ohne Rückendeckung/Grund).

## 8. Testresultate

- **`npm test`**: 68/68 grün (12 importer, 11 api-skills, 17 api-checkout,
  12 installer, 10 advisor, 5 pricing + 1 generateLicense-Unit-Test).
- **Rot-Probe**: dokumentiert unter Entscheidung 6 — Suite ging exakt bei der
  invertierten Assertion rot, sonst nirgends; nach Rückbau wieder 68/68 grün.
- **Pricing-Flag**: automatisiert (5 Tests: Feld fehlt/vorhanden auf allen 4
  Lese-Endpunkten, license null vs. `LIC-...`) UND live im Browser geprüft:
  `SHOP_PRICING=on` → Katalogkarten, Produktseite, Bundle-Seite und
  Warenkorb-Summe zeigen "kostenlos"; ohne Flag → `price` fehlt im
  API-Response (per curl bestätigt), keine Preis-UI sichtbar. Keine
  Konsolenfehler in beiden Zuständen.
- **Performance-Nachweis** (`node bin/bench.js`, 20 Läufe je Route, gegen den
  echten importierten Katalog): `/api/skills` Median 5.27 ms (min 3.52 ms,
  max 82.26 ms Ausreißer beim ersten Request/JIT-Warmup) — `/api/facets`
  Median 4.52 ms (min 2.75 ms, max 7.27 ms). Beide weit unter der 100-ms-Schwelle.
- **localhost-Bindung**: `Get-NetTCPConnection -LocalPort 4711` zeigt
  `LocalAddress 127.0.0.1`, kein `0.0.0.0`.
- **Keine externen Requests**: `grep -rE "https?://"` über `shop/public/`
  findet keine Treffer (kein CDN, kein externer Link); einziger dynamischer
  `fetch(url)`-Aufruf in `app.js` ist der generische `fetchJson`-Helfer, dessen
  einzige Aufrufer überall relative `/api/...`-Pfade übergeben.
- **Dependencies**: `package.json` enthält ausschließlich `express` und
  `better-sqlite3` — keine Telemetrie-/Analytics-Pakete.
- **Ehrlichkeits-Prinzip**: `POST /api/checkout rejects an in-entwicklung
  skill server-side, writes nothing` (api-checkout.test.js) beweist, dass kein
  in-entwicklung-Skill installierbar ist, unabhängig von der UI.

## Abnahme-Protokoll (gegen SHOP-BIBEL § 1-8)

| § | Regel | Status | Beleg |
|---|---|---|---|
| 1 | Vision/Positionierung, deutsche UI, Kauf-Metapher | ✅ erfüllt | Alle 8 Seiten (Landing…Berater) auf Deutsch, Regal/Warenkorb/Kasse/Bibliothek durchgehend verwendet (Sprint 22-24) |
| 2.1 | Dependency-Inseln, keine Frontend-Frameworks | ✅ erfüllt | `package.json` nur express+better-sqlite3; `public/` ist reines HTML/CSS/Vanilla-JS, kein Build-Schritt |
| 2.2 | DB abgeleitet, gitignored | ✅ erfüllt | `shop/.gitignore` deckt `data/*.db(-wal/-shm)`, `node_modules/`; `npm run import` idempotent (Sprint-21-Test) |
| 2.3 | Installer-Schutzregel | ✅ erfüllt | `assertAllowedTarget` + 12 Installer-Tests + Rot-Probe (oben) |
| 2.4 | Localhost-only, keine Telemetrie/CDN | ✅ erfüllt | Siehe Testresultate oben (netstat + grep) |
| 2.5 | Ehrlichkeits-Prinzip | ✅ erfüllt | Server-seitige Statusprüfung in Checkout, dediziert getestet |
| 2.6 | Monetarisierung vorbereitet, nicht aktiv | ✅ erfüllt | Preis-Schema seit Sprint 21, Flag `SHOP_PRICING` Default off, keine Zahlungsintegration |
| 3 | Produkt-/Bundle-Modell | ✅ erfüllt | 22 Skills + 6 Bundles kuratiert (Sprint 21), `related`/Bundle-Zugehörigkeit auf Produktseite (Sprint 22) |
| 4 | Taxonomie, Kurations-Pflicht | ✅ erfüllt | 8 Dimensionen, Kurations-Lücken-Warnung im Importer |
| 5 | Datenmodell | ✅ erfüllt | Schema entspricht `db.js` 1:1 (inkl. `order_items.bundle_id`, seit Sprint 21 ungenutzt vorbereitet) |
| 6 | API-Contract | ✅ erfüllt | Alle 9 Endpunkt-Gruppen implementiert + getestet (skills, facets, bundles, checkout, library, reinstall, watchlist, advisor, advisor/rules) |
| 7 | UX-Konzept, < 100 ms, max. 2 Klicks | ✅ erfüllt | Alle 7 Seiten vorhanden; Bench bestanden; Landing→Regal-Karte→Produkt = 1 Klick, Landing→Katalog→Produkt = 2 Klicks |
| 8 | Sprint-/Testprotokoll | ✅ erfüllt | node:test durchgehend, `npm start` liefert festen Port, dieses Protokoll selbst ist der Beleg |

**Ergebnis: Gesamtabnahme bestanden, keine offenen Abweichungen.**

## 7. DoD-Checkliste

- [x] Test-Suite vollständig (jede Route ±, Guards, Advisor-Vertrag, Fixture-Katalog)
- [x] Pricing-Flag end-zu-end (off/on getestet, license-Format dokumentiert:
      `LIC-<YYYYMMDD>-<6-hex>`)
- [x] shop/README.md vollständig (Setup, Betrieb, Pflege, Troubleshooting)
- [x] Bench bestanden (Median < 100 ms, Werte protokolliert: 5.27 ms / 4.52 ms)
- [x] Abnahme-Protokoll gegen SHOP-BIBEL § 1-8 in diesem File
- [x] Rot-Probe der Suite dokumentiert
- [x] tracking.md aktualisiert, Commit `sprint-25: shop-haertung implementiert`
