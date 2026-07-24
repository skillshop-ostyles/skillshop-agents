# N+1 Query Hunter - /n-plus-one

## What this is for

ORM N+1 queries are the #1 performance antipattern in web applications. A loop
that fetches 100 parent rows then executes 100 more queries for each child
produces 101 database round-trips where 1 would suffice. This skill finds the
pattern statically by tracing loop constructs to ORM data-access calls, then
the LLM distinguishes real N+1 problems from intentional batch patterns.

The dominant failure mode is the hidden N+1 that degrades production performance
linearly with data growth - invisible in development with small datasets.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/loop-query-trace.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each candidate:
   - Read the `loopType`, `loopSource`, and `queryCall` fields.
   - Check `hasBatchHint`: does the query use IN clause, whereIn, include, or relations?
   - If hasBatchHint is false and the query is inside a loop: real N+1.
   - If hasBatchHint is true: intentional batch or eager-loaded pattern.
5. Confidence: `proven` (query inside loop with no batch hint), `likely`
   (query inside loop with partial batch hint), `suspected` (ambiguous).
6. Write `n-plus-one-report.md` to the working directory.

## Usage

```
/n-plus-one                         # interactive, prompts for directory
/n-plus-one <dir>                   # scan project directory
/n-plus-one -help                   # show usage
```

Returns JSON with `candidates[]`: each entry `{file, line, loopType,
loopSource, queryCall, queryArgs, hasBatchHint}` plus `counts: {scannedFiles,
totalCandidates, byVerdict}`.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/data/n-plus-one-hunter ~/.claude/skills/
```

## Audience

Both - seniors use it to find performance landmines before they hit production,
vibe-coders learn to recognize the pattern and fix it with eager loading or
batch queries.
