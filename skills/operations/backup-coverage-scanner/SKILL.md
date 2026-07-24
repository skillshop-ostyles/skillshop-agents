---
name: backup-coverage-scanner
description: "Backup coverage scanner: inventory every stateful resource, trace backup configuration for each, then LLM identifies critical gaps. Read-only. Trigger: /backup-scan"
trigger: /backup-scan
---
# /backup-scan

Every database, volume, and config file needs backup. This skill traces coverage and finds gaps before the incident.

## What this is for

- DB connections, persistent volumes, stateful sets without backup config
- Docker volumes, S3 buckets, DynamoDB tables missing snapshot policies
- **Read-only skill.** No backup creation, no infrastructure changes.

## What You Must Do When Invoked

If `/backup-scan -help` or `/backup-scan -h` (without further arguments)
is invoked: output the `## Usage` section unchanged and stop.

Otherwise follow these steps in order, skipping none.

### Step 1 - Clarify target

Clarify `-ProjectDir`. Get confirmation.

### Step 2 - Scan

```powershell
& "<SKILL_DIR>/scripts/backup-scan.ps1" -ProjectDir "<path>"
```

### Step 3 - Analysis

Read each resource without backup coverage:

- Is this resource stateful enough to need backup? (Ephemeral cache? Probably not. User-uploaded file storage? Critical.)
- What would be the impact of data loss?
- Is there implicit coverage (replication, snapshot inherited from infra)?

### Step 4 - Write report

File `backup-coverage-report.md` in current working directory:

1. **Summary** - total resources, covered, uncovered, critical uncovered.
2. **Uncovered resources** - sorted critical first. Per resource: type, criticality, impact of data loss, recommended backup strategy.
3. **Covered resources** in appendix for completeness.
4. **Open questions**.

### Step 5 - Summarize

State report path, highlight critical gaps.

## Usage

```
/backup-scan               # interactive
/backup-scan <dir>         # scan project
/backup-scan -help
```
