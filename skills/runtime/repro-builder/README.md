# repro-builder

Available - **Trigger:** `/repro` - **Risk:** writing (only in own `repro/`
working folder, never in target project)

> "Doesn't work" is not an answer. A runnable repro is.

Turns a vague bug report into a minimal, actually EXECUTED repro test
(max 5 attempts) - or a precise list of which information is missing to reproduce.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/env-snapshot.ps1` requires PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.
- A runtime matching the target project (Node/Python/.NET/Go) so the generated
  repro artifact can be executed.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/runtime/repro-builder ~/.claude/skills/runtime/repro-builder
# or project-local:
cp -r skill-shop-agents/skills/runtime/repro-builder <your-project>/.claude/skills/runtime/repro-builder
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\runtime\repro-builder $HOME\.claude\skills\runtime\repro-builder
```

## Usage

In Claude Code:

```
/repro                          # interactive
/repro <repo>                   # report will be prompted
/repro <repo> <report-file>     # report from file
/repro -help
```

Details: [`SKILL.md`](SKILL.md).
