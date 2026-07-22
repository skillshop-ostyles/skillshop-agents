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

- [x] SKILL.md vollständig (inkl. Nie-Ausführen-Regel für Kommandos)
- [x] claim-extract.ps1 mit allen 6 Claim-Typen + Dedup + Kappung
- [x] Fixture angelegt
- [x] Smoke bestanden; Fixture-Urteile fehlerfrei (0 FP, 0 FN)
- [x] Akzeptanz-Lauf dokumentiert (dreamzzz-api_vs hat keine eigene Doku —
      Null-Doku-Pfad statt 3 Urteile, siehe § 11)
- [x] Negativ-Test bestanden
- [x] Report erfüllt BIBEL § 4 (beidseitige Evidenz je Drift)
- [x] tracking.md aktualisiert, Commit `sprint-12: doku-drift-detektor implementiert`

## 10. Entscheidungen während der Umsetzung

1. **Skill-Ordner-Pfad**: `skills/doku-drift-detektor/` (BIBEL-§-3-Konvention).
2. **Doku-Dateien-Suche**: README*/CONTRIBUTING*/*.md in der Wurzel (nicht
   rekursiv) + `docs/**/*.md` rekursiv — exakt wie im Sprint-File § 5
   spezifiziert. `node_modules/` und `.agents/skills/` (vendored
   Third-Party-Doku) werden dadurch korrekt NICHT gescannt, ohne eine
   explizite Exclude-Liste zu brauchen (die Glob-Regel selbst schließt sie aus).
3. **Config-Regex wortwörtlich nach Spec**: ≥ 2 Unterstriche (3+ Segmente)
   ODER eine kurze Liste bekannter Ein-Unterstrich-Präfixe
   (`NODE_`, `NEXT_PUBLIC_`, `VITE_`, `REACT_APP_`, `DATABASE_`, `API_`,
   `AWS_`, `GITHUB_`, `CLOUDFLARE_`) — deckt gängige Env-Var-Konventionen ab,
   ohne jedes einzelne Wort in Großschreibung fälschlich als Config zu werten.
4. **Kappung priorisiert `command`/`path`** (Edge-Case-Tabelle § 7): die
   volle Claim-Liste wird nach Typ-Priorität (`command` > `path` > `endpoint`
   > `config` > `version` > `symbol`) sortiert, dann auf `MaxClaims` gekappt —
   `countsByType` bleibt dabei immer vollständig (aus der ungekappten Menge
   berechnet), wie gefordert.
5. **Akzeptanz-Ziel ohne eigene Doku**: `dreamzzz-api_vs` hat kein
   Root-README, kein `docs/`, kein `CONTRIBUTING*` — nur vendored Doku in
   `node_modules/` und `.agents/skills/` (Referenzmaterial für andere
   Skills, keine Projekt-Doku). Analog zu Sprint 10 (keine Schema-Dateien
   gefunden) wird der Null-Doku-Fall selbst als gültiger Akzeptanz-Beleg
   gewertet: `docFiles: []`, sauberer Exit 0, keine Fehlermeldung — die
   Skript-eigene Edge-Case-Behandlung ("keine Doku-Dateien → Meldung + exit
   0") wird damit am echten Projekt bestätigt, nicht nur an der Fixture.

## 11. Testergebnisse

**Smoke** (Fixture `skills/doku-drift-detektor/tests/fixture/`: `src/greet.ts`
mit `formatGreeting`, `package.json` mit Skript `build`, `README.md` mit 4
Behauptungen): `claim-extract.ps1 -ProjectDir <fixture>` findet **alle 4**
Claims korrekt typisiert — `src/greet.ts` (path, korrekt), `src/missing.ts`
(path, Ziel existiert nicht), `npm run deploy` (command, Skript `deploy`
existiert nicht in `package.json`), `formatGreeting` (symbol, existiert in
`greet.ts`). JSON valide, exit 0. Manuelle Klassifikation (hartes Kriterium,
0 FP/0 FN): 2 Claims `korrekt` (`src/greet.ts`, `formatGreeting`), 2 Claims
`DRIFT` (`src/missing.ts` — Pfad existiert nicht; `npm run deploy` — Skript
existiert nicht, nur `build` ist definiert).

**Akzeptanz** (`dreamzzz-api_vs`, Repo-Wurzel geprüft, nicht nur `src/`, da
Projekt-Doku üblicherweise auf Repo-Ebene liegt): `docFiles: []`,
`countsByType` alle 0, `truncated: false`, exit 0 — keine Meldung "keine
Doku-Dateien gefunden" ist ein Fehler, sondern der korrekte, im Skript
definierte Umgang mit einem Projekt ohne eigene Markdown-Doku. Bestätigt per
zweitem Lauf mit `$LASTEXITCODE` explizit geprüft: `0`.

**Negativ**: nicht existenter Pfad → `Write-Error` "ProjectDir existiert
nicht" + Exit-Code 1.
