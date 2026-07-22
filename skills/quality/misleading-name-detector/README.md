# Misleading-Name Detector - /name-lies

## What this is for

`getUser()` that pushes a default user. `isValid()` that returns a string.
`tempFix()` from 2019. Identifiers whose names promise something the
implementation does not deliver.

The skill harvests every prefixed function with conventional cues -> reader
(`get*`, `find*`, `fetch*`), mutator (`set*`, `write*`, `push*`), predicate
(`is*`, `has*`, `can*`) -> and pairs the symbol name with the first 600 chars
of brace-balanced body. The LLM judges whether behavior matches promise.
The collector never raises false positives alone, but it gives the LLM exactly
what it needs to do so.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/name-harvest.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each symbol with prefix-kind + body preview:
   - Does the body do what the name promises?
   - Readers (get*) must not mutate or perform I/O.
   - Predicates (is*/has*/can*) must return boolean.
   - Mutators (set*/write*/push*) are not subject to a wrong-shape finding.
   - Async/Sync suffix must match actual sync-ness, not lie about it.
5. Classify: `truthful` / `lies-kind` (severity by call count and visibility).
6. Confidence: `proven` (direct evidence in body), `likely` (context clue),
   `suspected` (judgment call).
7. Write `name-lies-report.md` to the working directory.

## Usage

```
/name-lies                           # interactive, prompts for directory
/name-lies <dir>                     # scan project directory
/name-lies -help                     # show usage
```

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/misleading-name-detector ~/.claude/skills/
```

## Audience

Both - seniors audit their own code, vibe-coders catch the footguns their LLM
suggests.
