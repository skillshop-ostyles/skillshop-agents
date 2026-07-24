# skill-dedup

**Trigger:** `/skill-dedup` | **Risk:** read-only | **Audience:** Both

> Find functional overlap between skills via description similarity and script pattern matching.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/_meta/skill-dedup $HOME/.claude/skills/_meta/skill-dedup
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/_meta/skill-dedup $HOME\.claude\skills\_meta\skill-dedup
```

## Usage

```
/skill-dedup                    # interactive - prompts for target
/skill-dedup <project-dir>      # scan specified project
/skill-dedup -help              # show full usage and stop
```

## Output

Markdown report: dedup-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


