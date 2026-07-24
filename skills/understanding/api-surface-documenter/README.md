# api-surface-documenter

**Trigger:** `/api-survey` | **Risk:** read-only | **Audience:** Both

> API surface documenter: extracts ALL API surface types from a codebase — REST routes, event handlers, CLI commands, l...

API surface documenter: extracts ALL API surface types from a codebase — REST routes, event handlers, CLI commands, library exports. Classifies stability and generates a complete reference. No Swagger decorations needed.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/understanding/api-surface-documenter $HOME/.claude/skills/understanding/api-surface-documenter
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/understanding/api-surface-documenter $HOME\.claude\skills\understanding\api-surface-documenter
```

## Usage

```
/api-survey                    # interactive - prompts for target
/api-survey <project-dir>      # scan specified project
/api-survey -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: api-surface-documenter-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


