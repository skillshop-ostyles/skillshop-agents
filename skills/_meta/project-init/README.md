# project-init

Available - **Trigger:** `/project-init` - **Risk:** writing (only after approval)

> An empty directory, a good conversation, a finished foundation.

Runs an interactive onboarding interview and scaffolds a new project completely
- structure, tooling, ops docs. Instead of guessing an empty repo, `project-init`
asks specifically about goal, stack, structure, tooling, docs, secrets and platform,
and writes a complete, consistent foundation including `manifest.md` and
`tracking.md` that every later session automatically reads back.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- Script `scripts/init.ps1` requires PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**, developed
  on Windows.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/_meta/project-init ~/.claude/skills/_meta/project-init       # global
# or project-local:
cp -r skill-shop-agents/skills/_meta/project-init <your-project>/.claude/skills/_meta/project-init
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\_meta\project-init $HOME\.claude\skills\_meta\project-init
```

## Usage

In Claude Code, in the (empty) target project:

```
/project-init                 # interactive onboarding in current directory
/project-init <path>          # interactive onboarding in <path>
/project-init -help          # short help
```

Details: [`SKILL.md`](SKILL.md).
