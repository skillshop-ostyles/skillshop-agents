# Architecture Visualizer - /arch-vis

**Cluster:** `understanding/` - **Audience:** Both (Senior + Vibe) - **Trigger:** `/arch-vis`

## Purpose

Automatically reverse-engineers a codebase's module dependency structure. Provides
Mermaid diagrams for visual review, layer boundary violation detection, circular
dependency analysis, and a quantified structural health score.

## Detection Approach

The collector parses import/require/include statements for multiple languages:

- **JavaScript/TypeScript:** ESM `import`, CommonJS `require()`, dynamic `import()`
- **Python:** `import X`, `from X import Y`
- **PowerShell:** dot-source `. .\file.ps1`, `using module`
- **Java:** `import package.Class`
- **C#:** `using Namespace`
- **Go:** `import "package"`
- **Ruby:** `require`, `require_relative`
- **PHP:** `require`, `include`, `require_once`, `include_once`

Relative imports are resolved against the file location; bare specifiers are
marked as external. Layer assignment is based on directory name patterns.
Cycles are detected via DFS with Tarjan-style deduplication.

## Validation

LLM reads the module graph, violation list, and cycle paths:
- Are violations genuine architecture breaches or legitimate cross-layer references?
- What is the remediation for each cycle (extract, invert, merge)?
- Generate Mermaid `graph TD` and `graph LR` diagrams for the report.

## Reporting

Output is `arch-vis-report.md` with executive summary, Mermaid diagrams,
layer analysis, and open questions.

## Files

```
scripts/arch-scan.ps1        # collector (module graph, layers, cycles)
SKILL.md                      # skill definition
README.md                     # this file
```
