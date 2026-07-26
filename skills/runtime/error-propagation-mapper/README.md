# error-propagation-mapper

**Trigger:** `/error-map` | **Risk:** read-only | **Audience:** Both

> Error propagation mapper: trace every error from origin through handling blocks to surface, LLM classifies each path ...

Error propagation mapper: trace every error from origin through handling blocks to surface, LLM classifies each path as monitored/silent/dangerous.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/runtime/error-propagation-mapper $HOME/.claude/skills/runtime/error-propagation-mapper
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/runtime/error-propagation-mapper $HOME\.claude\skills\runtime\error-propagation-mapper
```

## Usage

```
/error-map                    # interactive - prompts for target
/error-map <project-dir>      # scan specified project
/error-map -help              # show full usage and stop
```

## Output

Markdown report: propagation-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


