# elevate

Available - **Trigger:** `/elevate` - **Risk:** writing (only after approval)

> Your project deserves enterprise level - without paying for it or inventing it
> yourself.

Audits a project against 7 enterprise dimensions (tests+coverage, lint/format,
CI/CD, secrets hygiene, docs, type-safety, dependency audit) and elevates it - only the
parts you individually approve. Generic across stacks and CI systems, runs
completely locally.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- Scripts in `scripts/*.ps1` require PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**, developed
  on Windows.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/_meta/elevate ~/.claude/skills/_meta/elevate       # global, all projects
# or project-local:
cp -r skill-shop-agents/skills/_meta/elevate <your-project>/.claude/skills/_meta/elevate
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\_meta\elevate $HOME\.claude\skills\_meta\elevate
```

## Usage

In Claude Code, in the target project:

```
/elevate                 # audit + elevate current directory
/elevate <path>          # audit + elevate <path>
/elevate -help          # short help
```

Details: [`SKILL.md`](SKILL.md).
