---
name: convention-extractor
description: "Extracts implicit coding conventions from code patterns: naming style, import style, async patterns, error handling, null handling. Quantifies each convention by consistency score and surfaces deviations. Read-only. Audience: Both. Trigger: /conventions"
trigger: /conventions
---

## What this is for

Every team has implicit conventions nobody wrote down: "we use async/await, not .then()", "controllers are named *Controller", "we import lodash as _". These rules exist in hundreds of files but never as documentation. This skill extracts them, quantifies consistency, and surfaces intentional deviations vs. convention breaks.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/convention-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. Per convention:
   - What is the dominant pattern? Describe it in one sentence.
   - How consistent is it? 90%+ = established, 50-90% = emerging trend, <50% = noise.
   - Deviations: are they intentional (legacy code, different module purpose) or accidental?
   - Recommendations: should the convention be documented, automated (ESLint rule), or discarded?
5. Write `code-conventions.md` to the working directory.

## Usage

```
/conventions                            # interactive
/conventions <dir>                      # scan project
/conventions -help                      # show usage
```

Returns JSON with `conventions[]` each having `{pattern, score, examples[], counterExamples[]}`.
