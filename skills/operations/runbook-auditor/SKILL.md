---
name: runbook-auditor
description: "Runbook auditor: read runbook files, extract verifiable claims, check each against current codebase. LLM judges correctness and completeness. Read-only. Trigger: /runbook-audit"
trigger: /runbook-audit
---
# /runbook-audit

Runbooks are the first casualty of shipping. This skill audits them for correctness.

## What this is for

- Commands that reference nonexistent services or wrong names
- Dashboards that redirect or no longer exist
- Recovery procedures missing critical steps
- **Read-only skill.** No runbook modification.

## What You Must Do When Invoked

If `/runbook-audit -help` or `/runbook-audit -h` (without further arguments)
is invoked: output the `## Usage` section unchanged and stop.

Otherwise follow these steps in order, skipping none.

### Step 1 - Clarify target

Clarify `-ProjectDir`. Get confirmation.

### Step 2 - Scan

```powershell
& "<SKILL_DIR>/scripts/runbook-read.ps1" -ProjectDir "<path>"
```

### Step 3 - Analysis

Read each runbook claim:

- Do referenced commands match current docker-compose/CI/infra config?
- Do dashboard URLs exist in the codebase?
- Are recovery procedures complete and in order?
- Are contacts and escalation paths valid?

### Step 4 - Write report

File `runbook-quality-report.md` in current working directory:

1. **Summary** - freshness score, total claims, valid, stale, invalid.
2. **Per-runbook analysis** - file, score, findings.
3. **Recommendations** - specific fixes for stale/invalid claims.
4. **Open questions**.

### Step 5 - Summarize

State report path, highlight most out-of-date runbook.

## Usage

```
/runbook-audit               # interactive
/runbook-audit <dir>         # scan project
/runbook-audit -help
```
