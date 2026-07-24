# side-effect-radar

**Trigger:** `/blast` | **Risk:** read-only | **Audience:** Both

> Blast-radius predictor for a planned change: combines a static reference scan (which files mention the target's expor...

Blast-radius predictor for a planned change: combines a static reference scan (which files mention the target's exported symbols) with git co-change analysis (which files historically changed together with the target), then produces a risk-tiered report with concrete review/test recommendations.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/side-effect-radar $HOME/.claude/skills/quality/side-effect-radar
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/side-effect-radar $HOME\.claude\skills\quality\side-effect-radar
```

## Usage

```
/blast                    # interactive - prompts for target
/blast <project-dir>      # scan specified project
/blast -help              # show full usage and stop
```

## Output

Markdown report: side-effect-radar-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


