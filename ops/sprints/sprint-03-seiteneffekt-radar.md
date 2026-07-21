# Sprint 03 — seiteneffekt-radar (/blast)

Regeln: `ops/BIBEL.md` gilt vollständig. Wiederverwendung: Git-Mining-Muster aus
Sprint 01 (`intent-archaeologie/scripts/git-mine.ps1`) darf kopiert/angepasst werden.

## 1. Problem

"Kleiner Change, was soll schon passieren" — und drei Tage später bricht ein Feature,
von dem niemand wusste, dass es dieselbe Funktion nutzt. Statische Referenzen zeigen
nur die halbe Wahrheit; die andere Hälfte steckt in historischer Kopplung: Dateien,
die in der Vergangenheit fast immer GEMEINSAM geändert wurden, hängen fachlich
zusammen, auch ohne Import-Beziehung. Diese Kopplung aus tausenden Commits zu lesen
und mit dem Referenz-Graph zu einem Risikobild zu verschmelzen — das kann erst ein LLM.

## 2. Nutzen

Vorher: Blast-Radius = Bauchgefühl des dienstältesten Devs. Nachher: vor jedem
riskanten Change ein Report: welche Stellen sind betroffen (statisch belegt), welche
wahrscheinlich (historisch gekoppelt), was konkret prüfen/testen. Profiteure: jeder
vor einem Refactoring, Reviewer, On-Caller.

## 3. Scope / Nicht-Scope

**Scope:** Eingabe = eine oder mehrere Ziel-Dateien (der geplante Change-Ort) in
einem Git-Repo. Ausgabe = Blast-Radius-Report. Textbasierte Referenz-Suche
(sprachagnostisch via Symbol-Grep) + Co-Change-Analyse.
**Nicht-Scope:** Kein echter AST/Typgraph (kein tsc/Sprachserver — Simplicity First,
Grep-Niveau reicht für Risiko-Hinweise). Keine dynamische Analyse. Read-only.

## 4. Skill-Spezifikation

Ordner: `seiteneffekt-radar/`

Frontmatter:

```yaml
---
name: seiteneffekt-radar
description: "Blast-radius predictor for a planned change: combines a static reference scan (which files mention the target's exported symbols) with git co-change analysis (which files historically changed together with the target), then produces a risk-tiered report with concrete review/test recommendations. Read-only. Trigger: /blast"
trigger: /blast
---
```

Invocation-Steps:

1. `--help` → Usage, stopp.
2. Klären: `-ProjectDir` (Repo-Wurzel) + Ziel-Datei(en) + kurze Beschreibung des
   geplanten Changes (Freitext vom User — bestimmt, welche Symbole relevant sind).
3. Ziel-Datei lesen, exportierte/öffentliche Symbole identifizieren (LLM, kein Skript —
   sprachabhängig; bei Unsicherheit alle top-level Bezeichner nehmen).
4. `scripts/ref-scan.ps1` mit den Symbolnamen ausführen.
5. `scripts/co-change.ps1` mit den Ziel-Dateien ausführen.
6. LLM-Analyse gemäß § 6, Report `blast-report-<datei>.md` ins Arbeitsverzeichnis.

Usage:

```
/blast                          # interaktiv
/blast <repo> <datei> [...]     # Blast-Radius für geplanten Change an <datei>
/blast --help
```

## 5. Collector-Skripte

### scripts/ref-scan.ps1

Parameter: `-ProjectDir` (Pflicht), `-Symbols` (Pflicht, String-Array), `-Exclude`
(optional, Default: `node_modules,dist,build,.git,vendor,coverage`).

Read-only. Für jedes Symbol: Volltext-Suche (Wortgrenze, case-sensitive) über
Quelldateien (Erweiterungs-Whitelist: ts,tsx,js,jsx,py,cs,go,rs,java,php,rb,vue,
sql,ps1 — als Parameter `-Extensions` überschreibbar). Pro Treffer: Datei, Zeile,
Zeileninhalt (getrimmt, max 200 Zeichen).

JSON-Schema (Beispiel):

```json
{
  "symbols": [
    { "symbol": "calculateTax", "hits": [ { "file": "src/checkout/cart.ts", "line": 88, "text": "const tax = calculateTax(items)" } ], "hitCount": 1 }
  ],
  "scannedFiles": 412
}
```

### scripts/co-change.ps1

Parameter: `-ProjectDir` (Pflicht), `-Files` (Pflicht, String-Array, repo-relativ),
`-MaxCommits` (optional, Default 500), `-MinCoChanges` (optional, Default 3).

Read-only. Für jede Ziel-Datei: alle Commits ermitteln, die sie berührt haben
(`git log --format=%H -- <file>`, begrenzt auf `-MaxCommits`), dann für jeden dieser
Commits die mitgeänderten Dateien (`git show --name-only`). Aggregieren: welche
andere Datei taucht wie oft gemeinsam auf. Ausgeben ab `-MinCoChanges`, sortiert
absteigend, inkl. Kopplungsquote (gemeinsame Commits / Commits der Ziel-Datei).

JSON-Schema (Beispiel):

```json
{
  "targets": [
    {
      "file": "src/billing/invoice.ts",
      "commitCount": 47,
      "coChanged": [
        { "file": "src/billing/tax.ts", "together": 31, "ratio": 0.66 },
        { "file": "tests/invoice.test.ts", "together": 28, "ratio": 0.60 }
      ]
    }
  ],
  "truncated": false
}
```

Fehlerverhalten beider Skripte: fehlender Pfad / kein Repo → exit 1 mit Meldung.

## 6. LLM-Analyse-Steps

1. Statische Treffer bewerten: echte Nutzung vs. Namenskollision/Kommentar/String
   (Zeileninhalt liegt vor). Kollisionen aussortieren, aber im Report-Anhang listen.
2. Risiko-Stufen bilden:
   - **Stufe 1 — direkt betroffen** (`belegt`): Dateien mit echter Symbol-Nutzung.
   - **Stufe 2 — historisch gekoppelt** (`wahrscheinlich`): hohe Co-Change-Quote
     (Ratio ≥ 0.4) ohne statische Referenz — die gefährlichste Kategorie, explizit
     erklären, WARUM die Kopplung bestehen könnte (aus Dateinamen/Pfaden ableiten,
     Konfidenz ehrlich angeben).
   - **Stufe 3 — Umfeld** : schwache Kopplung (Ratio < 0.4, ≥ MinCoChanges), nur listen.
3. Change-Beschreibung des Users einbeziehen: welche Stufe-1/2-Stellen sind vom
   KONKRETEN Change betroffen (z. B. Signatur-Änderung vs. interne Optimierung).
4. Report: Kurzfassung (Risiko-Einschätzung in 3 Sätzen) → Stufe 1 mit Datei:Zeile
   → Stufe 2 mit Kopplungszahlen → konkrete Empfehlungen ("vor Merge: Test X laufen
   lassen, Datei Y reviewen, Owner von Z informieren") → Offene Fragen.
5. Evidenz-Pflicht: Stufe 1 = Datei:Zeile, Stufe 2 = Kopplungszahlen (n/N Commits).

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Symbol kommt 500+ mal vor (zu generischer Name) | ref-scan kappt bei 200 Treffern/Symbol, Flag `capped: true`; LLM meldet "Symbol zu generisch für statische Analyse" |
| Ziel-Datei frisch, kaum Historie | Co-Change leer; Report stützt sich nur auf Statik und sagt das |
| Monorepo, riesig | Exclude-Liste greift; bei > 60 s Laufzeit MaxCommits/Extensions einschränken und ausweisen |
| Datei umbenannt | co-change nutzt den aktuellen Pfad; Hinweis im Report, dass Historie vor Rename fehlt (kein --follow bei Co-Change — bewusste Vereinfachung, dokumentieren) |
| Kein Git | co-change exit 1; Skill läuft nur mit ref-scan weiter und weist die Lücke aus |

## 8. Testplan

Smoke (AGENTS-Repo):

```powershell
& .\seiteneffekt-radar\scripts\ref-scan.ps1 -ProjectDir "C:\Users\ostol\Desktop\AGENTS" -Symbols @("Normalize") -Extensions @("ps1")
& .\seiteneffekt-radar\scripts\co-change.ps1 -ProjectDir "C:\Users\ostol\Desktop\AGENTS" -Files @("elevate/SKILL.md") -MinCoChanges 1
```

Erwartung: ref-scan findet `Normalize` in elevate- und project-init-Skripten (belegt
die Kopie-Verwandtschaft); co-change liefert die Dateien des Initial-Commits als
gemeinsam geändert. Beide: exit 0, JSON valide.

Akzeptanz (dreamzzz-api): eine zentrale Datei wählen, Change-Beschreibung "Signatur
einer exportierten Funktion ändern". Erwartung: Stufe-1-Liste mit echten Fundstellen
(3 Stichproben prüfen), Stufe 2 nur falls Historie genug hergibt — sonst sauber
ausgewiesen.

Negativ: ungültiger Pfad → exit != 0 (beide Skripte).

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig
- [ ] ref-scan.ps1 (Whitelist, Exclude, Capping) + co-change.ps1 (Ratio, MinCoChanges)
- [ ] Smoke bestanden (beide Skripte, JSON validiert)
- [ ] Akzeptanz-Lauf dokumentiert (3 Stichproben Stufe 1 verifiziert)
- [ ] Negativ-Tests bestanden
- [ ] Report erfüllt BIBEL § 4 (Stufen sauber getrennt, Kopplungszahlen als Evidenz)
- [ ] tracking.md aktualisiert, Commit `sprint-03: seiteneffekt-radar implementiert`
