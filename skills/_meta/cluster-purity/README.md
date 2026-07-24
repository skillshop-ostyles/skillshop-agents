# cluster-purity

**Trigger:** `/cluster-purity` | **Risk:** read-only | **Audience:** Both

> Detect skills that may belong to a different cluster based on description, trigger, and script patterns.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/_meta/cluster-purity $HOME/.claude/skills/_meta/cluster-purity
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/_meta/cluster-purity $HOME\.claude\skills\_meta\cluster-purity
```

## Usage

```
/cluster-purity                    # interactive - prompts for target
/cluster-purity <project-dir>      # scan specified project
/cluster-purity -help              # show full usage and stop
```

## Output

Markdown report: purity-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


