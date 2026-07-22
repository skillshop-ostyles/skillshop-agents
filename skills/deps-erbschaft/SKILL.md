---
name: deps-erbschaft
description: "Dependency inheritance audit: for every direct dependency answers the questions nobody asks - why is it here (from actual usage sites), how deep is the coupling, how replaceable is it, and what is the concrete exit plan. Parses manifests/lockfiles, scans usage, optionally enriches with registry metadata (offline-safe). Read-only. Trigger: /deps-audit"
trigger: /deps-audit
---

# /deps-audit

Beantwortet für jede direkte Dependency die Erbschaftsfragen, die niemand stellt:
Wofür wird sie WIRKLICH verwendet, wie tief ist die Kopplung, wie austauschbar ist
sie, und was ist der konkrete Exit-Plan.

## What this is for

- Dependency-Entscheidungen ("können wir X rauswerfen/ersetzen?") dauern sonst Tage
  Recherche. Dieser Skill liefert ein lebendes Erbschafts-Register.
- **Reiner Lese-Skill.** Kein CVE-Scan (dafür `npm audit` & Co — nicht dupliziert).
  Keine transitiven Dependencies in der Tiefenanalyse, nur gezählt.

## What You Must Do When Invoked

Wenn `/deps-audit --help` oder `/deps-audit -h` (ohne weitere Argumente)
aufgerufen wird: gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel klären

Kläre `-ProjectDir` und optional einen Fokus auf einzelne Dependency-Namen.
Bestätigung einholen.

### Step 2 — Inventar

```powershell
& "<SKILL_DIR>/scripts/deps-inventory.ps1" -ProjectDir "<pfad>" [-Only <namen>]
```

Kein Manifest gefunden: sauber melden, stoppen.

### Step 3 — Registry-Metadaten (optional)

Netz verfügbar und User nicht dagegen:

```powershell
& "<SKILL_DIR>/scripts/registry-meta.ps1" -Names <dependency-namen> -Ecosystem npm
```

`metaError` bei einzelnen Paketen: ohne Wartungssignal für die betroffene
Dependency weiterarbeiten, im Report ausweisen — kein Abbruch. Hinweis: das
Feld `lastRelease` stammt aus dem `time.modified`-Feld der Registry, das nicht
zwingend exakt "letzte Veröffentlichung" bedeutet (Registry-Metadaten können auch
ohne neuen Release aktualisiert werden) — im Report als Näherungswert kennzeichnen.

### Step 4 — Analyse

Pro direkter Dependency:

1. **Zweck** (aus den Nutzungsstellen): wofür wird sie WIRKLICH verwendet — die
   ehrliche Antwort ist oft "für eine einzige Funktion". Konfidenz angeben.
2. **Kopplungstiefe**: `oberflächlich` (wenige Stellen, einfache Aufrufe) /
   `mittel` / `tief` (API-Typen in eigenen Signaturen, Vererbung, Konfig-Magie).
   Beleg: `usageCount` + charakteristische Fundstellen.
3. **Risiko**: Kombination aus Kopplungstiefe, Wartungssignal (falls
   Registry-Meta vorhanden), Lizenz-Auffälligkeit (nur Hinweis, keine
   Rechtsberatung), `unusedDeclared`.
4. Vor jeder `unusedDeclared`-Bestätigung: Config-Dateien (json/yaml/rc) prüfen —
   z. B. eslint-Plugins werden oft nur dort referenziert, nicht im Code. Erst dann
   als "wirklich unused" einstufen.
5. **Austauschbarkeit + Exit-Plan**: konkrete Alternative(n) benennen
   (Stdlib-Ersatz zuerst prüfen), Aufwandsschätzung (Stunden/Tage/Wochen), die
   ersten 3 konkreten Schritte des Exits.
6. > 50 Dependencies: Register-Tabelle für alle, Detail-Analyse nur Top 15 nach
   Risiko, Rest auf Anfrage.
7. Evidenz-Pflicht: Zweck/Kopplung immer mit Fundstellen; Wartungsaussagen nur mit
   Registry-Daten (sonst "keine Metadaten verfügbar" — nie raten).

### Step 5 — Report schreiben

Datei `deps-erbschaft-report.md` im aktuellen Arbeitsverzeichnis:

1. **Kurzfassung** — Bestand, Top-3-Risiken, Quick Wins (`unusedDeclared`).
2. **Register-Tabelle** — Name, Zweck, Kopplung, Risiko, Austauschbarkeit.
3. **Detail-Abschnitte** pro auffälliger Dependency.
4. **Offene Fragen**.

### Step 6 — Zusammenfassen

Pfad des Reports nennen, Quick Wins zuerst nennen.

## Usage

```
/deps-audit                    # interaktiv, alle direkten Dependencies
/deps-audit <dir>              # Projekt analysieren
/deps-audit <dir> <dep> [...]  # nur genannte Dependencies
/deps-audit --help
```
