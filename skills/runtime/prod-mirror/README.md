# prod-mirror

Available - **Trigger:** `/mirror` - **Risk:** read-only

> What your code promises, and what prod really does, are two different stories.

Matches exported logs statistically against code expectations: dead features,
swallowed errors, unexpected hot paths, "impossible" states that fire anyway.
Works completely offline on exported log files.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/*.ps1` requires PowerShell (5.1+ or 7+). Available natively on Windows.
  On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.
- Exported log files (`.log`/`.txt`/`.jsonl`/`.json`) - no live connection
  to observability platforms needed or supported.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/runtime/prod-mirror ~/.claude/skills/runtime/prod-mirror
# or project-local:
cp -r skill-shop-agents/skills/runtime/prod-mirror <your-project>/.claude/skills/runtime/prod-mirror
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\runtime\prod-mirror $HOME\.claude\skills\runtime\prod-mirror
```

## Usage

In Claude Code:

```
/mirror                          # interactive
/mirror <repo> <logdir>          # compare code vs logs
/mirror -help
```

Details: [`SKILL.md`](SKILL.md).
