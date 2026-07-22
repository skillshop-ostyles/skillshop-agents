# side-effect-radar

Available - **Trigger:** `/blast` - **Risk:** read-only

> Small change, big surprise? Not anymore.

Combines static reference search with historical co-change analysis (which
files in the past were almost always changed together with the target) into
a risk-tiered blast radius report before a planned change.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/*.ps1` requires PowerShell (5.1+ or 7+). Available natively on Windows.
  On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.
- A local git repo as analysis target (co-change analysis; reference search
  also works without git).

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/side-effect-radar ~/.claude/skills/quality/side-effect-radar
# or project-local:
cp -r skill-shop-agents/skills/quality/side-effect-radar <your-project>/.claude/skills/quality/side-effect-radar
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\quality\side-effect-radar $HOME\.claude\skills\quality\side-effect-radar
```

## Usage

In Claude Code:

```
/blast                          # interactive
/blast <repo> <file> [...]      # blast radius for planned change at <file>
/blast -help
```

Details: [`SKILL.md`](SKILL.md).
