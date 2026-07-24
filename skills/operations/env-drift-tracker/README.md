# env-drift-tracker

**Trigger:** `/env-drift` | **Risk:** read-only | **Audience:** Both

> Env drift tracker: compare config values across environments (dev/staging/prod), LLM flags each difference with risk ...

Env drift tracker: compare config values across environments (dev/staging/prod), LLM flags each difference with risk assessment.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/env-drift-tracker $HOME/.claude/skills/operations/env-drift-tracker
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/env-drift-tracker $HOME\.claude\skills\operations\env-drift-tracker
```

## Usage

```
/env-drift                    # interactive - prompts for target
/env-drift <project-dir>      # scan specified project
/env-drift -help              # show full usage and stop
```

## Output

Markdown report: drift-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


