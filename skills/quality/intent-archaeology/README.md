# intent-archaeology

Available - **Trigger:** `/intent` - **Risk:** read-only

> Why does this code exist? Your repo remembers.

Reconstructs the intent story of a file from git history, blame and
ticket IDs - with commit evidence. Analyzes one file (optionally a symbol within it)
per run and delivers a chronological why-story with confidence levels instead of
guesses.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/git-mine.ps1` requires PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.
- A local git repo with history as analysis target.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/intent-archaeology ~/.claude/skills/quality/intent-archaeology
# or project-local:
cp -r skill-shop-agents/skills/quality/intent-archaeology <your-project>/.claude/skills/quality/intent-archaeology
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\quality\intent-archaeology $HOME\.claude\skills\quality\intent-archaeology
```

## Usage

In Claude Code:

```
/intent                          # interactive: ask for repo, file, optional symbol
/intent <repo> <file>            # file analysis
/intent <repo> <file> <symbol>   # symbol analysis
/intent -help                   # short help
```

Details: [`SKILL.md`](SKILL.md).
