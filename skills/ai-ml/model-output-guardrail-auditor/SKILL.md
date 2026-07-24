---
name: model-output-guardrail-auditor
description: "Model output guardrail auditor: find unvalidated LLM outputs that cause crashes, data corruption, or bad decisions. Read-only. Trigger: /guardrails"
trigger: /guardrails
---
# /guardrails

Every unvalidated LLM output is a bug waiting to happen. This skill finds output consumption without guardrails.

## What this is for

- Model output used in JSON.parse without try/catch (crash on malformed output)
- Model output written to DB without schema validation (data corruption)
- Model output used for decisions without bounds checking (wrong action)
- **Read-only skill.** No code changes.

## What You Must Do When Invoked

If `/guardrails -help` or `/guardrails -h` (without further arguments)
is invoked: output the `## Usage` section unchanged and stop.

Otherwise follow these steps in order, skipping none.

### Step 1 - Clarify target

Clarify `-ProjectDir`. Get confirmation.

### Step 2 - Scan

```powershell
& "<SKILL_DIR>/scripts/guardrail-scan.ps1" -ProjectDir "<path>"
```

### Step 3 - Classification

Read each output consumption:

- **Safe**: validated or display-only with bounds
- **Risky**: db-write without schema validation
- **Dangerous**: decision without guardrails

### Step 4 - Write report

File `guardrail-report.md` in current working directory:

1. **Summary** - consumptions by risk level.
2. **Consumption table** - dangerous first. Per consumption: file, line, output source, usage type, has validation, risk, recommendation.
3. **Open questions**.

### Step 5 - Summarize

State report path, highlight outputs that could cause production incidents.

## Usage

```
/guardrails               # interactive
/guardrails <dir>         # scan project
/guardrails -help
```