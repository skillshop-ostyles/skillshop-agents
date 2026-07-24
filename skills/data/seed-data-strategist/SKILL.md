---
name: seed-data-strategist
description: "Seed data strategist: reads a schema (DDL/ORM models), analyzes tables, columns, constraints, and enum values, and generates a comprehensive seed data strategy with meaningful test scenarios. Read-only. Audience: Both. Trigger: /seed-data"
trigger: /seed-data
---

## What this is for

Empty databases are useless for testing. Teams waste days writing seed data that
misses edge cases, duplicates production patterns incorrectly, or creates
unrealistic distributions. This skill reads a schema and generates a comprehensive
seed data strategy: which entities need what variety, what edge values matter,
what cardinality to aim for.

The dominant failure mode is the seed data that covers only the happy path,
leaving error paths and edge cases untested until production.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/seed-analyze.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each entity:
   - What seed variants cover meaningful test scenarios?
   - List specific instances (e.g. "Customer with active subscription",
     "Customer with expired card", "Customer with maxed credit limit").
   - Ensure all FK chains have at least one complete path.
   - What edge values for nullable/enum/unique fields?
5. Confidence: `proven` (from schema constraints), `likely` (inferred from
   column names), `suspected` (domain assumption).
6. Write `seed-strategy-report.md` to the working directory.

## Usage

```
/seed-data                         # interactive, prompts for directory
/seed-data <dir>                   # scan project directory
/seed-data -help                   # show usage
```

Returns JSON with `entities[]`: each entry `{table, columns[], fkDependencies[],
statusFields[], nullableFields[], uniqueFields[], enumValues[]}` plus
`counts: {scannedFiles, totalEntities, totalColumns}`.

## Report Format

`seed-strategy-report.md` with:
- Executive summary (total entities, total columns, FK chains)
- Per-entity seed strategy (what variants, what edge values)
- FK chain coverage (which paths are complete, which are missing)
- Edge case recommendations (nulls, enums, boundaries)
- Confidence column for every finding
- Open questions (suspected, needs human review)
