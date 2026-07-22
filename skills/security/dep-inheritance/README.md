# dep-inheritance

Available - **Trigger:** `/deps-audit` - **Risk:** read-only

> Every dependency was married into the family. Time for the inheritance questions.

Answers for each direct dependency: purpose (from actual usage sites), real
coupling depth, risk, replaceability and a concrete exit plan.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/*.ps1` requires PowerShell (5.1+ or 7+). Available natively on Windows.
  On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.
- For registry metadata (optional): internet access. Without network the skill runs
  with a clear note (offline fallback is mandatory).

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/security/dep-inheritance ~/.claude/skills/security/dep-inheritance
# or project-local:
cp -r skill-shop-agents/skills/security/dep-inheritance <your-project>/.claude/skills/security/dep-inheritance
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\security\dep-inheritance $HOME\.claude\skills\security\dep-inheritance
```

## Usage

In Claude Code:

```
/deps-audit                    # interactive, all direct dependencies
/deps-audit <dir>              # analyze project
/deps-audit <dir> <dep> [...]  # only specified dependencies
/deps-audit -help
```

Details: [`SKILL.md`](SKILL.md).
