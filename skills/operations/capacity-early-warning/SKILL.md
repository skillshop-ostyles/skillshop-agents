---
name: capacity-early-warning
description: "Capacity early warning: find hardcoded limits, pool sizes, timeouts, quotas, then LLM judges each as adequate/approaching/critical. Read-only. Trigger: /capacity"
trigger: /capacity
---
# /capacity

Production outages from exceeded capacity always seem sudden. This skill finds limits before they break.

## What this is for

- Connection pool of 10 for a service that grew 3x
- 30-second timeout that fires daily
- Hardcoded limits with no monitoring
- **Read-only skill.** No config changes.

## What You Must Do When Invoked

If `/capacity -help` or `/capacity -h` (without further arguments)
is invoked: output the `## Usage` section unchanged and stop.

Otherwise follow these steps in order, skipping none.

### Step 1 - Clarify target

Clarify `-ProjectDir`. Get confirmation.

### Step 2 - Scan

```powershell
& "<SKILL_DIR>/scripts/limit-harvest.ps1" -ProjectDir "<path>"
```

### Step 3 - Analysis

Read each limit:

- Given the service domain and typical workload, is the limit adequate?
- What happens if traffic grows 2x/5x/10x?
- Is there monitoring before the limit is hit?

### Step 4 - Write report

File `capacity-report.md` in current working directory:

1. **Summary** - total limits, adequate, approaching, critical.
2. **Limit table** - critical first. Per limit: value, unit, config mechanism, growth risk, recommendation.
3. **Open questions**.

### Step 5 - Summarize

State report path, highlight critical limits.

## Usage

```
/capacity               # interactive
/capacity <dir>         # scan project
/capacity -help
```
