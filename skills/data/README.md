# Cluster data - Schemas, Migrations, and Test Coverage

Skills in this cluster deal with **data** in the structural sense: database
schemas, their evolution over time, and how well tests cover the behaviors
they are meant to protect.

## Skills in this Cluster

| Skill | Trigger | Audience | Purpose |
|--|--|--|--|
| [migration-surgeon](../data/migration-surgeon/) | /migrate | Senior | Given a schema diff, generate a migration plan + rollback script + validation queries. Handles online migrations, long-running locks, and backfill strategies. |
| [test-gap-cartographer](../data/test-gap-cartographer/) | /testgap | Senior | Find untested BEHAVIOR (not lines) per public symbol: which functions have no tests, which branches are untested, which edge cases are missing. |
| [schema-health-scanner](../data/schema-health-scanner/) | /schema-health | Both | Static analysis of DDL/ORM schemas for structural anti-patterns with LLM-contextualized severity. |
| [migration-safety-inspector](../data/migration-safety-inspector/) | /migration-safety | Senior | Analyze SQL migration files for dangerous operations with blast-radius assessment. |
| [sql-smell-detector](../data/sql-smell-detector/) | /sql-smells | Both | Find inline SQL anti-patterns (SELECT *, missing WHERE, implicit casts) with impact classification. |
| [schema-documentation-generator](../data/schema-documentation-generator/) | /schema-docs | Both | Generate human-readable data dictionary from DDL with LLM-written business descriptions. |
| [n-plus-one-hunter](../data/n-plus-one-hunter/) | /n-plus-one | Both | Detect ORM N+1 query patterns statically, distinguish real bugs from intentional patterns. |
| [data-contract-auditor](../data/data-contract-auditor/) | /data-contract | Senior | Compare schema declarations against code usage sites for contract violations. |
| [schema-drift-tracker](../data/schema-drift-tracker/) | /schema-drift | Senior | Compare two schema snapshots, detect structural drift with LLM severity assessment. |
| [data-fixture-auditor](../data/data-fixture-auditor/) | /fixture-audit | Senior | Analyze test fixtures for quality, coverage, and edge-case completeness. |
| [pii-schema-classifier](../data/pii-schema-classifier/) | /pii-scan | Senior | Classify schema columns by sensitivity using naming patterns + LLM domain judgment. |
| [migration-test-writer](../data/migration-test-writer/) | /migration-test | Senior | Generate pre- and post-migration validation queries from a schema diff. |
| [relationship-inference](../data/relationship-inference/) | /infer-rels | Senior | Infer missing FK relationships from naming + query join patterns with LLM validation. |
| [seed-data-strategist](../data/seed-data-strategist/) | /seed-data | Both | Design optimal seed data strategy from schema analysis with meaningful test scenarios. |

## Cross-Links

- `runtime/` - `prod-mirror` (code expectation vs. log reality) is the runtime complement to test coverage.
- `quality/` - `spec-lie-detector` catches gaps in specifications that test-gap-cartographer would surface as untested behavior.
- `security/` - `data-trail-tracker` maps PII sinks; `pii-schema-classifier` (data/) identifies PII sources at schema level for the full PII map.
- `quality/` - `api-footgun-reviewer` catches API misuse; `data-contract-auditor` (data/) catches schema-to-code contract drift.
