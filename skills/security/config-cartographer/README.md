# config-cartographer

**Trigger:** `/config-map` | **Risk:** read-only | **Audience:** Senior

> Configuration cartographer: maps a system's complete config surface - every env var, setting and flag, where it is de...

Configuration cartographer: maps a system's complete config surface - every env var, setting and flag, where it is defined (.env, yaml/json configs, compose, Dockerfile) versus where it is read in code - and reports read-but-never-defined keys (crash candidates), defined-but-never-read orphans and divergent defaults. Never outputs values, keys only.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/security/config-cartographer $HOME/.claude/skills/security/config-cartographer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/security/config-cartographer $HOME\.claude\skills\security\config-cartographer
```

## Usage

```
/config-map                    # interactive - prompts for target
/config-map <project-dir>      # scan specified project
/config-map -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: map-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


