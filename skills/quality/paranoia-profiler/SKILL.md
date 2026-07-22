---
name: paranoia-profiler
description: "Paranoia profiler: catalogs every defensive guard (null/undefined/empty/try-catch/typeof/instanceof) with its context. LLM judges each guard for impossibility (paranoid zone), under-defense on external input (naive zone), or calibrated (good fit). Read-only. Audience: Senior. Trigger: /paranoia"
trigger: /paranoia
---

## What this is for

Codebases are simultaneously over- and under-defensive: forty null checks on
values that cannot be null, zero checks on the user input that can. This
skill catalogs every defensive guard with its context and the LLM judges
each one - is this paranoia (paranoid about an impossible case) or under-defense
(naive about an external input)?

SAST partially covers the under-defensive side via taint tracing. Nothing
covers the over-defensive side at all - those are buried as noise that
dilutes the genuine checks.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/guard-census.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each guard:
   - Can the guarded condition actually occur given the code path?
   - If no: this is paranoid. Flag for removal.
   - If yes: this is calibrated. Leave it alone.
5. For each unguarded external-input surface (req/argv/stdin/body/params):
   - Should it be checked? Does it flow into a dangerous sink?
6. Produce an imbalance map: paranoid zones / naive zones / calibrated zones.
7. Write `paranoia-report.md` to the working directory.

## Usage

```
/paranoia                         # interactive
/paranoia <dir>                   # scan project directory
/paranoia -help                   # show usage
```

Returns JSON with `guards[]` (kind, subject, context, file, line) plus
summary counts.
