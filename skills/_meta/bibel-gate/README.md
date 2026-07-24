# bibel-gate

**Trigger:** `/bibel-gate` | **Risk:** read-only | **Audience:** Both

> Pre-commit gate: BIBEL compliance check + smoke test + JSON contract per changed skill. Exit 1 on failure.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/_meta/bibel-gate $HOME/.claude/skills/_meta/bibel-gate
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/_meta/bibel-gate $HOME\.claude\skills\_meta\bibel-gate
```

## Usage

```
/bibel-gate                    # interactive - prompts for target
/bibel-gate <project-dir>      # scan specified project
/bibel-gate -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Console summary with key metrics | Markdown report: gate-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


