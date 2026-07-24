# Data Fixture Auditor Skill

Sprint 83 · Data Cluster

Analyzes test seed data against schemas to surface coverage gaps.

## Files

| File | Purpose |
|------|---------|
| SKILL.md | Skill manifest (trigger: `/fixture-audit`) |
| scripts/fixture-scan.ps1 | Collector — scans, parses, analyzes fixtures |
| tests/fixtures/smoke/src/ | Smoke test fixture set (2 customers, 1 product, 1 order) |
| tests/fixtures/empty/ | Edge case: empty directory |

## Quick Start

```powershell
powershell -File skills/data/data-fixture-auditor/scripts/fixture-scan.ps1 `
    -ProjectDir skills/data/data-fixture-auditor/tests/fixtures/smoke/src
```

## Smoke Test

Expect:
- exit code 0
- `status` detected as constant field (`"active"` on both customers)
- `email`, `created_at` flagged as never populated (missing from fixture data)
- `ordered_at` missing on orders

```powershell
powershell -File scripts/fixture-scan.ps1 -ProjectDir tests/fixtures/smoke/src
$LASTEXITCODE -eq 0
```

## Output

- Console summary with coverage ratios per entity
- Full JSON to stdout (pipe to file for analysis)
- `fixture-quality-report.md` from LLM analysis phase
