# vocabulary-guardian

Available - **Trigger:** `/vocab` - **Risk:** read-only

> Customer, Client, Account, Kunde - four names, one concept, a constant misunderstanding.

Harvests identifiers from code, schema and API definitions, clusters synonyms into
domain concepts and proposes one canonical name per cluster. No automatic
renaming - only proposal + impact estimate.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/term-harvest.ps1` requires PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/vocabulary-guardian ~/.claude/skills/quality/vocabulary-guardian
# or project-local:
cp -r skill-shop-agents/skills/quality/vocabulary-guardian <your-project>/.claude/skills/quality/vocabulary-guardian
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\quality\vocabulary-guardian $HOME\.claude\skills\quality\vocabulary-guardian
```

## Usage

In Claude Code:

```
/vocab                     # interactive
/vocab <dir>               # vocabulary analysis
/vocab <dir> "<domain>"    # with domain hint
/vocab -help
```

Details: [`SKILL.md`](SKILL.md).
