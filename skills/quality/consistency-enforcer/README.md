# consistency-enforcer

Available - **Trigger:** `/consist` - **Risk:** read-only

> One rule, fourteen implementations - and nobody knows which one is correct.

Finds semantically identical business rules in different code (not text duplicates)
and reports divergences between their implementations with a
single-source-of-truth proposal.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/rule-candidates.ps1` requires PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/consistency-enforcer ~/.claude/skills/quality/consistency-enforcer
# or project-local:
cp -r skill-shop-agents/skills/quality/consistency-enforcer <your-project>/.claude/skills/quality/consistency-enforcer
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\quality\consistency-enforcer $HOME\.claude\skills\quality\consistency-enforcer
```

## Usage

In Claude Code:

```
/consist                  # interactive
/consist <dir>            # entire directory
/consist <dir> "<focus>"  # with domain focus
/consist -help
```

Details: [`SKILL.md`](SKILL.md).
