# data-fixture-auditor

**Trigger:** `/fixture-audit` | **Risk:** read-only | **Audience:** Both

> No description.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/data/data-fixture-auditor $HOME/.claude/skills/data/data-fixture-auditor
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/data/data-fixture-auditor $HOME\.claude\skills\data\data-fixture-auditor
```

## Usage

```
/fixture-audit                    # interactive - prompts for target
/fixture-audit <project-dir>      # scan specified project
/fixture-audit -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: quality-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


