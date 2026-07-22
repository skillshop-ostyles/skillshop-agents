---
name: api-footgun-reviewer
description: "API footgun reviewer: harvests exported function/method signatures, flags boolean-trap positions (multiple bare bool params in a row), same-type-adjacent swaps (from/to, save/loadUntil), and inconsistent family conventions (create*/update* with different param orders or arities). Read-only. Audience: Senior > Vibe. Trigger: /footguns"
trigger: /footguns
---

## What this is for

Internal APIs are the ones we use daily and have full control of - that is
exactly why they grow footguns. Boolean trap: `saveFile(overwrite, verbose)`
with two bare bools. Same-type swap: `send(from, to, subject)` where from/to
are interchangeable by mistake. Inconsistent family: `createThing(a, b, c)`
versus `createThingPrefixed(a, b, c, d)` with different param orders that
look identical at the caller.

Spectral and API-design linters exist for public REST APIs. None of them
catch in-code function-signature footguns. This skill does.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/signature-harvest.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each finding:
   - Is this distinction intentional (e.g., from this library for type
     safety) or a real footgun?
   - Check call sites. How many places invoke this with the bare-bool or
     adjacent-type ambiguity? Higher count = higher severity.
   - For inconsistent family: is the order alphabetical, type-grouped,
     or just historical? Make it intentional.
5. Propose a fix per finding. For booleans, prefer options-object. For
   same-type, name the params (`fromAddress`, `toAddress`). For families,
   choose one convention.
6. Write `footgun-report.md` to the working directory.

## Usage

```
/footguns                          # interactive
/footguns <dir>                    # scan project directory
/footguns -help                    # show usage
```

Returns JSON with `signatures[]`, `similarityGroups{}`, `findings[]`
plus summary counts.
