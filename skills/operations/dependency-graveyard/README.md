# dependency-graveyard

**Trigger:** `/dep-graveyard` | **Risk:** read-only | **Audience:** Both

> Dependency graveyard: inventory every dependency, check registry health metadata, then LLM judges each as healthy/agi...

Dependency graveyard: inventory every dependency, check registry health metadata, then LLM judges each as healthy/aging/zombie/dead.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/operations/dependency-graveyard $HOME/.claude/skills/operations/dependency-graveyard
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/operations/dependency-graveyard $HOME\.claude\skills\operations\dependency-graveyard
```

## Usage

```
/dep-graveyard                    # interactive - prompts for target
/dep-graveyard <project-dir>      # scan specified project
/dep-graveyard -help              # show full usage and stop
```

## Output

Markdown report: dependency-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


