# Code Smell Detection — /code-smell

**Cluster:** `quality/` · **Audience:** Beide (Senior + Vibe) · **Trigger:** `/code-smell`

## Purpose

Systematically detects 10 families of structural code smells. Each finding includes
a metric value, code context, and LLM-validated confidence rating. This turns vague
intuition ("this code feels wrong") into an evidence-based action plan.

## Detection Approach

The collector uses static heuristics per smell family:

- **Long method:** counts executable lines (ignoring blanks/comments)
- **Deep nesting:** tracks brace/indent depth
- **God class:** class size × method count × field cohesion heuristic
- **Feature envy:** symbol reference ratio (external vs own)
- **Primitive obsession:** repeated primitive type parameter patterns
- **Data clump:** parameter set fingerprinting across methods
- **Shotgun surgery:** grep-based concept-scatter detection
- **Message chain:** dot-chain depth on member access
- **Refused bequest:** subclass-override-ratio < 0.2
- **Speculative generality:** abstract class/interface usage tracking

## Validation

LLM reads each finding with surrounding code context and answers:
- Is this a genuine smell or necessary complexity?
- What is the confidence level (high/medium/low)?
- What refactoring approach is appropriate?

## Reporting

Output is `code-smell-report.md` with executive summary, findings grouped by
smell family, and a false-positive section.

## Files

```
scripts/smell-scan.ps1        # collector (10 smell families)
tests/fixture/                # test fixtures
SKILL.md                      # skill definition
README.md                     # this file
```
