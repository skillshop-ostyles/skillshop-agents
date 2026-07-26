# trigger-audit

**Trigger:** `/trigger-audit` | **Risk:** read-only | **Audience:** Both

> Check trigger uniqueness, naming convention, and README documentation.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/_meta/trigger-audit $HOME/.claude/skills/_meta/trigger-audit
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/_meta/trigger-audit $HOME\.claude\skills\_meta\trigger-audit
```

## Usage

```
/trigger-audit                    # interactive - prompts for target
/trigger-audit <project-dir>      # scan specified project
/trigger-audit -help              # show full usage and stop
```

## Output

Markdown report: audit-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


