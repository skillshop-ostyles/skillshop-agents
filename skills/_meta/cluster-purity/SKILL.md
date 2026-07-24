---
name: cluster-purity
description: "Detect skills that may belong to a different cluster based on description, trigger, and script patterns. Trigger: /cluster-purity"
trigger: /cluster-purity
---
# /cluster-purity

Skills can drift into the wrong cluster. This skill analyzes each skill's description and script patterns against cluster definitions.

## What this is for

- Security-pattern skills in the quality cluster
- Data-access skills in the operations cluster
- Cluster boundary violations
- **Read-only skill.** No code changes.

## Steps

1. `-ProjectDir` target
2. Run collector: per skill, extract keywords and compare to expected cluster keywords
3. Report boundary candidates
4. Write `cluster-purity-report.md`

## Usage

```
/cluster-purity           # interactive
/cluster-purity <dir>     # scan project
/cluster-purity -help
```
