# migration-surgeon

Available - **Trigger:** `/migrate` - **Risk:** writing (package always created
in working directory; into target project only after explicit approval)

> Schema migrations are open-heart surgery. This one comes with rollback.

Diffs two schema states (SQL-DDL or Prisma) and generates the complete package
nobody writes by hand: forward migration, rollback, validation queries and a
risk protocol with explicit data-loss warnings. **Never executes a migration** - only files.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/schema-diff.ps1` requires PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.
- Two schema states as files (SQL-DDL or Prisma) - no access to a live database
  needed or intended.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/data/migration-surgeon ~/.claude/skills/data/migration-surgeon
# or project-local:
cp -r skill-shop-agents/skills/data/migration-surgeon <your-project>/.claude/skills/data/migration-surgeon
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\data\migration-surgeon $HOME\.claude\skills\data\migration-surgeon
```

## Usage

In Claude Code:

```
/migrate                              # interactive
/migrate <old> <new> <dialect>        # diff + generate package
/migrate -help
```

Details (including the never-execute rule): [`SKILL.md`](SKILL.md).
