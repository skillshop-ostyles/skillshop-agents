---
name: dockerfile-best-practices
description: "Dockerfile best-practices auditor: statically scans Dockerfiles for 18 common anti-patterns including unpinned base images, root execution, missing HEALTHCHECK, excessive layers, package cache bloat, and hardcoded secrets. Produces an evidence-backed report with severity and remediation. Read-only. Trigger: /dockerfile-audit"
trigger: /dockerfile-audit
---

## What this is for

Dockerfiles accumulate anti-patterns over time. Base images without pinned
versions, running as root, unnecessary layers, missing HEALTHCHECK, and package
caches bloating image size are common issues that lead to insecure, oversized,
and unpredictable container images.

This skill finds those patterns statically. It combines a deterministic
collector (18 best-practice checks) with LLM context analysis that validates
each finding and produces an actionable report.

**Audience:** Both
- Platform/DevOps engineers use it for PR gates on Dockerfile changes.
- Developers use it as a self-check before building images.

### Trigger: `/dockerfile-audit`

Intervention-free static analysis. The collector reads only.

## PROTECTION RULE - never `~/.claude/`

Read-only skill. No protection guard needed; the collector validates path
existence.

## What You Must Do When Invoked

### Step 1 - `-help`/`-h` check
If invoked with `-help` or `-h`, print the usage block below and stop.

### Step 2 - Confirm `-ProjectDir`
If not provided, prompt the user. Confirm the path exists. Print:
`Dockerfile audit on <path> ...`

### Step 3 - Run Collector
```powershell
& .\scripts\dockerfile-scan.ps1 -ProjectDir "<path>"
```

Parse the JSON output. If exit code != 0, report error and stop.

### Step 4 - Validate each finding
For each finding in the JSON:
1. Read the surrounding context (3 lines around the flagged line).
2. Determine **true positive**, **false positive**, or **uncertain**.
3. Assign confidence: `proven`, `likely`, `suspected`.
4. For `hardcoded-secret`: redact the value in your output (show `[REDACTED]`).

### Step 5 - Prioritize
Sort findings by severity (high first), group by check type.

### Step 6 - Produce report
Write `dockerfile-report.md` to the working directory:

```
# Dockerfile Best Practices Report - <project-name>

## 1. Summary
- <N> Dockerfiles scanned, <M> findings
- <H> high, <M> medium, <L> low

## 2. Critical (high severity)
| # | File | Line | Check | Detail | Remediation |
|---|---|---|---|---|---|
| 0 | Dockerfile | 1 | tag-pinning | FROM node without version | ... |

## 3. Warnings (medium severity)
Grouped by check type. Each entry: file, line, detail, remediation.

## 4. Informational (low severity)

## 5. Dockerfile Overview
Per file: base images used, total layers, finding count.

## 6. Remediation Guide
Quick-reference: one-liner fix for each check type.

## 7. False Positives Removed
Each dismissed finding with reason.

## 8. Open Questions
```

## Usage

```powershell
# Full scan
& .\scripts\dockerfile-scan.ps1 -ProjectDir "C:\Projects\my-app"

# Scan with custom exclusion
& .\scripts\dockerfile-scan.ps1 -ProjectDir "C:\Projects\my-app" -Exclude "node_modules,.git,dist,vendor,test"
```
