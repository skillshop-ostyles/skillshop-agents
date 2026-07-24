# failure-simulator

**Trigger:** `/failsim` | **Risk:** read-only | **Audience:** Senior

> Failure simulator on code level: inventories every external touchpoint (HTTP clients, DB access, filesystem, queues, ...

Failure simulator on code level: inventories every external touchpoint (HTTP clients, DB access, filesystem, queues, caches) with its surrounding error handling, then for a chosen failure scenario (DB down, API timeouts, disk full) mentally executes the failure path at each touchpoint and reports the resulting behavior - retry, degradation, crash or silent loss - plus inconsistencies and hardening recommendations. Pure thought experiment, nothing is ever shut down.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/failure-simulator $HOME/.claude/skills/operations/failure-simulator
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/failure-simulator $HOME\.claude\skills\operations\failure-simulator
```

## Usage

```
/failsim                    # interactive - prompts for target
/failsim <project-dir>      # scan specified project
/failsim -help              # show full usage and stop
```

## Output

Markdown report: failure-simulator-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


