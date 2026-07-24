# schema-drift-tracker

**Trigger:** `/schema-drift` | **Risk:** read-only | **Audience:** Both

> >

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/data/schema-drift-tracker $HOME/.claude/skills/data/schema-drift-tracker
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/data/schema-drift-tracker $HOME\.claude\skills\data\schema-drift-tracker
```

## Usage

```
/schema-drift                    # interactive - prompts for target
/schema-drift <project-dir>      # scan specified project
/schema-drift -help              # show full usage and stop
```

## Output

Markdown report: drift-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


