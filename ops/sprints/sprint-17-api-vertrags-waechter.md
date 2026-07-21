# Sprint 17 — api-vertrags-waechter (/api-diff)

Regeln: `ops/BIBEL.md` gilt vollständig. Wiederverwendung: Routen-Muster aus
Sprint 09 (`code-claims.ps1`) darf kopiert/angepasst werden.

## 1. Problem

Breaking Changes an APIs passieren nebenbei: ein Feld umbenannt, ein Pflichtparameter
ergänzt, ein Statuscode geändert — und Wochen später bricht ein Konsument, dessen
Existenz niemand kannte. Die API-Oberfläche zweier Code-Stände vollständig zu
vergleichen und jede Änderung nach Vertragsbruch-Schwere zu klassifizieren, ist
manuell so mühsam, dass es niemand tut. Ein LLM kann Oberflächen extrahieren, diffen
und — der eigentliche Mehrwert — je Breaking Change die Migrations-Notiz für
Konsumenten formulieren.

## 2. Nutzen

Vorher: Breaking Changes fallen beim Konsumenten auf, Schuldfrage-Meetings folgen.
Nachher: vor jedem Release ein Vertrags-Diff: was ist additiv, was breaking, und für
jeden Bruch eine kopierfertige Migrations-Notiz. Profiteure: API-Anbieter (Release
Notes entstehen nebenbei), Konsumenten-Teams, Versionierungs-Entscheidungen
(SemVer-Ehrlichkeit).

## 3. Scope / Nicht-Scope

**Scope:** API-Oberfläche = HTTP-Routen (Methode, Pfad, erkennbare Parameter) +
DTO-/Typ-Definitionen (Felder, Optionalität) + exportierte Funktions-Signaturen
(für Library-APIs). Vergleich zweier Stände: Git-Ref vs. Working Tree (oder
Ref vs. Ref). OpenAPI-/Swagger-Dateien werden, falls vorhanden, als BEVORZUGTE
Quelle genutzt.
**Nicht-Scope:** Keine Laufzeit-Prüfung (kein Request-Replay). Keine
Konsumenten-Suche außerhalb des Repos. Semantische Verhaltensänderungen ohne
Signatur-Änderung (dafür: /blast, Sprint 03) nur als Hinweis, nicht als Diff-Gegenstand.

## 4. Skill-Spezifikation

Ordner: `api-vertrags-waechter/`

Frontmatter:

```yaml
---
name: api-vertrags-waechter
description: "API contract guard: extracts the API surface (HTTP routes with params, DTO fields, exported signatures - preferring OpenAPI files when present) from two git states of a repo, diffs them, classifies every change as breaking / non-breaking / additive, and writes a ready-to-ship consumer migration note per breaking change. Read-only. Trigger: /api-diff"
trigger: /api-diff
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir` + Alt-Stand (`-OldRef`, z. B. Tag/Branch/Hash; Default:
   letzter Tag, sonst HEAD~20 vorschlagen) + Neu-Stand (Default: Working Tree).
   Bestätigen.
3. `scripts/api-surface.ps1` zweimal ausführen (Alt via `-Ref`, Neu ohne).
4. LLM-Diff + Klassifikation gemäß § 6.
5. Report `api-diff-report.md` ins Arbeitsverzeichnis; Kurzfassung: Breaking-Zahl
   + SemVer-Empfehlung (major/minor/patch).

Usage:

```
/api-diff                          # interaktiv (Ref-Vorschlag)
/api-diff <repo> <old-ref>         # old-ref vs. Working Tree
/api-diff <repo> <old-ref> <new-ref>
/api-diff --help
```

## 5. Collector-Skripte

### scripts/api-surface.ps1

Parameter: `-ProjectDir` (Pflicht), `-Ref` (optional; ohne Ref: Working Tree),
`-Extensions`/`-Exclude` (Defaults wie Sprint 03).

Read-only. Bei `-Ref`: Dateien via `git show <ref>:<pfad>` lesen (Dateiliste via
`git ls-tree -r <ref> --name-only`) — KEIN Checkout, Working Tree bleibt unberührt.

Extraktions-Ebenen (alle, die das Projekt hergibt):

1. **OpenAPI/Swagger**: `openapi*.{json,yaml,yml}`, `swagger*.{json,yaml}` —
   falls vorhanden: Pfade, Methoden, Parameter (Name, in, required), Response-Codes,
   Schema-Felder (Name, Typ, required). Diese Quelle dominiert (Flag
   `source: "openapi"`).
2. **Code-Routen**: Muster aus Sprint 09 (Express/Decorator/Attribut-Stile) →
   Methode, Pfad, Datei:Zeile; Pfad-Parameter aus dem Pfad-String (`:id`, `{id}`).
3. **DTO/Typen**: `interface|type|class|record`-Blöcke, deren Name auf
   `Dto|Request|Response|Model|Payload` endet ODER die von Routen-Dateien
   importiert werden (vereinfachend: Namens-Heuristik reicht) → Felder mit Name,
   Typ-Text, Optionalitäts-Marker (`?`, `| null`, `Optional[...]`, `*`-Pointer).
4. **Exportierte Signaturen** (Library-Fall): `export function <name>(<params>)` —
   Name, Parameter-Namen/Typen-Text, Return-Typ-Text.

JSON-Schema (Beispiel):

```json
{
  "ref": "v1.4.0",
  "source": "code",
  "routes": [ { "method": "POST", "path": "/orders", "params": ["body:CreateOrderDto"], "file": "src/api/orders.ts", "line": 12 } ],
  "dtos": [ { "name": "CreateOrderDto", "file": "src/api/dto.ts", "fields": [ { "name": "customerId", "type": "string", "optional": false } ] } ],
  "signatures": [],
  "openapiFiles": []
}
```

Fehlerverhalten: ungültiger Ref → git-Fehler durchreichen + exit 1. Leere
Oberfläche → exit 0 mit Zählwert 0 (SKILL.md: prüfen, ob das Projekt überhaupt
eine API hat; sonst sauber beenden).

## 6. LLM-Analyse-Steps

1. **Matching**: Routen über (Methode, normalisierter Pfad — Parameter-Namen egal:
   `/users/:id` = `/users/{userId}`), DTOs über Namen (Umbenennungs-Verdacht:
   gleiches Feld-Set, anderer Name → nachfragen bzw. `vermutet`), Signaturen über
   Namen.
2. **Klassifikation jeder Differenz** (Regelwerk, im Report referenzieren):
   - **breaking**: Route entfernt; Methode geändert; Pflichtparameter/Pflichtfeld
     NEU; Feld entfernt; Feld-Typ inkompatibel geändert; optional → required;
     Response-Feld entfernt (bei openapi-Quelle); Signatur: Parameter entfernt/
     umgeordnet/Pflicht ergänzt.
   - **additiv**: neue Route; neues optionales Feld/Param; neue Signatur.
   - **non-breaking**: Doku/Beschreibung; required → optional; Typ-Verbreiterung.
   - Grauzonen (Typ-Text geändert, Kompatibilität unklar) → `vermutet` + Offene Frage.
3. **Migrations-Notiz je Breaking Change** (der Kern-Mehrwert): kopierfertiger
   Absatz für Konsumenten — was ändert sich, was ist VOR dem Update zu tun,
   Beispiel vorher/nachher (aus den echten Feld-/Pfadnamen).
4. **SemVer-Empfehlung**: breaking > 0 → major; sonst additiv > 0 → minor; sonst patch.
5. Report: Kurzfassung (Zahlen + SemVer) → Breaking mit Migrations-Notizen →
   Additiv → Non-breaking (kompakt) → Umbenennungs-Verdachte + Offene Fragen.
6. Evidenz-Pflicht: jede Differenz mit beiden Fundstellen (alt: Ref+Datei:Zeile,
   neu: Datei:Zeile) bzw. Fehlanzeige-Beleg bei Entfernungen.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| OpenAPI vorhanden, aber veraltet vs. Code | Beide extrahieren; Diskrepanz als eigener Befund ("Spec-Drift" — Querverweis /doc-drift), Code gilt als Wahrheit |
| Route dynamisch registriert (Loop über Config) | Nicht extrahierbar → Abdeckungslücke ausweisen (wie dynamicReads in Sprint 14) |
| Pfad-Präfixe aus Router-Mounting (app.use('/api', r)) | Best effort: Mount-Stellen scannen; unsichere Vollpfade als `vermutet` |
| Alt-Ref hat andere Dateistruktur | git show arbeitet ref-lokal — unkritisch; Matching läuft über Oberflächen-Ebene, nicht Dateipfade |
| Kein Git-Tag, flache Historie | HEAD~N-Vorschlag; bei Ablehnung User nach Ref fragen |
| GraphQL/gRPC statt REST | *.graphql/*.proto als DTO-Quelle mitnehmen (Felder/required analog); Routen-Ebene entfällt, ausweisen |

## 8. Testplan

Smoke: Fixture `api-vertrags-waechter/tests/fixture/` als eigenes Mini-Git-Repo
(im Fixture-Ordner `git init`, zwei Commits): Commit 1 = 2 Routen + 1 DTO
(3 Felder); Commit 2 = 1 Route entfernt, 1 DTO-Feld entfernt, 1 optionales Feld
ergänzt, 1 Feld optional → required. Dann:

```powershell
& .\api-vertrags-waechter\scripts\api-surface.ps1 -ProjectDir ".\api-vertrags-waechter\tests\fixture" -Ref HEAD~1
& .\api-vertrags-waechter\scripts\api-surface.ps1 -ProjectDir ".\api-vertrags-waechter\tests\fixture"
```

Erwartung: exit 0, JSON valide, beide Stände korrekt extrahiert. LLM-Durchlauf:
3 breaking + 1 additiv korrekt klassifiziert, SemVer = major, je Breaking eine
Migrations-Notiz mit echten Namen (harte Kriterien). Hinweis: verschachteltes
Git-Repo im AGENTS-Repo — Fixture-Ordner in `.gitignore` des AGENTS-Repos
aufnehmen ODER Fixture bei Bedarf per Setup-Skript erzeugen
(`tests/setup-fixture.ps1`, von Sonnet zu entscheiden und zu dokumentieren).

Akzeptanz (dreamzzz-api): `-OldRef` = ein älterer erreichbarer Stand (HEAD~10 o. ä.,
je nach Historie). Erwartung: Lauf ohne Fehler; 3 Klassifikationen stichprobenartig
gegen `git show` verifiziert.

Negativ: ungültiger Ref → exit != 0; ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig
- [ ] api-surface.ps1 (openapi-Präferenz, Routen, DTOs, Signaturen, -Ref via git show)
- [ ] Fixture-Strategie umgesetzt (Setup-Skript oder gitignore) und dokumentiert
- [ ] Smoke bestanden; alle 4 Differenzen korrekt klassifiziert, SemVer major
- [ ] Migrations-Notizen: je Breaking vorhanden, mit echten Namen
- [ ] Akzeptanz-Lauf dokumentiert (3 Stichproben)
- [ ] Negativ-Tests bestanden
- [ ] Report erfüllt BIBEL § 4 (beidseitige Fundstellen je Differenz)
- [ ] tracking.md aktualisiert, Commit `sprint-17: api-vertrags-waechter implementiert`
