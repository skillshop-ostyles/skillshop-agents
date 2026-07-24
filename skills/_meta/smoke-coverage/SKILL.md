---
name: smoke-coverage
description: "Audit smoke test coverage across all skills. Report which have tests, which don't, and which test scripts actually run. Trigger: /smoke-coverage"
trigger: /smoke-coverage
---
# /smoke-coverage

Every skill should have a smoke test. This skill audits coverage and execution status.

## What this is for

- Skills without any fixture or smoke test
- Scripts that reference files missing from fixture
- Smoke test gaps per cluster
- **Read-only skill.** No code changes.

## Steps

1. `-ProjectDir` target
2. Run collector: per skill check fixture dir, script existence, referenced files
3. Report gaps by cluster
4. Write `smoke-coverage-report.md`

## Usage

```
/smoke-coverage           # interactive
/smoke-coverage <dir>     # scan project
/smoke-coverage -help
```
