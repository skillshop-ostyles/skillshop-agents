# Sprint 12 — doku-drift-detektor (/doc-drift)

Regeln: `ops/BIBEL.md` gilt vollständig.

## 1. Problem

Dokumentation lügt nach sechs Monaten: das README nennt Kommandos, die es nicht mehr
gibt, Pfade, die umgezogen sind, Env-Vars, die umbenannt wurden, Beispiele, die nicht
mehr kompilieren. Niemand prüft das, weil es bedeutet, jede Behauptung einzeln gegen
den Code zu halten — stupide Fleißarbeit in großer Menge. Genau das kann ein LLM:
prüfbare Behauptungen aus Doku extrahieren und systematisch gegen die Repo-Realität
verifizieren.

## 2. Nutzen

Vorher: neue Devs scheitern am README, Doku-Vertrauen erodiert, irgendwann liest sie
niemand mehr. Nachher: Drift-Report mit jeder falschen Behauptung + Korrektur-Vorschlag;
Doku wird wieder vertrauenswürdig. Profiteure: Onboarding, Support, jeder
"folge einfach dem README"-Moment.

## 3. Scope / Nicht-Scope

**Scope:** Markdown-Doku eines Repos (README*, docs/, CONTRIBUTING* etc.) gegen
denselben Repo-Stand. Prüfbare Behauptungs-Typen: Datei-/Verzeichnis-Pfade,
Kommandos/Skripte, Config-Schlüssel/Env-Vars, API-Endpoints, Versionsangaben,
Code-Beispiel-Bezüge (referenzierte Symbole).
**Nicht-Scope:** KEINE Kommandos ausführen (rein statischer Abgleich — Sicherheit vor
Vollständigkeit). Keine externen Links prüfen (kein Netz-Crawling). Keine inhaltliche
Prosa-Bewertung ("ist das gut erklärt").

## 4. Skill-Spezifikation

Ordner: `doku-drift-detektor/`

Frontmatter:

```yaml
---
name: doku-drift-detektor
description: "Documentation drift detector: extracts verifiable claims from a repo's markdown docs (file paths, commands/scripts, config keys, endpoints, versions, referenced symbols) and statically verifies each one against the actual code, reporting every stale claim with a concrete fix suggestion. Never executes documented commands. Read-only. Trigger: /doc-drift"
trigger: /doc-drift
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir`. Bestätigen.
3. `scripts/claim-extract.ps1` ausführen.
4. LLM-Verifikation gemäß § 6 (mit Grep/Glob/Read gegen das Repo).
5. Report `doc-drift-report.md` ins Arbeitsverzeichnis; Kurzfassung: Drift-Quote,
   schlimmste Funde zuerst.

Usage:

```
/doc-drift               # interaktiv
/doc-drift <dir>         # Repo-Doku prüfen
/doc-drift --help
```

## 5. Collector-Skripte

### scripts/claim-extract.ps1

Parameter: `-ProjectDir` (Pflicht), `-DocGlobs` (Default: `README*`, `*.md` in
Wurzel, `docs/**/*.md`, `CONTRIBUTING*`), `-MaxClaims` (Default 500).

Read-only. Extrahiert aus jeder Doku-Datei Behauptungs-Kandidaten mit Typ,
Fundstelle (Datei:Zeile) und Rohtext:

1. **Pfade**: backtick-umschlossene Strings mit `/` oder Datei-Endung
   (`` `src/config.ts` ``), Verzeichnis-Erwähnungen.
2. **Kommandos**: Zeilen in ```-Codeblöcken der Sprachen bash/sh/powershell/console
   sowie Zeilen, die mit `npm|yarn|pnpm|pip|python|dotnet|go|cargo|make|git ` beginnen.
3. **Config/Env**: `UPPER_SNAKE_CASE`-Tokens (≥ 2 Unterstriche oder bekannte
   Präfixe), backtick-Schlüssel in Config-Kontext-Zeilen.
4. **Endpoints**: `(GET|POST|PUT|DELETE|PATCH)\s+/[\w/{}:.-]*` und Pfade beginnend
   mit `/api/`.
5. **Versionen**: `(node|python|dotnet|go|java|npm)[^\n]{0,20}\d+(\.\d+)*` sowie
   `requires .* \d+` — nur als Kandidat, Bewertung beim LLM.
6. **Symbol-Referenzen**: backtick-Bezeichner in CamelCase/snake_case ohne Pfad-Zeichen.

Deduplizieren pro (Typ, Rohtext); Zähler behalten. Bei > MaxClaims kappen
(`truncated: true`), Zählung je Typ vollständig.

JSON-Schema (Beispiel):

```json
{
  "docFiles": ["README.md", "docs/setup.md"],
  "claims": [
    { "type": "path", "text": "src/config.ts", "doc": "README.md", "line": 42, "occurrences": 2 },
    { "type": "command", "text": "npm run build:prod", "doc": "docs/setup.md", "line": 17, "occurrences": 1 }
  ],
  "countsByType": { "path": 12, "command": 9, "config": 5, "endpoint": 3, "version": 2, "symbol": 8 },
  "truncated": false
}
```

Fehlerverhalten: Pfad fehlt → exit 1; keine Doku-Dateien → Meldung + exit 0
(SKILL.md: User informieren, stopp).

## 6. LLM-Analyse-Steps (Verifikation)

Pro Claim statisch gegen das Repo prüfen — Methode je Typ:

1. **path**: existiert Datei/Verzeichnis (Glob)? Bei Fehlschlag: ähnliche Pfade
   suchen (umgezogen?) → Korrektur-Vorschlag.
2. **command**: npm-Skripte gegen `package.json scripts` (analog Makefile-Targets,
   pyproject-Skripte); genannte Binaries/Subkommandos plausibilisieren (nur
   Existenz-Logik, NIE ausführen). Nicht statisch prüfbar → `nicht-prüfbar`.
3. **config**: Schlüssel im Code/Config gegreppt — wird er gelesen/definiert?
4. **endpoint**: Route im Code vorhanden (Muster aus Sprint 09 code-claims
   wiederverwendbar)?
5. **version**: gegen engines/target-Angaben in Manifesten halten.
6. **symbol**: existiert der Bezeichner im Code (Wortgrenzen-Grep)?

Urteil je Claim: `korrekt` / `DRIFT` (mit Beleg: was die Doku sagt vs. was das Repo
zeigt, beides mit Fundstelle) / `nicht-prüfbar` (mit Grund). Severity für Drift:
`hoch` (Kommando/Pfad im Setup-Weg — blockiert Onboarding) / `mittel` / `niedrig`.

Report: Kurzfassung (Claims gesamt, Drift-Quote, hoch-Severity-Funde) → Drift-Funde
nach Severity mit Korrektur-Vorschlag (konkreter Ersatztext) → nicht-prüfbar-Liste →
korrekt-Zählung → Offene Fragen. Evidenz-Pflicht: jedes Drift-Urteil mit beiden
Fundstellen (Doku-Zeile + Repo-Beleg bzw. Fehlanzeige der Suche).

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Doku beschreibt geplantes/zukünftiges Verhalten ("wird bald…") | LLM erkennt Futur-Kontext → nicht-prüfbar, nicht Drift |
| Platzhalter in Kommandos (`<your-key>`, `$VAR`) | Platzhalter normalisieren, nur Struktur prüfen |
| Monorepo (Doku meint Teilprojekt) | Pfad-Prüfung relativ zu Doku-Verzeichnis UND Repo-Wurzel versuchen |
| Auto-generierte Doku (api-docs) | Erkennen (Generator-Marker) → ausschließen, listen |
| Riesige Doku (> MaxClaims) | truncated; hoch-relevante Typen (command, path) priorisieren |
| Anker-Links innerhalb der Doku (#abschnitt) | Nicht-Scope (externe Links ebenso) — nicht melden |

## 8. Testplan

Smoke: Fixture `doku-drift-detektor/tests/fixture/` mit Mini-Projekt: 1 Quelldatei,
`package.json` mit einem Skript, `README.md` mit 4 Behauptungen — 1 korrekter Pfad,
1 falscher Pfad, 1 nicht existentes npm-Skript, 1 korrektes Symbol. Dann:

```powershell
& .\doku-drift-detektor\scripts\claim-extract.ps1 -ProjectDir ".\doku-drift-detektor\tests\fixture"
```

Erwartung: exit 0, JSON valide, alle 4 Claims extrahiert und korrekt typisiert.
LLM-Durchlauf: beide eingebauten Drifts gefunden, beide korrekten Claims als korrekt
(harte Kriterien: 0 False Positives, 0 False Negatives auf der Fixture).

Akzeptanz (dreamzzz-api): Komplettlauf gegen die Projekt-Doku. Erwartung: Lauf ohne
Fehler; 3 Drift-Urteile (falls vorhanden, sonst 3 korrekt-Urteile) manuell gegen
Doku + Code verifiziert.

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig (inkl. Nie-Ausführen-Regel für Kommandos)
- [ ] claim-extract.ps1 mit allen 6 Claim-Typen + Dedup + Kappung
- [ ] Fixture angelegt
- [ ] Smoke bestanden; Fixture-Urteile fehlerfrei (0 FP, 0 FN)
- [ ] Akzeptanz-Lauf dokumentiert (3 Urteile verifiziert)
- [ ] Negativ-Test bestanden
- [ ] Report erfüllt BIBEL § 4 (beidseitige Evidenz je Drift)
- [ ] tracking.md aktualisiert, Commit `sprint-12: doku-drift-detektor implementiert`
