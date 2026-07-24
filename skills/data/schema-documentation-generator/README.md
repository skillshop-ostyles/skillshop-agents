# schema-documentation-generator

**Trigger:** `/schema-docs` | **Risk:** read-only | **Audience:** Both

> Generate human-readable data dictionary from DDL with LLM-written business descriptions. Reads DDL or ORM models, ext...

Generate human-readable data dictionary from DDL with LLM-written business descriptions. Reads DDL or ORM models, extracts structural metadata, and writes plain-English descriptions for every table, column, and relationship.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/data/schema-documentation-generator $HOME/.claude/skills/data/schema-documentation-generator
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/data/schema-documentation-generator $HOME\.claude\skills\data\schema-documentation-generator
```

## Usage

```
/schema-docs                    # interactive - prompts for target
/schema-docs <project-dir>      # scan specified project
/schema-docs -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: schema-documentation-generator-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


