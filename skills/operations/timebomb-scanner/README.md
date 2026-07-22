# timebomb-scanner

Available - **Trigger:** `/timebomb` - **Risk:** read-only

> Every codebase ticks. This one tells you when.

Finds hardcoded expiry dates, expiry keywords, rotten "temporary" markers (with
git age) and 32-bit time suspicion - sorted by detonation date.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/timebomb-scan.ps1` requires PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.
- For age analysis of provisional markers: a local git repo (optional, otherwise
  this evaluation is simply omitted).

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/operations/timebomb-scanner ~/.claude/skills/operations/timebomb-scanner
# or project-local:
cp -r skill-shop-agents/skills/operations/timebomb-scanner <your-project>/.claude/skills/operations/timebomb-scanner
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\operations\timebomb-scanner $HOME\.claude\skills\operations\timebomb-scanner
```

## Usage

In Claude Code:

```
/timebomb               # interactive
/timebomb <dir>         # scan project
/timebomb -help
```

Details: [`SKILL.md`](SKILL.md).
