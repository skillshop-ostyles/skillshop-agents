---
name: process-lifetime-tracker
description: "Process lifetime tracker: map every process/service/daemon, trace shutdown paths, LLM judges graceful shutdown readiness. Read-only. Trigger: /lifetime"
trigger: /lifetime
---
# /lifetime

Every long-running process needs graceful shutdown. This skill maps shutdown readiness.

## What this is for

- HTTP servers without graceful shutdown (connections dropped on SIGTERM)
- Workers/queues that don't drain jobs before exit
- Cron jobs with no rollback on interrupt
- **Read-only skill.** No configuration changes.

## What You Must Do When Invoked

If `/lifetime -help` or `/lifetime -h` (without further arguments)
is invoked: output the `## Usage` section unchanged and stop.

Otherwise follow these steps in order, skipping none.

### Step 1 - Clarify target

Clarify `-ProjectDir`. Get confirmation.

### Step 2 - Scan

```powershell
& "<SKILL_DIR>/scripts/lifetime-scan.ps1" -ProjectDir "<path>"
```

### Step 3 - Classification

Read each process:

- **Graceful**: clean shutdown with drain, grace period, resource cleanup
- **Rough**: catches signal but no drain or grace period
- **Abrupt**: no signal handler, kills immediately
- **Dangerous**: mid-transaction data loss risk (no rollback on interrupt)

### Step 4 - Write report

File `lifetime-report.md` in current working directory:

1. **Summary** - processes by classification.
2. **Process table** - most dangerous first. Per process: name, type, entry file, shutdown handler, grace period, recommendation.
3. **Open questions**.

### Step 5 - Summarize

State report path, highlight processes that would lose data if terminated now.

## Usage

```
/lifetime               # interactive
/lifetime <dir>         # scan project
/lifetime -help
```
