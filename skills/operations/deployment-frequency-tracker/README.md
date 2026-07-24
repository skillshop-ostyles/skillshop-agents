# deployment-frequency-tracker

**Trigger:** `/deploy-freq` | **Risk:** read-only | **Audience:** Both

> Deployment frequency tracker: compute DORA metrics from git history, LLM identifies bottlenecks and improvement oppor...

Deployment frequency tracker: compute DORA metrics from git history, LLM identifies bottlenecks and improvement opportunities.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/deployment-frequency-tracker $HOME/.claude/skills/operations/deployment-frequency-tracker
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/deployment-frequency-tracker $HOME\.claude\skills\operations\deployment-frequency-tracker
```

## Usage

```
/deploy-freq                    # interactive - prompts for target
/deploy-freq <project-dir>      # scan specified project
/deploy-freq -help              # show full usage and stop
```

## Output

Markdown report: frequency-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


