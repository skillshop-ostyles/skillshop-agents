# Migration Safety Inspector - /migration-safety

## What this is for

Database migrations are the leading cause of production incidents. Missing
CONCURRENTLY, ALTER COLUMN TYPE causing full-table rewrites, destructive DROP
without rollback, unsafe constraint additions with no lock-timeout - every SQL
migration file carries risks that schema review often misses.

This skill automates the safety review: a deterministic collector finds all SQL
migration files, parses every DDL statement, and checks 20+ safety rules. The
LLM then assesses the blast radius of each finding against the actual schema
and usage patterns, and recommends safer alternatives.

## What You Must Do When Invoked

1. If `-help` is passed, print the `## Usage` block below and stop.
2. Confirm `-ProjectDir` is provided and the path exists.
3. Run: `scripts/migration-scan.ps1 -ProjectDir "<path>"`
4. LLM reads the JSON output. For each finding, note the severity, line, description, and DDL statement.
5. Assess blast radius per finding against schema usage patterns. Is this acceptable in a maintenance window?
6. Write `migration-safety-report.md` to the working directory.

## Usage

```
/migration-safety                           # interactive, prompts for directory
/migration-safety <dir>                     # scan SQL migration files in directory
/migration-safety -help                     # show usage
```

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/data/migration-safety-inspector ~/.claude/skills/data/migration-safety-inspector
```

## Audience

Senior - DBAs use it for migration review before deployment. Backend engineers
learn which SQL patterns are unsafe on production-scale data.
