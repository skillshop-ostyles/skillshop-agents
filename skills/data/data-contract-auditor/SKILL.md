---
name: data-contract-auditor
description: "Schema-vs-usage contract auditor: compares schema declarations (DDL, ORM models, TypeScript interfaces, GraphQL types, OpenAPI schemas) against actual usage sites (API responses, form handlers, import parsers, ORM writes) and has the LLM judge whether each violation is a real contract break, harmless flexibility, or schema too strict. Read-only. Trigger: /data-contract"
trigger: /data-contract
---

## What this is for

The schema says `VARCHAR(255) NOT NULL` but the API returns null, the form submits a number where a string is expected. These silent contract violations cause production surprises that no single tool catches — because the schema lives in one file and the usage lives in another, and no linter connects them.

This skill extracts schema declarations (DDL, ORM models, TypeScript interfaces, GraphQL types, OpenAPI schemas) and usage sites (API response serialization, form/data parsing, import/export handlers, ORM write calls), then lets the LLM judge each discrepancy: real violation, harmless flexibility, or schema too strict?

**Audience:** Both — seniors use it as pre-deployment safety net and API contract review; juniors learn where their code silently drifts from declared contracts.

## What You Must Do When Invoked

1. If `-help` or `-h` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists. If not, print usage and stop.
3. Run the collector script:
   ```
   scripts/contract-scan.ps1 -ProjectDir "<path>"
   ```
4. LLM reads the JSON output. Per contract element (`contracts[]`):
   - Examine `field`, `declaredType`, `declaredNullable`.
   - Examine each `usageSites[]` entry: `file`, `line`, `usageType`, `usedType`, `usedNullable`.
5. Per discrepancy:
   - Is this a **real violation**? (e.g. NOT NULL field is assigned undefined — will produce `null` in JSON, may crash strict consumers.)
   - Is this **harmless flexibility**? (e.g. `parseInt` correctly coerces string to number — the consumer handles both.)
   - Is the **schema too strict**? (e.g. field declared `number` but real-world API returns numeric string — schema should be `string | number`.)
   - Classify: `real-violation` / `harmless-flexibility` / `schema-too-strict`.
   - Add confidence: `proven` / `likely` / `suspected`.
6. Write `data-contract-report.md` to the working directory with:
   - Executive summary (files scanned, contracts found, discrepancies)
   - Per-field breakdown (field, declared contract, usage sites, verdict, confidence, reasoning)
   - Cross-cutting patterns (which type of violation is most common)
   - Recommendations (schema changes, runtime guards, or accept-as-is)
   - Open questions (suspected-confidence findings needing human review)

## Usage

```
/data-contract                          # interactive, prompts for directory
/data-contract <dir>                    # scan schema + usage in directory
/data-contract -help                    # show usage
```

Returns JSON with `contracts[]`: each entry `{field, declaredType, declaredNullable, usageSites[{file, line, usageType, usedType, usedNullable}]}` plus summary `counts: {filesScanned, schemasFound, fieldsFound, usageSitesFound, discrepanciesFound}`.

## Report Format

`data-contract-report.md` with:
- Executive summary (files scanned, contracts found, discrepancies by severity)
- Per-field breakdown (field, declared contract, usage sites, verdict, confidence, human-readable reasoning)
- Cross-cutting patterns (most common contract break type)
- Recommendations (schema changes, runtime guards, documentation updates)
- Open questions (findings needing human review)

## Collector Output Schema

```json
{
  "contracts": [
    {
      "field": "email",
      "declaredType": "string",
      "declaredNullable": false,
      "usageSites": [
        {
          "file": "handler.ts",
          "line": 10,
          "usageType": "response-return",
          "usedType": "string | undefined",
          "usedNullable": true
        }
      ]
    }
  ],
  "summary": {
    "filesScanned": 2,
    "schemasFound": 1,
    "fieldsFound": 5,
    "usageSitesFound": 8,
    "discrepanciesFound": 2
  }
}
```
