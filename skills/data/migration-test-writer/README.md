# Migration Test Writer - /migration-test

## What this is for

A schema migration is only safe if you can verify it worked. Most teams ship
migrations without validation queries - no row-count checks, no null-consistency
checks, no referential-integrity verification, no data-loss detection. This skill
reads a schema diff (old DDL vs. new DDL) and the LLM generates validation
queries that should pass before and after the migration.

The dominant failure mode is the silent data loss or constraint violation that
only surfaces in production after the migration has run.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/migration-diff.ps1 -ProjectDir "<path>" -OldSchema "v1/schema.sql" -NewSchema "v2/schema.sql"`
4. LLM reads the JSON output. For each diff entry:
   - If `requiresPreCheck` is true: generate a pre-migration validation query
     (verify assumptions before the migration runs).
   - If `requiresPostCheck` is true: generate a post-migration validation query
     (verify data integrity after the migration completes).
5. Confidence: `proven` (deterministic diff from DDL), `likely` (inferred
   requirement), `suspected` (edge case).
6. Write `migration-validation-queries.sql` to the working directory.

## Usage

```
/migration-test                         # interactive, prompts for directory
/migration-test <dir>                   # scan with default v1/v2 schema paths
/migration-test <dir> -OldSchema <path> -NewSchema <path>  # custom schema paths
/migration-test -help                   # show usage
```

Returns JSON with `diff[]`: each entry `{type, table, column, old, new,
requiresPreCheck, requiresPostCheck}` plus `counts: {tablesCompared,
totalChanges, byType}`.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/data/migration-test-writer ~/.claude/skills/
```

## Audience

Senior - database engineers and DevOps who need to verify migrations are safe.

## Cross-Links

- `data/migration-surgeon` - generates the migration plan + rollback script.
  This skill generates the TEST for that migration.
