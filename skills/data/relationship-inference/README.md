# relationship-inference

**Trigger:** `/infer-rels` | **Risk:** read-only | **Audience:** Senior

> Relationship inference: scans DDL and code for missing foreign key relationships, infers relationships from naming pa...

Relationship inference: scans DDL and code for missing foreign key relationships, infers relationships from naming patterns and query join patterns, and validates each inference against business logic.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/data/relationship-inference $HOME/.claude/skills/data/relationship-inference
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/data/relationship-inference $HOME\.claude\skills\data\relationship-inference
```

## Usage

```
/infer-rels                    # interactive - prompts for target
/infer-rels <project-dir>      # scan specified project
/infer-rels -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: relationship-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


