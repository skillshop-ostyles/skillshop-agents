---
name: magic-value-genealogist
description: "Magic value genealogist: extracts numeric and uppercase-string literals from non-test source files, filters trivials (0/1/24/60/...), groups by literal value, traces each first occurrence to its introducing commit and author via git blame, clusters semantically duplicated constants that should be unified. Read-only. Audience: Both. Trigger: /magic-values"
trigger: /magic-values
---

## What this is for

Why 86400? Is it seconds per day, milliseconds cache TTL, video frame rate:
or five different independent choices that should be unified into a named
constant? This skill extracts every numeric and uppercase-string literal outside
tests and CONFIG-names them: occurrence count, full context lines, and the
commit where the magic value first appeared.

Linters flag "magic number" style violations with mechanical noise. This skill
goes further: it surfaces the same literal appearing in unrelated places with
different meanings - the kind of bug that comes from one person remembering the
value differently from another.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/magic-harvest.ps1 -ProjectDir "<path>" [-MinOccurrence 3]`
4. LLM reads the JSON output. For each recurring literal:
   - Read the `context` lines for each occurrence.
   - Is the meaning the SAME across occurrences? If yes, this is a candidate
     for unification into a named constant.
   - Is the meaning DIFFERENT? If yes, the same literal with different intents
     is an active footgun (changing one ripples unexpectedly).
   - For the introducing commit: read the commit subject. Does it explain why
     the value was chosen? If not, the value is unexplained.
5. Classify: `unify` (same meaning, should be one constant) / `rethink` (different
   meanings, danger) / `unexplained` (no git history clue) / `documented` (intentional).
6. Write `magic-values-report.md` to the working directory.

## Usage

```
/magic-values                         # interactive, prompts for directory
/magic-values <dir>                   # scan project directory
/magic-values <dir> -MinOccurrence 3 # raise the bar
/magic-values -help                   # show usage
```

Returns JSON with `values[]`:
`{valueType, value, occurrences[], introducedBy, introducingCommit,
introducingSubject}` plus summary counts.
