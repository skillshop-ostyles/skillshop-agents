---
name: skill-lifecycle
description: "Report on skill age, last modified, git activity, and deprecation status across all clusters. Trigger: /skill-lifecycle"
trigger: /skill-lifecycle
---
# /skill-lifecycle

Tracks the health and freshness of every skill in the project.

## What this is for

- Skills with no git activity in months (stale)
- Skills that have never been smoke-tested
- Skills that reference deprecated patterns
- **Read-only skill.** No code changes.

## Steps

1. `-ProjectDir` target
2. Run collector: git log per skill directory + file stats
3. Report stalest skills by cluster
4. Write `skill-lifecycle-report.md`

## Usage

```
/skill-lifecycle           # interactive
/skill-lifecycle <dir>     # scan project
/skill-lifecycle -help
```
