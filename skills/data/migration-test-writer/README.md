# migration-test-writer

**Trigger:** `/migration-test` | **Risk:** read-only | **Audience:** Senior

> Migration test writer: reads a schema diff (old DDL vs. new DDL), identifies structural changes, and generates pre- a...

Migration test writer: reads a schema diff (old DDL vs. new DDL), identifies structural changes, and generates pre- and post-migration validation queries.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skills/data/migration-test-writer $HOME/.claude/skills/data/migration-test-writer
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skills/data/migration-test-writer $HOME\.claude\skills\data\migration-test-writer
```

## Usage

```
/migration-test                    # interactive - prompts for target
/migration-test <project-dir>      # scan specified project
/migration-test -help              # show full usage and stop
```

## Output

Structured JSON evidence on stdout | Markdown report: migration-test-writer-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


