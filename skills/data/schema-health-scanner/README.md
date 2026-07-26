# schema-health-scanner

**Trigger:** `/schema-health` | **Risk:** read-only | **Audience:** Both

> Database schema health scanner: parses DDL files (.sql, .prisma, ORM models), extracts per-table structural metrics (...

Database schema health scanner: parses DDL files (.sql, .prisma, ORM models), extracts per-table structural metrics (columns, PKs, FKs, indexes, naming conventions, type consistency), detects anti-patterns (missing PKs, unbounded strings, mixed naming, god tables, missing timestamps, FK without index), then the LLM judges each finding in domain context.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/data/schema-health-scanner $HOME/.claude/skills/data/schema-health-scanner
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/data/schema-health-scanner $HOME\.claude\skills\data\schema-health-scanner
```

## Usage

```
/schema-health                    # interactive - prompts for target
/schema-health <project-dir>      # scan specified project
/schema-health -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: health-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


