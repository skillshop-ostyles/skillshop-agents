---
name: code-smell-erkennung
description: "Code smell detector: statically identifies 10 families of structural code quality issues (long methods, deep nesting, god classes, feature envy, primitive obsession, data clumps, shotgun surgery, message chains, refused bequest, speculative generality). Evidence-based report with metrics and LLM validation. Read-only. Audience: Both. Trigger: /code-smell"
trigger: /code-smell
---

# /code-smell — Code Smell Detector

Detects 10 code smell families in a target directory. Produces a structured report
with metrics, evidence, and LLM-based validation of each finding.

## Usage

```
/code-smell              # interactive (prompts for directory)
/code-smell <dir>        # scan directory directly
/code-smell --help       # show usage
```

## Steps

1. `--help` / `-h` → print usage, exit 0.
2. Confirm target directory exists.
3. Run `scripts/smell-scan.ps1 -ProjectDir <dir>`.
4. LLM reads the JSON output, validates each finding against the code context,
   assigns confidence, and suggests a refactoring path.
5. Write `code-smell-report.md` to the working directory.

## Supported Smell Families

| # | Smell | Severity | Metric |
|---|-------|----------|--------|
| 1 | Long method | medium | >30 executable lines |
| 2 | Deep nesting | medium | >4 indentation levels |
| 3 | God class | high | >300 lines, >10 methods, low cohesion |
| 4 | Feature envy | medium | more external than internal symbol references |
| 5 | Primitive obsession | low | repeated primitive type parameters |
| 6 | Data clump | medium | same 3+ parameters repeated across methods |
| 7 | Shotgun surgery | high | single concept scattered across many files |
| 8 | Message chain | low | a.b.c.d().e() style chains |
| 9 | Refused bequest | medium | subclass ignores inherited members |
| 10 | Speculative generality | low | unused abstract classes/interfaces |

## Output

`code-smell-report.md` with:
- Executive summary (total findings, severity breakdown)
- Detailed findings per smell family (id, file, line, metric, confidence, suggestion)
- False positives section (rejected by LLM analysis)
