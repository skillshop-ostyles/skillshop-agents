# ai-decision-logger

**Trigger:** `/ai-log` | **Risk:** read-only | **Audience:** Both

> Find model-based decision points and check if they are logged with sufficient context.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/ai-ml/ai-decision-logger $HOME/.claude/skills/ai-ml/ai-decision-logger
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/ai-ml/ai-decision-logger $HOME\.claude\skills\ai-ml\ai-decision-logger
```

## Usage

```
/ai-log                    # interactive - prompts for target
/ai-log <project-dir>      # scan specified project
/ai-log -help              # show full usage and stop
```

## Output

Markdown report: decision-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


