---
name: benchmark
description: "Run each collector script against its fixture, measure time and output size, detect regressions. Trigger: /benchmark"
trigger: /benchmark
---
# /benchmark

Performance and correctness regression detection for collector scripts.

## What this is for

- Scripts that error on their own fixture
- Output size anomalies (empty or bloated JSON)
- Execution time regressions
- **Read-only skill.** No code changes.

## Steps

1. `-ProjectDir` target
2. Run collector: execute each script against its fixture, capture time + output + exit code
3. Report failures, anomalies, slow scripts
4. Write `benchmark-report.md`

## Usage

```
/benchmark                # interactive
/benchmark <dir>          # scan project
/benchmark -help
```
