# migration-surgeon

**Trigger:** `/migrate` | **Risk:** read-only | **Audience:** Both

> Schema migration surgeon: diffs two schema states (SQL DDL or Prisma), then generates the complete package nobody wri...

Schema migration surgeon: diffs two schema states (SQL DDL or Prisma), then generates the complete package nobody writes by hand - forward migration, rollback, pre/post validation queries and a risk protocol with explicit data-loss warnings. NEVER executes anything against a database; generates files only.

## Quick Install

```bash
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
cp -r skills/data/migration-surgeon $HOME/.claude/skills/data/migration-surgeon
```

### Windows (PowerShell)

```powershell
git clone https://github.com/skillshop-ostyles/skillshop-agents.git
Copy-Item -Recurse skills/data/migration-surgeon $HOME\.claude\skills\data\migration-surgeon
```

## Usage

```
/migrate                    # interactive - prompts for target
/migrate <project-dir>      # scan specified project
/migrate -help              # show full usage and stop
```

## Output

Markdown report: migration-surgeon-report.md

## Details

Full workflow and LLM instructions: [`SKILL.md`](SKILL.md)

## Prerequisites

- [Claude Code](https://claude.com/claude-code) installed
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Target must be a local directory with source code


