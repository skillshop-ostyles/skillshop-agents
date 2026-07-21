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

## 7. DoD-Checkliste

- [ ] Test-Suite vollständig (jede Route ±, Guards, Advisor-Vertrag, Fixture-Katalog)
- [ ] Pricing-Flag end-zu-end (off/on getestet, license-Format dokumentiert)
- [ ] shop/README.md vollständig (Setup, Betrieb, Pflege, Troubleshooting)
- [ ] Bench bestanden (Median < 100 ms, Werte protokolliert)
- [ ] Abnahme-Protokoll gegen SHOP-BIBEL § 1-8 in diesem File
- [ ] Rot-Probe der Suite dokumentiert
- [ ] tracking.md aktualisiert, Commit `sprint-25: shop-haertung implementiert`
