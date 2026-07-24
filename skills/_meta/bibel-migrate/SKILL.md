---
name: bibel-migrate
description: "Auto-generate migration patches when BIBEL.md conventions change. Trigger: /bibel-migrate"
trigger: /bibel-migrate
---
# /bibel-migrate

When BIBEL rules evolve, this skill scans every script and produces per-file patch instructions.

## What this is for

- Adding `[CmdletBinding()]` to all scripts at once
- Standardizing `=== TITLE ===` format across the project
- Bulk convention enforcement
- **Read-only skill.** No code changes (generates patch instructions).

## Steps

1. `-ProjectDir` target
2. Run collector: scan all scripts for BIBEL rule violations
3. For each violation, generate a deterministic patch template
4. Write `bibel-migrate-report.md` with per-file migration plan

## Usage

```
/bibel-migrate            # interactive
/bibel-migrate <dir>      # scan project
/bibel-migrate -help
```
