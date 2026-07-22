# doc-drift-detector

Available - **Trigger:** `/doc-drift` - **Risk:** read-only

> Your README has been lying for six months. Time to catch it.

Extracts verifiable doc claims - paths, commands, config keys,
endpoints, versions, symbol references - and statically checks each against the
code reality. Documented commands are never executed.

## Installation

### Prerequisites

- [Claude Code](https://claude.com/claude-code) installed.
- `scripts/claim-extract.ps1` requires PowerShell (5.1+ or 7+). Available natively on
  Windows. On macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) - **cross-platform operation not yet tested**,
  developed on Windows.

### Via Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/quality/doc-drift-detector ~/.claude/skills/quality/doc-drift-detector
# or project-local:
cp -r skill-shop-agents/skills/quality/doc-drift-detector <your-project>/.claude/skills/quality/doc-drift-detector
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\quality\doc-drift-detector $HOME\.claude\skills\quality\doc-drift-detector
```

## Usage

In Claude Code:

```
/doc-drift               # interactive
/doc-drift <dir>         # check repo docs
/doc-drift -help
```

Details: [`SKILL.md`](SKILL.md).
