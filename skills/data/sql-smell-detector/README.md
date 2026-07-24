# sql-smell-detector

**Trigger:** `/sql-smells` | **Risk:** read-only | **Audience:** Senior

> Inline SQL smell detector: harvests SQL strings from application code, runs 15+ static analysis rules (SELECT *, miss...

Inline SQL smell detector: harvests SQL strings from application code, runs 15+ static analysis rules (SELECT *, missing WHERE, implicit casts, non-sargable filters, cartesian products, SELECT DISTINCT masking bad joins), then LLM classifies business impact and proposes rewritten SQL.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/data/sql-smell-detector $HOME/.claude/skills/data/sql-smell-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/data/sql-smell-detector $HOME\.claude\skills\data\sql-smell-detector
```

## Usage

```
/sql-smells                    # interactive - prompts for target
/sql-smells <project-dir>      # scan specified project
/sql-smells -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: smells-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


