---
name: error-handling-overview
description: "Strategic overview of how a project handles errors: catch-type taxonomy (log/rethrow/swallow/recover/fallback), global handlers, error class hierarchy, clustered weaknesses. Read-only. Audience: Both. Trigger: /errors-overview"
trigger: /errors-overview
---

## What this is for

Per-file error analysis misses the gestalt. This skill builds a complete
taxonomy: every try/catch, .catch(), except:, global error middleware,
process.on('uncaughtException'), @ControllerAdvice, and custom error class.
The LLM clusters weaknesses by module and strategy — which errors are
swallowed, which global handlers eat everything, which retry patterns exist.

`error-handling-auditor` (quality/) finds anti-patterns per file.
This skill gives you the strategic map across the entire project.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/errors-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each module cluster:
   - **Strategy**: what is the module's error-handling pattern (log-all,
     rethrow-wrapped, swallow-trivial, recover-via-retry)?
   - **Swallowed errors**: empty catch blocks or catches with only a comment.
     Are they intentionally ignored or forgotten?
   - **Global handlers**: do they log+rethrow, log+respond, or log+swallow?
     A handler that catches everything and returns 200 is eating evidence.
   - **Weakness cluster**: 3+ related weaknesses in one module or cross-module
     pattern (e.g. "all services swallow DB errors").
5. Write `error-strategy-report.md` to the working directory.

## Usage

```
/errors-overview                          # interactive
/errors-overview <dir>                    # scan project
/errors-overview -help                    # show usage
```

Returns JSON with `handlers[]`, `globalHandlers[]`, `errorHierarchy[]`,
`counts{}` plus per-catch-type breakdown.
