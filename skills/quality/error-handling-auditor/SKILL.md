---
name: error-handling-auditor
description: "Error handling auditor: detects 8 anti-patterns (swallowed exceptions, generic catches, missing error handling, missing finally, error handling inconsistency, logging without context, ignored return codes, exception type abuse). Risk-tiered report with remediation suggestions. Read-only. Audience: Both. Trigger: /error-audit"
trigger: /error-audit
---
# /error-audit - Error Handling Auditor

## What this is for

Error handling grows scattered and inconsistent: swallowed exceptions, generic
catches, missing cleanup. This skill systematically scans code for 8
anti-patterns, validates each finding against context, and produces a
risk-tiered remediation report.

Detects 8 error-handling anti-patterns in a target directory. Produces a structured
report with severity tiers, evidence, and LLM-validated remediation suggestions.

## Usage

```
/error-audit              # interactive (prompts for directory)
/error-audit <dir>        # scan directory directly
/error-audit -help        # show usage
```

## What You Must Do When Invoked

1. `-help` / `-h` -> print usage, exit 0.
2. Confirm target directory exists.
3. Run `scripts/error-scan.ps1 -ProjectDir <dir>`.
4. LLM reads the JSON output, validates each finding:
   - Is this a genuine anti-pattern or intentional design?
   - Assign confidence (`proven`/`likely`/`suspected`).
   - Determine risk tier (critical/medium/low/informational).
   - Generate a concrete remediation code snippet.
5. Cross-reference inconsistency findings (pattern 5) by reading both call sites.
6. Filter false positives (framework handlers, test assertions, fire-and-forget).
7. Write `error-audit-report.md` to the working directory.

## Anti-Patterns

| # | Pattern | Severity | Description |
|---|---------|----------|-------------|
| 1 | Swallowed exception | high | Empty catch block, error disappears silently |
| 2 | Generic catch | high | Catching base Exception/Error masks unexpected errors |
| 3 | Missing error handling | medium | Error-prone operation not wrapped in try/catch |
| 4 | Missing finally | medium | Resources opened without cleanup block |
| 5 | Error handling inconsistency | medium | Same operation handled differently across call sites |
| 6 | Logging without context | low | Catch block logs without dynamic state |
| 7 | Ignored return code | medium | Function return value not checked for errors |
| 8 | Exception type abuse | low | Throwing generic Exception/Error or throwing strings |

## Output

`error-audit-report.md` with:
- Executive summary (total findings, severity breakdown, by pattern)
- Critical findings (high severity, with remediation code snippet)
- Medium findings (grouped by anti-pattern type)
- Low findings (information only, with justification)
- False positives (dismissed with reason)
- Open questions (suspected confidence findings)
