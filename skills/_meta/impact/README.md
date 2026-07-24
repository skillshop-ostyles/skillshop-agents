# impact

**Trigger:** `/impact` | **Risk:** read-only | **Audience:** Both

> Given a BIBEL.md diff, list every skill that would need updating.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/_meta/impact $HOME/.claude/skills/_meta/impact
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/_meta/impact $HOME\.claude\skills\_meta\impact
```

## Usage

```
/impact                    # interactive - prompts for target
/impact <project-dir>      # scan specified project
/impact -help              # show full usage and stop
```

## Output

Markdown report: impact-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


