# dead-code-burier

Available - **Trigger:** `/bury` - **Risk:** writing (only after approval)

> Dead code does not die on its own. Someone must bury it - with evidence.

Identifies provably unreachable code (static unreachability + optional
coverage/log evidence + git age) and buries it - **never automatically**,
only after your explicit individual approval per candidate.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/*.ps1` requires PowerShell (5.1+ or 7+). Available natively on Windows.
  On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.
- For age evidence: a local git repo (optional, otherwise this part omitted).

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/dead-code-burier ~/.claude/skills/quality/dead-code-burier
# or project-local:
cp -r skill-shop-agents/skills/quality/dead-code-burier <your-project>/.claude/skills/quality/dead-code-burier
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\quality\dead-code-burier $HOME\.claude\skills\quality\dead-code-burier
```

## Usage

In Claude Code:

```
/bury                                # interactive
/bury <dir>                          # static + git age only
/bury <dir> -coverage <report>       # plus coverage evidence
/bury <dir> -logs <logdir>           # plus log evidence
/bury -help
```

Details (including the approval rule before any deletion): [`SKILL.md`](SKILL.md).
