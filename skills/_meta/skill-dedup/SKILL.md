---
name: skill-dedup
description: "Find functional overlap between skills via description similarity and script pattern matching. Trigger: /skill-dedup"
trigger: /skill-dedup
---
# /skill-dedup

Detects skills that do similar things: same trigger domain, overlapping description keywords, identical script patterns.

## What this is for

- Skills with overlapping purpose across clusters
- Skills that could be merged or deprecated
- Semantic duplication despite different trigger names
- **Read-only skill.** No code changes.

## Steps

1. `-ProjectDir` target
2. Run collector: pairwise description Jaccard + script pattern overlap
3. Report candidate pairs with overlap score
4. Write `skill-dedup-report.md`

## Usage

```
/skill-dedup             # interactive
/skill-dedup <dir>       # scan project
/skill-dedup -help
```
