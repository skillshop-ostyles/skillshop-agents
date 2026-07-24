# capacity-early-warning

**Trigger:** `/capacity` | **Risk:** read-only | **Audience:** Both

> Capacity early warning: find hardcoded limits, pool sizes, timeouts, quotas, then LLM judges each as adequate/approac...

Capacity early warning: find hardcoded limits, pool sizes, timeouts, quotas, then LLM judges each as adequate/approaching/critical.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/capacity-early-warning $HOME/.claude/skills/operations/capacity-early-warning
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/capacity-early-warning $HOME\.claude\skills\operations\capacity-early-warning
```

## Usage

```
/capacity                    # interactive - prompts for target
/capacity <project-dir>      # scan specified project
/capacity -help              # show full usage and stop
```

## Output

Markdown report: capacity-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


