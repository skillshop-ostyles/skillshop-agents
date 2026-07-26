# schema-query-mismatch

**Trigger:** `/schema-query` | **Risk:** read-only | **Audience:** Both

> Schema-query mismatch detector: compare every query pattern against the declared DB schema, LLM judges production risk.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/runtime/schema-query-mismatch $HOME/.claude/skills/runtime/schema-query-mismatch
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/runtime/schema-query-mismatch $HOME\.claude\skills\runtime\schema-query-mismatch
```

## Usage

```
/schema-query                    # interactive - prompts for target
/schema-query <project-dir>      # scan specified project
/schema-query -help              # show full usage and stop
```

## Output

Markdown report: query-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


