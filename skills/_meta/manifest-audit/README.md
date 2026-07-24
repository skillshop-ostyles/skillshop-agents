# manifest-audit

**Trigger:** `/manifest-audit` | **Risk:** read-only | **Audience:** Both

> Verify project tracking docs, README.md, and actual filesystem are in sync.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/_meta/manifest-audit $HOME/.claude/skills/_meta/manifest-audit
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/_meta/manifest-audit $HOME\.claude\skills\_meta\manifest-audit
```

## Usage

```
/manifest-audit                    # interactive - prompts for target
/manifest-audit <project-dir>      # scan specified project
/manifest-audit -help              # show full usage and stop
```

## Output

Markdown report: audit-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


