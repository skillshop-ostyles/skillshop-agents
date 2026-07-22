# Cluster data — Schemas, Migrations, and Test Coverage

Skills in this cluster deal with **data** in the structural sense: database
schemas, their evolution over time, and how well tests cover the behaviors
they are meant to protect.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|---|---|---|---|
| [migrations-chirurg](../data/migrations-chirurg/) | /migrate | Senior | Given a schema diff, generate a migration plan + rollback script + validation queries. Handles online migrations, long-running locks, and backfill strategies. |
| [test-luecken-kartograf](../data/test-luecken-kartograf/) | /testgap | Senior | Find untested BEHAVIOR (not lines) per public symbol: which functions have no tests, which branches are untested, which edge cases are missing. |

## Cross-Links

- `runtime/` — `prod-spiegel` (code expectation vs. log reality) is the runtime complement to test coverage.
- `quality/` — `spec-luegendetektor` catches gaps in specifications that test-luecken-kartograf would surface as untested behavior.
