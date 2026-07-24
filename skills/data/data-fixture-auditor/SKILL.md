---
name: data-fixture-auditor
trigger: /fixture-audit
sprint: 83
cluster: data
---

# Data Fixture Auditor

Test fixtures silently rot: happy-path only, stale shapes, zero error-scenario
coverage. This skill scans fixture files, parses entities, measures field coverage,
and generates a quality report.

## Usage

```
/fixture-audit <project-directory>
```

Loade das Skill, dann:

```
/fixture-audit C:\Users\ostol\Desktop\AGENTS\skills\data\data-fixture-auditor\tests\fixtures\smoke\src
```

## Pipeline

1. **Collect** — `fixture-scan.ps1` scannt nach Fixture-Dateien (JSON, YAML, SQL INSERT,
   Factory-Definitions) anhand Namenskonvention (`*fixture*`, `*seed*`, `*test-data*`).
2. **Parse** — Extrahiert Entities und Feldwerte aus jeder Datei.
3. **Measure** — Pro Entity: Cardinality, Konstante-Felder, Null-Ratio, Coverage.
4. **Validate** — Vergleich gegen Companion-Schema (DDL oder JSON Schema).
5. **Report** — `fixture-quality-report.md` mit LLM-bewerteter Coverage-Analyse.

## Quality Dimensions

| Dimension | Bedeutung |
|-----------|-----------|
| Field coverage | Welche Columns sind populated vs. immer null vs. fehlen |
| Cardinality | Verschiedene Werte pro Feld (niedrig = Testlücke) |
| Constant fields | Gleicher Wert in jedem Record |
| Schema drift | Felder im Schema aber nie in Fixtures |
