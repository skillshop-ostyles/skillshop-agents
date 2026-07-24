# config-surface-documenter

**Trigger:** `/config-docs` | **Risk:** read-only | **Audience:** Both

> Extracts the full configuration surface from code (env vars, config files, CLI flags) and generates a human-readable ...

Extracts the full configuration surface from code (env vars, config files, CLI flags) and generates a human-readable reference with descriptions, types, defaults, and effects.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/config-surface-documenter $HOME/.claude/skills/understanding/config-surface-documenter
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/config-surface-documenter $HOME\.claude\skills\understanding\config-surface-documenter
```

## Usage

```
/config-docs                    # interactive - prompts for target
/config-docs <project-dir>      # scan specified project
/config-docs -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: config-surface-documenter-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


