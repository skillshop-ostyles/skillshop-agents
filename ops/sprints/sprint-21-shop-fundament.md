# Sprint 21 — shop-fundament

Regeln: `ops/BIBEL.md` + `ops/SHOP-BIBEL.md` gelten vollständig.

## 1. Ziel

Das Fundament des Skill-Shops: Node-Projekt unter `shop/`, SQLite-Schema, der
Importer (Dateien → DB) und der vollständige kuratierte Katalog (22 Skill-JSONs,
Taxonomie, 6 Bundles). Am Sprint-Ende existiert noch keine UI, aber eine korrekte,
idempotent reproduzierbare Produktdatenbank.

## 2. Nutzen

Alles Spätere (Katalog, Checkout, Berater) ist nur Projektion dieser Datenbasis.
Ein sauberes Fundament heißt: jede weitere Schicht bleibt dünn.

## 3. Scope / Nicht-Scope

**Scope:** `shop/`-Projektgerüst, Schema + Migration, Importer inkl. FTS5,
Katalog-Kuration aller 22 Skills, taxonomy.json, 6 Bundle-JSONs, .gitignore.
**Nicht-Scope:** Kein HTTP-Server (Sprint 22), kein Installer (Sprint 23), keine
Preise sichtbar (Flag bleibt off; prices-Tabelle wird aber befüllt mit amount 0).

## 4. Komponenten-Spezifikation

Struktur:

```
shop/
  package.json            # name skill-shop, scripts: import, start (Platzhalter bis S22), test
  .gitignore              # node_modules/, data/*.db
  src/
    db.js                 # Verbindung + Schema-Erstellung (CREATE TABLE IF NOT EXISTS, SHOP-BIBEL § 5)
    importer.js           # Import-Logik (unten)
  bin/
    import.js             # CLI-Einstieg: node bin/import.js [--root <AGENTS-Pfad>]
  catalog/
    taxonomy.json         # Dimensionen + Start-Terme (SHOP-BIBEL § 4)
    skills/<name>.json    # 22 kuratierte Produkt-Dateien (SHOP-BIBEL § 3.1)
    bundles/<id>.json     # 6 Bundles (SHOP-BIBEL § 3.2)
  data/                   # DB-Ablage (gitignored), .gitkeep
  test/
    importer.test.js
```

### Importer (`npm run import`)

Ablauf:

1. Skill-Ordner scannen (AGENTS-Wurzel, Default `..` relativ zu shop/, per
   `--root` übersteuerbar): jeder Ordner mit `SKILL.md` = Skill. Frontmatter
   parsen (name, description, trigger — einfacher YAML-Zeilen-Parser reicht,
   keine YAML-Lib). Ordner-Hash: SHA-256 über sortierte (Pfad, Inhalt)-Paare
   aller Dateien des Skill-Ordners.
2. Status aus `ops/tracking.md` lesen: Tabellenzeilen parsen; Skill-Name →
   Status (`fertig` → `verfuegbar`, sonst `in-entwicklung`). Skills ohne
   tracking-Eintrag (elevate, project-init) → `verfuegbar` (sie existieren
   implementiert).
3. Kuratierte JSONs mergen (SHOP-BIBEL § 3.1 inkl. uncurated-/Geisterprodukt-Regeln).
4. Taxonomie upserten; skill_terms aus den terms-Blöcken; Validierung:
   unbekannte Dimension/Term → Import-Fehler mit Klartext (Kurations-Tippfehler
   sollen knallen, nicht durchrutschen). Kurations-Pflicht prüfen: kuratierter
   Skill ohne Zuordnung in einer Dimension → Warnung.
5. Bundles upserten; Bundle-Referenz auf unbekannten Skill → Import-Fehler.
6. prices befüllen (je Skill/Bundle ein Eintrag, tier aus JSON, amount 0).
7. FTS5-Tabelle neu aufbauen. orders/watchlist unangetastet lassen.
8. Zusammenfassung ausgeben: Anzahl Skills (verfuegbar/in-entwicklung/uncurated),
   Terme je Dimension, Bundles, Warnungen.

### Katalog-Kuration (Fleißarbeit dieses Sprints, Qualität zählt)

Für ALLE 22 Skills eine `catalog/skills/<name>.json` verfassen. Quelle: die
Problem/Nutzen-Abschnitte der Sprint-Files 01-20 bzw. SKILL.md von elevate/
project-init. Claim = ein Satz, der den Schmerz trifft (kein Feature-Satz).
`related` kuratieren (2-4 sinnvolle Nachbarn). Terme in allen 8 Dimensionen.

## 5. Edge-Cases

| Fall | Verhalten |
|---|---|
| Skill-Ordner ohne Frontmatter-name | Import-Fehler mit Dateipfad (kaputte SKILL.md soll auffallen) |
| tracking.md-Format ändert sich | Parser tolerant (Spalten über Header finden); bei Parse-Versagen: alle als in-entwicklung + Warnung |
| Doppelter Skill-Name | Import-Fehler |
| Re-Import nach Skill-Umbenennung | Alter Eintrag bleibt verwaist → Importer meldet Waisen (in DB, nicht auf Platte) und entfernt sie, orders bleiben über name-Historie unauflösbar → Order-Zeile behalten, Skill-Referenz auf NULL + Warnung |
| shop/ selbst, ops/, .git | Vom Ordner-Scan ausschließen |
| Leere catalog/skills | Import läuft, alles uncurated (Warnung) — kein Abbruch |

## 6. Testplan

Smoke:

```powershell
cd shop; npm install; npm run import
node --test
```

Erwartung: Import exit 0; Zusammenfassung zeigt 22 Skills (2 verfuegbar, 20
in-entwicklung), 0 uncurated, 6 Bundles, 0 Warnungen. Tests decken ab:
Frontmatter-Parser, tracking-Parser, Idempotenz (2× Import → identische Zählungen,
keine Duplikate), Geisterprodukt-Fehler, unbekannter-Term-Fehler,
Bundle-mit-Phantom-Skill-Fehler (Fixtures unter `test/fixture/`).

Akzeptanz: `sqlite3`-freie Verifikation über ein kleines `bin/stats.js`
(liest DB, druckt Kennzahlen) — Zahlen stimmen mit Katalog überein; zweiter
Import verändert nichts (Hash-Vergleich der Kennzahlen-Ausgabe).

Negativ: `npm run import -- --root C:\gibt\es\nicht` → exit != 0, Klartext-Fehler.

## 7. DoD-Checkliste

- [ ] shop/-Gerüst inkl. .gitignore (node_modules, data/*.db) — package-lock.json wird committet
- [ ] Schema vollständig (SHOP-BIBEL § 5) inkl. FTS5
- [ ] Importer mit allen 8 Schritten + Fehler-/Warnregeln
- [ ] 22 kuratierte Skill-JSONs (Claim-Qualität: kein Feature-Satz), taxonomy.json, 6 Bundles
- [ ] Alle Tests grün (node --test), Idempotenz bewiesen
- [ ] Negativ-Test bestanden
- [ ] bin/stats.js liefert korrekte Kennzahlen
- [ ] tracking.md aktualisiert, Commit `sprint-21: shop-fundament implementiert`
