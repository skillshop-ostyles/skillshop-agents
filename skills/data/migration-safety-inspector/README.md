# migration-safety-inspector

**Trigger:** `/migration-safety` | **Risk:** read-only | **Audience:** Both

> Database migration safety inspector: scans SQL migration files for 20+ safety rules (table rewrites, missing CONCURRE...

Database migration safety inspector: scans SQL migration files for 20+ safety rules (table rewrites, missing CONCURRENTLY, destructive DROP, unsafe constraints, missing IF EXISTS, DML on existing tables, missing transaction wrappers), then the LLM assesses blast radius per finding against actual schema and usage patterns, recommending safer alternatives.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/data/migration-safety-inspector $HOME/.claude/skills/data/migration-safety-inspector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/data/migration-safety-inspector $HOME\.claude\skills\data\migration-safety-inspector
```

## Usage

```
/migration-safety                    # interactive - prompts for target
/migration-safety <project-dir>      # scan specified project
/migration-safety -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: safety-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


