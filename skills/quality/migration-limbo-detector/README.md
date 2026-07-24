# migration-limbo-detector

**Trigger:** `/migration-limbo` | **Risk:** read-only | **Audience:** Senior

> Migration limbo detector: screens for half-finished migrations by counting usage of competing patterns (axios/fetch, ...

Migration limbo detector: screens for half-finished migrations by counting usage of competing patterns (axios/fetch, moment/date-fns, jest/vitest, require/import, redux/zustand, joi/zod, ...), reconstructing the migration timeline via git log, and estimating completion effort. Custom pattern pairs supported via -CustomPairs.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/quality/migration-limbo-detector $HOME/.claude/skills/quality/migration-limbo-detector
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/quality/migration-limbo-detector $HOME\.claude\skills\quality\migration-limbo-detector
```

## Usage

```
/migration-limbo                    # interactive - prompts for target
/migration-limbo <project-dir>      # scan specified project
/migration-limbo -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: limbo-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


