# seed-data-strategist

**Trigger:** `/seed-data` | **Risk:** read-only | **Audience:** Both

> Seed data strategist: reads a schema (DDL/ORM models), analyzes tables, columns, constraints, and enum values, and ge...

Seed data strategist: reads a schema (DDL/ORM models), analyzes tables, columns, constraints, and enum values, and generates a comprehensive seed data strategy with meaningful test scenarios.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/data/seed-data-strategist $HOME/.claude/skills/data/seed-data-strategist
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/data/seed-data-strategist $HOME\.claude\skills\data\seed-data-strategist
```

## Usage

```
/seed-data                    # interactive - prompts for target
/seed-data <project-dir>      # scan specified project
/seed-data -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: strategy-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


