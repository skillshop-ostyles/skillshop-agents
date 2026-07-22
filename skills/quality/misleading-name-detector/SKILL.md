---
name: misleading-name-detector
description: "Misleading name detector: harvests every prefixed function with reader/mutator/predicate cues (get*/find*/fetch*/set*/write*/is*/has*/can*/...) and extracts the first 600 chars of brace-balanced body. LLM judges whether the code does what the name promises. Severity scales with call count and visibility. Read-only. Audience: Both. Trigger: /name-lies"
trigger: /name-lies
---

## What this is for

`getUser()` that pushes a default user. `isValid()` that returns a string.
`tempFix()` from 2019. Identifiers whose names promise something the
implementation does not deliver - linguistic anti-patterns the type system
cannot see.

The skill harvests every prefixed function with conventional cues - reader
(`get*`, `find*`, `fetch*`), mutator (`set*`, `write*`, `push*`), predicate
(`is*`, `has*`, `can*`) - and pairs the symbol name with the first 600 chars
of brace-balanced body. The LLM judges whether behavior matches promise.
The collector never raises false positives alone, but it gives the LLM exactly
what it needs to do so.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/name-harvest.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each symbol with prefix-kind + body preview:
   - Does the body do what the name promises?
   - Readers (`get*` etc.) must not mutate or perform write I/O.
   - Predicates (`is*`/`has*`/`can*` etc.) must return boolean.
   - Mutators (`set*`/`write*`/`push*` etc.) are not subject to a wrong-kind
     finding, but their name should reflect what they mutate.
   - Async/Sync suffix must match actual sync vs. promise-yielding behavior.
5. Classify: `truthful` / `lies-kind` (severity by API surface and call count).
6. Confidence: `proven` (direct code evidence), `likely` (multiple cues),
   `suspected` (judgment call).
7. Write `name-lies-report.md` to the working directory.

## Usage

```
/name-lies                           # interactive, prompts for directory
/name-lies <dir>                     # scan project directory
/name-lies -help                     # show usage
```

Returns JSON with `symbols[]`:
`{file, line, name, prefixKind, mutations[], ios[], isAsync, hasAsyncSuffix,
bodyPreview}` plus `counts` summary.

## Report Format

`name-lies-report.md`:
- Executive summary (total prefixed symbols, % truthful vs lies)
- Critical findings (promise breaks for widely-called public APIs)
- Medium findings (less-visible naming lies, fix candidates)
- Low findings (inconclusive - body too short to judge)
- Confidence column
- Open questions (suspected)
