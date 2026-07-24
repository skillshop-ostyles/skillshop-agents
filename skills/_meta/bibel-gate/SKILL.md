---
name: bibel-gate
description: "Pre-commit gate: BIBEL compliance check + smoke test + JSON contract per changed skill. Exit 1 on failure. Trigger: /bibel-gate"
trigger: /bibel-gate
---
# /bibel-gate

Validates every changed skill against BIBEL.md conventions before commit. Runs smoke test and verifies JSON output contract.

## What this is for

- BIBEL rule violations in new/changed skills
- Missing `[CmdletBinding()]`, `$ErrorActionPreference = 'Stop'`, `=== TITLE ===` summary
- Smoke test failures or missing JSON contract
- **Read-only skill.** No code changes.

## Steps

1. `-ProjectDir` target
2. Run collector: identifies changed skills vs BIBEL rules
3. Classify: pass / violation / smoke-fail
4. Write `bibel-gate-report.md`

## Usage

```
/bibel-gate              # interactive
/bibel-gate <dir>        # scan project
/bibel-gate -help
```
