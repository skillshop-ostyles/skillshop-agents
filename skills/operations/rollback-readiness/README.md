# rollback-readiness

**Trigger:** `/rollback` | **Risk:** read-only | **Audience:** Both

> Rollback readiness: check each deployable change against rollback criteria, LLM estimates cost and risk of undoing it.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/rollback-readiness $HOME/.claude/skills/operations/rollback-readiness
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/rollback-readiness $HOME\.claude\skills\operations\rollback-readiness
```

## Usage

```
/rollback                    # interactive - prompts for target
/rollback <project-dir>      # scan specified project
/rollback -help              # show full usage and stop
```

## Output

Markdown report: readiness-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


