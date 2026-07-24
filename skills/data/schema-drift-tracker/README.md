# schema-drift-tracker

Detect and assess DDL drift between two database schema snapshots.

## Quick start

```powershell
# Run the collector against the bundled smoke-test fixtures
powershell -File skills/data/schema-drift-tracker/scripts/drift-diff.ps1 `
  -ProjectDir skills/data/schema-drift-tracker/tests/fixtures/smoke/src `
  -OldSchema v1/schema.sql `
  -NewSchema v2/schema.sql
```

## Drift kinds detected

| Kind      | Changes                                           |
|-----------|---------------------------------------------------|
| table     | added / removed                                   |
| column    | added / removed / type / nullability / default    |
| index     | added / removed                                   |
| foreign key | added / removed                                |

## Severity classification

| Severity | Impact                                                   |
|----------|----------------------------------------------------------|
| critical | Removed table/column, type narrowing                     |
| major    | Renamed column, removed index, NOT NULL → nullable       |
| minor    | New nullable column, new index, new table                |
| info     | Default value change, type widening, new FK              |

## Trigger

OpenCode: `/schema-drift`
