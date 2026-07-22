# Sprint 04 — konsistenz-enforcer (/consist)

Regeln: `ops/BIBEL.md` gilt vollständig.

## 1. Problem

Dieselbe fachliche Regel — eine Preisberechnung, eine E-Mail-Validierung, eine
Altersgrenze — lebt an 5, 10, 14 Stellen im System, jeweils leicht anders
implementiert. Klassische Clone-Detection findet nur Text-Duplikate; sie ist blind
für semantisch gleiche Logik in verschiedenem Code (`if (age >= 18)` vs.
`isAdult(user)` vs. `MINIMUM_AGE = 18` in einer Config). Divergenzen zwischen diesen
Stellen sind schleichende Produktionsfehler. Semantische Gleichheit erkennen kann
erst ein LLM.

## 2. Nutzen

Vorher: Divergenz fällt auf, wenn ein Kunde zwei verschiedene Preise sieht. Nachher:
Report aller mehrfach implementierten Geschäftsregeln inkl. der Stellen, die
abweichen, plus Single-Source-of-Truth-Vorschlag. Profiteure: alle — das ist die
Fehlerklasse, die niemand zuordnen kann, weil "der Code doch stimmt".

## 3. Scope / Nicht-Scope

**Scope:** Ein Quellverzeichnis. Kandidaten-Extraktion per Skript, semantischer
Vergleich per LLM. Fokus-Kategorien: Validierungen, Berechnungen, fachliche
Konstanten/Grenzwerte, Regexe, Status-/Enum-Logik.
**Nicht-Scope:** Kein automatisches Refactoring (nur Vorschlag). Kein
Framework-/Boilerplate-Code (Kandidaten-Filter). Read-only.

## 4. Skill-Spezifikation

Ordner: `konsistenz-enforcer/`

Frontmatter:

```yaml
---
name: konsistenz-enforcer
description: "Finds duplicated BUSINESS LOGIC (not duplicated text): extracts rule candidates (validations, calculations, domain constants, regexes, status logic) from a codebase, then has the LLM cluster semantically equal rules across different implementations and flag divergent ones with a single-source-of-truth proposal. Read-only. Trigger: /consist"
trigger: /consist
---
```

Invocation-Steps:

1. `--help` → Usage, stopp.
2. Klären: `-ProjectDir` + optional fachlicher Fokus (Freitext, z. B. "alles rund um
   Preise") — engt die LLM-Clusterung ein, nicht die Extraktion.
3. `scripts/rule-candidates.ps1` ausführen.
4. LLM-Analyse gemäß § 6 (bei > 300 Kandidaten: erst clustern nach Kategorie, dann
   je Kategorie analysieren).
5. Report `consist-report.md` ins Arbeitsverzeichnis.

Usage:

```
/consist                  # interaktiv
/consist <dir>            # ganzes Verzeichnis
/consist <dir> "<fokus>"  # mit fachlichem Fokus
/consist --help
```

## 5. Collector-Skripte

### scripts/rule-candidates.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions` (Default wie Sprint 03),
`-Exclude` (Default wie Sprint 03), `-MaxCandidates` (Default 1000).

Read-only. Extrahiert Kandidaten-Zeilen (mit `Datei:Zeile` + Zeileninhalt + 2 Zeilen
Kontext davor/danach) über Muster-Familien:

1. **Vergleiche mit Literalen**: `[<>]=?\s*\d`, `===?\s*['"\d]` (Grenzwerte).
2. **Numerische Konstanten-Deklarationen**: `(const|final|static|readonly|[A-Z_]{3,}\s*=)\s*.*\d`.
3. **Regex-Literale**: Zeilen mit `/.../`-Literalen oder `Regex|Pattern|match`-Aufrufen.
4. **Validierungs-Indikatoren**: `valid|check|verify|ensure|require|assert` in
   Funktions-/Methodennamen-Zeilen.
5. **Berechnungs-Indikatoren**: `calc|compute|total|sum|rate|price|tax|fee|discount`.
6. **Status-Logik**: `status|state`-Vergleiche mit String-Literalen.

Jeder Kandidat bekommt seine Kategorie(n). Deduplizierung identischer Zeilen NICHT
durchführen (identische Duplikate sind gerade interessant). Bei > MaxCandidates:
kappen, `truncated: true`, Zählung je Kategorie trotzdem vollständig ausgeben.

JSON-Schema (Beispiel):

```json
{
  "candidates": [
    { "file": "src/user/service.ts", "line": 42, "category": ["comparison"], "text": "if (user.age >= 18) {", "context": ["...", "..."] }
  ],
  "countsByCategory": { "comparison": 120, "constant": 45, "regex": 12, "validation": 60, "calculation": 33, "status": 18 },
  "truncated": false,
  "scannedFiles": 300
}
```

Fehlerverhalten: Pfad fehlt → exit 1.

## 6. LLM-Analyse-Steps

1. Kandidaten sichten, offensichtliches Rauschen verwerfen (Loop-Indizes, Test-Zahlen,
   HTTP-Status-Codes in Framework-Code) — verworfene Kategorien im Report-Anhang nennen.
2. **Clustern nach fachlicher Bedeutung**, nicht nach Text: "alles, was Volljährigkeit
   prüft", "alles, was MwSt berechnet". Bei gesetztem Fokus: nur passende Cluster tief
   analysieren, Rest als Inventar listen.
3. Pro Cluster mit ≥ 2 Stellen:
   - Alle Stellen mit `Datei:Zeile` + Code-Ausschnitt.
   - **Konsistenz-Urteil**: `konsistent` (gleiche Semantik, gleiche Werte) oder
     `DIVERGENT` (z. B. `>= 18` an einer Stelle, `> 18` an anderer; `0.19` vs `19`).
     Divergenzen sind die Hauptbefunde — präzise benennen, worin die Abweichung
     besteht und welches Fehlverhalten sie erzeugen kann.
   - **SSoT-Vorschlag**: wo die Regel künftig einzig leben sollte (existierende
     Konstante/Funktion bevorzugen, sonst Vorschlag mit Modul-Ort), Konfidenz angeben.
4. Report: Kurzfassung (X Regeln mehrfach, davon Y divergent) → Divergenzen zuerst
   (Severity: divergente Werte = hoch) → konsistente Mehrfach-Implementierungen →
   SSoT-Vorschläge → Offene Fragen (Cluster der Stufe `vermutet`).
5. Evidenz-Pflicht: keine Cluster-Behauptung ohne alle Fundstellen; Divergenz-Urteil
   nur mit direktem Code-Zitat beider Seiten.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| 0 Kandidaten (z. B. reines Config-Repo) | Sauber melden, kein leerer Pseudo-Report |
| > 1000 Kandidaten | truncated; LLM analysiert kategorienweise, priorisiert per Fokus oder fragt User nach Eingrenzung |
| Generierter Code (dist, *.min.js, *.generated.*) | In Default-Exclude aufnehmen (`*.min.*`, `*generated*`) |
| Gleiche Regel in Code UND SQL/Config | Ausdrücklich gewollt — cross-language Cluster bilden |
| Test-Dateien | NICHT ausschließen (Tests kodieren oft die "wahre" Regel), aber im Cluster als Test markieren |

## 8. Testplan

Smoke: Fixture `konsistenz-enforcer/tests/fixture/` mit 3 kleinen Dateien, die
dieselbe Regel dreimal enthalten, davon EINE divergent (z. B. zweimal `>= 18`, einmal
`> 18` — unterschiedlich formuliert: if-Statement, Konstante, Funktion). Dann:

```powershell
& .\konsistenz-enforcer\scripts\rule-candidates.ps1 -ProjectDir ".\konsistenz-enforcer\tests\fixture"
```

Erwartung: exit 0, JSON valide, alle 3 Stellen als Kandidaten. LLM-Durchlauf:
Cluster wird gebildet, die Divergenz MUSS gefunden und korrekt benannt werden
(hartes Akzeptanzkriterium).

Akzeptanz (dreamzzz-api): Komplettlauf ohne Fokus. Erwartung: Lauf ohne Fehler,
Kandidaten-Zählung plausibel, mindestens die Cluster-Bildung nachvollziehbar
(3 Fundstellen-Stichproben gegen Quelle prüfen). Divergenz-Funde sind projektabhängig —
keine Pflicht, aber falls gemeldet: Code-Zitate müssen stimmen.

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [x] SKILL.md vollständig
- [x] rule-candidates.ps1 mit allen 6 Muster-Familien + Kategorisierung + Capping
- [x] Fixture mit eingebauter Divergenz angelegt
- [x] Smoke bestanden; Divergenz gefunden und korrekt beschrieben
- [x] Akzeptanz-Lauf dokumentiert (3 Stichproben verifiziert)
- [x] Negativ-Test bestanden
- [x] Report erfüllt BIBEL § 4
- [x] tracking.md aktualisiert, Commit `sprint-04: konsistenz-enforcer implementiert`

## 10. Entscheidungen während der Umsetzung

1. **Skill-Ordner-Pfad**: `skills/konsistenz-enforcer/` (BIBEL-§-3-Konvention seit
   Sprint 29).
2. **PSObject-Serialisierungs-Bug gefunden und behoben**: `Get-Content`-Zeilen
   tragen PowerShell-ETS-Metadaten (`PSPath`, `PSParentPath`, `PSChildName`,
   `PSDrive`) am Objekt. Werden sie unverändert in ein `[ordered]`-Hashtable
   geschrieben, serialisiert `ConvertTo-Json` das komplette PSObject statt nur den
   Zeileninhalt (aufgefallen im `context`-Array, wo `text` durch `.Trim()` bereits
   unbeabsichtigt "sauber" war). Fix: `[string]`-Cast auf jede Kontext-Zeile.
   Für künftige Sprints relevant: JEDE direkt aus `Get-Content` übernommene Zeile,
   die in JSON landet, braucht einen expliziten String-Cast.
3. **6 Muster-Familien als einfache Regex-Heuristiken**: bewusst grob (Grep-Niveau,
   Simplicity First, wie bei `ref-scan.ps1` in Sprint 03) — Kandidaten-Extraktion
   ist ein Vorfilter für die LLM-Analyse, keine exakte Klassifikation.

## 11. Testergebnisse

**Smoke** (Fixture `skills/konsistenz-enforcer/tests/fixture/`, 3 Dateien mit
derselben Volljährigkeits-Regel, davon eine divergent: `>= 18` zweimal, `> 18`
einmal): `rule-candidates.ps1` liefert 5 Kandidaten (2× comparison, 2× validation,
1× constant), alle 3 Dateien erfasst. Manuelle LLM-Analyse (hartes
Akzeptanzkriterium): Divergenz korrekt gefunden und benannt (`eligibility-check.ts:2`
`>= 18` vs. `signup-validator.ts:2` `> 18`, Off-by-one an der Geschäftsregel-Grenze),
SSoT-Vorschlag (bestehende `MINIMUM_AGE`-Konstante nutzen). Report erfüllt BIBEL § 4.

**Akzeptanz** (`dreamzzz-api_vs/src`, Komplettlauf ohne Fokus): 460 Kandidaten in 9
Dateien (constant 185, comparison 117, regex 129, calculation 45, validation 15,
status 7). LLM-Analyse fand einen echten Divergenz-Cluster: "Retry-Versuchsbudget
für Gemini/Imagen-Aufrufe" — `gemini.ts:73` (`RETRY_ATTEMPTS = 3`), `vision.ts:217`
(`SYNTH_MAX = 3`), `vision.ts:266` (`MAX_ATTEMPTS = 3`) sind konsistent bei 3
Versuchen, `vision-v7.ts:132` (`MATRIX_MAX = 2`) weicht ab. Alle 3 Stichproben per
`sed -n` gegen die Quelle verifiziert — exakte Übereinstimmung. Offene Frage korrekt
ausgewiesen (beabsichtigt vs. Versehen nicht aus dem Code klärbar).

**Negativ**: nicht existenter Pfad → `Write-Error` + Exit-Code 1, kein
unkontrollierter Stack-Trace.
