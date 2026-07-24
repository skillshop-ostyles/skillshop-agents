# bibel-migrate

**Trigger:** `/bibel-migrate` | **Risk:** read-only | **Audience:** Both

> Auto-generate migration patches when BIBEL.md conventions change.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/_meta/bibel-migrate $HOME/.claude/skills/_meta/bibel-migrate
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/_meta/bibel-migrate $HOME\.claude\skills\_meta\bibel-migrate
```

## Usage

```
/bibel-migrate                    # interactive - prompts for target
/bibel-migrate <project-dir>      # scan specified project
/bibel-migrate -help              # show full usage and stop
```

## Output

Console summary with key metrics | Markdown report: migrate-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


