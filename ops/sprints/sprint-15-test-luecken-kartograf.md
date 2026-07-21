# Sprint 15 — test-luecken-kartograf (/testgap)

Regeln: `ops/BIBEL.md` gilt vollständig. Wiederverwendung: Export-Inventar-Muster
aus Sprint 05 (`reachability.ps1`) darf kopiert/angepasst werden.

## 1. Problem

Coverage misst Zeilen, nicht Verhalten. Eine Funktion kann 100 % Zeilen-Coverage
haben und trotzdem ungetestet sein für genau die Fälle, die in Prod wehtun: Leerlisten,
Grenzwerte, Fehlerpfade, Nebenläufigkeit. Die Frage "welches VERHALTEN ist ungetestet?"
erfordert, Code fachlich zu verstehen UND vorhandene Tests semantisch zuzuordnen —
für Menschen bei realer Systemgröße nicht leistbar, für ein LLM systematisch machbar.

## 2. Nutzen

Vorher: Test-Priorisierung nach Bauchgefühl oder Coverage-Prozent-Kosmetik. Nachher:
Verhaltens-Lückenkarte pro öffentlicher Funktion/Route: was ist getestet (mit
Test-Verweis), was nicht (mit Risiko-Einstufung und vorgeschlagenen Testfall-Namen).
Profiteure: QA, Reviewer ("fehlt hier ein Test?"), Refactoring-Vorbereitung.

## 3. Scope / Nicht-Scope

**Scope:** Öffentliche Code-Oberfläche (Exporte, Routen) + vorhandene Tests
(Unit/Integration, erkennbare Frameworks: vitest/jest/mocha, pytest, xunit/nunit,
go test). Semantisches Mapping Verhalten ↔ Test, Lücken-Report mit
Testfall-Vorschlägen (nur Namen + Kurzbeschreibung, KEIN Test-Code ins Zielprojekt).
**Nicht-Scope:** Keine Coverage-Messung (kein Instrumentieren, kein Test-Lauf —
statisch). Kein Generieren/Einchecken von Tests im Zielprojekt (Vorschläge im
Report; Umsetzung ist Folgeauftrag). E2E-/UI-Tests nur inventarisieren, nicht mappen.

## 4. Skill-Spezifikation

Ordner: `test-luecken-kartograf/`

Frontmatter:

```yaml
---
name: test-luecken-kartograf
description: "Semantic test gap mapper: inventories the public code surface (exports, routes) and all existing tests, then has the LLM map which BEHAVIORS of each public symbol are covered by which test and which are not - reporting untested behaviors (edge cases, error paths, boundaries) ranked by risk, with proposed test case names. Static, never runs tests. Read-only. Trigger: /testgap"
trigger: /testgap
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir` + optional Fokus (Modul/Verzeichnis — bei großen Projekten
   dringend empfohlen, sonst Vorschlag machen: das größte Nicht-Test-Verzeichnis).
   Bestätigen.
3. `scripts/surface-inventory.ps1` und `scripts/test-inventory.ps1` ausführen.
4. LLM-Analyse gemäß § 6 (liest die relevanten Quell- und Testdateien vollständig).
5. Report `testgap-report.md` ins Arbeitsverzeichnis; Kurzfassung: riskanteste
   Lücken zuerst.

Usage:

```
/testgap                     # interaktiv
/testgap <dir>               # ganzes Projekt (bei Größe: Fokus empfohlen)
/testgap <dir> <fokus-pfad>  # nur Teilbereich
/testgap --help
```

## 5. Collector-Skripte

### scripts/surface-inventory.ps1

Parameter: `-ProjectDir` (Pflicht), `-Focus` (optional, Unterpfad),
`-Extensions`/`-Exclude` (Defaults wie Sprint 03; Testdateien hier AUSSCHLIESSEN:
`*.test.*`, `*.spec.*`, `test_*`, `*_test.*`, `tests/`).

Read-only. Export-Inventar wie Sprint 05 (öffentliche Symbole per Muster-Familie)
PLUS Routen (Muster aus Sprint 09). Pro Symbol zusätzlich Größen-Signale:
Zeilenumfang des zugehörigen Blocks (grob: bis zur nächsten Deklaration gleicher
Ebene), Anzahl Verzweigungs-Schlüsselwörter im Block (`if|else|switch|case|catch|
for|while|\?` — Komplexitäts-Proxy).

JSON-Schema (Beispiel):

```json
{
  "symbols": [
    { "file": "src/billing/invoice.ts", "line": 24, "symbol": "calculateTotal", "kind": "function", "blockLines": 48, "branchCount": 9 }
  ],
  "routes": [ { "file": "src/api/orders.ts", "line": 12, "method": "POST", "path": "/orders" } ],
  "scannedFiles": 120
}
```

### scripts/test-inventory.ps1

Parameter: `-ProjectDir` (Pflicht), `-Exclude` (Default wie Sprint 03).

Read-only. Findet Testdateien (Muster oben) und extrahiert die Test-Struktur:
`describe|context|suite`-Blöcke und `it|test|def test_|func Test|[Fact]|[Theory]`-
Fälle — je mit Datei:Zeile und dem Namens-String. Zusätzlich: importierte/
referenzierte Produktions-Symbole pro Testdatei (Import-Zeilen + Wortgrenzen-Grep
der Surface-Symbole falls als `-Symbols`-Parameter übergeben; sonst nur Imports).

JSON-Schema (Beispiel):

```json
{
  "testFiles": [
    { "file": "tests/invoice.test.ts", "framework": "vitest",
      "cases": [ { "line": 10, "name": "calculates total with tax", "suite": "invoice" } ],
      "imports": ["src/billing/invoice.ts"] }
  ],
  "counts": { "files": 14, "cases": 213 }
}
```

Fehlerverhalten beider Skripte: Pfad fehlt → exit 1. Keine Tests gefunden →
leeres Inventar, exit 0 (dann ist ALLES Lücke — Report sagt das nüchtern).

## 6. LLM-Analyse-Steps

1. **Verhaltens-Modell je Symbol** (Priorisierung: branchCount × blockLines,
   Routen immer): Quellcode lesen und die unterscheidbaren Verhaltensweisen
   aufzählen — Normalfall(e), Randfälle (leer/null/0/negativ/Maximum),
   Fehlerpfade (throws, Fehler-Returns), Zustandsabhängigkeiten. Nüchtern bleiben:
   nur Verhalten, das der Code erkennbar hat, nichts Hypothetisches.
2. **Test-Zuordnung**: über Imports + Test-Namen + (bei Unklarheit) Testdatei-Inhalt
   lesen → welches Verhalten deckt welcher Testfall ab. Konfidenz je Zuordnung
   (`belegt` = Test ruft Symbol mit passendem Szenario auf; `wahrscheinlich` =
   Name passt, Inhalt nicht geprüft).
3. **Lücken bestimmen**: Verhalten ohne zugeordneten Test. Risiko je Lücke:
   `hoch` (Fehlerpfad/Geld/Datenverlust-Nähe — Schlüsselwörter + Kontext),
   `mittel` (Randfall in genutztem Pfad), `niedrig` (exotisch).
4. Report: Kurzfassung (Oberfläche n Symbole, m Verhalten, k ungetestet, davon
   hoch: x) → Lückenliste nach Risiko: Symbol (Datei:Zeile), ungetestetes
   Verhalten, warum riskant, **vorgeschlagener Testfall-Name + Ein-Satz-Szenario**
   → Abdeckungs-Tabelle (Symbol × Verhalten × Test-Verweis) → nicht zugeordnete
   Tests (Tests, deren Ziel unklar ist — eigener Befund) → Offene Fragen.
5. Evidenz-Pflicht: jede "ungetestet"-Aussage stützt sich auf das vollständige
   Test-Inventar (Suche dokumentieren); jede Abdeckungs-Aussage mit Test-Fundstelle.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Keine Tests im Projekt | Alles Lücke; Report priorisiert nach Risiko statt alles zu listen (Top 20 + Zählwerte) |
| Sehr große Oberfläche (> 50 Symbole) | Fokus-Pflicht bzw. Top-N nach branchCount; ausweisen was ausgelassen wurde |
| Snapshot-Tests | Als `wahrscheinlich`-Abdeckung des Normalfalls werten, nie der Randfälle |
| Tests testen private Helfer via Export-Hack | Zuordnung über Imports fängt es; sonst nicht zugeordnete Tests |
| Parametrisierte Tests ([Theory], test.each) | Ein Fall kann mehrere Verhalten abdecken — Parameter-Liste lesen |
| Mocks verdecken echtes Verhalten | Nicht bewertbar — Zuordnung bleibt `wahrscheinlich`, Hinweis im Report |

## 8. Testplan

Smoke: Fixture `test-luecken-kartograf/tests/fixture/` mit 1 Modul (Funktion mit
3 klar unterscheidbaren Verhalten: Normalfall, Leer-Input, Fehler-Throw) + 1
Testdatei, die NUR den Normalfall testet. Dann:

```powershell
& .\test-luecken-kartograf\scripts\surface-inventory.ps1 -ProjectDir ".\test-luecken-kartograf\tests\fixture"
& .\test-luecken-kartograf\scripts\test-inventory.ps1 -ProjectDir ".\test-luecken-kartograf\tests\fixture"
```

Erwartung: exit 0, JSON valide; Symbol mit branchCount ≥ 2, Testfall inventarisiert.
LLM-Durchlauf: exakt 2 Lücken (Leer-Input, Fehlerpfad) gemeldet, Normalfall als
abgedeckt mit Test-Verweis (harte Kriterien: 0 FP, 0 FN auf der Fixture).

Akzeptanz (dreamzzz-api): Lauf mit Fokus auf ein Kernmodul. Erwartung: Lauf ohne
Fehler; 2 "abgedeckt"-Aussagen und 2 Lücken stichprobenartig gegen Quelle/Tests
verifiziert.

Negativ: ungültiger Pfad → exit != 0 (beide Skripte).

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig (statisch, kein Test-Lauf, keine Tests ins Zielprojekt)
- [ ] surface-inventory.ps1 + test-inventory.ps1 gemäß Spezifikation
- [ ] Fixture angelegt (3 Verhalten, 1 getestet)
- [ ] Smoke bestanden; Fixture-Urteile fehlerfrei (0 FP, 0 FN)
- [ ] Akzeptanz-Lauf dokumentiert (4 Stichproben)
- [ ] Negativ-Tests bestanden
- [ ] Report erfüllt BIBEL § 4
- [ ] tracking.md aktualisiert, Commit `sprint-15: test-luecken-kartograf implementiert`
