---
name: manifest-audit
description: "Verify project tracking docs, README.md, and actual filesystem are in sync. Trigger: /manifest-audit"
trigger: /manifest-audit
---
# /manifest-audit

The manifest (tracking.md) and README.md are manually maintained. This skill detects drift between declared and actual skills.

## What this is for

- Skills on disk not in tracking.md or README
- Skills in tracking.md missing from disk
- Sprint count or skill count mismatches
- **Read-only skill.** No code changes.

## Steps

1. `-ProjectDir` target
2. Run collector: compare filesystem skills vs tracking vs README
3. Report additions, deletions, count mismatches
4. Write `manifest-audit-report.md`

## Usage

```
/manifest-audit           # interactive
/manifest-audit <dir>     # scan project
/manifest-audit -help
```
