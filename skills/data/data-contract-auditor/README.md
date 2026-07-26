# data-contract-auditor

**Trigger:** `/data-contract` | **Risk:** read-only | **Audience:** Both

> Schema-vs-usage contract auditor: compares schema declarations (DDL, ORM models, TypeScript interfaces, GraphQL types...

Schema-vs-usage contract auditor: compares schema declarations (DDL, ORM models, TypeScript interfaces, GraphQL types, OpenAPI schemas) against actual usage sites (API responses, form handlers, import parsers, ORM writes) and has the LLM judge whether each violation is a real contract break, harmless flexibility, or schema too strict.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/data/data-contract-auditor $HOME/.claude/skills/data/data-contract-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/data/data-contract-auditor $HOME\.claude\skills\data\data-contract-auditor
```

## Usage

```
/data-contract                    # interactive - prompts for target
/data-contract <project-dir>      # scan specified project
/data-contract -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: contract-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


