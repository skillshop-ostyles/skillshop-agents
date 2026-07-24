---
name: startup-profile-analyzer
description: "Startup profile analyzer: trace the entire initialization chain, LLM judges each step as essential/lazy-loadable/suspicious. Read-only. Trigger: /startup"
trigger: /startup
---
# /startup

What happens when your service starts? This skill traces every init step and finds cold-start optimizations.

## What this is for

- Module-level imports that could be lazy-loaded
- Connection pools, cache warming, scheduler registration at boot
- Heavy dependencies loaded at startup but used only in one handler
- **Read-only skill.** No code modification.

## What You Must Do When Invoked

If `/startup -help` or `/startup -h` (without further arguments)
is invoked: output the `## Usage` section unchanged and stop.

Otherwise follow these steps in order, skipping none.

### Step 1 - Clarify target

Clarify `-ProjectDir`. Get confirmation.

### Step 2 - Scan

```powershell
& "<SKILL_DIR>/scripts/startup-trace.ps1" -ProjectDir "<path>"
```

### Step 3 - Analysis

Read each init step in context:

- Is this essential at startup or could it be lazy-loaded?
- What would break if deferred?
- Is this a side effect at import time (suspicious)?

### Step 4 - Write report

File `startup-report.md` in current working directory:

1. **Summary** - total init steps, deferrable count, estimated boot time reduction.
2. **Init chain** - sorted by phase. Per step: phase, description, classification, deferral recommendation.
3. **Suspicious findings** (side effects at import time).
4. **Open questions**.

### Step 5 - Summarize

State report path, highlight top 3 deferral candidates.

## Usage

```
/startup               # interactive
/startup <dir>         # scan project
/startup -help
```
