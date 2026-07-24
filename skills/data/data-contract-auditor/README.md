# Data Contract Auditor — `/data-contract`

## What this is for

The schema says `VARCHAR(255) NOT NULL` but the API returns null, the form submits a number where a string is expected. These silent contract violations cause production surprises that no single tool catches — because the schema lives in one file and the usage lives in another, and no linter connects them.

This skill extracts schema declarations (DDL, ORM models, TypeScript interfaces, GraphQL types, OpenAPI schemas) and usage sites (API response serialization, form/data parsing, import/export handlers, ORM write calls), then lets the LLM judge each discrepancy: real violation, harmless flexibility, or schema too strict?

## Usage

```powershell
& .\scripts\contract-scan.ps1 -ProjectDir "C:\Projects\my-app\src"
```

Produces JSON with `contracts[]` comparing declared schema vs actual usage per field.

See [`SKILL.md`](SKILL.md) for full invocation workflow.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/data/data-contract-auditor ~/.claude/skills/data/data-contract-auditor
```

## Audience

Both — seniors use it as pre-deployment contract review and API boundary audit; juniors learn where their code silently drifts from declared contracts.

## Status

Implemented. Full specification in sprint 81 data cluster.
