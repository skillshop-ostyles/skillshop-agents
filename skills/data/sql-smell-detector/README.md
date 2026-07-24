# sql-smell-detector

Available - **Trigger:** `/sql-smells` - **Risk:** read-only

> Inline SQL in application code is a silent quality drain.

Scans source files for inline SQL strings, runs 15+ static analysis rules (SELECT *, missing WHERE, implicit casts, non-sargable filters, cartesian products, SELECT DISTINCT masking bad joins), then the LLM classifies business impact and proposes rewritten SQL.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/sql-harvest.ps1` requires PowerShell (5.1+ or 7+). Available natively on Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell) (`pwsh`) - **cross-platform operation not yet tested**, developed on Windows.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/data/sql-smell-detector ~/.claude/skills/data/sql-smell-detector
# or project-local:
cp -r skill-shop-agents/skills/data/sql-smell-detector <your-project>/.claude/skills/data/sql-smell-detector
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\data\sql-smell-detector $HOME\.claude\skills\data\sql-smell-detector
```

## Usage

In Claude Code:

```
/sql-smells                        # interactive
/sql-smells C:\Projects\my-app     # scan directory
/sql-smells -help                  # show usage
```

Details (including report format): [`SKILL.md`](SKILL.md).
