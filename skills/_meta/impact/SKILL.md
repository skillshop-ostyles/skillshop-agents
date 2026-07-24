---
name: impact
description: "Given a BIBEL.md diff, list every skill that would need updating. Trigger: /impact"
trigger: /impact
---
# /impact

When BIBEL.md conventions change, this skill traces each rule to its implementation in every skill's SKILL.md and scripts.

## What this is for

- BIBEL rule additions requiring all skill updates
- Convention changes that break existing collectors
- Migration planning before a BIBEL change
- **Read-only skill.** No code changes.

## Steps

1. `-ProjectDir` + `-Bibeldiff <path to new BIBEL.md>` target
2. Run collector: diff old vs new BIBEL, map rules to skill files
3. Report affected skills per changed rule
4. Write `impact-report.md`

## Usage

```
/impact                  # interactive
/impact <dir> -Bibeldiff <path>
/impact -help
```
