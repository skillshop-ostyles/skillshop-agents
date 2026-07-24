# schema-documentation-generator

**Cluster:** data | **Trigger:** `/schema-docs` | **Audience:** Both

Generate human-readable data dictionary from DDL with LLM-written business descriptions.

## What it does

1. Scans a project directory for DDL/ORM files (.sql, .prisma, TypeORM, SQLAlchemy)
2. Extracts structural metadata: tables, columns, types, nullability, defaults, PKs, FKs, indexes, unique constraints
3. Detects and expands naming abbreviations (cst -> customer, ord -> order, prd -> product)
4. Writes `schema-dictionary.md` with LLM-written plain-English descriptions

## Usage

```powershell
# Interactive
/schema-docs

# Direct
/schema-docs -ProjectDir ./path/to/schemas
```

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Skill definition and invocation rules |
| `scripts/schema-extract.ps1` | Collector: parses DDL/ORM files, extracts structural metadata, outputs JSON |
| `tests/fixtures/smoke/src/schema.sql` | Smoke test fixture: 3 tables with abbreviated column names |
| `tests/fixtures/empty/.gitkeep` | Empty fixture placeholder |
