# n-plus-one-hunter

**Trigger:** `/n-plus-one` | **Risk:** read-only | **Audience:** Both

> N+1 query hunter: traces loop-to-query data flows in source code, identifies ORM N+1 patterns, and distinguishes real...

N+1 query hunter: traces loop-to-query data flows in source code, identifies ORM N+1 patterns, and distinguishes real N+1 problems from intentional batch/join patterns.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/data/n-plus-one-hunter $HOME/.claude/skills/data/n-plus-one-hunter
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/data/n-plus-one-hunter $HOME\.claude\skills\data\n-plus-one-hunter
```

## Usage

```
/n-plus-one                    # interactive - prompts for target
/n-plus-one <project-dir>      # scan specified project
/n-plus-one -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: one-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


