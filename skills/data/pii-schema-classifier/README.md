# pii-schema-classifier

**Trigger:** `/pii-scan` | **Risk:** read-only | **Audience:** Senior

> PII schema classifier: scans DDL/ORM models for columns that may contain sensitive data, classifies by sensitivity le...

PII schema classifier: scans DDL/ORM models for columns that may contain sensitive data, classifies by sensitivity level using naming patterns, and flags ambiguous columns for LLM domain review.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/data/pii-schema-classifier $HOME/.claude/skills/data/pii-schema-classifier
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/data/pii-schema-classifier $HOME\.claude\skills\data\pii-schema-classifier
```

## Usage

```
/pii-scan                    # interactive - prompts for target
/pii-scan <project-dir>      # scan specified project
/pii-scan -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: classification-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


