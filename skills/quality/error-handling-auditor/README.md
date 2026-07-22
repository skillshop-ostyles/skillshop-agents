# Error Handling Auditor - /error-audit

**Cluster:** `quality/` - **Audience:** Both (Senior + Vibe) - **Trigger:** `/error-audit`

## Purpose

Systematically finds error-handling gaps across 8 anti-pattern categories. Each
finding includes severity, evidence snippet, and a concrete remediation suggestion.
This turns implicit "we handle errors" assumptions into a quantified gap map.

## Detection Approach

The collector uses regex-based pattern matching and scope analysis:

- **Swallowed exception:** matches empty catch/except/rescue blocks (body is
  whitespace/comment only)
- **Generic catch:** matches catch of base Exception/Error types or bare catch
- **Missing error handling:** error-prone operations (I/O, network, parsing)
  not within a try/catch scope
- **Missing finally:** resource acquisition without a finally/ensure block
- **Error handling inconsistency:** same operation wrapped in try in some
  call sites but not others (cross-file analysis)
- **Logging without context:** catch blocks with static log messages (no
  variable interpolation, no parameters)
- **Ignored return code:** function calls whose return value is not checked
- **Exception type abuse:** throwing base Exception/Error or throwing strings

## Validation

LLM reads each finding with surrounding code context and answers:
- Is this a genuine gap or intentional design?
- What is the confidence level (proven/likely/suspected)?
- What is the appropriate remediation (with code snippet)?

## Reporting

Output is `error-audit-report.md` with executive summary, findings by severity
tier, false-positive section, and open questions.

## Files

```
scripts/error-scan.ps1        # collector (8 anti-patterns)
SKILL.md                      # skill definition
README.md                     # this file
```
