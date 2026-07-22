# Sprint 32 — code-smell-erkennung (/code-smell → quality/)

Regeln: `ops/BIBEL.md` gilt vollständig (Sprint 30+, englische Artefakte).
Physisch in `skills/quality/`. Zielgruppe: Beide.

## 1. Problem

Code smells are subtle structural signals that something is wrong — not bugs, but
design debt that will become bugs. Long methods, deep nesting, god classes, feature
envy, primitive obsession, data clumps, shotgun surgery, and message chains are
hard to spot across a large codebase. Linters catch formatting, not structure.

Vorher: "This code feels wrong" — ein Bauchgefühl ohne systematische Evidenz.
Nachher: Eine quantitative Smell-Landkarte mit Datei:Zeile, Metrik, und Kontext.

## 2. Nutzen

- Systematische Identifikation von 10 Code-Smell-Familien
- Jeder Fund enthält Metrik-Wert (z.B. Nesting-Tiefe, Method-Länge) + Code-Kontext
- LLM validiert: ist das ein echter Smell oder notwendige Komplexität?
- Für Vibe-Coder: Erklärung, warum das ein Problem ist und wie man es fixen kann

## 3. Scope / Nicht-Scope

**Scope:** 10 Smell-Familien:
1. **Long method** (>30 lines executable code)
2. **Deep nesting** (>4 levels of indentation)
3. **God class** (>300 lines, >10 methods, low cohesion)
4. **Feature envy** (method that uses more symbols from other classes than its own)
5. **Primitive obsession** (using primitive types instead of small objects)
6. **Data clump** (same 3+ parameters appearing together in multiple methods)
7. **Shotgun surgery** (single concept scattered across many files)
8. **Message chain** (a.b.c.d.e() style long chains)
9. **Refused bequest** (subclass that doesn't use inherited members)
10. **Speculative generality** (unused abstract classes, unused interface implementations)

**Nicht-Scope:** KEIN Refactoring (nur Detektion). KEIN Datenfluss-Graph.

## 4. Skill-Spezifikation

Ordner: `skills/quality/code-smell-erkennung/`

Frontmatter:

```yaml
---
name: code-smell-erkennung
description: "Code smell detector: statically identifies 10 families of structural code quality issues (long methods, deep nesting, god classes, feature envy, primitive obsession, data clumps, shotgun surgery, message chains, refused bequest, speculative generality). Evidence-based report with metrics and LLM validation. Read-only. Audience: Both. Trigger: /code-smell"
trigger: /code-smell
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stop.
2. Confirm: `-ProjectDir`.
3. Run `scripts/smell-scan.ps1`.
4. LLM analysis per § 6.
5. Report `code-smell-report.md` into working directory.

Usage:

```
/code-smell            # interactive
/code-smell <dir>      # scan directory
/code-smell --help
```

## 5. Collector Scripts

### scripts/smell-scan.ps1

Parameters: `-ProjectDir` (mandatory), `-Extensions`/`-Exclude` (Sprint 03 defaults).

Read-only. Scans source files for 10 smell families. Produces JSON.

JSON output schema:

```json
{
  "findings": [
    {
      "id": 1,
      "smell": "long-method",
      "severity": "medium",
      "file": "src/processor.ts",
      "line": 1,
      "metric": { "lines": 47, "threshold": 30 },
      "evidence": "function processOrder(order, config, ...",
      "context": "..."
    }
  ],
  "counts": {
    "total": 15,
    "bySeverity": { "high": 3, "medium": 8, "low": 4 },
    "bySmell": { "long-method": 5, "deep-nesting": 3, "god-class": 1, "primitive-obsession": 3, "message-chain": 3 }
  }
}
```

Error behavior: missing path → exit 1. No findings → exit 0.

## 6. LLM Analysis Steps

1. Parse findings from JSON. For each, read the context.
2. Validate: is this a genuine smell or intentional/necessary complexity?
   - Long method in a hot path may be justified (but still flag)
   - Deep nesting in a parser is expected
3. Assign confidence and suggested refactoring approach.
4. Report: executive summary → detailed findings by smell family → false positives.

## 7. Test Plan

Smoke: Fixture with:
- 1 long method (>30 lines)
- 1 deep nesting (>4 levels)
- 1 god class (large class)
- 1 message chain (a.b.c.d)
- 1 clean file (no smells)

```powershell
& .\skills\quality\code-smell-erkennung\scripts\smell-scan.ps1 -ProjectDir ".\skills\quality\code-smell-erkennung\tests\fixture"
```

Akzeptanz (dreamzzz-api): Complete run. Plausible findings ≥10.

Negativ: invalid path → exit 1.

## 8. DoD Checklist

- [ ] SKILL.md complete
- [ ] smell-scan.ps1 (10 smell families)
- [ ] Fixture created
- [ ] Smoke passed
- [ ] Acceptance run documented
- [ ] Negative test passed
- [ ] tracking.md updated, commit `sprint-32: code-smell-erkennung implementiert`
