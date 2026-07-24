---
name: trigger-audit
description: "Check trigger uniqueness, naming convention, and README documentation. Trigger: /trigger-audit"
trigger: /trigger-audit
---
# /trigger-audit

Every skill has a `/trigger`. This skill checks they're unique, follow convention (kebab-case), and are listed in README.

## What this is for

- Duplicate triggers across skills
- Triggers that don't match kebab-case convention
- Triggers missing from README.md
- **Read-only skill.** No code changes.

## Steps

1. `-ProjectDir` target
2. Run collector: extract triggers from SKILL.md, compare to README table
3. Report duplicates, convention violations, omissions
4. Write `trigger-audit-report.md`

## Usage

```
/trigger-audit            # interactive
/trigger-audit <dir>      # scan project
/trigger-audit -help
```
