# knowledge-testament

Available - **Trigger:** `/testament` - **Risk:** read-only

> When the head with the knowledge leaves, the knowledge must come out first.

Mines git ownership (blame shares, hotspots, exclusive knowledge) to find where a
person's exclusive knowledge lives and runs a targeted, evidence-anchored handover interview.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/ownership.ps1` requires PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.
- A local git repo with history as analysis target.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/understanding/knowledge-testament ~/.claude/skills/understanding/knowledge-testament
# or project-local:
cp -r skill-shop-agents/skills/understanding/knowledge-testament <your-project>/.claude/skills/understanding/knowledge-testament
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\understanding\knowledge-testament $HOME\.claude\skills\understanding\knowledge-testament
```

## Usage

In Claude Code:

```
/testament                       # interactive
/testament <repo> <author>       # testament for <author> from <repo>
/testament <repo> -list          # list authors with shares
/testament -help
```

Details: [`SKILL.md`](SKILL.md).
